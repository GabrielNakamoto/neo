const cpu = @import("./cpu.zig");
const interrupt = @import("./interrupt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;
const std = @import("std");
const keyboard = @import("./drivers/keyboard.zig");
const Video = @import("./drivers/video.zig");
const paging = @import("./paging.zig");
const memory = @import("./memory.zig");

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	runtime_services: *uefi.tables.RuntimeServices,
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
	uart.init_serial();
	uart.print("\x1B[2J\x1B[H");
	uart.print("Initialized serial i/o.\n\r");
	uart.printf("Kernel paddr: 0x{x}\n\r", .{boot_info.kernel_paddr});
	uart.printf("Kernel stack addr: 0x{x}\n\r", .{boot_info.stack_paddr});

	gdt.load();
	uart.print("Loaded GDT and TSS.\n\r");
	interrupt.initialize();
	uart.print("Initialized interrupts.\n\r");
	keyboard.initialize();
	asm volatile("sti");

	var video = Video.initialize(boot_info.graphics_mode);
	video.fill_screen(0x0);

	const time, _  = boot_info.runtime_services.getTime() catch unreachable;
	video.printf("{d:0>2}:{d:0>2}:{d:0>2}> ", .{time.hour, time.minute, time.second});

	// uart.printf("{}\n\r", .{@intFromPtr(boot_info.final_mmap.ptr)});
	// uart.printf("{}\n\r", .{boot_info.final_mmap.info.len});

	memory.find_memory(boot_info.final_mmap);

	// TODO: key callback functions
	// Pass function to be called when a certain key is clicked

	keyboard.subscribers[0] = &video_subscriber;

	while (true) {
		render(&video);
		cpu.hlt();
	}
}

var i: u8 = 0;
var str: [32]u8 = [_]u8 {0} ** 32;
fn video_subscriber() void {
	if (keyboard.is_clicked(0x8) and i > 0) {
		i -= 1;
	}
	if (keyboard.is_clicked(' ')) {
		str[i]=' ';
		i += 1;
	}
	for ('A'..'Z'+1) |c|{
		const key: u8 = @truncate(c);
		if (keyboard.is_clicked(key)) {
			str[i]=key;
			i += 1;
		}
	}
}

fn render(video: *Video) void {
	str[i] = '_';
	video.fill_screen(0x0);
	video.printf("{s}", .{str[0..i+1]});
}
