const std = @import("std");
const uart = @import("../uart.zig");
const uefi = std.os.uefi;
const bump = @import("./bump.zig");
// A simple buddy page frame allocator

// https://www.researchgate.net/publication/324435676_A_Non-blocking_Buddy_System_for_Scalable_Memory_Allocation_on_Multi-core_Machines

const PAGE_SIZE = 4096;

// 4096 * 2^11 = 8.0mib (same as linux)
const MAX_ORDER = 11;
// 8 * 8.08mib = 64mib total coverage
const TOP_LEVEL_WIDTH = 8;

const LEAF_COUNT = 2 << (MAX_ORDER-1);
const TOTAL_NODES = (LEAF_COUNT << 1) - 1;

// number of bytes the in memory rep takes up
const N = std.math.divCeil(usize, TOTAL_NODES * TOP_LEVEL_WIDTH, 8); 

var NODE_STATES: [N]u8 = [_]u8 { 0 } ** N;
var memory_region_start: u64 = 0;
var memory_region_size: u64 = 0;

const free_memory_types = [_]uefi.tables.MemoryType {
	.conventional_memory, .boot_services_code, .boot_services_data
};

fn is_free(descr: *uefi.tables.MemoryDescriptor) bool {
	for (free_memory_types) |tp| {
		if (descr.type == tp) return true;
	}
	return false;
}

// Initialize buddy node states
pub fn initialize(mmap: uefi.tables.MemoryMapSlice) void {
	var iter = mmap.iterator();
	var largest_free_start: u64 = 0;
	var largest_free_size: u64 = 0;
	var current_start: u64 = 0;
	var current_size: u64 = 0;
	var last_free = false;
	while (iter.next()) |descr| {
		if (! is_free(descr)) {
			last_free = false;
			continue;
		}

		if (last_free) {
			current_size += descr.number_of_pages;
		} else {
			current_start = descr.physical_start;
			current_size = descr.number_of_pages;
		}
		last_free = true;

		if (current_size > largest_free_size) {
			largest_free_size = current_size;
			largest_free_start = current_start;
		}
	}
	uart.printf("Largest contigous free memory zone at 0x{x} with {} pages\n\r", .{largest_free_start, largest_free_size});

	// TODO: Maybe update tree allocation to use bump allocator at runtime for better coverage (match actual size)?
	var total_size: usize = @min(largest_free_size, LEAF_COUNT * TOP_LEVEL_WIDTH);
	total_size -= total_size % LEAF_COUNT;

	memory_region_start = largest_free_start;
	memory_region_size = total_size;
	uart.printf("Initialized buddy allocator over region: 0x{x} with truncated size: {}mib\n\r", .{memory_region_start, memory_region_size * 4096 / 1_048_576});
}

pub fn alloc(units: u64) *u8 {
}
