// https://wiki.osdev.org/Page_Tables

const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");
const elf = @import("std").elf;

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
};

inline fn hlt() void {
	asm volatile("hlt");
}

export fn kmain() noreturn {
	const msg = "Hello, paging!";

	uart.init_serial();
	uart.serial_print(msg);

	while (true) {
		hlt();
	}
}
