const console = @import("./console.zig");
const paging = @import("./paging.zig");
const loader = @import("./loader.zig");
const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const std = @import("std");
const expect = std.testing.expect;

var boot_services: *uefi.tables.BootServices = undefined;
var runtime_services: *uefi.tables.RuntimeServices = undefined;

const KERNEL_STACK_PAGES = 6;
const BOOTSTRAP_PAGES_SIZE = 16; //~65kb

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	runtime_services: *uefi.tables.RuntimeServices,
	kernel_paddr: u64,
	kernel_size: u64,
	kernel_vaddr: u64,
	stack_paddr: u64,
	bootstrap_pages: []align(4096) [4096]u8
};

// Preallocate early kernel memory for bootstrapping
// proper page frame allocator

inline fn hlt() void {
	asm volatile("hlt");
}

fn load_mmap() !uefi.tables.MemoryMapSlice {
	const mmap_info = boot_services.getMemoryMapInfo() catch |err| {
		console.print("Error: retrieving UEFI memory map info");
		return err;
	};

	const mmap_size: usize = mmap_info.len * mmap_info.descriptor_size;
	const mmap_buffer = boot_services.allocatePool(.loader_data, mmap_size + 128) catch |err| {
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
	var kernel_paddr: u64 = undefined;
	var kernel_size: u64 = undefined;
	try loader.load_kernel_image(
		root_filesystem,
		kernel_path,
		&kernel_entry_vaddr,
		&kernel_paddr,
		&kernel_size
	);

	const bootstrap_pages = try boot_services.allocatePages(.any, .loader_data, BOOTSTRAP_PAGES_SIZE);
	const graphics_mode = get_graphics();
	const final_mmap_buffer: [*]u8 = @ptrCast(try boot_services.allocatePages(.any, .loader_data, 2));

	try paging.map_pages(@intFromPtr(bootstrap_pages.ptr), BOOTSTRAP_PAGES_SIZE, 0);
	try paging.map_pages(@intFromPtr(final_mmap_buffer), 2, 0);

	// Allocate boot info
	const kernel_stack = try boot_services.allocatePages(.any, .loader_data, KERNEL_STACK_PAGES);
	const boot_info: *BootInfo = @ptrCast(@alignCast((try boot_services.allocatePool(.loader_data, @sizeOf(BootInfo))).ptr));

 	// Identity map relevant memory map sections
	const mmap = try load_mmap();
	var mmap_iter = mmap.iterator();
	while (mmap_iter.next()) |descr| {
		if (descr.type == .loader_data or descr.type == .boot_services_code or descr.type == .loader_code or descr.type == .boot_services_data or descr.type == .runtime_services_data or descr.type == .runtime_services_code) {
			try paging.map_pages(descr.physical_start, descr.number_of_pages, 0);
		}
	}
	//boot_services.freePool(@alignCast(mmap.ptr)) catch {};

	console.print("Disabling watchdog timer");
	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
     	console.print("Error: Disabling watchdog timer failed");
     	return err;
   };

	// Keep in mind: no boot service calls can be made from this point, including printing
	var final_mmap = try exit_boot_services();

	const copy_len = final_mmap.info.len * final_mmap.info.descriptor_size;
	@memcpy(final_mmap_buffer, final_mmap.ptr[0..copy_len]);
	final_mmap.ptr = @alignCast(final_mmap_buffer);

	boot_info.* = .{
		.final_mmap = final_mmap,
		.graphics_mode = graphics_mode,
		.runtime_services = runtime_services,
		.kernel_paddr = kernel_paddr,
		.kernel_size = kernel_size,
		.kernel_vaddr = kernel_entry_vaddr,
		.stack_paddr = @intFromPtr(kernel_stack.ptr),
		.bootstrap_pages = bootstrap_pages
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
