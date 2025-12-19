const x86 = @import("./x86.zig");
const idt = @import("./idt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
};

export fn kmain() noreturn {
	gdt.load();
	idt.load();

	const msg = "Hello, paging!";

	uart.init_serial();
	uart.serial_print(msg);

	// Should print "Exception!"
	asm volatile("int3");

	while (true) {
		x86.hlt();
	}
}
