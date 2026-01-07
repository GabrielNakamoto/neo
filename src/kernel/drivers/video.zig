const std = @import("std");
const uefi = std.os.uefi;
const mem = @import("../memory/mem.zig");
const vmm = @import("../memory/vmm.zig");
const uart = @import("../uart.zig");
const shared = @import("shared");

// Terminus 8x16 (ter-i16n) font bitmap
// 128 glyphs
const RAW_BITMAP = @embedFile("./font.bin");
const Pixel = u32;

var fb_info = std.mem.zeroes(shared.FramebufferInfo);

var foreground: Pixel = 0xFFFFFFFF;
var background: Pixel = 0x0;
const Cursor = struct {
	x: u32,
	y: u32
};
var cursor: Cursor = .{ .x = 0, .y = 0 };

const font_bitmap: *const[128][16]u8 = @ptrCast(RAW_BITMAP);
var frame_buffer: []volatile Pixel = &.{};
var swap_buffer: []volatile Pixel = &.{};

pub fn initialize(b_fb_info: *shared.FramebufferInfo) void {
	fb_info = b_fb_info.*;

	const frame_buffer_array: [*]volatile Pixel = @ptrFromInt(fb_info.base);
	const frame_buffer_len = fb_info.size / @sizeOf(Pixel);

	const swap_memory = mem.alloc_pages((fb_info.size + 4095) / 4096);
	const swap_pixels: [*]volatile Pixel = @ptrCast(@alignCast(swap_memory.ptr));

	frame_buffer = frame_buffer_array[0..frame_buffer_len];
	swap_buffer = swap_pixels[0..frame_buffer_len];
}

pub fn render() void {
	@memcpy(frame_buffer, swap_buffer);
}

// Write current text at same time / do buffer swap
pub fn fill_screen(pixel: Pixel) void {
	@memset(swap_buffer, pixel);
}

pub fn putchar(c: u8) void {
	for (0..16) |y| {
		for (0..8) |x| {
			const shift: u3 = @truncate(8 - x);
			const b = (font_bitmap[c][y] >> shift) & 1;
			const by = cursor.y*16 + y;
			const bx = cursor.x*8 + x;
			swap_buffer[by*fb_info.scanline_width + bx] = switch (b) {
				1 => foreground,
				else => background
			};
		}
	}
}

pub fn print(str: []const u8) void {
	for (str) |c| {
		putchar(c);
		cursor.x += 1;
	}
}

var format_buffer = std.mem.zeroes([1024]u8);
pub fn printf(comptime format: []const u8, args: anytype) void {
	const str = std.fmt.bufPrint(&format_buffer, format, args) catch unreachable;
	print(str);
}
