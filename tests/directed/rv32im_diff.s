.section .text.start
.globl _start

_start:
	addi a0, zero, 0

	# Cover all four multiplication instructions inherited from Zmmul.
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

	# Cover signed and unsigned quotient and remainder operations.
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

	# Division by zero returns the architectural quotient or original dividend.
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

	# Signed overflow returns the dividend for DIV and zero for REM.
	li t0, 0x80000000
	li t1, -1
	div t2, t0, t1
	bne t2, t0, fail
	rem t2, t0, t1
	bne t2, zero, fail

	# Boundary operands exercise the high quotient and remainder bits.
	li t0, 0x7fffffff
	li t1, 3
	div t2, t0, t1
	li t3, 0x2aaaaaaa
	bne t2, t3, fail
	rem t2, t0, t1
	li t3, 1
	bne t2, t3, fail

	li t0, 0x80000000
	li t1, 3
	divu t2, t0, t1
	li t3, 0x2aaaaaaa
	bne t2, t3, fail
	remu t2, t0, t1
	li t3, 2
	bne t2, t3, fail

	# Source and destination registers may overlap.
	li t0, -19
	li t1, 4
	div t0, t0, t1
	li t3, -4
	bne t0, t3, fail

	li t0, 19
	li t1, 4
	remu t1, t0, t1
	li t3, 3
	bne t1, t3, fail

	ebreak

fail:
	addi a0, zero, 1
	ebreak
