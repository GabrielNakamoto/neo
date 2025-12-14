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

// Function ensures that no other boot service calls are made between
// getMemoryMap() and exitBootServices() that could mutate system mmap
fn exit_boot_services() !void {
	console.print("Exiting UEFI boot services");
	const final_msg = "\n\rThe Matrix is everywhere...\n\rIt is the world that has been pulled over your eyes to blind you from the truth";
	console.print(final_msg);
	const final_mmap = try load_mmap();
	boot_services.exitBootServices(uefi.handle, final_mmap.info.key) catch |err| {
		console.print("Error: exiting UEFI boot services");
		return err;
	};
}

fn bootloader() !void {
	const uefi_table = uefi.system_table;

	// Initialize service pointers
	console.out = uefi_table.con_out.?;
	boot_services = uefi_table.boot_services.?;
	runtime_services = uefi_table.runtime_services;

	// Find kernel image
	const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernel.elf");
	const fsp = try boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null);
	const root_filesystem = try fsp.?.openVolume();

	var kernel_entry_vaddr: u64 = undefined;
	var kernel_base_paddr: u64 = undefined;
	var kernel_base_vaddr: u64 = undefined;
	_ = try loader.load_kernel_image(
		root_filesystem,
		kernel_path,
		&kernel_entry_vaddr,
		&kernel_base_vaddr,
		&kernel_base_paddr,
	);
	const kernel_entry_absolute = kernel_base_paddr + (kernel_entry_vaddr - kernel_base_vaddr);
	console.printf("Physical kernel entry address: 0x{x}", .{kernel_entry_absolute});

	console.printf("Kernel entry virtual address: 0x{x}", .{kernel_entry_vaddr});
	console.print("Disabling watchdog timer");
	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
        console.print("Error: Disabling watchdog timer failed");
        return err;
    };

	// Keep in mind: no boot service calls can be made from this point, including printing
	try exit_boot_services();

	// Pass kernel info such as segment paddrs as ptr in arg register
	asm volatile (
		\\ mov %[arg], %%rdi
		\\ jmpq *%[entry]
		:
		: [arg] "r" ('A'),
		  [entry] "r" (kernel_entry_absolute)
		: .{ .memory = true }
	);

	return error.LoadError;
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
