#ifndef BLUERV32_RVMODEL_MACROS_H
#define BLUERV32_RVMODEL_MACROS_H

#ifdef STANDARD_SM_SUPPORTED
#undef STANDARD_SM_SUPPORTED
#endif

#ifdef ZICSR_SUPPORTED
#undef ZICSR_SUPPORTED
#endif

#ifdef ZIFENCEI_SUPPORTED
#error "blueRV32 ACT4 DUT configuration must not enable Zifencei."
#endif

#define RVMODEL_BOOT
#define RVMODEL_BOOT_TO_MMODE
#define RVMODEL_IO_INIT(_R1, _R2, _R3)

#define RVMODEL_INTERRUPT_LATENCY 1
#define RVMODEL_TIMER_INT_SOON_DELAY 1
#define RVMODEL_MAX_CYCLES_PER_TIMER_TICK 1

#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)

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
