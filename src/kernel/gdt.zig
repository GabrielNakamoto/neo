const uefi = @import("std").os.uefi;
const x86 = @import("./x86.zig");

const SegmentDescriptor = packed struct {
	limit_low: u16,
	base_low: u24,
	access: u8,
	limit_high: u4, 
	flags: u4,
	base_high: u8
};

const GDTDescriptor = packed struct {
	size: u16,
	offset: u64
};

const GDT = packed struct {
	null_descriptor: SegmentDescriptor,
	kernel_code: SegmentDescriptor,
	kernel_data: SegmentDescriptor,
	user_code: SegmentDescriptor,
	user_data: SegmentDescriptor,
	tss_low: SegmentDescriptor,
	tss_high: SegmentDescriptor
};

// Intel 64 and IA-32 Architectures Software Developers Manual
// Volume 3 Section 8.7
const TSS = packed struct {
	_0: u32,
	// Stack Pointers (RSP) for privilege level 0-2
	rsp0: u64,
	rsp1: u64,
	rsp2: u64,
	_1: u64,
	// Interrupt stack table (IST) Pointers
	ist1: u64,
	ist2: u64,
	ist3: u64,
	ist4: u64,
	ist5: u64,
	ist6: u64,
	ist7: u64,
	_2: u80,
	// 16-bit offset to I/0 permission bitmap from TSS base
	io_map: u16,
};

fn build_segment_descriptor(base: u32, limit: u20, access: u8, flags: u4) SegmentDescriptor {
	return .{
		.limit_low 	= @truncate(limit),
		.base_low 	= @truncate(base),
		.access 		= access,
		.limit_high = @truncate(limit >> 16),
		.flags 			= @truncate(flags),
		.base_high  = @truncate(base >> 24),
	};
}

// GDT Entry binary spec: https://wiki.osdev.org/Global_Descriptor_Table#Segment_Descriptor
// GDT Entry Access Flags
const PRESENT 			= (1 << 7);
const CODE_OR_DATA 	= (1 << 4);
const CODE					= (1 << 3);
const READ_WRITE 		= (1 << 1);
const USER_LEVEL 		= (3 << 5);
const KERNEL_ACCESS = (0 << 5);

const KERNEL = PRESENT | CODE_OR_DATA | READ_WRITE | KERNEL_ACCESS;
const USER   = PRESENT | CODE_OR_DATA | READ_WRITE | USER_LEVEL;

// GDT Entry Flags
const LONG_CODE = (1 << 1);
const PROTECTED = (1 << 2);
const BLOCKS_4K = (1 << 3);

// https://wiki.osdev.org/GDT_Tutorial#Flat_/_Long_Mode_Setup
var global_descriptor_table: GDT = .{
	.null_descriptor 	= build_segment_descriptor(0, 0, 0, 0),
	.kernel_code 			= build_segment_descriptor(0, 0xffff, KERNEL | CODE, 	BLOCKS_4K | LONG_CODE),
	.kernel_data 			= build_segment_descriptor(0, 0xffff, KERNEL, 				BLOCKS_4K | PROTECTED),
	.user_code 				= build_segment_descriptor(0, 0xffff, USER | CODE, 		BLOCKS_4K | LONG_CODE),
	.user_data 				= build_segment_descriptor(0, 0xffff, USER, 					BLOCKS_4K | PROTECTED),
	.tss_low					= build_segment_descriptor(0, 0, 0, 0),
	.tss_high					= build_segment_descriptor(0, 0, 0, 0),
};

// Empty tss?
const task_state_segment: TSS = undefined;

// https://wiki.osdev.org/Global_Descriptor_Table#Long_Mode_System_Segment_Descriptor
pub fn describe_tss(base: u64, size: u20) void {
	const base_low: u32 	= @truncate(base);
	const base_high: u32 	= @truncate(base >> 32);

	global_descriptor_table.tss_low  = build_segment_descriptor(base_low, size, 0x89, 0);
	global_descriptor_table.tss_high = .{
		.limit_low 	= @truncate(base_high),
		.base_low  	= @intCast(base_high >> 16),
		.access 		= 0,
		.limit_high = 0,
		.flags 			= 0,
		.base_high 	= 0,
	};
}

pub fn load() void {
	const gdt_descriptor: GDTDescriptor = .{
		.offset = @intFromPtr(&global_descriptor_table),
		.size = (@bitSizeOf(GDT) / 8) - 1 
	};

	describe_tss(@intFromPtr(&task_state_segment), (@bitSizeOf(TSS) / 8) - 1);
	x86.lgdt(@intFromPtr(&gdt_descriptor));
}
