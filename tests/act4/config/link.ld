OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)

__num_harts = 1;
__stack_size = 0x00001000;

MEMORY
{
	ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00100000
}

SECTIONS
{
	.text.init : {
		KEEP(*(.text.init))
	} > ram

	.text.rvtest : {
		*(.text.rvtest)
		*(.text.rvtest.*)
	} > ram

	.rodata : {
		. = ALIGN(0x4000);
		*(.rodata)
		*(.rodata.*)
		*(.srodata)
		*(.srodata.*)
	} > ram

	.data : {
		. = ALIGN(16);
		*(.data)
		*(.data.*)
		*(.sdata)
		*(.sdata.*)
	} > ram

	.bss (NOLOAD) : {
		. = ALIGN(16);
		__bss_start = .;
		*(.sbss)
		*(.sbss.*)
		*(.bss)
		*(.bss.*)
		*(COMMON)
		__bss_end = .;
	} > ram

	.stack (NOLOAD) : {
		. = ALIGN(16);
		__stack_bottom = .;
		. = . + (__stack_size * __num_harts);
		__stack_top = .;
	} > ram

	.text.rvmodel : {
		. = ALIGN(0x1000);
		*(.text.rvmodel)
		*(.text.rvmodel.*)
		*(.text)
		*(.text.*)
	} > ram

	.tohost : {
		. = ALIGN(8);
		*(.tohost)
	} > ram

	__act4_memory_end = .;
	ASSERT(__act4_memory_end <= ORIGIN(ram) + LENGTH(ram),
		"ACT4 image exceeds the 1 MiB unified simulation memory")

	/DISCARD/ : {
		*(.comment)
		*(.riscv.attributes)
	}
}
