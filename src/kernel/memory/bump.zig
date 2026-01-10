const std = @import("std");
const uart = @import("../uart.zig");
const layout = @import("../layout.zig");

// Physical addresses!
pub var fbase: usize = 0;
pub var ftop: usize = 0;

// Update to use firmware memory regions and save what regions I have reserved
pub fn initialize(kernel_paddr: u64) void {
	fbase = kernel_paddr + layout.bootstrapMemStart() - layout.kernelVirtStart();
	ftop = kernel_paddr + layout.bootstrapMemEnd() - layout.kernelVirtStart();
}

pub fn alloc(comptime T: type) *T {
	const bytes = @sizeOf(T);
	if (fbase + bytes > ftop) {
		@panic("Kernel bump allocator out of memory");
	}
	const value: *T = @ptrFromInt(fbase);
	fbase += bytes;

	return value;
}
