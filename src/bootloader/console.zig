const std = @import("std");
const uefi = @import("std").os.uefi;

pub var out: *uefi.protocol.SimpleTextOutput = undefined;

// Reusable, compile time allocated buffer for formatted strings at runtime
var format_buf: [128]u8 = undefined;

pub fn printf(comptime format: []const u8, args: anytype) void {
	const buf = std.fmt.bufPrint(format_buf[0..], format, args) catch unreachable;
	print(buf);
}

pub fn print(str: []const u8) void {
	// UEFI uses 16 bit, null terminated strings
	// Instead of allocating memory at runtime we can just
	// output each char as its own string
	for (str) |c| {
		const c_ = [1:0]u16 {c};
		_ = out.outputString(&c_) catch {};
	}
	const end = [_:0]u16 {'\n', '\r'};
	_ = out.outputString(&end) catch {};
}
