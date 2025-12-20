const std = @import("std");
const idt = @import("./idt.zig");
const cpu = @import("./cpu.zig");
const uart = @import("./uart.zig");

// ISR Stack State
const Context = packed struct {
	// Pushed in bootstrap isr
	registers: Registers,
	vector: u64,

	// Pushed by CPU
	error_code: u64,
	rip: u64,
	cs: u64,
	rflags: u64,
};

pub export var context: *volatile Context = undefined;

// General purpose x86-64 registers
const Registers = packed struct {
	r8: u64,
	r9: u64,
	r10: u64,
	r11: u64,
	r12: u64,
	r13: u64,
	r14: u64,
	r15: u64,
	rax: u64,
	rbx: u64,
	rcx: u64,
	rdx: u64,
	rsi: u64,
	rdi: u64,
	rbp: u64,
	rsp: u64,
};

export fn exception_handler() callconv(.c) void {
	const vector: u8 = @truncate(context.vector);

	uart.print("Exception! vector: ");
	cpu.out(0x3f8, '0' + vector);
	cpu.hlt();
}

const IsrFn = *const fn() callconv(.naked) void;

pub fn generateIsr(comptime vector: u64) IsrFn {
	return struct {
		fn handler() callconv(.naked) void {
			asm volatile(
				\\pushq %[vector]
				:: [vector] "i" (vector)
			);
			cpu.push_all();	

			asm volatile (
				\\mov %esp, context
				\\call exception_handler
			);

			cpu.pop_all();

			asm volatile(
				\\add $0x10, %%rsp
				\\iretq
			);
		}
	}.handler;
}

pub fn install() void {
	inline for (0..48) |i| {
		const fn_ptr = generateIsr(i);
		idt.set_gate(i, 0x8, @intFromPtr(fn_ptr), idt.INTERRUPT_GATE);
	}
}
