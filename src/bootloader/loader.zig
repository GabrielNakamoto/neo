const console = @import("./console.zig");
const std = @import("std");
const elf = @import("std").elf;
const uefi = @import("std").os.uefi;

var boot_services: *uefi.tables.BootServices = undefined;

// Allocates a buffer from UEFI boot service memory pool 
// Then fills it with bytes read from file starting at provided position
fn allocate_and_read(
	file: *uefi.protocol.File,
	position: u64,
	size: u32,
) ![]u8 {
	try file.setPosition(position);
	const buffer = try boot_services.allocatePool(.loader_data, size);
	_ = try file.read(buffer);
	return buffer;
}

// Read PT_LOAD segment directly from kernel image
// into conventional memory
fn load_elf_segment(
	elf_file: *uefi.protocol.File,
	phdr: *elf.Elf64.Phdr,
	segment_physical_address: u64,
) !void {
	// Allocate system memory
	// Has to be by pages because ELF says so (neater?)
	const pages_needed = (phdr.filesz + (4095)) / 4096;
	var segment_buffer: []u8 = &.{};
	const seg_buf = boot_services.allocatePages(
		.{ .address=@ptrFromInt(segment_physical_address), },
		.loader_data,
		pages_needed
	) catch |err| {
		console.printf("Error: allocating buffer for elf segment at phaddr: {}", .{segment_physical_address});
		return err;
	};
	segment_buffer.ptr = @ptrCast(seg_buf.ptr);
	segment_buffer.len = seg_buf.len * 4096;
	//Load the segment into the memory
	try elf_file.setPosition(phdr.offset);
	_ = try elf_file.read(segment_buffer);
}

pub fn load_kernel_image(
	root_filesystem: *const uefi.protocol.File,
	kernel_path: [*:0]const u16,
	kernel_base_addr: u64,
	kernel_start_addr: *u64,
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
	const ehdr_buffer = try allocate_and_read(kernel, 0, 64);
	const ehdr: *elf.Elf64.Ehdr = @ptrCast(@alignCast(ehdr_buffer));

	const phdrs_buffer = try allocate_and_read(kernel, ehdr.phoff, ehdr.phentsize * ehdr.phnum);
	const phdrs: [*]elf.Elf64.Phdr = @ptrCast(@alignCast(phdrs_buffer));
	console.print("Loaded kernel ELF headers into memory");

	// Load ELF segments into memory at:
	// offset = first_segment_vaddr - kernel_base_phaddr
	// segment_address = segment_vaddr - offset
	// Ensures that each segment is properly offset
	var index: u32 = 0;
	var entry_segment_found = false; 
	var vir_to_phys: u64 = 0;
	while (index < ehdr.phnum) : (index += 1) {
		if (phdrs[index].type == .LOAD) {
			if (! entry_segment_found) {
				entry_segment_found = true;
				kernel_start_addr.* = phdrs[index].vaddr;
				vir_to_phys = phdrs[index].vaddr - kernel_base_addr;
			}
			try load_elf_segment(kernel, &phdrs[index], phdrs[index].vaddr - vir_to_phys);
		}
	}
	console.print("Loaded kernel ELF segments to main memory");
}

