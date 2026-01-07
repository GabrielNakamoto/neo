// OS Address Space / Virtual Memory Map

// Link symbol addrs
extern const __kernel_virtual_start: u64;
extern const __bootstrap_mem_start: u64;
extern const __bootstrap_mem_end: u64;

pub inline fn kernelVirtStart() usize {
	return @intFromPtr(&__kernel_virtual_start);
}

pub inline fn bootstrapMemStart() usize {
	return @intFromPtr(&__bootstrap_mem_start);
}

pub inline fn bootstrapMemEnd() usize {
	return @intFromPtr(&__bootstrap_mem_end);
}
