#!/bin/bash

nasm -f bin boot.s -o boot.bin
zig build
cat boot.bin zig-out/bin/neo > os-image
qemu-system-i386 os-image
