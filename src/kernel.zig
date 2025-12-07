const video = @import("video.zig");

export fn kmain() noreturn {
	const msg = "Test";
	video.print(msg);
	
	while (true) {
		asm volatile("hlt");
	}
}
