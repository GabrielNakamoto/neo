const cpu = @import("../cpu.zig");
const uart = @import("../uart.zig");
const pic = @import("../pic.zig");

const CMD_PORT: u8 = 0x64;
const DATA_PORT: u8 = 0x60;

fn output_empty() bool {
	return (cpu.in(0x64) & 0b10) == 0;
}

fn write_command(byte: u8) void {
	while (! output_empty()) {}
	cpu.out(CMD_PORT, byte);
}

fn write_data(byte: u8) void {
	while (! output_empty()) {}
	cpu.out(DATA_PORT, byte);
}

pub fn initialize() void {
	// Enable port 1
	write_command(0xAE);

	// Enable port 1 interrupts
	write_command(0x60);
	write_data(0x1);

	// Test port 1
	write_command(0xAB);

	while ((cpu.in(CMD_PORT) & 1) == 0) {}
	const result = cpu.in(0x60);
	uart.printf("PS/2 Keyboard ok: {}", .{result == 0});

	write_data(0xf4);

	pic.enable_irq(1);
}
