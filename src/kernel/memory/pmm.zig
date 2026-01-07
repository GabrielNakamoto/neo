const uefi = @import("std").os.uefi;
const buddy = @import("./buddy.zig");
const bump = @import("./bump.zig");
const uart = @import("../uart.zig");
const shared = @import("shared");

const free_memory_types = [_]uefi.tables.MemoryType {
	.conventional_memory, .boot_services_code, .boot_services_data
};

fn is_free_descriptor(descr: *uefi.tables.MemoryDescriptor) bool {
	for (free_memory_types) |tp| {
		if (descr.type == tp) return true;
	}
	return false;
}

fn map_physical_memory(mmap: uefi.tables.MemoryMapSlice) struct { u64, u64 } {
	var iter = mmap.iterator();
	var largest_free_start: u64 = 0;
	var largest_free_size: u64 = 0;
	var current_start: u64 = 0;
	var current_size: u64 = 0;
	var last_free = false;
	while (iter.next()) |descr| {
		if (! is_free_descriptor(descr)) {
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
	return .{ largest_free_start, largest_free_size };
}

pub fn initialize(boot_info: *shared.BootInfo) void {
	const largest_start, const largest_size = map_physical_memory(boot_info.final_mmap);
	buddy.initialize(largest_start, largest_size);
	bump.initialize(boot_info.kernel_paddr);
}
