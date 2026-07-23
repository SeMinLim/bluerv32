.section .text.start
.globl _start

_start:
	li t0, 0x00010000
	jalr zero, 0(t0)
