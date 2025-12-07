OUTPUT_FORMAT(binary)
ENTRY(_start)

SECTIONS {
	/*
	Kernel start address in memory is 0x1000
	*/
	. = 0x1000;

	/*
	- Align sections on 4K byte boundaries
	- *(.<name>) selects every section with name = <name> from every input file?
	*/
	.text 0 : {
		*(.text._start)
		*(.text*)
	}

	.rodata : ALIGN(4K) {
		*(.rodata)
	}

	.data : ALIGN(4K) {
		*(.data)
	}

	.bss : ALIGN(4K) {
		*(.bss)
		*(COMMON)
	}
}
