// Heap implementation
const std = @import("std");
const buddy = @import("./buddy.zig");
const paging = @import("./vmm.zig");
const layout = @import("../layout.zig");
const uart = @import("../uart.zig");

// TODO:
// - make this doubly linked list for easier semantics
// - check for alignment

// Spacial vs temporal efficiency
// Make each block contain 4 ptrs:
// - prev and next block (allocatedd? or just both)
// - prev and next free block

const Block = struct {
	size: u32,
	is_free: bool,
	next: ?RawPtr,

	const RawPtr = *volatile Block;

	inline fn buffer(self: RawPtr) *u8 {
		return &@as([*]u8, @ptrCast(@volatileCast(self)))[@sizeOf(Block)];
	}

	inline fn joinable(left: RawPtr, right: RawPtr) bool {
		return @intFromPtr(left) + left.size + @sizeOf(Block) == @intFromPtr(right);
	}

	// Returns ptr to new free block, this block becomes allocated one
	fn split(self: RawPtr, requested: u32) RawPtr {
		const base: [*]u8 = @ptrCast(@volatileCast(self));
		const free: *volatile Block = @ptrCast(@alignCast(&base[requested + @sizeOf(Block)]));

		free.size = self.size - requested - @sizeOf(Block);
		free.next = self.next;
		free.is_free = true;

		self.next = null;
		self.size = requested;
		self.is_free = false;

		return free;
	}

	fn try_join_right(self: RawPtr, other: RawPtr) RawPtr {
		if (! self.joinable(other)) return other;

		self.size += other.size + @sizeOf(Block);
		if (other.is_free) {
			self.next = other.next;
		}
		return self;
	}
};

var head: Block.RawPtr = undefined;
var heap_size: usize = 0;

fn find_first_fit(size: usize) ?struct { last: ?Block.RawPtr, found: Block.RawPtr } {
	var block: ?Block.RawPtr = head;
	var last: ?Block.RawPtr = null;

	while (block) |b| {
		if (b.is_free and b.size >= size + @sizeOf(Block)) {
			return .{
				.last = last,
				.found = b
			};
		}
		last = b;
		block = b.next;
	}
	return null;
}

fn expand(n: u32) Block.RawPtr {
	const mem = buddy.alloc(n);
	const paddr = @intFromPtr(mem.ptr);
	const vaddr = layout.kernelHeapStart() + heap_size;
	paging.map_pages(paddr, n, vaddr - paddr);
	@memset(@as([*]u8, @ptrFromInt(vaddr))[0..n*4096], 0);

	const block: Block.RawPtr = @ptrFromInt(vaddr);
	block.size = n*4096 - @sizeOf(Block);
	block.next = null;
	block.is_free = true;

	heap_size += n*4096;
	return block;
}

pub fn debug_freelist() void {
	uart.print("Heap free list:\n\r");
	uart.printf("\tHead -> 0x{x} ({})\n\r", .{@intFromPtr(head), head.size});
	var block = head;
	while (block.next) |b| {
		uart.printf("\tIter -> 0x{x} ({})\n\r", .{@intFromPtr(b), b.size});
		block = b;
	}
}

pub fn init() void {
	head = expand(1);
	uart.printf("Initialized heap at vaddr: 0x{x}\n\r", .{@intFromPtr(head)});
}

pub fn create(T: type) !*T {
	var result = find_first_fit(@sizeOf(T));
	if (result == null) {
		var last = head;
		while (last.next) |b| : (last=b) {}

		const n = (@sizeOf(T) + 4095) / 4096;
		const expansion = expand(n);
		last.next = expansion;
		_ = last.try_join_right(expansion);
		result = find_first_fit(@sizeOf(T));
	}

	if (result) |block| {
		const free = block.found.split(@sizeOf(T));
		if (block.last) |prev| {
			prev.next = free;
		} else {
			head = free;
		}

		const ptr: *T = @ptrCast(@alignCast(block.found.buffer()));
		return ptr;
	} else {
		// expand
		return error.MemoryNotFound;
	}

}

pub fn destroy(ptr: anytype) void {
	const info = @typeInfo(@TypeOf(ptr)).pointer;
	const T = info.child;
	if (@sizeOf(T) == 0) return;
	const freed_ptr = @as([*]u8, @ptrCast(@constCast(ptr))) - @sizeOf(Block);
	const freed_block: *Block = @ptrCast(@alignCast(freed_ptr));
	freed_block.is_free = true;

	std.debug.assert(freed_block.is_free);

	// Check siblings for coalescence
	if (@intFromPtr(freed_block) < @intFromPtr(head)) {
		freed_block.next = head;
		_ = freed_block.try_join_right(head);
		head = freed_block;
	} else {
		var left: Block.RawPtr = head;
		var right: Block.RawPtr = head;
		while (right.next) |b| {
			left = right;
			right = b;
			if (@intFromPtr(right) > @intFromPtr(freed_block)) break;
		}
		left.next = freed_block;

		const head_changed = head == left;
		const joined = left.try_join_right(freed_block);
		if (head_changed) head = joined;
		_ = joined.try_join_right(right);
	}
}
