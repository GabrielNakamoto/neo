ENTRY(kmain)

KERNEL_VIR_START = 1M;

SECTIONS {
	. = KERNEL_VIR_START;

	.text : ALIGN(4K) {
		*(.text*)
	}

	.rodata : ALIGN(4K) {
		*(.rodata*)
	}

	.data : ALIGN(4K) {
		*(.data*)
	}

	.bss : ALIGN(4K) {
		*(COMMON)
		*(.bss*)
	}

	/DISCARD/ : {
		*(.eh_frame*)
	}
}
