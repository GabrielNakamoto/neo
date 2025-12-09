const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const std = @import("std");

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

fn load_mmap() !uefi.tables.MemoryMapSlice {
	const mmap_info = try boot_services.getMemoryMapInfo();
	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;

	var buf: [32]u8 = undefined;
	const res = try std.fmt.bufPrint(&buf, "Size of mmap: {}\n\r", .{mmap_size});
	echo(res);

	const mmap_buffer = try boot_services.allocatePool(.boot_services_data, mmap_size);
	return try boot_services.getMemoryMap(mmap_buffer);
}

fn bootloader() !void {
	const uefi_table = uefi.system_table;

	con_out = uefi_table.con_out.?;
	boot_services = uefi_table.boot_services.?;

	echo("Hello, uefi!\n\r");

	const mmap = try load_mmap();

	var buf: [64]u8 = undefined;
	var mmap_iter = mmap.iterator();
	while (mmap_iter.next()) |descr| {
		const phys = descr.physical_start;
		const vir = descr.virtual_start;
		const pages = descr.number_of_pages;
		const res = try std.fmt.bufPrint(&buf, "Phys: {} Vir: {} # Pages: {}\n\r", .{phys, vir, pages});
		echo(res);
	}

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
