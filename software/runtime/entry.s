.section .text.start
.globl _start

_start:
	la sp, __stack_top
	la t0, __bss_start
	la t1, __bss_end

clearBss:
	bgeu t0, t1, runMain
	sw zero, 0(t0)
	addi t0, t0, 4
	j clearBss

runMain:
	call main
	ebreak

halt:
	j halt
