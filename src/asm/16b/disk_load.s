; load 'dh' sectors from drive 'dl' into ES:BX
disk_load:
	push dx

	mov ah, 0x02	; BIOS function
	mov al, dh		; # of sectors to read
	mov ch, 0x00	; track/cylinder #
	mov dh, 0x00	; sector #
	mov cl, 0x02 	; (1:...), 2 to start reading after boot sector

	int 0x13		; call interrupt

	jc .error

	pop dx
	cmp dh, al		; sectors requested == sectors read?
	jne .error
	ret

.error:

	mov bx, ERROR_MSG
	call print
	jmp $


ERROR_MSG	db "Disk read error!", 0
