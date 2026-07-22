.section .text.start
.globl _start

_start:
	li t6, 0x10000000
	la t0, testData

	li t1, 0x80
	sb t1, 0(t0)
	lb t2, 0(t0)
	li t3, 0xffffff80
	bne t2, t3, fail
	lbu t2, 0(t0)
	li t3, 0x80
	bne t2, t3, fail

	li t1, 0x8001
	sh t1, 2(t0)
	lh t2, 2(t0)
	li t3, 0xffff8001
	bne t2, t3, fail
	lhu t2, 2(t0)
	li t3, 0x8001
	bne t2, t3, fail

	li t1, 0x89abcdef
	sw t1, 4(t0)
	lw t2, 4(t0)
	bne t2, t1, fail

	li t1, 'P'
	sb t1, 0(t6)
	ebreak

fail:
	li t1, 'F'
	sb t1, 0(t6)
	ebreak

.section .bss
.align 2
testData:
	.space 8
