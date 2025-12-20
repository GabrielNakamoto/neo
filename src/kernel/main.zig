const x86 = @import("./x86.zig");
const interrupt = @import("./interrupt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;
const std = @import("std");

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
};

export fn kmain() noreturn {
	gdt.load();

	const msg = "Hello, paging!";

	uart.init_serial();
	uart.serial_print(msg);

	interrupt.initialize();
	asm volatile("int $3");

	while (true) {
		x86.hlt();
	}
}
