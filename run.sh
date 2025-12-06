#!/bin/bash

nasm -f bin boot.s -o boot.bin

nasm kernel_entry.s -f elf -o kernel_entry.o
gcc -m32 -fno-PIE -no-pie -ffreestanding -c kernel.c -o kernel.o
ld -m elf_i386 -o kernel.bin -Ttext 0x1000 kernel_entry.o kernel.o --oformat binary
cat boot.bin kernel.bin > os-image
qemu-system-i386 os-image
