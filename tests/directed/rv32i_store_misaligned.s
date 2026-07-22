.section .text.start
.globl _start

_start:
	li t0, 0x00001002
	li t1, 1
	sw t1, 0(t0)
