const uefi = @import("std").os.uefi;

const SegmentDescriptor = packed struct {
	limit_low: u16,
	base_low: u24,
	access: u8,
	limit_high: u4, 
	flags: u4,
	base_high: u8
};

fn build_segment_descriptor(base: u32, limit: u20, access: u8, flags: u4) SegmentDescriptor {
	return .{
		.limit_low = limit & 0xffff,
		.base_low = base & 0xfffff,
		.access = access,
		.limit_high = (limit >> 16) & 0xf,
		.flags = flags,
		.base_high = (base >> 24) & 0xff
	};
}

// https://wiki.osdev.org/GDT_Tutorial#Flat_/_Long_Mode_Setup
const global_descriptor_table = [_]SegmentDescriptor{
	build_segment_descriptor(0, 0, 0, 0),							// Null descriptor
	build_segment_descriptor(0, 0xffff, 0x9A, 0xA),		// Kernel Code
	build_segment_descriptor(0, 0xffff, 0x92, 0xC),		// Kernel Data
	build_segment_descriptor(0, 0xffff, 0xF2, 0xC),		// User Code
	build_segment_descriptor(0, 0xffff, 0xFA, 0xA)		// User Data
};

pub fn load(boot_services: *uefi.tables.BootServices) !void {
	const byte_size: usize = global_descriptor_table.len * 8;
	const buffer = try boot_services.allocatePool(.boot_services_data, byte_size);
	const buffer_ptr: [*]SegmentDescriptor = @ptrCast(@alignCast(buffer.ptr));
	@memcpy(buffer_ptr, &global_descriptor_table);

	const gdt_addr = @intFromPtr(buffer.ptr);
	const gdt_descriptor: u64 = (gdt_addr << 16) | (byte_size - 1);

	asm volatile (
		\\lgdt %[gdtr]
		:: [gdtr] "m" (gdt_descriptor)
	);
}
