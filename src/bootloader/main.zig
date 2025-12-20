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

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
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

	// Load kernel segments
	var kernel_entry_vaddr: u64 = undefined;
	var kernel_base_vaddr: u64 = undefined;
	const phdrs_slice = try loader.load_kernel_image(
		root_filesystem,
		kernel_path,
		&kernel_entry_vaddr,
		&kernel_base_vaddr,
	);

	// Set up initial paging tables
	const pml4_ptr = try paging.allocate_level(boot_services);
	const pml4: *paging.PagingLevel = @ptrFromInt(pml4_ptr);

 	// Identity map relevant memory map sections
	const mmap = try load_mmap();
	var mmap_iter = mmap.iterator();
	while (mmap_iter.next()) |descr| {
		if (descr.type == .loader_data or descr.type == .loader_code or descr.type == .boot_services_data or descr.type == .boot_services_code) {
			var offset: u64 = descr.physical_start;
			for (0..descr.number_of_pages) |_| {
				offset += 4096;
				try paging.map_addr(offset, offset, pml4, boot_services);
			}
		}
	}

	// Map kernel segments
	for (phdrs_slice) |phdr| {
		if (phdr.type != .LOAD) { continue; }
		console.printf("Mapping segment address space 0x{x}->0x{x} to 0x{x}->0x{x}", .{phdr.vaddr, phdr.vaddr+phdr.memsz, phdr.paddr, phdr.paddr+phdr.memsz});
		var offset: u64 = 0;
		while (offset < phdr.memsz) : (offset += 4096) {
			try paging.map_addr(phdr.vaddr+offset, phdr.paddr+offset, pml4, boot_services);
		}
	}
	boot_services.freePool(@alignCast(@ptrCast(phdrs_slice.ptr))) catch {};

	console.print("Disabling watchdog timer");
	boot_services.setWatchdogTimer(0, 0, null) catch |err| {
     		console.print("Error: Disabling watchdog timer failed");
     		return err;
    };

	// Keep in mind: no boot service calls can be made from this point, including printing
	const final_mmap = try exit_boot_services();
	const boot_info = .{
		.final_mmap = final_mmap,
	};

	// Update paging tables to allow virtual kernel addressing
	paging.enable(pml4_ptr);

	asm volatile (
		\\ mov %[arg], %%rdi
		\\ jmpq *%[entry]
		:
		: [arg] "r" (&boot_info),
		  [entry] "r" (kernel_entry_vaddr)
		: .{ .memory = true }
	);

	return error.LoadError;
}

pub fn main() void {
	bootloader() catch |err| {
		console.printf("{s}", .{@errorName(err)});
		while (true) {
			hlt();
		}
	};
}
