const std = @import("std");
const uart = @import("../uart.zig");
const uefi = @import("std").os.uefi;

pub const PagingLevel = [512]u64;
const PAGE_ADDR_MASK: u64 =  0x000ffffffffff000; // 52 bit, page aligned address

const PRESENT_FLAG 	= 1 << 0;
const RW_FLAG 			= 1 << 1;
const USR_FLAG 			= 1 << 2;

const STACK_SIZE = 6;

var pml4: *PagingLevel = undefined;
var empty_paging_tables: []PagingLevel = undefined;
var tables_used: usize = 0;

pub inline fn enable() void {
	asm volatile (
		\\ mov %[pml4_ptr], %%cr3
		:: [pml4_ptr] "r" (@intFromPtr(pml4) & PAGE_ADDR_MASK)
	);
}

pub fn initialize(
	allocated: []PagingLevel,
	kernel_paddr: u64,
	kernel_vaddr: u64,
	kernel_size: u64,
	stack_paddr: u64,
	mmap: uefi.tables.MemoryMapSlice
) void {
	empty_paging_tables = allocated;
	pml4 = @ptrFromInt(get_level());

	// Set up kernel paging tables
	// We need to map:
	// - Kernel code and data
	// - Kernel stack
	// - Runtime uefi services
	map_pages(kernel_paddr, kernel_size, kernel_vaddr - kernel_paddr);
	map_pages(stack_paddr, STACK_SIZE, 0);

	var iter = mmap.iterator();
	while (iter.next()) |descr| {
		if (descr.type == .runtime_services_data or descr.type == .runtime_services_code) {
			map_pages(descr.physical_start, descr.number_of_pages, 0);
		}
	}
}

fn get_level() u64 {
	const ptr = &empty_paging_tables[tables_used];
	tables_used += 1;
	uart.printf("[VMM]\t{}/{} paging tables used\n\r", .{tables_used, empty_paging_tables.len});
	return @intFromPtr(ptr);
}

pub fn map_pages(base: u64, npages: u64, delta: u64) void {
	for (0..npages) |p| {
		const paddr = base + (p*4096);
		map_addr(paddr + delta, paddr);
	}
}

// Allocates memory for, and fills paging tables as necessary to have a page entry, mapping vaddr -> paddr
// Basically ported from here: https://blog.llandsmeer.com/tech/2019/07/21/uefi-x64-userland.html
pub fn map_addr(vaddr: u64, paddr: u64) void {
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

