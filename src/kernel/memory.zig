const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");
const vmemory = @import("./vmemory.zig");

const MemoryBlock = struct {
	phys_start: u64,
	n_pages: u64,
	bytes_used: u64 = 0,

	fn allocate(self: *MemoryBlock, comptime T: type, n: u64) *T {
		const bytes = @sizeOf(T) * n;
		uart.printf("Allocating {} kb of physical memory 0x{x} -> 0x{x}\n\r", .{bytes / 1000, self.phys_start, self.phys_start + bytes});
		if (self.n_pages * 4096 < self.bytes_used + bytes) {
			 // TODO: Emit error
		}
		const ptr: *T = @ptrFromInt(self.phys_start);
		self.bytes_used += bytes;

		const rem = (self.n_pages * 4096) - self.bytes_used;
		const mbs: u64 = rem / 1_000_000;
		uart.printf("{} mbs remaining in allocator block\n\r", .{mbs});
		return ptr;
	}
};

const free_memory_types = [_]uefi.tables.MemoryType {
	.conventional_memory, .boot_services_code, .boot_services_data
};

// First naive allocator: just use biggest chunk of free memory
var allocator_block: MemoryBlock = .{
	.phys_start = 0,
	.n_pages = 0,
};

pub fn malloc(comptime T: type, n: u64) *T {
	return allocator_block.allocate(T, n);
}

// TODO: pre-allocate empty page tables in boot loader
// to be able to map allocator block in kernel

// Concatenate blocks of free memory to use
pub fn find_memory(mmap: uefi.tables.MemoryMapSlice) void {
	var iter = mmap.iterator();
	var cur_block: MemoryBlock = undefined;
	while (iter.next()) |descr| {
		var usable = false;
		for (free_memory_types) |tp| {
			if (descr.type == tp) {
				usable = true;
				break;
			}
		}
		if (! usable) continue;

		if (cur_block.phys_start + (cur_block.n_pages * 4096) == descr.physical_start) {
			cur_block.n_pages += descr.number_of_pages;
		} else {
			if (cur_block.n_pages > allocator_block.n_pages) {
				allocator_block = cur_block;
			}

			cur_block = .{
				.phys_start = descr.physical_start,
				.n_pages = descr.number_of_pages,
			};
		}
	}

	uart.printf("Chose physical memory block: {}\n\r", .{allocator_block});
	// vmemory.map_pages(allocator_block.phys_start, allocator_block.n_pages, 0);
}
