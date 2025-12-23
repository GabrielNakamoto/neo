const cpu = @import("./cpu.zig");
const interrupt = @import("./interrupt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;
const std = @import("std");
const keyboard = @import("./drivers/keyboard.zig");
const video = @import("./drivers/video.zig");
const paging = @import("./paging.zig");

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	pml4: *paging.PagingLevel,
	kernel_paddr: u64,
	kernel_size: u64,
	stack_paddr: u64,
};

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
	uart.print("Kernel panicked!");
	cpu.hang();
}

export fn kmain(boot_info: *BootInfo) noreturn {
	gdt.load();
	interrupt.initialize();
	asm volatile("sti");

	const msg = "Follow the white rabbit.\n\r";

	uart.init_serial();
	uart.print("\x1B[2J\x1B[H");
	uart.print(msg);

	video.initialize(boot_info.graphics_mode);
	video.fill_screen(0x0);
	video.print("Hello, graphics!");

	//keyboard.initialize();

	cpu.hang();
}
