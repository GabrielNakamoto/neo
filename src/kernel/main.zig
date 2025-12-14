// https://wiki.osdev.org/Page_Tables

const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");

inline fn hlt() void {
	asm volatile("hlt");
}

inline fn outb(port: u16, byte: u8) void {
	asm volatile (
		\\out %[byte], %[port]
		:
	 	: [byte] "{al}" (byte),
		  [port] "{dx}" (port),
	);
}

// 0x61a0960
export fn kmain() noreturn {
	outb(0xE9, 'X');
	// uart.init_serial();
	// uart.serial_print("test");

	while (true) {
		hlt();
	}
}
