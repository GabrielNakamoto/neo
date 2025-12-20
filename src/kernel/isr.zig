const std = @import("std");
const idt = @import("./idt.zig");
const x86 = @import("./x86.zig");
const uart = @import("./uart.zig");

export fn exception_handler() callconv(.naked) void {
	x86.out(0x3f8, 'I');
	x86.hlt();
}

const IsrFn = *const fn() callconv(.naked) noreturn;

// Defines first 32 Interrupt Service Routines
// And adds their descriptors to IDT
// 
// Zig comptime is goated
comptime {
	for (0..32) |idx| {
		const template = \\.globl isr_{} 
		\\.type isr_{}, @function
		\\isr_{}:
		\\  call exception_handler
		\\  iretq
		;

		asm (std.fmt.comptimePrint(template, .{idx, idx, idx}));
	}
}

pub fn install() void {
	inline for (0..32) |i| {
		const fn_ptr = @extern(IsrFn, .{ .name = std.fmt.comptimePrint("isr_{}", .{i})});
		idt.set_gate(i, 0x8, @intFromPtr(fn_ptr), idt.INTERRUPT_GATE);
	}
}
