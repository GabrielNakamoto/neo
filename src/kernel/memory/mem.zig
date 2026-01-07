// Kernel Memory Management API
// uses Virtual and Physical memory management implementations (vmm.zig and buddy.zig)
const bump = @import("./bump.zig");
const pmm = @import("./buddy.zig");
const vmm = @import("./vmm.zig");
const uart = @import("../uart.zig");
const BootInfo = @import("../main.zig").BootInfo;
const layout = @import("../layout.zig");

pub fn initialize(boot_info: *BootInfo) void {
	bump.initialize(boot_info.kernel_paddr);
	pmm.initialize(boot_info.final_mmap);
	vmm.initialize();

	// Initial mappings
	var iter = boot_info.final_mmap.iterator();
	while (iter.next()) |descr| {
		if (descr.type == .runtime_services_data or descr.type == .runtime_services_code or descr.type == .loader_data) {
			vmm.map_pages(descr.physical_start, descr.number_of_pages, 0);
		}
	}
	vmm.map_pages(
		boot_info.kernel_paddr,
		boot_info.kernel_size,
		layout.kernelVirtStart() - boot_info.kernel_paddr
	);
	vmm.map_pages(
		boot_info.fb_info.base,
		(boot_info.fb_info.size + 4095) / 4096,
		0
	);

	vmm.enable();
	uart.print("Enabled paging\n\r");
}

pub fn alloc_pages(n: u64) [][4096]u8 {
	const physical_slice = pmm.alloc(n);
	// TODO: dont identity map?
	vmm.map_pages(@intFromPtr(physical_slice.ptr), physical_slice.len, 0);
	return physical_slice;
}

// pub fn malloc() void {}
