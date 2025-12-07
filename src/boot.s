[org 0x7c00]
KERNEL_OFFSET equ 0x1000
	mov [BOOT_DRIVE], dl

	; initialize stack
	mov bp, 0x9000
	mov sp, bp
	
	mov bx, MSG_RM
	call print

	call load_kernel
	call switch_to_pm

	jmp $ ; hang

%include "src/asm/16b/disk_load.s"
%include "src/asm/16b/print.s"
%include "src/asm/16b/print_hex.s"
%include "src/asm/gdt.s"
%include "src/asm/pm.s"
%include "src/asm/print.s"

[bits 16]
load_kernel:
	mov bx, MSG_KERNEL
	call print

	mov bx, KERNEL_OFFSET
	mov dh, 2
	mov dl, [BOOT_DRIVE]
	call disk_load

	ret

[bits 32]
BEGIN_PM:
	mov ebx, MSG_PM
	call print_pm

	call KERNEL_OFFSET

	jmp $ ; hang

BOOT_DRIVE 	db 0
MSG_RM		db "Starting in 16-bit Real Mode", 0
MSG_PM		db "Switched to 32-bit Protected Mode", 0
MSG_KERNEL	db "Loading kernel executable from disk", 0

times 510-($-$$) db 0
dw 0xaa55
