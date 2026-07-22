OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
	imem (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00001000
	dmem (rwx) : ORIGIN = 0x00001000, LENGTH = 0x00001000
}

SECTIONS
{
	.text : {
		KEEP(*(.text.start))
		*(.text)
		*(.text.*)
	} > imem

	.rodata : {
		. = ALIGN(4);
		*(.rodata)
		*(.rodata.*)
	} > dmem

	.data : {
		. = ALIGN(4);
		*(.data)
		*(.data.*)
		*(.sdata)
		*(.sdata.*)
	} > dmem

	.bss (NOLOAD) : {
		. = ALIGN(4);
		__bss_start = .;
		*(.sbss)
		*(.sbss.*)
		*(.bss)
		*(.bss.*)
		*(COMMON)
		__bss_end = .;
	} > dmem

	__stack_top = ORIGIN(dmem) + LENGTH(dmem);

	/DISCARD/ : {
		*(.comment)
		*(.riscv.attributes)
	}
}
