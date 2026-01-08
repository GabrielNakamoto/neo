ENTRY(_start)

__kernel_virtual_start = 0xC0000000;

SECTIONS {
	. = __kernel_virtual_start;

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
		*(.bss*)
		*(COMMON)

		. = ALIGN(4K);
		__bootstrap_mem_start = .;
		. += 128K;
		__bootstrap_mem_end = .;
	}

	. = ALIGN(4K);
	__kernel_virtual_end = .;


	/DISCARD/ : {
		*(.eh_frame*)
	}
}
