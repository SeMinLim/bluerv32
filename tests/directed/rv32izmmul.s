.section .text.start
.globl _start

_start:
	li t6, 0x10000000

	li t0, 7
	li t1, -3
	mul t2, t0, t1
	li t3, -21
	bne t2, t3, fail

	li t0, 0x80000000
	li t1, 2
	mul t2, t0, t1
	bne t2, zero, fail

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

	li t0, 0x12345
	li t1, 3
	mul t0, t0, t1
	li t3, 0x369cf
	bne t0, t3, fail

	li t0, 4
	li t1, 5
	mul t1, t0, t1
	li t3, 20
	bne t1, t3, fail

	mul zero, t0, t1
	mul t2, zero, t1
	bne t2, zero, fail
	mul t2, t0, zero
	bne t2, zero, fail

	li t0, 'P'
	sb t0, 0(t6)
	ebreak

fail:
	li t0, 'F'
	sb t0, 0(t6)
	ebreak
