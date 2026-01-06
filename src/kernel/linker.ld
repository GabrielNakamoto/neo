ENTRY(kmain)

V_START = 0xC0000000;

SECTIONS {
	. = V_START; /* does this matter? */

	.text ALIGN(4K) : {
		*(.text*)
	}

	.rodata ALIGN(4K) : {
		*(.rodata*)
	}

	.data ALIGN(4K) : {
		*(.data*)
	}

	.bss ALIGN(4K) : {
		*(COMMON)
		*(.bss*)
	}

	/DISCARD/ : {
		*(.eh_frame*)
	}
}
