.section .text.start
.globl _start

_start:
	li t0, 7
	li t1, -3
	mul t2, t0, t1
	li t3, -21
	bne t2, t3, fail

	li t0, -2
	li t1, 3
	mulh t2, t0, t1
	li t3, -1
	bne t2, t3, fail

	li t0, -2
	li t1, -1
	mulhsu t2, t0, t1
	li t3, -2
	bne t2, t3, fail

	li t0, -1
	li t1, -1
	mulhu t2, t0, t1
	li t3, -2
	bne t2, t3, fail

	ebreak

fail:
	addi a0, zero, 1
	ebreak
