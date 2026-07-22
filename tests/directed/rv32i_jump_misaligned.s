.section .text.start
.globl _start

_start:
	li t0, 2
	jalr zero, 0(t0)
