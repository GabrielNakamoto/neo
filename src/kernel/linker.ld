ENTRY(kmain)

KERNEL_PHYS_START = 1M;

SECTIONS {
	. = KERNEL_PHYS_START;

	.text : ALIGN(4K) {
		*(.text)
	}

	.rodata : ALIGN(4K) {
		*(.rodata*)
	}

	/DISCARD/ : {
		*(.eh_frame*)
	}
}
