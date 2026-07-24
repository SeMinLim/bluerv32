#ifndef BLUERV32_RVMODEL_MACROS_H
#define BLUERV32_RVMODEL_MACROS_H

#define RVMODEL_BOOT
#define RVMODEL_BOOT_TO_MMODE
#define RVMODEL_FENCEI nop
#define RVMODEL_IO_INIT(_R1, _R2, _R3)

#ifdef SIGNATURE

#define RVMODEL_DATA_SECTION \
	.pushsection .tohost,"aw",@progbits; \
	.align 3; \
	.global tohost; \
	tohost: .dword 0; \
	.align 3; \
	.global fromhost; \
	fromhost: .dword 0; \
	.popsection;

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)

#define RVMODEL_HALT_PASS \
	li t0, 1; \
	la t1, tohost; \
1: \
	sw t0, 0(t1); \
	sw zero, 4(t1); \
	j 1b;

#define RVMODEL_HALT_FAIL \
	li t0, 3; \
	la t1, tohost; \
1: \
	sw t0, 0(t1); \
	sw zero, 4(t1); \
	j 1b;

#else

#define RVMODEL_DATA_SECTION

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR) \
	li _R2, 0x10000000; \
1: \
	lbu _R1, 0(_STR_PTR); \
	beq _R1, zero, 2f; \
	sb _R1, 0(_R2); \
	addi _STR_PTR, _STR_PTR, 1; \
	j 1b; \
2:

#define RVMODEL_HALT_PASS \
	ebreak; \
1: \
	j 1b;

#define RVMODEL_HALT_FAIL \
	ebreak; \
1: \
	j 1b;

#endif

#endif
