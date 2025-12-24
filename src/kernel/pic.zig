const cpu = @import("./cpu.zig");
// PIC Ports
const PIC1_COMMAND 	= 0x20;
const PIC1_DATA 		= 0x21;
const PIC2_COMMAND 	= 0xA0;
const PIC2_DATA 		= 0xA1;

// PIC Commands
const ICW1_INIT 			= 0x10;
const ICW1_ICW4 			= 0x01;
const ICW4_8086_MODE 	= 0x01;
const PIC_EOI 				= 0x20;

// https://wiki.osdev.org/8259_PIC#Programming_the_PIC_chips
pub fn initialize() void {
	// Start initialization
	cpu.out(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
	cpu.out(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);

	// Specify IDT vector indices
	cpu.out(PIC1_DATA, 32); // IRQ 0->8
	cpu.out(PIC2_DATA, 40); // IRQ 8->15

	// Cascade identity mapping?
	cpu.out(PIC1_DATA, 0b100);
	cpu.out(PIC2_DATA, 2);

	// Set ICW4 Mode
	cpu.out(PIC1_DATA, ICW4_8086_MODE);
	cpu.out(PIC2_DATA, ICW4_8086_MODE);

	// Mask/disable all irqs initially
	cpu.out(PIC1_DATA, 0xFF);
	cpu.out(PIC2_DATA, 0xFF);
}

pub inline fn end_irq(irq_line: u8) void {
	if (irq_line >= 8) {
		cpu.out(PIC2_COMMAND, PIC_EOI);
	}
	cpu.out(PIC1_COMMAND, PIC_EOI);
}

pub fn enable_irq(irq_line: u8) void {
	var offset: u8 = irq_line;
	const port: u8 = switch (irq_line) {
		0...8 => PIC1_DATA,
		else 	=> blk: {
			offset -= 8;
			break :blk PIC2_DATA;
		}
	};
	const status = cpu.in(port);
	const shift: u3 = @truncate(offset);
	const mask: u8 = ~(@as(u8, 1) << shift);
	cpu.out(port, status & mask);
}
