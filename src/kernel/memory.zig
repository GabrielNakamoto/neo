const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");

const MemoryBlock = struct {
	phys_start: u64,
	n_pages: u64,
};

const free_memory_types = [_]uefi.tables.MemoryType {
	.conventional_memory, .boot_services_code, .boot_services_data
};

// First naive allocator: just use biggest chunk of free memory
var allocator_block: MemoryBlock = .{
	.phys_start = 0,
	.n_pages = 0,
};

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
}
