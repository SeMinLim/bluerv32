.section .text.start
.globl _start

_start:
	li t6, 0x10000000

	addi t0, zero, 2047
	li t1, 2047
	bne t0, t1, fail
	addi t0, zero, -2048
	li t1, -2048
	bne t0, t1, fail

	addi t0, zero, 1
	slli t0, t0, 31
	li t1, 0x80000000
	bne t0, t1, fail
	srli t0, t0, 31
	addi t1, zero, 1
	bne t0, t1, fail

	li t0, 0x80000000
	srai t0, t0, 31
	addi t1, zero, -1
	bne t0, t1, fail

	lui t0, 0xfffff
	li t1, 0xfffff000
	bne t0, t1, fail

	li t0, 'P'
	sb t0, 0(t6)
	ebreak

fail:
	li t0, 'F'
	sb t0, 0(t6)
	ebreak
