// https://www.programmersought.com/article/77814539630/
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/
// https://wiki.osdev.org/Rolling_Your_Own_Bootloader
// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf
// https://en.wikipedia.org/wiki/Memory_map
// https://wiki.osdev.org/Memory_management

const console = @import("./console.zig");
const loader = @import("./loader.zig");
const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const std = @import("std");
const expect = std.testing.expect;

var boot_services: *uefi.tables.BootServices = undefined;

inline fn hlt() void {
	asm volatile("hlt");
}

fn load_mmap(
	mmap_info: *uefi.tables.MemoryMapInfo
) !uefi.tables.MemoryMapSlice {
	mmap_info.* = try boot_services.getMemoryMapInfo();
	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;

	console.printf("Size of mmap: {}", .{mmap_size});

	const mmap_buffer = boot_services.allocatePool(.loader_data, mmap_size + 128) catch |err| {
		console.print("Error: Allocating memory map buffer");
		return err;
	};
	return try boot_services.getMemoryMap(mmap_buffer);
}

fn display_mmap(mmap: *const uefi.tables.MemoryMapSlice) void {
	var mmap_iter = mmap.iterator();
	var type_pages = std.mem.zeroes([@typeInfo(uefi.tables.MemoryType).@"enum".fields.len]u64);

	while (mmap_iter.next()) |descr| {
		const pages = descr.number_of_pages;
		type_pages[@intFromEnum(descr.type)] += pages;
	}

	for (type_pages, 0..) |pages, tp_| {
		if (pages > 0) {
			const tp: uefi.tables.MemoryType = @enumFromInt(tp_);
			console.printf("Memory type: {s}, Pages Available: {}", .{@tagName(tp), pages});
		}
	}
}

// https://wiki.osdev.org/A20_Line#Fast_A20_Gate
inline fn fast_a20_gate() void {
	asm volatile (
		\\ in al, 0x92
		\\ or al, 2
		\\ out 0x92, al
	);
}

fn bootloader() !void {
	// fast_a20_gate();
	// TODO: better error handling as usual
	const uefi_table = uefi.system_table;

	console.out = uefi_table.con_out.?;

	// Set service pointers
	boot_services = uefi_table.boot_services.?;

	// Load memory map
	const KERNEL_SIZE: u64 = 4488;
	var mmap_info: uefi.tables.MemoryMapInfo = undefined;
	var mmap = try load_mmap(&mmap_info);
	display_mmap(&mmap);

	console.print("Finding free space for kernel image");
	var mmap_iter = mmap.iterator();
	var base_addr: u64 = 0x1000;
	while (mmap_iter.next()) |descr| {
		if (descr.type == .conventional_memory and descr.physical_start > base_addr) {
			base_addr = descr.physical_start;
			const pages = descr.number_of_pages;
			const needed = (KERNEL_SIZE + (4095)) / 4096;
			if (pages > needed) {
				break;
			}
		}
	}
	// try boot_services.freePool(@ptrCast(&mmap));
	console.printf("Kernel physical addr chosen: 0x{x}", .{base_addr});
	// try display_mmap(&mmap);

	// Find kernel image
	const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernel.elf");
	const fsp = try boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null);
	const root_filesystem = try fsp.?.openVolume();

	// var kernel_entry_address: u64 = undefined;
	// var kernel_entry: *const fn () callconv(.c) void = undefined;
	var kernel_start: u64 = undefined;
	try loader.load_kernel_image(root_filesystem, kernel_path, base_addr, &kernel_start);

	// const kernel_entry: *const fn () callconv(.c) void = @ptrFromInt(kernel_start);
	// kernel_entry()

	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
        console.print("Error: Disabling watchdog timer failed");
        return err;
    };

	while (true) {
		if (boot_services.exitBootServices(uefi.handle, mmap_info.key)) {
			break;
		} else |err| switch (err) {
			error.InvalidParameter => {
				console.print("Retrying exit boot services");
				continue;
			},
			error.Unexpected => {
				console.print("Error: unexpected error from exitBootServices() call");
				return err;
			},
		}
	}


	while (true) {
		hlt();
	}
}

pub fn main() void {
	// TODO: error handle
	bootloader() catch |err| {
		console.printf("{s}", .{@errorName(err)});
		while (true) {
			hlt();
		}
	};
}
