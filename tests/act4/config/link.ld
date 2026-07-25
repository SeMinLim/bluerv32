OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)

__num_harts = 1;
__stack_size = 0x00000400;

MEMORY
{
	imem (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00008000
	dmem (rwx) : ORIGIN = 0x00008000, LENGTH = 0x00008000
}

SECTIONS
{
	.text.init : {
		KEEP(*(.text.init))
	} > imem

	.text.rvtest : {
		*(.text.rvtest)
		*(.text.rvtest.*)
	} > imem

	__imem_end = .;
	ASSERT(__imem_end <= ORIGIN(imem) + LENGTH(imem),
		"ACT4 instruction image exceeds the 32 KiB instruction BRAM")

	.rodata : {
		. = ALIGN(0x4000);
		*(.rodata)
		*(.rodata.*)
	} > dmem

	.data : {
		. = ALIGN(16);
		*(.data)
		*(.data.*)
		*(.sdata)
		*(.sdata.*)
	} > dmem

	.bss (NOLOAD) : {
		. = ALIGN(16);
		__bss_start = .;
		*(.sbss)
		*(.sbss.*)
		*(.bss)
		*(.bss.*)
		*(COMMON)
		__bss_end = .;
	} > dmem

	.stack (NOLOAD) : {
		. = ALIGN(16);
		__stack_bottom = .;
		. = . + (__stack_size * __num_harts);
		__stack_top = .;
	} > dmem

	.text.rvmodel : {
		. = ALIGN(0x1000);
		*(.text.rvmodel)
		*(.text.rvmodel.*)
		*(.text)
		*(.text.*)
	} > dmem

	.tohost : {
		. = ALIGN(8);
		*(.tohost)
	} > dmem

	__dmem_end = .;
	ASSERT(__dmem_end <= ORIGIN(dmem) + LENGTH(dmem),
		"ACT4 data and RV model image exceeds the 32 KiB data BRAM")

	/DISCARD/ : {
		*(.comment)
		*(.riscv.attributes)
	}
}
