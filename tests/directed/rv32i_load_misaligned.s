.section .text.start
.globl _start

_start:
	li t0, 0x00001001
	lh t1, 0(t0)
