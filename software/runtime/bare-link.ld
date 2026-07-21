MEMORY
{
	ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0xffffffff
}

SECTIONS
{
	. = 0x0;

	.text : {
		*(.text)
		*(.text.*)
	} > ram

	. = ALIGN(0x4000);

	.rodata : {
		*(.rodata)
		*(.rodata.*)
	} > ram

	.data : {
		*(.data)
		*(.data.*)
	} > ram

	.sdata : {
		*(.sdata)
		*(.sdata.*)
	} > ram

	.sbss (NOLOAD) : {
		*(.sbss)
		*(.sbss.*)
	} > ram

	.bss (NOLOAD) : {
		*(.bss)
		*(.bss.*)
		*(COMMON)
	} > ram

	.riscv.attributes : {
		*(.riscv.attributes)
	} > ram
}
