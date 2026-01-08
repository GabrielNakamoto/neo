const elf = @import("std").elf;
const std = @import("std");
const uefi = std.os.uefi;

const cpu = @import("./cpu.zig");
const gdt = @import("./gdt.zig");

const uart = @import("./uart.zig");

const keyboard = @import("./drivers/keyboard.zig");
// const video = @import("./drivers/video.zig");
// const shell = @import("./shell.zig");

const bump = @import("./memory/bump.zig");
const pmm = @import("./memory/pmm.zig");
const vmm = @import("./memory/vmm.zig");
const heap = @import("./memory/heap.zig");

const isr = @import("./interrupts/isr.zig");
const idt = @import("./interrupts/idt.zig");
const pic = @import("./interrupts/pic.zig");

const layout = @import("./layout.zig");
const shared = @import("shared");

pub var boot_info: shared.BootInfo = undefined;
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

export fn kmain(old_info: *shared.BootInfo) noreturn {
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

	pmm.initialize(&boot_info);
	vmm.initialize(&boot_info);
	heap.init();

	const x = heap.create([20]u64) catch unreachable;
	const y = heap.create([20]u32) catch unreachable;
	const z = heap.create([512]u64) catch unreachable;

	heap.debug_freelist();

	heap.destroy(y);
	heap.debug_freelist();
	heap.destroy(x);
	heap.debug_freelist();
	heap.destroy(z);
	heap.debug_freelist();

	//video.initialize(&boot_info.fb_info);
	//video.fill_screen(0x0);
	//video.render();
	// shell.initialize(boot_info.runtime_services);
	while (true) {
		// shell.periodic();
		cpu.hlt();
	}
}
