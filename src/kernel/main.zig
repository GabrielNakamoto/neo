const elf = @import("std").elf;
const std = @import("std");
const uefi = std.os.uefi;

const cpu = @import("./cpu.zig");
const gdt = @import("./gdt.zig");

const uart = @import("./uart.zig");

const keyboard = @import("./drivers/keyboard.zig");
const video = @import("./drivers/video.zig");
const shell = @import("./shell.zig");

const mem = @import("./memory/mem.zig");

const isr = @import("./interrupts/isr.zig");
const idt = @import("./interrupts/idt.zig");
const pic = @import("./interrupts/pic.zig");

pub const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	runtime_services: *uefi.tables.RuntimeServices,
	kernel_paddr: u64,
	kernel_size: u64,
	kernel_vaddr: u64,
	stack_paddr: u64,
	bootstrap_pages: [] align(4096) [4096]u8
};

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
	uart.print("Kernel panicked!");
	cpu.hang();
}

export fn kmain(boot_info: *BootInfo) noreturn {
	uart.init_serial();
	uart.print("\x1B[2J\x1B[H");
	uart.print("Initialized serial i/o.\n\r");
	uart.printf("Kernel paddr: 0x{x}\n\r", .{boot_info.kernel_paddr});
	uart.printf("Kernel stack addr: 0x{x}\n\r", .{boot_info.stack_paddr});

	gdt.load();
	uart.print("Loaded GDT and TSS.\n\r");

	pic.initialize();
	isr.install();
	idt.load();
	asm volatile("sti");
	uart.print("Initialized interrupts.\n\r");

	keyboard.initialize();

	video.graphics_mode = boot_info.graphics_mode.*;
	mem.initialize(boot_info);

	video.initialize();
	video.fill_screen(0x0);
	video.render();

	//shell.initialize(boot_info.runtime_services);
	while (true) {
		//shell.periodic(&video);
		cpu.hlt();
	}
}
