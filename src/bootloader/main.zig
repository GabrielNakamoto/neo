const uefi = @import("std").os.uefi;
const elf = @import("std").elf;

inline fn hlt() void {
	asm volatile("hlt");
}

fn bootloader() !void {
	// const uefi_table: *uefi.tables.SystemTable = uefi.system_table;

	while (true) {
		hlt();
	}
}

pub fn main() void {
	// TODO: error handle
	bootloader() catch {
		while (true) {
			hlt();
		}
	};
}
