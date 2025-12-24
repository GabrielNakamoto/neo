const std = @import("std");
const idt = @import("./idt.zig");
const cpu = @import("./cpu.zig");
const uart = @import("./uart.zig");
const pic = @import("./pic.zig");

// https://wiki.osdev.org/Exceptions
const exception_names: [32][]const u8 = .{
	"Division Error",
	"Debug",
	"Non-maskable Interrupt",
	"Breakpoint",
	"Overflow",
	"Bound Range Exceeded",
	"Invalid Opcode",
	"Device Not Available",
	"Double Fault",
	"Reserved",
	"Invalid TSS",
	"Segment Not Present",
	"Stack-Segment Fault",
	"General Protection Fault",
	"Page Fault",
	"Reserved",
	"x87 Floating-Point Exception",
	"Alignment Check",
	"Machine Check",
	"SIMD Floating-Point Exception",
	"Virtualization Exception",
	"Control Protection Exception",
	"Reserved",
	"Reserved",
	"Reserved",
	"Reserved",
	"Reserved",
	"Reserved",
	"Hypervisor Injection Exception",
	"VMM Communication Exception",
	"Security Exception",
	"Reserved"
};

const irq_names: [16][] const u8 = .{
	"Programmable Interrupt Timer",
	"Keyboard",
	"Cascade",
	"COM2",
	"COM1",
	"LPT2",
	"Floppy Disk",
	"LPT1",
	"CMOS real-time clock",
	"Free (peripherals / SCSI / NIC)",
	"Free (peripherals / SCSI / NIC)",
	"Free (peripherals / SCSI / NIC)",
	"PS2 Mouse",
	"FPU / Coprocessor / Inter-processor",
	"Primary ATA Hard Disk",
	"Secondary ATA Hard Disk"
};

// ISR Stack State
pub const StackFrame = packed struct {
	// Pushed in bootstrap isr
	registers: cpu.Registers,
	vector: u64,

	// Pushed by CPU
	error_code: u64,
	rip: u64,
	cs: u64,
	rflags: u64,
};

const IsrFn = *const fn() callconv(.naked) void;
const InterruptHandler = *const fn(*StackFrame) void;

var exception_handlers: [32]InterruptHandler = [_]InterruptHandler{default_exception} ** 32;
var irq_handlers: [16]InterruptHandler = [_]InterruptHandler{default_irq} ** 16;

pub fn register_irq(vector: u64, handler: InterruptHandler) void {
	irq_handlers[vector]=handler;
}

pub fn register_exception(vector: u64, handler: InterruptHandler) void {
	exception_handlers[vector]=handler;
}

fn default_exception(ctx: *StackFrame) void {
	uart.printf("\n\rException #0x{x}: \"{s}\"\n\r", .{ctx.vector, exception_names[ctx.vector]});
	uart.print("===========================\n\r");
	uart.printf("RFLAGS:\t0x{x}\n\r", .{ctx.rflags});
	uart.printf("RIP:\t0x{x}\n\r", .{ctx.rip});

	inline for (std.meta.fields(cpu.Registers)) |reg| {
		uart.printf("{s}:\t0x{x:0>16}\n\r", .{reg.name, @field(ctx.registers, reg.name)});
	}
	cpu.hang();
}

fn default_irq(ctx: *StackFrame) void {
	uart.printf("\n\rIRQ #0x{x}: \"{s}\"\n\r", .{ctx.vector - 32, irq_names[ctx.vector - 32]});
	cpu.hang();
}

export fn interrupt_dispatch(ctx: *StackFrame) callconv(.c) void {
	switch (ctx.vector) {
		0...31 => exception_handlers[ctx.vector](ctx),
		else => {
			const irq_line = ctx.vector - 32;
			irq_handlers[irq_line](ctx);
			pic.end_irq(@truncate(irq_line));
		}
	}
}

export fn intCommon() callconv(.naked) void {
	cpu.push_all();	

	asm volatile (
		\\mov %%rsp, %%rdi
		\\call interrupt_dispatch
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
