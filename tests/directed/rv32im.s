.section .text.start
.globl _start

_start:
	li t6, 0x10000000

	# Signed division truncates toward zero.
	li t0, 10
	li t1, 3
	div t2, t0, t1
	li t3, 3
	bne t2, t3, fail

	li t0, -10
	li t1, 3
	div t2, t0, t1
	li t3, -3
	bne t2, t3, fail

	li t0, 10
	li t1, -3
	div t2, t0, t1
	li t3, -3
	bne t2, t3, fail

	li t0, -10
	li t1, -3
	div t2, t0, t1
	li t3, 3
	bne t2, t3, fail

	# Unsigned division preserves the full 32-bit operand range.
	li t0, -1
	li t1, 2
	divu t2, t0, t1
	li t3, 0x7fffffff
	bne t2, t3, fail

	# Signed remainder follows the dividend sign.
	li t0, -10
	li t1, 3
	rem t2, t0, t1
	li t3, -1
	bne t2, t3, fail

	li t0, 10
	li t1, -3
	rem t2, t0, t1
	li t3, 1
	bne t2, t3, fail

	li t0, -10
	li t1, -3
	rem t2, t0, t1
	li t3, -1
	bne t2, t3, fail

	li t0, -1
	li t1, 2
	remu t2, t0, t1
	li t3, 1
	bne t2, t3, fail

	# Division by zero is an architectural result rather than a trap.
	li t0, 0x12345678
	li t1, 0
	div t2, t0, t1
	li t3, -1
	bne t2, t3, fail
	divu t2, t0, t1
	bne t2, t3, fail
	rem t2, t0, t1
	bne t2, t0, fail
	remu t2, t0, t1
	bne t2, t0, fail

	# The only signed overflow case also returns a defined result.
	li t0, 0x80000000
	li t1, -1
	div t2, t0, t1
	bne t2, t0, fail
	rem t2, t0, t1
	bne t2, zero, fail

	# Source and destination registers may overlap.
	li t0, -19
	li t1, 4
	div t0, t0, t1
	li t3, -4
	bne t0, t3, fail

	li t0, 19
	li t1, 4
	rem t1, t0, t1
	li t3, 3
	bne t1, t3, fail

	# Writes to x0 are discarded and x0 operands remain zero.
	div zero, t0, t1
	div t2, zero, t1
	bne t2, zero, fail
	rem t2, zero, t1
	bne t2, zero, fail

	li t0, 'P'
	sb t0, 0(t6)
	ebreak

fail:
	li t0, 'F'
	sb t0, 0(t6)
	ebreak
