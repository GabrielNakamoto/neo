const cpu = @import("./cpu.zig");
const interrupt = @import("./interrupt.zig");
const uefi = @import("std").os.uefi;
const gdt = @import("./gdt.zig");
const uart = @import("./uart.zig");
const elf = @import("std").elf;
const std = @import("std");
const keyboard = @import("./drivers/keyboard.zig");
const Video = @import("./drivers/video.zig");
const pmm = @import("./pmm.zig");
const vmm = @import("./vmm.zig");
const shell = @import("./shell.zig");

const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	graphics_mode: *uefi.protocol.GraphicsOutput.Mode,
	runtime_services: *uefi.tables.RuntimeServices,
	kernel_paddr: u64,
	kernel_size: u64,
	kernel_vaddr: u64,
	stack_paddr: u64,
	empty_paging_tables: [][512]u64
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
	uart.printf("Pre-allocated paging tables: {}\n\r", .{boot_info.empty_paging_tables.len});

	gdt.load();
	uart.print("Loaded GDT and TSS.\n\r");
	interrupt.initialize();
	uart.print("Initialized interrupts.\n\r");
	keyboard.initialize();
	asm volatile("sti");

	vmm.initialize(
		boot_info.empty_paging_tables,
		boot_info.kernel_paddr,
		boot_info.kernel_vaddr,
		boot_info.kernel_size,
		boot_info.stack_paddr,
		boot_info.final_mmap
	);
	vmm.enable();
	uart.print("Enabled kernel paging\n\r");
	// pmm.foo(boot_info.final_mmap);
	// pmm.map_memory(boot_info.final_mmap);
	// pmm.build_buddy_list(boot_info.final_mmap);
	// pmm.find_memory(boot_info.final_mmap);
	// var video = Video.initialize(boot_info.graphics_mode);

	// Shell testing
	// shell.initialize(boot_info.runtime_services);
	while (true) {
		// shell.periodic(&video);
		cpu.hlt();
	}
}
