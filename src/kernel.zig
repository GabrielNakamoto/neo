export fn kmain() noreturn {
	const vga_address: usize = 0xb8000;
	const vga_memory: *u8 = @ptrFromInt(vga_address);

	vga_memory.* = 'B';
	
	while (true) {
		asm volatile("hlt");
	}
}
