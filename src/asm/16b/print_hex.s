; dx = hexadecimal number to be printed
print_hex:
	pusha

	mov cx, 0
.loop:
	cmp cx, 4
	je .done

	mov ax, dx
	and ax, 0x000f
	add al, '0'
	cmp al, 0x39
	jle .step2
	add al, 7

.step2:
	mov bx, HEX_TEMPLATE + 5
	sub bx, cx
	mov [bx], al
	shr dx, 4

	add cx, 1
	jmp .loop

.done:
	mov bx, HEX_TEMPLATE
	call print

	popa
	ret

HEX_TEMPLATE:
	db '0x0000', 0
