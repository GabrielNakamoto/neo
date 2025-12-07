#!/bin/bash

nasm -f bin src/boot.s -o bin/boot.bin
zig build
cat bin/boot.bin zig-out/bin/neo > bin/os-image
qemu-system-i386 bin/os-image
