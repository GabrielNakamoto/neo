// https://www.programmersought.com/article/77814539630/
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/
// https://wiki.osdev.org/Rolling_Your_Own_Bootloader
// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf
// https://en.wikipedia.org/wiki/Memory_map
// https://wiki.osdev.org/Memory_management

const console = @import("./console.zig");
const paging = @import("./paging.zig");
const loader = @import("./loader.zig");
const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const std = @import("std");
const expect = std.testing.expect;

var boot_services: *uefi.tables.BootServices = undefined;
var runtime_services: *uefi.tables.RuntimeServices = undefined;

const final_msg = "\n\rConventional operating systems are everywhere...\n\rThey are the systems that have been pulled over your eyes to blind you from the truth";

const KERNEL_STACK_PAGES = 6;

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	pml4: *paging.PagingLevel,
};

inline fn hlt() void {
	asm volatile("hlt");
}

fn load_mmap() !uefi.tables.MemoryMapSlice {
	const mmap_info = boot_services.getMemoryMapInfo() catch |err| {
		console.print("Error: retrieving UEFI memory map info");
		return err;
	};

	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;
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
fn exit_boot_services() !uefi.tables.MemoryMapSlice {
	console.print("Exiting UEFI boot services");
	console.print(final_msg);
		
	const final_mmap = try load_mmap();
	boot_services.exitBootServices(uefi.handle, final_mmap.info.key) catch |err| {
		console.print("Error: exiting UEFI boot services");
		return err;
	};
	return final_mmap;
}

fn get_graphics() *uefi.protocol.GraphicsOutput.Mode {
	const gop_protocol = boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null) catch unreachable;
	return gop_protocol.?.mode;
}

fn bootloader() !void {
	const uefi_table = uefi.system_table;

	// Initialize service pointers
	console.out = uefi_table.con_out.?;
	boot_services = uefi_table.boot_services.?;
	runtime_services = uefi_table.runtime_services;

	try paging.initialize(boot_services);

	// Find kernel image
	const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernel.elf");
	const fsp = try boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null);
	const root_filesystem = try fsp.?.openVolume();

	// Load kernel segments
	var kernel_entry_vaddr: u64 = undefined;
	try loader.load_kernel_image(
		root_filesystem,
		kernel_path,
		&kernel_entry_vaddr,
	);

	const graphics_mode = get_graphics();

	// Allocate boot info
	const kernel_stack = try boot_services.allocatePages(.any, .loader_data, KERNEL_STACK_PAGES);
	const boot_info: *BootInfo = @ptrCast(@alignCast((try boot_services.allocatePool(.loader_data, @sizeOf(BootInfo))).ptr));
	try paging.map_pages(graphics_mode.frame_buffer_base, (graphics_mode.frame_buffer_size+4096)/4096, 0);

 	// Identity map relevant memory map sections
	const mmap = try load_mmap();
	var mmap_iter = mmap.iterator();
	while (mmap_iter.next()) |descr| {
		if (descr.type == .loader_data or descr.type == .boot_services_code or descr.type == .loader_code or descr.type == .boot_services_data) {
			try paging.map_pages(descr.physical_start, descr.number_of_pages, 0);
		}
	}

	console.print("Disabling watchdog timer");
	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
     	console.print("Error: Disabling watchdog timer failed");
     	return err;
   };

	// Keep in mind: no boot service calls can be made from this point, including printing
	const final_mmap = try exit_boot_services();

	boot_info.* = .{
		.final_mmap = final_mmap,
		.graphics_mode = graphics_mode,
		.pml4 = paging.pml4
	};

	paging.enable();

	asm volatile (
		\\mov %[boot_info], %%rdi
		\\mov %[kernel_stack_top], %%rsp
		\\jmpq *%[entry]
		:
		: [kernel_stack_top] "r" (@intFromPtr(kernel_stack.ptr) + (KERNEL_STACK_PAGES * 4096)),
			[boot_info] "r" (boot_info),
		  [entry] "r" (kernel_entry_vaddr)
		: .{ .memory = true }
	);
	unreachable;
}

pub fn main() void {
	bootloader() catch |err| {
		console.printf("{s}", .{@errorName(err)});
		while (true) {
			hlt();
		}
	};
}
