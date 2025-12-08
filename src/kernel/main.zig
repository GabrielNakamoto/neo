inline fn hlt() void {
	asm volatile("hlt");
}

export fn kmain() noreturn {
	while (true) {
		hlt();
	}
}
