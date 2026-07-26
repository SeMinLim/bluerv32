.section .text.start
.globl _start

_start:
	addi t0, zero, 7
	addi t1, zero, 3
	.word 0x0262d3b3
	ebreak
