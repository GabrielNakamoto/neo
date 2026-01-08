// Heap implementation
const std = @import("std");
const buddy = @import("./buddy.zig");
const paging = @import("./vmm.zig");
const layout = @import("../layout.zig");
const uart = @import("../uart.zig");

const Block = packed struct {
	size: u32,
	is_free: bool,
	next: ?*volatile Block,

	const Self = @This();

	inline fn buffer(self: *volatile Self) *u8 {
		return &@as([*]u8, @ptrCast(@volatileCast(self)))[@sizeOf(Block)];
	}

	inline fn joinable(left: *volatile Block, right: *volatile Block) bool {
		return @intFromPtr(left) + left.size + @sizeOf(Block) == @intFromPtr(right);
	}

	// Returns ptr to new free block, this block becomes allocated one
	fn split(self: *volatile Self, requested: u32) *volatile Block {
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

	fn try_join_right(self: *volatile Self, other: *volatile Block) bool {
		if (! self.joinable(other)) return false;

		self.size += other.size + @sizeOf(Block);
		if (! other.is_free) {
			self.next = other.next;
		}
		
		uart.printf("Coalesced into new block: addr=0x{x}, size={}\n\r", .{@intFromPtr(self), self.size});
		return true;
	}
};

var head: *volatile Block = undefined;

fn find_first_fit(size: usize) ?struct { last: ?*volatile Block, found: *volatile Block } {
	var block: ?*volatile Block = head;
	var last: ?*volatile Block = null;

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

pub fn init() void {
	const mem = buddy.alloc(1);
	const paddr = @intFromPtr(mem.ptr);
	const vaddr = layout.kernelHeapStart();
	paging.map_pages(paddr, 1, vaddr - paddr);

	@memset(@as([*]u8, @ptrFromInt(vaddr))[0..4096], 0);
	head = @ptrFromInt(vaddr);
	head.size = 4096 - @sizeOf(Block);
	head.next = null;
	head.is_free = true;

	uart.printf("[Heap] Block header size: {}\n\r", .{@sizeOf(Block)});
	uart.printf("[Heap] Initialized heap at vaddr: 0x{x}\n\r", .{vaddr});
}

// - keep track of virtual address space
// - manage dynamic size allocations and free memory within address space
pub fn create(comptime T: type) !*T {
	const result = find_first_fit(@sizeOf(T));

	if (result) |block| {
		const free = block.found.split(@sizeOf(T));
		if (block.last) |prev| {
			prev.next = free;
		} else {
			head = free;
		}
		uart.printf("[Heap] Found block with enough space: 0x{x}, size={}\n\r", .{@intFromPtr(block.found), block.found.size});

		const ptr: *T = @ptrCast(@alignCast(block.found.buffer()));
		uart.printf("[Heap] Returning heap pointer to: 0x{x}\n\r", .{@intFromPtr(ptr)});
		return ptr;
	} else {
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

	uart.printf("[Heap] Freeing block: addr=0x{x}, size={}\n\r", .{@intFromPtr(freed_block), freed_block.size});
	std.debug.assert(freed_block.is_free);

	// check siblings for coalescence
	if (@intFromPtr(freed_block) < @intFromPtr(head)) {
		freed_block.next = head;
		_ = freed_block.try_join_right(head);
		head = freed_block;
	} else {
		var left: *volatile Block = head;
		var right: *volatile Block = head;
		while (right.next) |b| {
			left = right;
			right = b;
			if (@intFromPtr(right) > @intFromPtr(freed_block)) break;
		}
		left.next = freed_block;

		const joined = left.try_join_right(freed_block);
		if (joined) {
			_ = left.try_join_right(right);
		} else {
			_ = freed_block.try_join_right(right);
		}
	}
}
