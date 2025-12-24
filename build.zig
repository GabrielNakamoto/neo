const std = @import("std");

pub fn build(b: *std.Build) void {
	const kernel_target = b.resolveTargetQuery(.{
		.cpu_arch = .x86_64,
		.os_tag = .freestanding,
		.abi = .none,
		.ofmt = .elf,
	});
	
	const boot_target = b.resolveTargetQuery(.{
		.cpu_arch = .x86_64,
		.os_tag = .uefi,
		.abi = .none,
		.ofmt = .coff,
	});

	const kernel_mod = b.createModule(.{
		.root_source_file = b.path("src/kernel/main.zig"),
		.target = kernel_target,
		.optimize = .ReleaseSmall,
		.code_model = .kernel,
	});

	const kernel = b.addExecutable(.{
		.name = "kernel.elf",
		.root_module = kernel_mod,
		.use_lld = true,
		.use_llvm = true
	});

	kernel.entry = .disabled;
	kernel.setLinkerScript(b.path("src/kernel/linker.ld"));

	const boot_mod = b.createModule(.{
		.root_source_file = b.path("src/bootloader/main.zig"),
		.target = boot_target,
		.optimize = .ReleaseSmall,
	});

	const boot = b.addExecutable(.{
		.name = "bootx64",
		.root_module = boot_mod
	});

	b.installArtifact(boot);
	b.installArtifact(kernel);

	const boot_dir = b.addWriteFiles();

	_ = boot_dir.addCopyFile(
		boot.getEmittedBin(),
		b.pathJoin(&.{
			"efi",
			"boot",
			boot.out_filename
		}),
	);

	_ = boot_dir.addCopyFile(
		kernel.getEmittedBin(),
		kernel.out_filename
	);

	const qemu_cmd = b.addSystemCommand(&.{"qemu-system-x86_64"});
	qemu_cmd.addArg("-serial");
	qemu_cmd.addArg("mon:stdio");

	qemu_cmd.addArg("-machine");
	qemu_cmd.addArg("q35");

	//.qemu_cmd.addArg("--enable-kvm");
	qemu_cmd.addArg("-rtc");
	qemu_cmd.addArg("base=localtime,clock=host");

	const gdb_debug = b.option(bool, "gdb", "Configure QEMU for debugging with gdb") orelse false;
	if (gdb_debug) {
		qemu_cmd.addArg("-s");
		qemu_cmd.addArg("-S");
	}

	const ocp = b.path("OVMF.fd");
	const oc = boot_dir.addCopyFile(
		ocp,
		ocp.basename(b, &boot_dir.step),
	);

	//qemu_cmd.addArg("-drive");
	//qemu_cmd.addPrefixedFileArg(
		//"format=raw,if=pflash,file=",
		//oc,
	//);
	qemu_cmd.addArg("-bios");
	qemu_cmd.addFileArg(oc);

	qemu_cmd.addArg("-drive");
    qemu_cmd.addPrefixedDirectoryArg(
        "format=raw,index=3,media=disk,file=fat:rw:",
        boot_dir.getDirectory(),
	);

	const qemu_step = b.step("qemu", "Run the kernel via QEMU");
	qemu_step.dependOn(&qemu_cmd.step);
}
