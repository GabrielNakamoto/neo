// Kernel Memory Management API
// uses Virtual and Physical memory management implementations (vmm.zig and buddy.zig)
const bump = @import("./bump.zig");
const pmm = @import("./buddy.zig");
const vmm = @import("./vmm.zig");
const BootInfo = @import("../main.zig").BootInfo;

pub inline fn initialize(boot_info: *BootInfo) void {
	bump.initialize(boot_info.bootstrap_pages);
	pmm.initialize(boot_info.final_mmap);
	vmm.initialize(
		boot_info.kernel_paddr,
		boot_info.kernel_vaddr,
		boot_info.kernel_size,
		boot_info.stack_paddr,
		boot_info.final_mmap
	);
	vmm.enable();
}

pub fn alloc_pages(n: u64) [][4096]u8 {
	const physical_slice = pmm.alloc(n);
	// TODO: dont identity map?
	vmm.map_pages(@intFromPtr(physical_slice.ptr), physical_slice.len, 0);
	return physical_slice;
}

// pub fn malloc() void {}
