const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const std = @import("std");
const expect = std.testing.expect;

var con_out: *uefi.protocol.SimpleTextOutput = undefined;
var boot_services: *uefi.tables.BootServices = undefined;

inline fn hlt() void {
	asm volatile("hlt");
}

fn echo(msg: []const u8) void {
	for (msg) |c| {
		const uc = [1:0]u16{c};
		_ = con_out.outputString(&uc) catch {};
	}
}

// https://en.wikipedia.org/wiki/Memory_map
fn load_mmap() !uefi.tables.MemoryMapSlice {
	const mmap_info = try boot_services.getMemoryMapInfo();
	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;

	var buf: [32]u8 = undefined;
	const res = try std.fmt.bufPrint(&buf, "Size of mmap: {}\n\r", .{mmap_size});
	echo(res);

	const mmap_buffer = try boot_services.allocatePool(.loader_data, mmap_size + 128);
	return try boot_services.getMemoryMap(mmap_buffer);
}

fn display_mmap(mmap: *const uefi.tables.MemoryMapSlice) !void {
	var buf: [64]u8 = undefined;
	var mmap_iter = mmap.iterator();
	while (mmap_iter.next()) |descr| {
		const phys = descr.physical_start;
		const vir = descr.virtual_start;
		const pages = descr.number_of_pages;
		const res = try std.fmt.bufPrint(&buf, "Phys: {}\t\tVir: {}\t\t# Pages: {}\n\r", .{phys, vir, pages});
		echo(res);
	}
}

// Allocates a buffer from UEFI boot service memory pool 
// Then fills it with bytes read from file starting at provided position
fn allocate_and_read(file: *uefi.protocol.File, position: u64, size: usize) ![]u8 {
	const buffer = try boot_services.allocatePool(.loader_data, size);
	try file.setPosition(position);
	_ = try file.read(buffer);
	return buffer;
}

// https://wiki.osdev.org/Rolling_Your_Own_Bootloader
fn load_kernel_image(
	root_filesystem: *const uefi.protocol.File,
	kernel_path: [*:0]const u16,
) !void {
	// Locate kernel image
	echo("Locating kernel image...\n\r");
	var kernel = try root_filesystem.open(kernel_path, .read, .{.read_only = true});
	defer kernel.close() catch {};

	// Allocate memory for kernel + load into memory
	const ehdr: *elf.Elf64.Ehdr = @ptrCast(@alignCast(try allocate_and_read(kernel, 0, 592)));
	const entry = ehdr.entry;

	try expect(entry == 0x100000);
}


fn bootloader() !void {
	// TODO: better error handling as usual
	const uefi_table = uefi.system_table;

	// Set service pointers
	con_out = uefi_table.con_out.?;
	boot_services = uefi_table.boot_services.?;

	// Load memory map
	var mmap = try load_mmap();
	try display_mmap(&mmap);
	defer boot_services.freePool(@ptrCast(&mmap)) catch {};

	// Find kernel image
	const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernel.elf");
	const fsp = try boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null);
	const root_filesystem = try fsp.?.openVolume();

	try load_kernel_image(root_filesystem, kernel_path);

	while (true) {
		hlt();
	}
}

pub fn main() void {
	// TODO: error handle
	bootloader() catch |err| {
		echo(@errorName(err));
		while (true) {
			hlt();
		}
	};
}
