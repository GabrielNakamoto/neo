// https://wiki.osdev.org/Serial_Ports
const x86 = @import("./x86.zig");
const std = @import("std");

const COM1: u16 = 0x3f8;

// https://wiki.osdev.org/Serial_Ports#Initialization
pub fn init_serial() void {
	x86.out(COM1 + 1, 0x00);
	x86.out(COM1 + 3, 0x80);
	x86.out(COM1 + 0, 0x03);
	x86.out(COM1 + 1, 0x00);
	x86.out(COM1 + 3, 0x03);
	x86.out(COM1 + 2, 0xc7);
	x86.out(COM1 + 4, 0x0b);
}

inline fn is_transmit_empty() bool {
	return (x86.in(COM1 + 5) & 0x20) != 0;
}

pub inline fn serial_putc(c: u8) void {
	while (! is_transmit_empty()) {}
	x86.out(COM1, c);
}

pub fn serial_print(str: []const u8) void {
	for (str) |c| {
		serial_putc(c);
	}
}
