const uefi = @import("std").os.uefi;

pub const BootInfo = struct {
	final_mmap: uefi.tables.MemoryMapSlice,
	fb_info: FramebufferInfo,
	runtime_services: *uefi.tables.RuntimeServices,
	kernel_paddr: u64,
	kernel_size: u64,
};

pub const FramebufferInfo = struct {
	base: u64,
	size: u64,
	width: u32,
	height: u32,
	scanline_width: u32,
	format: uefi.protocol.GraphicsOutput.PixelFormat
};
