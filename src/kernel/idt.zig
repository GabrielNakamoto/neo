const std = @import("std");
const x86 = @import("./x86.zig");
const uart = @import("./uart.zig");
// Gate Types:
// 1. Interrupt Gate (specify ISR (Interrupt Service Routine))
// 2. Trap Gate (Exception handlers)
const INTERRUPT_GATE 	= 0xE;
const TRAP_GATE				= 0xF;

const GateDescriptor = packed struct {
	offset_low: u16,
	seg_selector: u16,
	ist: u3,
	_0: u5 = 0,
	gate_type: u4,
	_1: u1 = 0,
	privilege: u2,
	present: u1 = 1,
	offset_high: u48,
	_2: u32 = 0,
};

const IDTDescriptor = packed struct {
	size: u16,
	offset: u64,
};

var idt: [256]GateDescriptor = undefined;

pub fn set_gate(index: usize, seg_selector: u16, offset: u64, gate_type: u4) void {
	idt[index] = .{	
		.offset_low = @truncate(offset),
		.seg_selector = seg_selector,
		.ist = 0,
		.gate_type = gate_type,
		.privilege = 0,
		.offset_high = @truncate(offset >> 16),
	};
}

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
		\\isr_{}:
		\\  call exception_handler
		\\  iretq
		;

		asm (std.fmt.comptimePrint(template, .{idx, idx}));
	}
}

pub fn load() void {
	inline for (0..32) |i| {
		const fn_ptr = @extern(IsrFn, .{ .name = std.fmt.comptimePrint("isr_{}", .{i})});
		set_gate(i, 0x8, @intFromPtr(fn_ptr), INTERRUPT_GATE);
	}

	const idt_descriptor: IDTDescriptor = .{
		.size = (@bitSizeOf(IDTDescriptor) / 8) - 1,
		.offset = @intFromPtr(&idt)
	};

	x86.lidt(@intFromPtr(&idt_descriptor));
}
