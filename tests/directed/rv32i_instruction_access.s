.section .text.start
.globl _start

_start:
	li t0, 0x00002000
	jalr zero, 0(t0)
