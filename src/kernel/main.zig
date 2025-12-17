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

fn outb(port: u16, byte: u8) void {
	asm volatile (
		\\out %[byte], %[port]
		:
	 	: [byte] "{al}" (byte),
		  [port] "{dx}" (port),
	);
}

// Make this a seperate assembly file with function declaration
inline fn enable_IA32E_paging() void {
	asm volatile (
		// CR0.PG = 0
		\\mov %cr0, %rbx
  		\\and %ebx, ~(1 << 31)
  		\\mov %rbx, %cr0

		// CR4.PAE = 1
		\\mov %cr4, %rdx
  		\\or  %rdx, (1 << 5)
  		\\mov %rdx, %cr4

		//\\mov %[pml4_table], %rax
		//\\mov %rax, %cr3
		:
		: //[pml4_table]
	);
}

fn debug_print(str: []const u8) void {
	for (str) |c| {
		outb(0xE9, c);
	}
}

// https://dram.page/p/relative-relocs-explained/
// https://github.com/torvalds/linux/blob/master/arch/x86/boot/compressed/misc.c#L198
export fn kmain() noreturn {
	// Pass relocation tables in BootInfo
	// Use relocation tables to relocate self
	// Free memory used for relocation tables after
	outb(0xE9, 'X');

	while (true) {
		hlt();
	}
}
