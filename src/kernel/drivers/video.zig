const uefi = @import("std").os.uefi;

const Pixel = u32;
pub var frame_buffer: []volatile Pixel = undefined;

pub fn initialize(graphics_mode: *uefi.protocol.GraphicsOutput.Mode) void {
	frame_buffer.ptr = @ptrFromInt(graphics_mode.frame_buffer_base);
	frame_buffer.len = graphics_mode.frame_buffer_size / 32;
}
