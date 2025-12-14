// https://wiki.osdev.org/Serial_Ports

const COM1: u16 = 0xf38;

inline fn inb(port: u16) u8 {
	return asm volatile (
		\\in %[port], %[ret]
		: [ret] "={al}" (-> u8)
		: [port] "{dx}" (port)
	);
}

inline fn outb(port: u16, byte: u8) void {
	asm volatile (
		\\out %[byte], %[port]
		:
	 	: [byte] "{al}" (byte),
		  [port] "{dx}" (port),
	);
}

// https://wiki.osdev.org/Serial_Ports#Initialization
pub fn init_serial() void {
	outb(COM1 + 1, 0x00);
	outb(COM1 + 3, 0x80);
	outb(COM1 + 0, 0x03);
	outb(COM1 + 1, 0x00);
	outb(COM1 + 3, 0x03);
	outb(COM1 + 2, 0xC7);
	outb(COM1 + 4, 0x0B);
}

fn is_transmit_empty() bool {
	return (inb(COM1 + 5) & 0x20) != 0;
}

pub fn serial_putc(c: u8) void {
	while (! is_transmit_empty()) {}
	outb(COM1, c);
}

pub fn serial_print(str: []const u8) void {
	for (str) |c| {
		serial_putc(c);
	}
}
