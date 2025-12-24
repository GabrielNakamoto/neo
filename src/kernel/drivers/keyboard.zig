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

const KeyState = enum(u1) {
	Up,
	Down,
};

const ScanCode = packed struct {
	suffix: u8,
	root: u8 = 0x0,
	prefix: u8 = 0x0,
};

const KeyTrigger = struct {
	key_id: u8,
	pressed: ScanCode,
	released: ScanCode,
};

// Start with ineffient comptime array
//
// TODO: Optimize with custom comptime hashmap or
//       runtime std hashmap with memory allocation?
//
// https://webdocs.cs.ualberta.ca/~amaral/courses/329/labs/scancodes.html
const key_triggers: [128]KeyTrigger = blk: {
	var foo_triggers: [128]KeyTrigger = undefined;
	for (65..'Z'+1) |key| {
		foo_triggers[key] = KeyTrigger{
			.key_id = key,
			.pressed = .{ .suffix = alphabet_suffix_codes[key-65] },
			.released = .{ .root = 0xFA, .suffix = alphabet_suffix_codes[key-65] }
		};
	}
	break :blk foo_triggers;
};

const alphabet_suffix_codes = [_]u8 {
	0x1c, 0x32, 0x21, 0x23, 0x24, 0x2B, 0x34, 0x33, 0x43, 0x3B, 0x42, 0x4B, 0x3A, 0x31, 0x44, 0x4D, 0x15, 0x2D, 0x1B, 0x2C, 0x3C, 0x2A, 0x1D, 0x22, 0x35, 0x1A
};

// Start with just alphabet, numbers and space?
var keymap: [128]KeyState = undefined;
var current_scancode: ScanCode = undefined;

fn irq(_: *isr.StackFrame) void {
	const scancode = cpu.in(KBD_PORT);
	switch (scancode) {
		0xE0 => current_scancode.prefix = 0xE0,
		0xF0 => current_scancode.root = 0xFA,
		else => {
			current_scancode.suffix = scancode;
			for (&key_triggers) |trigger| {
				if (current_scancode == trigger.pressed) {
					uart.printf("{c} pressed\n\r", .{trigger.key_id});
				} else if (current_scancode == trigger.released) {
					uart.printf("{c} released\n\r", .{trigger.key_id});
				} else {
					continue;
				}
				break;
			}
			current_scancode = @bitCast(@as(u24, 0x0));
		}
	}
}

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

pub fn initialize() void {
	// Disable port 1 interrupts
	var config = get_ps2_cfg();
	config &= ~@as(u8, 1);
	set_ps2_cfg(config);

	// Enable port 1
	write_ps2_command(0xAE);

	// Enable keyboard scanning
	write_keyboard(0xF4, true);
	write_keyboard(0xF0, true); // Scan set 2
	write_keyboard(2, true); // Scan set 2

	// Enable port 1 interrupts
	var config2 = get_ps2_cfg();
	config2 |= 1;
	config2 &= ~@as(u8, 1 << 6); // Disable translation, force scan set 2
	set_ps2_cfg(config2);

	isr.register_irq(1, &irq);
	pic.enable_irq(1);

	uart.print("Keyboard initialized\n\r");
}
