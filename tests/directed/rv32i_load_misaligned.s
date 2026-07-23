.section .text.start
.globl _start

_start:
	li t0, 0x00008001
	lh t1, 0(t0)
