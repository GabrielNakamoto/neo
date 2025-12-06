int foo() {
	return 'A';
}

void main() {
	char *vga_memory = (char*) 0xb8000;

	*vga_memory = foo();
}
