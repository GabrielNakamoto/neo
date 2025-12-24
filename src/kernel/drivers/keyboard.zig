const cpu = @import("../cpu.zig");
const uart = @import("../uart.zig");
const pic = @import("../pic.zig");
const isr = @import("../isr.zig");
const std = @import("std");

const CMD_PORT: u8 	= 0x64;
const KBD_PORT: u8 	= 0x60;
const ACK: u8 			= 0xFA;
const RESEND: u8 		= 0xFE;

const ControllerStatus = packed struct {
	read_buffer_full: bool,
	write_buffer_full: bool,
	system_flag: bool,
	controller_command: bool,
	unknown: u2,
	time_out_error: bool,
	parity_error: bool,
};

fn get_ps2_cfg() u8 {
	write_ps2_command(0x20);
	return read_keyboard();
}

fn set_ps2_cfg(cfg: u8) void {
	write_ps2_command(0x60);
	write_keyboard(cfg, false);
}

fn status() ControllerStatus {
	return @bitCast(cpu.in(CMD_PORT));
}

fn read_keyboard() u8 {
	while (! status().read_buffer_full) {}
	return cpu.in(KBD_PORT);
}

fn write_keyboard(cmd: u8, ack: bool) void {
	while (status().write_buffer_full) {}
	cpu.out(KBD_PORT, cmd);
	if (ack) {
		var res = read_keyboard();
		while (res != ACK) : (res = read_keyboard()) {
			if (res == RESEND) cpu.out(KBD_PORT, cmd);
		}
	}
}

fn write_ps2_command(byte: u8) void {
	while (status().write_buffer_full) {}
	cpu.out(CMD_PORT, byte);
}

fn irq(_: *isr.StackFrame) void {
	uart.print("Keyboard interrupt received!\n\r");
	const recv = cpu.in(KBD_PORT);
	uart.printf("Keyboard sent: 0x{x}\n\r", .{recv});
}

pub fn initialize() void {
	// Disable port 1 interrupts
	var config = get_ps2_cfg();
	config &= ~@as(u8, 1);
	set_ps2_cfg(config);

	// Enable port 1
	write_ps2_command(0xAE);

	// Enable keyboard scanning
	write_keyboard(0xF0, true); // Scan set 2
	write_keyboard(2, false); // Scan set 2
	write_keyboard(0xF4, true);

	// Enable port 1 interrupts
	var config2 = get_ps2_cfg();
	config2 |= 1;
	set_ps2_cfg(config2);

	isr.register_irq(1, &irq);
	pic.enable_irq(1);

	uart.print("Keyboard initialized\n\r");
}
