// https://wiki.osdev.org/Serial_Ports
const cpu = @import("./cpu.zig");
const std = @import("std");

const COM1: u16 = 0x3f8;

// https://wiki.osdev.org/Serial_Ports#Initialization
pub fn init_serial() void {
	cpu.out(COM1 + 1, 0x00);
	cpu.out(COM1 + 3, 0x80);
	cpu.out(COM1 + 0, 0x03);
	cpu.out(COM1 + 1, 0x00);
	cpu.out(COM1 + 3, 0x03);
	cpu.out(COM1 + 2, 0xc7);
	cpu.out(COM1 + 4, 0x0b);
}

inline fn is_transmit_empty() bool {
	return (cpu.in(COM1 + 5) & 0x20) != 0;
}

pub inline fn serial_putc(c: u8) void {
	while (! is_transmit_empty()) {}
	cpu.out(COM1, c);
}

pub fn print(str: []const u8) void {
	for (str) |c| {
		serial_putc(c);
	}
}

var buf: [1024]u8 = undefined;
pub fn printf(comptime format: []const u8, args: anytype) void {
    const formatted = std.fmt.bufPrint(&buf, format, args) catch unreachable;
    print(formatted);
}
