const cpu = @import("./cpu.zig");
const idt = @import("./idt.zig");
const isr = @import("./isr.zig");
const uart = @import("./uart.zig");

// PIC Ports
const PIC1_COMMAND 	= 0x20;
const PIC1_DATA 		= 0x21;
const PIC2_COMMAND 	= 0xA0;
const PIC2_DATA 		= 0xA1;

// PIC Commands
const ICW1_INIT 			= 0x10;
const ICW1_ICW4 			= 0x01;
const ICW4_8086_MODE 	= 0x01;

// https://wiki.osdev.org/8259_PIC#Programming_the_PIC_chips
fn remap_PIC() void {
	// Start initialization
	cpu.out(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
	cpu.out(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);

	// Specify IDT vector indices
	cpu.out(PIC1_DATA, 32); // IRQ 0->7
	cpu.out(PIC1_DATA, 40); // IRQ 8->15

	// Cascade identity mapping?
	cpu.out(PIC1_DATA, 1 << 2);
	cpu.out(PIC2_DATA, 2);

	// Set ICW4 Mode
	cpu.out(PIC1_DATA, ICW4_8086_MODE);
	cpu.out(PIC2_DATA, ICW4_8086_MODE);

	cpu.out(PIC1_DATA, 0);
	cpu.out(PIC2_DATA, 0);
}

pub fn initialize() void {
	remap_PIC();

	isr.install();
	idt.load();
}
