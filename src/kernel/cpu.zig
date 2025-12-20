// Assembly wrapper functions for x86

// General
pub inline fn pop_all() void {
	asm volatile (
		\\popq %%rsp
		\\popq %%rbp
		\\popq %%rdi
		\\popq %%rsi
		\\popq %%rdx
		\\popq %%rcx
		\\popq %%rbx
		\\popq %%rax
		\\popq %%r15
		\\popq %%r14
		\\popq %%r13
		\\popq %%r12
		\\popq %%r11
		\\popq %%r10
		\\popq %%r9
		\\popq %%r8
	);
}

pub inline fn push_all() void {
	asm volatile (
		\\pushq %%r8
		\\pushq %%r9
		\\pushq %%r10
		\\pushq %%r11
		\\pushq %%r12
		\\pushq %%r13
		\\pushq %%r14
		\\pushq %%r15
		\\pushq %%rax
		\\pushq %%rbx
		\\pushq %%rcx
		\\pushq %%rdx
		\\pushq %%rsi
		\\pushq %%rdi
		\\pushq %%rbp
		\\pushq %%rsp
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
