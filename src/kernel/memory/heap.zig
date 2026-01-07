// Heap implementation
const buddy = @import("./buddy.zig");
const paging = @import("./vmm.zig");
const layout = @import("../layout.zig");
const uart = @import("../uart.zig");

const Block = struct {
	size: u32,
	meta: union(enum) {
		next: ?*Block,
		magic: u32
	},

	const Self = @This();

	// Returns ptr to new free block, this block becomes allocated one
	fn split(self: *Self, requested: u32) *Block {
		const base: [*]u8 = @ptrCast(self);
		const free: *Block = @ptrCast(@alignCast(base + requested));
		free.size = self.size - requested - @sizeOf(Block);
		free.meta.next = self.meta.next;

		self.meta = .{ .magic = 0xFACE };
		self.size = requested + @sizeOf(Block);

		return free;
	}
};

var head: *Block = undefined;

pub fn init() void {
	const mem = buddy.alloc(1);
	const paddr = @intFromPtr(mem.ptr);
	const vaddr = layout.kernelHeapStart();
	paging.map_pages(paddr, 1, vaddr - paddr);
	head = @ptrFromInt(vaddr);
	head.size = 4096 - @sizeOf(Block);
	head.meta.next = null;

	uart.print("Initialized heap\n\r");
}

// - keep track of virtual address space
// - manage dynamic size allocations and free memory within address space
pub fn create(comptime T: type) !*T {
	// Search
	var block = head;
	var last: ?*Block = null;
	while (block.size - @sizeOf(Block) < @sizeOf(T)) {
		if (block.meta.next) |next| {
			last = block;
			block = next;
		} else {
			// TODO: Expand heap
			return error.OutOfMemory;
		}
	}

	// Split
	const free = block.split(@sizeOf(T));
	if (last) |prev| {
		prev.meta.next = free;
	} else {
		head.meta.next = free;
	}

	const ptr: *T = @ptrFromInt(@intFromPtr(&block) + @sizeOf(Block));
	return ptr;
}

//pub fn destroy(ptr: anytype) void {
//}
