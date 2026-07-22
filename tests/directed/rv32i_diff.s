.section .text.start
.globl _start

_start:
	addi t0, zero, 0
	addi t1, zero, 32
	addi t2, zero, 1

loop:
	add t0, t0, t2
	xori t2, t2, 3
	addi t1, t1, -1
	bne t1, zero, loop

	auipc t3, 0
	addi t3, t3, 16
	jalr zero, 0(t3)
	nop
	nop
	ebreak
