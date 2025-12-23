const console = @import("./console.zig");
const std = @import("std");
const elf = @import("std").elf;
const uefi = @import("std").os.uefi;
const paging = @import("./paging.zig");

var boot_services: *uefi.tables.BootServices = undefined;

// Allocates a buffer from UEFI boot service memory pool 
// Then fills it with bytes read from file starting at provided position
fn allocate_and_read(
	file: *uefi.protocol.File,
	comptime allocate_type: uefi.tables.MemoryType,
	position: u64,
	size: u32,
) ![]u8 {
	try file.setPosition(position);
	const buffer = try boot_services.allocatePool(allocate_type, size);
	_ = try file.read(buffer);
	return buffer;
}

pub fn load_kernel_image(
	root_filesystem: *const uefi.protocol.File,
	kernel_path: [*:0]const u16,
	kernel_entry_vaddr: *u64,
	kernel_paddr: *u64,
	kernel_size: *u64,
) !void {
	// Populate runtime UEFI pointers
	boot_services = uefi.system_table.boot_services.?;

	// Locate kernel image
	var kernel = root_filesystem.open(kernel_path, .read, .{.read_only = true}) catch |err| {
		console.print("Error: locating kernel image in filesystem");
		return err;
	};
	defer kernel.close() catch {};
	console.print("Located kernel image");

	// Load ELF header and program headers into memory
	const ehdr_buffer = try allocate_and_read(kernel, .boot_services_data, 0, 64);
	const ehdr = std.mem.bytesAsValue(elf.Elf64.Ehdr, ehdr_buffer);

	const phdrs_buffer = try allocate_and_read(kernel, .boot_services_data, ehdr.phoff, ehdr.phentsize * ehdr.phnum);
	const phdrs: [*]elf.Elf64.Phdr = @ptrCast(@alignCast(phdrs_buffer)); // Kinda unsafe
	const phdrs_slice = phdrs[0..ehdr.phnum];

	kernel_entry_vaddr.* = ehdr.entry;
	console.printf("Kernel entry: 0x{x}", .{ehdr.entry});

	var kernel_virt_base: u64 = std.math.maxInt(u64);
	var kernel_virt_end: u64 = 0;
	for (phdrs_slice) |phdr| {
		if (phdr.type != .LOAD) continue;
		kernel_virt_base = @min(kernel_virt_base, phdr.vaddr);
		kernel_virt_end = @max(kernel_virt_end, phdr.vaddr+phdr.memsz);
	}
	const kernel_load_size = ((kernel_virt_end - kernel_virt_base) + 4095) / 4096;

	const kernel_buffer: []u8 = @ptrCast(@alignCast(try boot_services.allocatePages(.any, .loader_data, kernel_load_size)));
	const kernel_phys_base = @intFromPtr(kernel_buffer.ptr);
	kernel_paddr.* = kernel_phys_base;
	kernel_size.* = kernel_load_size;

	for (phdrs_slice) |phdr| {
		if (phdr.type != .LOAD) continue;

		const segment_offset = phdr.vaddr - kernel_virt_base;
		const segment_buffer = 	kernel_buffer[segment_offset..segment_offset+phdr.filesz];

		try kernel.setPosition(phdr.offset);
		_ = try kernel.read(segment_buffer);

		const bss_buffer = kernel_buffer[segment_offset+phdr.filesz..segment_offset+phdr.memsz];
		@memset(bss_buffer, 0);
	}

	console.print("Mapping kernel");
	try paging.map_pages(
		kernel_phys_base,
		kernel_load_size,
		kernel_virt_base - kernel_phys_base
	);
}

