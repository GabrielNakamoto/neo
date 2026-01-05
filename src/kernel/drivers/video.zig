const uefi = @import("std").os.uefi;
const std = @import("std");

// Terminus 8x16 (ter-i16n) font bitmap
// 128 glyphs
const RAW_BITMAP = @embedFile("../font.bin");
const Pixel = u32;

const Self = @This();

foreground: Pixel = 0xFFFFFFFF,
background: Pixel = 0x0,
scanline_width: u32,
font_bitmap: *const[128][16]u8 = @ptrCast(RAW_BITMAP),
frame_buffer: []volatile Pixel,
swap_buffer: []volatile Pixel,
cursor: u64 = 0,

pub fn initialize(graphics_mode: *uefi.protocol.GraphicsOutput.Mode) Self {
	const frame_buffer_array: [*]volatile Pixel = @ptrFromInt(graphics_mode.frame_buffer_base);
	const frame_buffer_len = graphics_mode.frame_buffer_size / @sizeOf(Pixel);

	// var swp: []volatile Pixel = &.{};
	// swp.ptr = @ptrCast(pmm.malloc(Pixel, frame_buffer_len));
	// swp.len = frame_buffer_len;

	return .{
		.frame_buffer = frame_buffer_array[0..frame_buffer_len],
		.swap_buffer = frame_buffer_array[0..frame_buffer_len],
		// .swap_buffer = swp,
		.scanline_width = graphics_mode.info.pixels_per_scan_line,
	};
}

pub fn render(self: *Self) void {
	_ = self;
	// @memcpy(self.frame_buffer, self.swap_buffer);
}

// Write current text at same time / do buffer swap
pub fn fill_screen(self: *Self, pixel: Pixel) void {
	@memset(self.swap_buffer, pixel);
}

pub fn putchar(self: Self, c: u8, dx: u32) void {
	for (0..16) |y| {
		for (0..8) |x| {
			const shift: u3 = @truncate(8 - x);
			const b = (self.font_bitmap[c][y] >> shift) & 1;
			self.swap_buffer[(y*self.scanline_width)+x+(dx*8)] = switch (b) {
				1 => self.foreground,
				else => self.background
			};
		}
	}
}

pub fn print(self: Self, str: []const u8) void {
	for (str, 0..) |c, dx| {
		self.putchar(c, @intCast(dx));
	}
}

var format_buffer: [1024]u8 = undefined;
pub fn printf(self: Self, comptime format: []const u8, args: anytype) void {
	const str = std.fmt.bufPrint(&format_buffer, format, args) catch unreachable;
	self.print(str);
}
