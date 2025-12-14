// https://wiki.osdev.org/Page_Tables

const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");

inline fn hlt() void {
	asm volatile("hlt");
}

export fn kmain() noreturn {
	uart.init_serial();
	uart.serial_print("Test");

	while (true) {
		hlt();
	}
}
