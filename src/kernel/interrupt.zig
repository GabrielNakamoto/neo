const cpu = @import("./cpu.zig");
const idt = @import("./idt.zig");
const isr = @import("./isr.zig");
const uart = @import("./uart.zig");
const pic = @import("./pic.zig");

pub fn initialize() void {
	pic.initialize();
	isr.install();
	idt.load();
}
