OUTPUT_FORMAT("binary");

MEMORY {
	PROG       (rwx) : ORIGIN = 0x0000, LENGTH = 462
	PART_TABLE (r)   : ORIGIN = ORIGIN(PROG) + LENGTH(PROG), LENGTH = 48
	SIGN       (r)   : ORIGIN = ORIGIN(PART_TABLE) + LENGTH(PART_TABLE), LENGTH = 2
}

SECTIONS {
	.prog : {*(.text) *(.data)} > PROG
	.sign : {SHORT(0xaa55)} > SIGN
}
