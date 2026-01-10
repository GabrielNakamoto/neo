const std = @import("std");
const uart = @import("../uart.zig");
const uefi = @import("std").os.uefi;
const bump = @import("./bump.zig");
const buddy = @import("./buddy.zig");
const shared = @import("shared");
const layout = @import("../layout.zig");

pub const PagingLevel = [512]u64;
const PAGE_ADDR_MASK: u64 =  0x000ffffffffff000; // 52 bit, page aligned address

const PRESENT_FLAG 	= 1 << 0;
const RW_FLAG 			= 1 << 1;
const USR_FLAG 			= 1 << 2;

var pml4: *PagingLevel = undefined;

pub inline fn enable() void {
	asm volatile (
		\\ mov %[pml4_ptr], %%cr3
		:: [pml4_ptr] "r" (@intFromPtr(pml4) & PAGE_ADDR_MASK)
	);
}

pub fn initialize(boot_info: *shared.BootInfo) void {
	pml4 = @ptrFromInt(get_level());

	// Initial mappings
	var iter = boot_info.final_mmap.iterator();
	while (iter.next()) |descr| {
		if (descr.type == .runtime_services_data or descr.type == .runtime_services_code) {
			map_pages(descr.physical_start, descr.number_of_pages, 0);
		}
	}

	// keep kernel identity mapped to start
	map_pages(
		boot_info.kernel_paddr,
		boot_info.kernel_size,
		0
	);

	// Higher Half Mapping
	map_pages(
		boot_info.kernel_paddr,
		boot_info.kernel_size,
		layout.kernelVirtStart() - boot_info.kernel_paddr
	);

	// Framebuffer
	map_pages(
		boot_info.fb_info.base,
		(boot_info.fb_info.size + 4095) / 4096,
		0
	);

	enable();
	uart.print("Enabled paging\n\r");
}

inline fn get_level() u64 {
	const ptr: *PagingLevel  = bump.alloc(PagingLevel);
	@memset(ptr, 0);
	return @intFromPtr(ptr);
}

pub fn map_pages(base: u64, npages: u64, delta: u64) void {
	// uart.printf("[Paging] Mapping {} pages 0x{x} -> 0x{x}\n\r", .{npages, base, base+delta});
	const aligned_base = base & ~@as(u64, 0xFFF);
	const offset = base - aligned_base;
	const total_size = npages*4096 + offset;
	const total_pages = (total_size+4095)/4096;
	for (0..total_pages) |p| {
		const paddr = aligned_base + (p*4096);
		map_addr(paddr + delta, paddr);
	}
}

// Allocates memory for, and fills paging tables as necessary to have a page entry, mapping vaddr -> paddr
// Basically ported from here: https://blog.llandsmeer.com/tech/2019/07/21/uefi-x64-userland.html
fn map_addr(vaddr: u64, paddr: u64) void {
	const flags = PRESENT_FLAG | RW_FLAG | USR_FLAG;

	// (4) Page Map Level 4
	// (3) Page Directory Ptr Table
	// (2) Page Directory Table
	// (1) Page Table
	const pml4_idx 	= 	(vaddr >> 39) & 0x1ff;
	const pdp_idx 	= 	(vaddr >> 30) & 0x1ff;
	const pd_idx 	= 	(vaddr >> 21) & 0x1ff;
	const pt_idx 	= 	(vaddr >> 12) & 0x1ff;

	if ((pml4[pml4_idx] & PRESENT_FLAG) == 0) {
		const pdpt_addr = get_level();
		pml4[pml4_idx] = (pdpt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pdpt: *PagingLevel = @ptrFromInt(pml4[pml4_idx] & PAGE_ADDR_MASK);

	if ((pdpt[pdp_idx] & PRESENT_FLAG) == 0) {
		const pdt_addr = get_level();
		pdpt[pdp_idx] = (pdt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pdt: *PagingLevel = @ptrFromInt(pdpt[pdp_idx] & PAGE_ADDR_MASK);

	if ((pdt[pd_idx] & PRESENT_FLAG) == 0) {
		const pt_addr = get_level();
		pdt[pd_idx] = (pt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pt: *PagingLevel = @ptrFromInt(pdt[pd_idx] & PAGE_ADDR_MASK);

	if ((pt[pt_idx] & PRESENT_FLAG) == 0) {
		pt[pt_idx] = (paddr & PAGE_ADDR_MASK) | flags;
	}
}

