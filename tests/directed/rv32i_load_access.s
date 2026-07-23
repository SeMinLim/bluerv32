.section .text.start
.globl _start

_start:
	li t0, 0x00010000
	lw t1, 0(t0)
