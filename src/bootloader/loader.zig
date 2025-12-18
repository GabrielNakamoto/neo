const console = @import("./console.zig");
const std = @import("std");
const elf = @import("std").elf;
const uefi = @import("std").os.uefi;

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

// https://wiki.osdev.org/ELF#Loading_ELF_Binaries
// Read PT_LOAD segment directly from kernel image into memory
// Return physical address where it was placed
fn load_elf_segment(
	elf_file: *uefi.protocol.File,
	phdr: *elf.Elf64.Phdr,
) !usize {
	// Allocate system memory
	// Has to be by pages because ELF says so (neater?)

	// Allocate the amount of memory needed for the segment (memsz)
	const pages_needed = (phdr.memsz + (4095)) / 4096;
	const seg_buf = boot_services.allocatePages(
		.any,
		// .{ .address=@ptrFromInt(segment_physical_address), },
		.loader_data,
		pages_needed
	) catch |err| {
		console.print("Error: allocating buffer for elf segment");
		return err;
	};

	// Set the length to filesz so we only read the segments file content
	const segment_buffer = @as([*]u8, @ptrCast(seg_buf.ptr))[0..phdr.filesz];

	//Load the segment into the memory
	try elf_file.setPosition(phdr.offset);
	_ = try elf_file.read(segment_buffer);

	// Zero fill padding
	const rem: [*]u8 = @ptrCast(seg_buf.ptr);
	for (phdr.filesz..phdr.memsz) |i| {
		rem[i]=0;
	}
	
	return @intFromPtr(seg_buf.ptr);
}

pub fn load_kernel_image(
	root_filesystem: *const uefi.protocol.File,
	kernel_path: [*:0]const u16,
	kernel_entry_vaddr: *u64,
	kernel_base_vaddr: *u64,
) ![]elf.Elf64.Phdr {
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
	defer boot_services.freePool(@alignCast(ehdr_buffer.ptr)) catch {};
	const ehdr = std.mem.bytesAsValue(elf.Elf64.Ehdr, ehdr_buffer);
	kernel_entry_vaddr.* = ehdr.entry;

	const phdrs_buffer = try allocate_and_read(kernel, .boot_services_data, ehdr.phoff, ehdr.phentsize * ehdr.phnum);
	const phdrs: [*]elf.Elf64.Phdr = @ptrCast(@alignCast(phdrs_buffer)); // Kinda unsafe
	console.print("Loaded kernel ELF headers into memory");

	// Load loadable ELF segments
	// Reuse phdr slice to build paging tables
	var first_segment = true;
	const phdrs_slice = phdrs[0..ehdr.phnum];
	for (phdrs_slice) |*phdr| {
		if (phdr.type != .LOAD) { continue; }

		const allocated_paddr = try load_elf_segment(kernel, phdr);
		phdr.paddr = allocated_paddr;

		if (first_segment) {
			first_segment = false;
			kernel_base_vaddr.* = phdr.vaddr;
		}
	}

	console.print("Loaded kernel ELF segments to main memory");
	return phdrs_slice;
}

