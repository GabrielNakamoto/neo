[bits 32]

; constants
VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x0f

print_pm:
	pusha
	mov edx, VIDEO_MEMORY

.loop:
	; VGA Byte
	mov al, [ebx] 			; store current ascii value in al
	mov ah, WHITE_ON_BLACK 	; store char attributes in ah

	cmp al, 0
	je .done

	mov [edx], ax	; place 2 byte VGA char in memory

	add ebx, 1 ; next char in string
	add edx, 2 ; next cell in VGA memory

	jmp .loop

.done:
	popa
	ret
