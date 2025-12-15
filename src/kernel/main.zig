// https://wiki.osdev.org/Page_Tables

const uefi = @import("std").os.uefi;
const uart = @import("./uart.zig");
const elf = @import("std").elf;

// TODO: share this definition between kernel and bootloader
// code somehow?
const AddrMap = u128; // Upper half vaddr, lower half paddr
const BootInfo = struct {
	segment_maps: []AddrMap,
	final_mmap: uefi.tables.MemoryMapSlice,
};

inline fn hlt() void {
	asm volatile("hlt");
}

inline fn outb(port: u16, byte: u8) void {
	asm volatile (
		\\out %[byte], %[port]
		:
	 	: [byte] "{al}" (byte),
		  [port] "{dx}" (port),
	);
}

// https://wiki.osdev.org/Paging#64-bit_Paging_2
// https://wiki.osdev.org/CPU_Registers_x86#Control_Registers
// Section 4.5: https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf

inline fn get_pml4_table() *u8 {
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

// 0x61a0960
export fn kmain(boot_info: *BootInfo) noreturn {
	outb(0xE9, 'X');
	const len: u8 = @intCast(boot_info.segment_maps.len);
	outb(0xE9, '0' + len);

	// enable_IA32E_paging();
	// uart.init_serial();
	// uart.serial_print("test");

	while (true) {
		hlt();
	}
}
