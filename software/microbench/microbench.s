.section .text.start
.globl _start

_start:
	li t6, 0x10000000

	addi t0, zero, 7
	addi t1, zero, 5
	add t2, t0, t1
	addi t3, zero, 12
	bne t2, t3, fail

	sub t2, t0, t1
	addi t3, zero, 2
	bne t2, t3, fail

	xori t2, t0, 3
	addi t3, zero, 4
	bne t2, t3, fail

	ori t2, zero, 0x55
	andi t2, t2, 0x0f
	addi t3, zero, 5
	bne t2, t3, fail

	slli t2, t1, 3
	srli t2, t2, 2
	addi t3, zero, 10
	bne t2, t3, fail

	la t0, testData
	lw t1, 0(t0)
	lw t2, 4(t0)
	add t3, t1, t2
	addi t4, zero, 3
	bne t3, t4, fail

	li t0, 'P'
	sb t0, 0(t6)
	ebreak

fail:
	li t0, 'F'
	sb t0, 0(t6)
	ebreak

.section .data
testData:
	.word 1, 2, 3
