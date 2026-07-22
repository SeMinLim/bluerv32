.section .text.start
.globl _start

_start:
	li t6, 0x10000000
	la t0, testData
	lw s1, 0(t0)
	lw s2, 4(t0)
	add s3, s1, s2
	li t1, 'P'
	sb t1, 0(t6)
	ebreak

.section .data
testData:
	.word 1, 2, 3
