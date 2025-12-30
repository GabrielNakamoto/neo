const uefi = @import("std").os.uefi;
const cpu = @import("./cpu.zig");

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

const TSSDescriptor = packed struct {
	limit_low: u16,
	base_low: u24,
	access: u8,
	limit_high: u4,
	flags: u4,
	base_high: u40,
	reserved: u32,
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

const Access = packed struct {
	accessed: 	bool 	= false,
	read_write: bool,
	dc: 				bool 	= false,
	exec: 			bool 	= false,
	not_system: bool 	= true,
	privilege: 	u2,
	present: 		bool 	= true,

	pub fn data(self: Access) u8 {
		var copy = self;
		copy.exec = false;
		return @bitCast(copy);
	}

	pub fn code(self: Access) u8 {
		var copy = self;
		copy.exec = true;
		return @bitCast(copy);
	}
};

const KernelAccess: Access = .{
	.privilege = 0,
	.read_write = true,
};

const UserAccess: Access = .{
	.privilege = 3,
	.read_write = true,
};

// GDT Entry Flags
const LONG_CODE = (1 << 1);
const BLOCKS_4K = (1 << 3);

// https://wiki.osdev.org/GDT_Tutorial#Flat_/_Long_Mode_Setup
var global_descriptor_table: GDT = .{
	.null_descriptor 	= build_segment_descriptor(0, 0, 0, 0),
	.kernel_code 			= build_segment_descriptor(0, 0xfffff, KernelAccess.code(), 	BLOCKS_4K | LONG_CODE),
	.kernel_data 			= build_segment_descriptor(0, 0xfffff, KernelAccess.data(), 	BLOCKS_4K),
	.user_code 				= build_segment_descriptor(0, 0xfffff, UserAccess.code(), 		BLOCKS_4K | LONG_CODE),
	.user_data 				= build_segment_descriptor(0, 0xfffff, UserAccess.data(), 		BLOCKS_4K),
	.tss_low					= build_segment_descriptor(0, 0, 0, 0),
	.tss_high					= build_segment_descriptor(0, 0, 0, 0),
};

// Empty tss?
const task_state_segment: TSS = undefined;

// https://wiki.osdev.org/Global_Descriptor_Table#Long_Mode_System_Segment_Descriptor
pub fn describe_tss(base: u64, size: u20) void {
	var tss_descr: *TSSDescriptor = @ptrCast(&global_descriptor_table.tss_low);

	tss_descr.base_low 		= @truncate(base);
	tss_descr.base_high 	= @truncate(base >> 32);
	tss_descr.limit_low 	= @truncate(size);
	tss_descr.limit_high 	= @truncate(size >> 16);
	tss_descr.access 			= 0x89;
	tss_descr.flags 			= 0x0;
}

// Reload segment registers with kernel data seg selector
fn reloadSegments() void {
	asm volatile (
		\\mov $0x10, %%rax
		\\mov %%rax, %%ds
		\\mov %%rax, %%es
		\\mov %%rax, %%fs
		\\mov %%rax, %%gs
		\\mov %%rax, %%ss
		::: .{ .rax = true }
	);
}

// Relead code segment register with kernel code seg selector
fn reloadCs() void {
	asm volatile (
		\\mov $0x8, %%rax
		\\push %%rax
		\\leaq next_%=(%%rip), %%rax
		\\pushq %%rax
		\\lretq
		\\next_%=:
	);
}

pub fn load() void {
	const gdt_descriptor: GDTDescriptor = .{
		.offset = @intFromPtr(&global_descriptor_table),
		.size = (@bitSizeOf(GDT) / 8) - 1 
	};

	describe_tss(@intFromPtr(&task_state_segment), (@bitSizeOf(TSS) / 8) - 1);
	cpu.lgdt(@intFromPtr(&gdt_descriptor));

	reloadSegments();
	reloadCs();
}
