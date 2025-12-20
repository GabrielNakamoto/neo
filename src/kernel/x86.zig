// Assembly wrapper functions for x86

// General
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
