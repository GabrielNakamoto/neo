const std = @import("std");

// Assembly wrapper functions for x86

// General purpose x86-64 registers
pub const Registers = packed struct {
	r15: u64,
	r14: u64,
	r13: u64,
	r12: u64,
	r11: u64,
	r10: u64,
	r9: u64,
	r8: u64,
	rbp: u64,
	rdi: u64,
	rsi: u64,
	rdx: u64,
	rcx: u64,
	rbx: u64,
	rax: u64,
};

// General
pub inline fn pop_all() void {
	asm volatile (
		\\popq %%r15
		\\popq %%r14
		\\popq %%r13
		\\popq %%r12
		\\popq %%r11
		\\popq %%r10
		\\popq %%r9
		\\popq %%r8
		\\popq %%rbp
		\\popq %%rdi
		\\popq %%rsi
		\\popq %%rdx
		\\popq %%rcx
		\\popq %%rbx
		\\popq %%rax
	);
}

pub inline fn push_all() void {
	asm volatile (
		\\pushq %%rax
		\\pushq %%rbx
		\\pushq %%rcx
		\\pushq %%rdx
		\\pushq %%rsi
		\\pushq %%rdi
		\\pushq %%rbp
		\\pushq %%r8
		\\pushq %%r9
		\\pushq %%r10
		\\pushq %%r11
		\\pushq %%r12
		\\pushq %%r13
		\\pushq %%r14
		\\pushq %%r15
	);
}

pub inline fn hang() noreturn {
	asm volatile("cli");
	while (true ){
		asm volatile("hlt");
	}
}

pub inline fn hlt() void {
	asm volatile("hlt");
}

// CPU Data Structures
pub inline fn lgdt(gdtr: u64) void {
	asm volatile (
		\\lgdt (%[gdtr])
		:: [gdtr] "r" (gdtr)
	);
}

pub inline fn lidt(idtr: u64) void {
	asm volatile (
	\\lidt (%[idtr])
	:: [idtr] "r" (idtr)
	);
}

// Port I/O
pub inline fn in(port: u16) u8 {
	return asm volatile (
		\\in %[port], %[ret]
		: [ret] "={al}" (-> u8)
		: [port] "{dx}" (port)
	);
}

pub inline fn out(port: u16, byte: u8) void {
	asm volatile (
		\\out %[byte], %[port]
		:: [byte] "{al}" (byte),
		   [port] "{dx}" (port),
	);
}
