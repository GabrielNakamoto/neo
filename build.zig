const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.resolveTargetQuery(.{
		.cpu_arch = .x86,
		.os_tag = .freestanding,
		.abi = .none,
	});
	const kernel = b.addExecutable(.{
		.name = "neo",
		.root_module = b.createModule(.{
			.root_source_file = b.path("kernel.zig"),
			.target = target,
			.optimize = .ReleaseSmall
		}),
	});
	kernel.addAssemblyFile(b.path("kernel_entry.s"));
	kernel.setLinkerScript(b.path("linker.ld"));
	b.installArtifact(kernel);
}
