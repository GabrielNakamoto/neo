// https://wiki.osdev.org/Paging#64-bit_Paging_2
// https://wiki.osdev.org/CPU_Registers_x86#Control_Registers
// Section 4.5: https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf
// https://blog.zolutal.io/understanding-paging/


// Set up initial page tables:
// - Identity maps some memory for early kernel allocator?
// - Maps the kernel data

const std = @import("std");
const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const console = @import("./console.zig");

const PagingLevel = [512]u64;
const PAGE_ADDR_MASK: u64 =  0x000ffffffffff000; // 52 bit, page aligned address

const PRESENT_FLAG 	= 1 << 0;
const RW_FLAG 		= 1 << 1;
const USR_FLAG 		= 1 << 2;

pub fn enable() void {
}

pub fn allocate_level(boot_services: *uefi.tables.BootServices) !u64 {
	const page_buffer = try boot_services.allocatePages(.any, .loader_data, 1);
	const level_buffer: *[512]u64 = @ptrCast(page_buffer.ptr);

	for (0..512) |i| {
		level_buffer[i]=0;
	}

	return @intFromPtr(level_buffer.ptr);
}

// Allocates memory for and fills paging tables
// as necessary to have a page entry mapping
// vaddr -> paddr
// Basically ported from here: https://blog.llandsmeer.com/tech/2019/07/21/uefi-x64-userland.html
pub fn map_addr(vaddr: u64, paddr: u64, pml4: *PagingLevel, boot_services: *uefi.tables.BootServices) !void {
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
		const pdpt_addr = try allocate_level(boot_services);
		pml4[pml4_idx] = (pdpt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pdpt: *PagingLevel = @ptrFromInt(pml4[pml4_idx] & PAGE_ADDR_MASK);

	if ((pdpt[pdp_idx] & PRESENT_FLAG) == 0) {
		const pdt_addr = try allocate_level(boot_services);
		pdpt[pdp_idx] = (pdt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pdt: *PagingLevel = @ptrFromInt(pdpt[pdp_idx] & PAGE_ADDR_MASK);

	if ((pdt[pd_idx] & PRESENT_FLAG) == 0) {
		const pt_addr = try allocate_level(boot_services);
		pdt[pd_idx] = (pt_addr & PAGE_ADDR_MASK) | flags;
	}

	const pt: *PagingLevel = @ptrFromInt(pdt[pd_idx] & PAGE_ADDR_MASK);

	if ((pt[pt_idx] & PRESENT_FLAG) == 0) {
		pt[pt_idx] = (paddr & PAGE_ADDR_MASK) | flags;
	}
}
