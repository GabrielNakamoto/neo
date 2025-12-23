const uefi = @import("std").os.uefi;
const paging = @import("../paging.zig");

const Pixel = u32;
pub var frame_buffer: []volatile Pixel = undefined;

// Terminus 8x16 (ter-i16n) font bitmap
// 128 glyphs
const RAW_BITMAP = @embedFile("../font.bin");
const BITMAP: *const [128][16]u8 = @ptrCast(RAW_BITMAP);

var scanline: u32 = undefined;

pub fn initialize(graphics_mode: *uefi.protocol.GraphicsOutput.Mode) void {
	frame_buffer.ptr = @ptrFromInt(graphics_mode.frame_buffer_base);
	frame_buffer.len = graphics_mode.frame_buffer_size / @sizeOf(Pixel);
	scanline = graphics_mode.info.pixels_per_scan_line;
}

pub fn fill_screen(pixel: Pixel) void {
	@memset(frame_buffer, pixel);
}

pub fn putchar(c: u8, dx: u32, fg: Pixel, bg: Pixel) void {
	for (0..16) |y| {
		for (0..8) |x| {
			const shift: u3 = @truncate(8 - x);
			const b = (BITMAP[c][y] >> shift) & 1;
			frame_buffer[(y*scanline)+x+(dx*8)] = switch (b) {
				1 => fg,
				else => bg
			};
		}
	}
}

pub fn print(str: []const u8) void {
	for (str, 0..) |c, dx| {
		putchar(c, @intCast(dx), 0xFFFFFFFF, 0x0);
	}
}
