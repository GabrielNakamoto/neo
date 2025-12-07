const VGA_MEMORY = @as([*]volatile u16, @ptrFromInt(0xB8000));
const VGA_INDEX_PORT: u16 = 0x3D4;
const VGA_DATA_PORT: u16 = 0x3D5;

fn read_port(port: u16) u8 {
	return asm volatile (
		\\ in %[port], %[result]
		: [result] "={al}" (-> u8)
		: [port] "{dx}" (port)
	);
}

fn write_port(port: u16, value: u8) void {
	asm volatile (
		\\ out %[value], %[port]
		:: [value] "{al}" (value),
		   [port]  "{dx}" (port)
	);
}

pub fn print(str: []const u8) void {
	var offset = get_cursor();

	for (str) |ch| {
		const attr: u16 = @as(u16, 0xF) << 8;
		const char: u16 = ch;
		VGA_MEMORY[offset] = attr | char;
		offset += 1;
	}

	set_cursor(offset);
}

pub fn get_cursor() u32 {
	write_port(VGA_INDEX_PORT, 14);
	var offset: u32 = read_port(VGA_DATA_PORT);
	offset <<= 8;
	write_port(VGA_INDEX_PORT, 15);
	offset += read_port(VGA_DATA_PORT);

	return offset;
}

pub fn set_cursor(offset: u32) void {
	write_port(VGA_INDEX_PORT, 14);
	write_port(VGA_DATA_PORT, @intCast(offset >> 8));

	write_port(VGA_INDEX_PORT, 15);
	write_port(VGA_DATA_PORT, @intCast(offset & 0xFF));
}
