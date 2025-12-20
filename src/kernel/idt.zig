const std = @import("std");
const cpu = @import("./cpu.zig");
const uart = @import("./uart.zig");
// Gate Types:
// 1. Interrupt Gate (specify ISR (Interrupt Service Routine))
// 2. Trap Gate (Exception handlers)
pub const INTERRUPT_GATE 	= 0xE;
pub const TRAP_GATE				= 0xF;

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

pub fn load() void {
	const idt_descriptor: IDTDescriptor = .{
		.size = (@bitSizeOf(IDTDescriptor) * idt.len / 8) - 1,
		.offset = @intFromPtr(&idt)
	};

	cpu.lidt(@intFromPtr(&idt_descriptor));
}
