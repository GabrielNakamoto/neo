const std = @import("std");
const idt = @import("./idt.zig");
const cpu = @import("./cpu.zig");
const uart = @import("./uart.zig");

// ISR Stack State
const StackFrame = packed struct {
	// Pushed in bootstrap isr
	registers: cpu.Registers,
	vector: u64,

	// Pushed by CPU
	error_code: u64,
	rip: u64,
	cs: u64,
	rflags: u64,
};

export fn exception_handler(ctx: *StackFrame) callconv(.c) void {
	uart.printf("\n\rException #0x{x}!\n\r", .{ctx.vector});
	uart.printf("Error Code: 0x{x}\n\r", .{ctx.error_code});
	uart.print("Stack Frame:\n\r");

	// Print registers / stack frame
	inline for (std.meta.fields(cpu.Registers)) |reg| {
		uart.printf("{s}:\t0x{x:0>16}\n\r", .{reg.name, @field(ctx.registers, reg.name)});
	}

	cpu.hang();
}

const IsrFn = *const fn() callconv(.naked) void;

export fn intCommon() callconv(.naked) void {
	cpu.push_all();	

	asm volatile (
		\\mov %%rsp, %%rdi
		\\call exception_handler
	);

	cpu.pop_all();

	asm volatile(
		\\add $16, %%rsp
		// TODO: This causes stack fault
		\\iretq
	);
}

pub fn generateIsr(comptime vector: u64) IsrFn {
	return struct {
		fn handler() callconv(.naked) noreturn {
			asm volatile("cli");
			if (vector != 8 and vector != 17 and vector != 21 and !(vector >= 10 and vector <= 14)) {
				asm volatile("pushq $0");
			}

			asm volatile(
				\\pushq %[vector]
				\\jmp intCommon
				:: [vector] "n" (vector)
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
