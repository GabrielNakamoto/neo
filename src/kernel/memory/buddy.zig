// A simple buddy page frame allocator
const std = @import("std");
const uart = @import("../uart.zig");
const uefi = std.os.uefi;
const bump = @import("./bump.zig");

const PageFrame = [4096]u8;
const PAGE_SIZE = 4096;

// 4096 * 2^11 = 8.0mib (same as linux)
const DEPTH = 11;
// 8 * 8.08mib = 64mib total coverage
const TOP_LEVEL_WIDTH = 8;
var actual_width: u64 = 0;

const LEAF_COUNT = 1 << DEPTH;
const TOTAL_NODES = (LEAF_COUNT << 1) - 1;


inline fn get_physical_start(subtree: u64, l: u64, node: u64) u64 {
	const level_offset = node - (@as(u64,1) << @truncate(l));
	const pages = @as(u64,1) << @truncate(DEPTH - l);
	return memory_region_start + (subtree*LEAF_COUNT + level_offset*pages)*PAGE_SIZE;
}

// TODO: remove Floating Point ops
inline fn get_level(pages: u64) u6 {
	var partition: f64 = @floatFromInt(LEAF_COUNT);
	partition /= @floatFromInt(pages);
	const level: u6 = @intFromFloat(@floor(@log2(partition)));
	return @min(level, DEPTH);
}

// adjusts for 0 indexed level
// 2^(level-1) -> (2^level) - 1
inline fn get_level_range(l: u6) struct { u64, u64 } {
	const from: u64 	= @as(u64, 1) << l;
	const to: u64 		= (@as(u64, 1) << (l+1)) - 1;
	return .{ from, to+1 };
}

// What is the layout of each tree / how should nodes be accessed?
// Order 0 -> d in memory
var free_trees = std.mem.zeroes([TOP_LEVEL_WIDTH][TOTAL_NODES]u1);
var memory_region_start: u64 = 0;
var memory_region_size: u64 = 0;

// Recursively checks if any child nodes are occupied
// TODO: optimize, caching or something??
fn is_free(level: usize, node: usize, subtree: usize) bool {
	if (level == DEPTH) {
		return free_trees[subtree][node] == 0;
	}

	if (free_trees[subtree][node] == 1) {
		return false;
	}

	const level_start, _ = get_level_range(@intCast(level));
	const n = node - level_start;

	const next_level_start, _ = get_level_range(@intCast(level+1));
	const lchild = next_level_start + n*2;
	const rchild = next_level_start + n*2 + 1;

	return is_free(level+1, lchild, subtree) and is_free(level+1, rchild, subtree);
}

// Recursively update parent states if sibling is also occupied
fn prop_occupy_up(level: usize, node: usize, subtree: usize) void {
	if (level == 0) return;

	const level_start, _ = get_level_range(@intCast(level));
	const n = node - level_start;

	const sibling = if (n%2 == 0) n+1 else n-1;
	if (free_trees[subtree][level_start + sibling] != 1) return;

	const parent_level_start, _ = get_level_range(@intCast(level-1));
	const parent_idx = @as(f64, @floatFromInt(n)) / 2.0;
	const parent = parent_level_start + @as(u64, @intFromFloat(@ceil(parent_idx)));

	prop_occupy_up(level-1, parent, subtree);
}


// --- API ---


pub fn initialize(largest_free_start: u64, largest_free_size: u64) void {
	// TODO: Maybe update tree allocation to use bump allocator at runtime for better coverage (match actual size)?
	var total_size: usize = @min(largest_free_size, LEAF_COUNT * TOP_LEVEL_WIDTH);
	total_size -= total_size % LEAF_COUNT;

	actual_width = total_size /  LEAF_COUNT;
	memory_region_start = largest_free_start;
	memory_region_size = total_size;
	uart.printf("Initialized buddy allocator over region: 0x{x} with truncated size: {}mib\n\r", .{memory_region_start, memory_region_size * 4096 / 1_048_576});
}

pub fn alloc(pages: u64) []PageFrame {
	// start with linear search
	const l = get_level(pages);
	const range_start, const range_end_inclusive = get_level_range(@intCast(l));
	// uart.printf("[Buddy] Searching for {} pages at level {} through range {}->{}\n\r", .{pages, l, range_start, range_end_inclusive});
	for (0..actual_width) |w| {
		for (range_start..range_end_inclusive) |i| {
			// (1) Check if any child nodes are occupied?
			if (is_free(l, i, w)) {
				// (2) Propogate occupation upwards and downwards
					// uart.printf("[Buddy] Found free node, subtree={}, level={} index={}\n\r", .{w, l, i});
					free_trees[w][i]=1;
					// Set sub nodes to allocated
					for (l+1..DEPTH+1) |sl| {
						const offset = i - range_start + 1;
						const sl_range = @as(u64, 1) << @truncate(sl - l);
						const sl_start = (@as(u64, 1) << @truncate(sl)) + (offset-1)*sl_range;
						@memset(free_trees[w][sl_start..sl_start+sl_range], 1);
					}

					prop_occupy_up(l, i, w);

					const frame_ptr: [*]PageFrame = @ptrFromInt(get_physical_start(w, l, i));
					return frame_ptr[0..pages];
			}
		}
	}
	@panic("Buddy allocator couldnt find space (TODO: implement better error handling)");
}

pub fn free() void {
}
