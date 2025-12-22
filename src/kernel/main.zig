const cpu = @import("./cpu.zig");
const interrupt = @import("./interrupt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;
const std = @import("std");

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
};

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
	uart.print("Kernel panicked!");
	cpu.hang();
}

export fn kmain() noreturn {
	gdt.load();
	interrupt.initialize();

	const msg = "Follow the white rabbit.\n\r";

	uart.init_serial();
	uart.print("\x1B[2J\x1B[H");
	uart.print(msg);

	cpu.hang();
}
