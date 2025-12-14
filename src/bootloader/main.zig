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
var runtime_services: *uefi.tables.RuntimeServices = undefined;

inline fn hlt() void {
	asm volatile("hlt");
}

fn load_mmap() !uefi.tables.MemoryMapSlice {
	const mmap_info = boot_services.getMemoryMapInfo() catch |err| {
		console.print("Error: retrieving UEFI memory map info");
		return err;
	};

	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;

	// console.printf("Size of mmap: {}", .{mmap_size});
	const mmap_buffer = boot_services.allocatePool(.boot_services_data, mmap_size + 128) catch |err| {
		console.print("Error: Allocating memory map buffer");
		return err;
	};

	return boot_services.getMemoryMap(mmap_buffer) catch |err| {
		console.print("Error: getMemoryMap() UEFI call");
		return err;
	};
}

// Function ensures that no other boot service calls are made that could
// make memory map stale
fn exit_boot_services() !uefi.tables.MemoryMapSlice {
	console.print("Exiting UEFI boot services");
	const final_msg = "\n\rThe Matrix is everywhere...\n\rIt is the world that has been pulled over your eyes to blind you from the truth";
	console.print(final_msg);
	const final_mmap = try load_mmap();
	boot_services.exitBootServices(uefi.handle, final_mmap.info.key) catch |err| {
		console.print("Error: exiting UEFI boot services");
		return err;
	};
	return final_mmap;
}

fn bootloader() !void {
	const uefi_table = uefi.system_table;

	// Initialize service pointers
	console.out = uefi_table.con_out.?;
	boot_services = uefi_table.boot_services.?;
	runtime_services = uefi_table.runtime_services;

	// Load memory map
	const KERNEL_SIZE: u64 = 4488;
	var mmap = try load_mmap();

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
	boot_services.freePool(@ptrCast(mmap.ptr)) catch {};
	console.printf("Kernel physical addr chosen: 0x{x}", .{base_addr});

	// Find kernel image
	const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernel.elf");
	const fsp = try boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null);
	const root_filesystem = try fsp.?.openVolume();

	var kernel_virtual_start: u64 = undefined;
	var kernel_entry_addr: u64 = undefined;
	try loader.load_kernel_image(
		root_filesystem,
		kernel_path,
		base_addr,
		&kernel_virtual_start,
		&kernel_entry_addr
	);
	console.printf("Kernel virtual address: 0x{x}, Kernel entry address: 0x{x}", .{kernel_virtual_start, kernel_entry_addr});


	console.print("Disabling watchdog timer");
	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
        console.print("Error: Disabling watchdog timer failed");
        return err;
    };

	// Keep in mind: no boot service calls from this point, including printing
	var fmmap = try exit_boot_services();
	var fmmap_iter = fmmap.iterator();
	while (fmmap_iter.next()) |descr| {
		if (descr.type == .loader_data) {
			// This should be the descriptor for the kernel segments that were loaded
			descr.virtual_start = kernel_virtual_start;
		} else {
			// Identity map
			descr.virtual_start = descr.physical_start;
		}
	}

	try runtime_services.setVirtualAddressMap(fmmap);

	const kernel_entry: *const fn () callconv(.c) void = @ptrFromInt(kernel_entry_addr);
	kernel_entry();

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
