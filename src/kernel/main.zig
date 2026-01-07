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

const layout = @import("./layout.zig");

pub const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	fb_info: FramebufferInfo,
	runtime_services: *uefi.tables.RuntimeServices,
	kernel_paddr: u64,
	kernel_size: u64,
};

pub const FramebufferInfo = struct {
	base: u64,
	size: u64,
	width: u32,
	height: u32,
	scanline_width: u32,
	format: uefi.protocol.GraphicsOutput.PixelFormat
};

pub var boot_info: BootInfo = undefined;
var stack_memory: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
	uart.print("Kernel panicked!");
	cpu.hang();
}

export fn _start() callconv(.naked) noreturn {
	asm volatile (
		\\movl %[stack_top], %%esp
		\\movl %%esp, %%ebp
		\\call %[kmain:P]
		:: [stack_top] "i" (&(@as([*]align(16) u8, @ptrCast(&stack_memory))[stack_memory.len])),
			 [kmain] "X" (&kmain)
	);
}

export fn kmain(old_info: *BootInfo) noreturn {
	boot_info = old_info.*;

	uart.init_serial();
	uart.print("\x1B[2J\x1B[H");
	uart.print("Initialized serial i/o.\n\r");
	uart.printf("Kernel paddr: 0x{x}\n\r", .{boot_info.kernel_paddr});

	gdt.load();
	uart.print("Loaded GDT and TSS.\n\r");

	pic.initialize();
	isr.install();
	idt.load();
	asm volatile("sti");
	uart.print("Initialized interrupts.\n\r");

	keyboard.initialize();

	mem.initialize(&boot_info);
	uart.printf("UEFI Frame buffer: 0x{x}\n\r", .{boot_info.fb_info.base});

	video.initialize(&boot_info.fb_info);
	shell.initialize(boot_info.runtime_services);
	while (true) {
		shell.periodic();
		cpu.hlt();
	}
}
