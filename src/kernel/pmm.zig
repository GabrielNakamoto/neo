const std = @import("std");
const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");
const vmm = @import("./vmm.zig");
const expect = std.testing.expect;

const free_memory_types = [_]uefi.tables.MemoryType {
	.conventional_memory, .boot_services_code, .boot_services_data
};

pub fn foo(mmap: uefi.tables.MemoryMapSlice) void {
	var iter = mmap.iterator();
	var cur_descr: ?*uefi.tables.MemoryDescriptor = null;
	while (iter.next()) |descr| {
		if (cur_descr == null) {
			cur_descr.? = descr;
			continue;
		}
		const cdescr = cur_descr.?;

		const free = (cdescr.type == .boot_services_data or cdescr.type == .boot_services_code or cdescr.type == .conventional_memory) and 
			(descr.type == .boot_services_data or descr.type == .boot_services_code or descr.type == .conventional_memory);
		const loader = (cdescr.type == .loader_data or cdescr.type == .loader_code) and 
			(descr.type == .loader_data or descr.type == .loader_code);

		if (loader or free) {
			cdescr.number_of_pages += descr.number_of_pages;
			if (free) { cur_descr.?.type = .conventional_memory; }
		} else {
			uart.printf("{s:<25}0x{x:0>16}\t{}\n\r", .{@tagName(cdescr.type), cdescr.physical_start, cdescr.number_of_pages});
			cur_descr.? = descr;
		}
	}
	uart.printf("{s:<25}0x{x:0>16}\t{}\n\r", .{@tagName(cur_descr.?.type), cur_descr.?.physical_start, cur_descr.?.number_of_pages});
}

// We start off by choosing some large contigous chunk of memory
// (does not all have to be free)
// Then we find the largest exponent of 2 of page frames that is contained
// within this main memory zone.

// Each level can be represented as a bitmap of size N where
// N = aligned_zone_size / (2^(max_oom - oom))
//
// Go bottom up, fill oom=0 first then use that information to 
// categorize free/used higher level states

const MAX_BUDDY_OOM = 5; // 4096 * (2 ^ 7) ~524kb top level blocks
const PAGE_DATA = 4096 - (MAX_BUDDY_OOM * @sizeOf(BuddyNode));

const BuddyNode = packed struct {
	magic: u8,
	next: u64,
};

const PageFrame = struct {
	buddy_nodes: [MAX_BUDDY_OOM]BuddyNode,
	data: [PAGE_DATA]u8,
};

var buddy_heads = [_]BuddyNode{.{.magic=0xBD, .next=0}} ** MAX_BUDDY_OOM;

fn is_free(descr: *uefi.tables.MemoryDescriptor) bool {
	for (free_memory_types) |tp| {
		if (descr.type == tp) return true;
	}
	return false;
}

pub fn map_memory(mmap: uefi.tables.MemoryMapSlice) void {
	var iter = mmap.iterator();
	var zone_start: ?u64 = null;
	var zone_end: u64 = 0;
	while (iter.next()) |descr| {
		if (! is_free(descr)) continue;

		if (zone_start == null) {
			zone_start = descr.physical_start;
		}
		zone_end = descr.physical_start + (descr.number_of_pages * 4096);
	}
	uart.printf("Chose physical memory zone 0x{x}->0x{x}\n\r", .{zone_start.?, zone_end});

	const zone_size = zone_end - zone_start.?;
	const zone_pages = zone_size / 4096;
	const max_oom: u64 = @min(MAX_BUDDY_OOM, @as(u64, @intCast(std.math.log2(zone_size))));
	const top_level_block_sz = std.math.pow(u64, 2, max_oom) * 4096;
	const buddy_start = zone_start.?;
	const buddy_end = buddy_start + (@divFloor(zone_size, top_level_block_sz) * top_level_block_sz);

	_ = zone_pages;
	_ = buddy_end;

	// First pass iterate along UEFI memory map at same time to figure out free pages
	iter = mmap.iterator();
	var last_node: *BuddyNode = &buddy_heads[0];
	while (iter.next()) |descr| {
		if (! is_free(descr)) continue;

		// Add page to order 0 free list
		uart.printf("Adding pages to order 0 free list: 0x{x}\n\r", .{descr.physical_start});
		vmm.map_pages(descr.physical_start, descr.number_of_pages, 0);

		for (0..descr.number_of_pages) |n| {
			uart.printf("Adding page to free list: 0x{x}\n\r", .{descr.physical_start + (n*4096)});
			var page_frame: *PageFrame = @ptrFromInt(descr.physical_start + (n*4096));
			last_node.next = @intFromPtr(&page_frame.buddy_nodes[0]);
			last_node = &page_frame.buddy_nodes[0];
		}
	}
}
