const std = @import("std");
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

export fn exception_handler() callconv(.naked) void {}

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

const IsrFn = *const fn() callconv(.naked) noreturn;

pub const isr_table: [32]IsrFn = blk: {
	var table: [32]IsrFn = undefined;
	for(0..32) |i| {
		table[i] = @extern(IsrFn, .{ .name = std.fmt.comptimePrint("isr_{}", .{i})});
	}
	break :blk table;
};
