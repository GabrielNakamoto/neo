// Assembly wrapper functions for x86

pub inline fn hlt() void {
	asm volatile("hlt");
}

pub inline fn lgdt(gdt_descriptor: u64) void {
	asm volatile (
		\\lgdt %[gdtr]
		:: [gdtr] "m" (gdt_descriptor)
	);
}

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

pub inline fn lidt(idt_descriptor: u64) void {
	asm volatile (
	\\lidt %[idtr]
	:: [idtr] "m" (idt_descriptor)
	);
}
