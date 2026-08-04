.section .text.start
.globl _start

_start:
	li t0, 7
	li t1, -3
	mul t2, t0, t1
	li t3, -21
	bne t2, t3, fail

	li t0, -2
	li t1, -1
	mulhsu t2, t0, t1
	li t3, -2
	bne t2, t3, fail

	li t0, -10
	li t1, 3
	div t2, t0, t1
	li t3, -3
	bne t2, t3, fail

	li t0, -1
	li t1, 2
	divu t2, t0, t1
	li t3, 0x7fffffff
	bne t2, t3, fail

	li t0, -10
	li t1, 3
	rem t2, t0, t1
	li t3, -1
	bne t2, t3, fail

	li t0, -1
	li t1, 2
	remu t2, t0, t1
	li t3, 1
	bne t2, t3, fail

	li t0, 0x12345678
	li t1, 0
	div t2, t0, t1
	li t3, -1
	bne t2, t3, fail
	rem t2, t0, t1
	bne t2, t0, fail

	li t0, 0x80000000
	li t1, -1
	div t2, t0, t1
	bne t2, t0, fail
	rem t2, t0, t1
	bne t2, zero, fail

	ebreak

fail:
	addi a0, zero, 1
	ebreak
