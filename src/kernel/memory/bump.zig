const std = @import("std");

var fbase: usize = undefined;
var ftop: usize = undefined;

pub fn initialize(bootstrap_pages: []align(4096)[4096]u8) void {
	fbase = @intFromPtr(bootstrap_pages.ptr);
	ftop = fbase + bootstrap_pages.len * 4096;
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
