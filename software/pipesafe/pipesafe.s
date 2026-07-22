.section .text.start
.globl _start

_start:
	li t6, 0x10000000
	addi s1, zero, 1
	addi s2, zero, 2
	nop
	nop
	nop
	nop
	add s3, s1, s2
	nop
	nop
	nop
	nop
	li t0, 'P'
	sb t0, 0(t6)
	ebreak
