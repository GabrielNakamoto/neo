.global _start
.type _start, @function

_start:
	call kmain

	cli
	hlt
