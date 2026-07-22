.section .text.start
.globl _start

_start:
	li t6, 0x10000000

	addi t0, zero, 7
	addi t1, zero, 5
	add t2, t0, t1
	addi t3, zero, 12
	bne t2, t3, fail

	sub t2, t0, t1
	addi t3, zero, 2
	bne t2, t3, fail

	and t2, t0, t1
	addi t3, zero, 5
	bne t2, t3, fail
	or t2, t0, t1
	addi t3, zero, 7
	bne t2, t3, fail
	xor t2, t0, t1
	addi t3, zero, 2
	bne t2, t3, fail

	addi t4, zero, 1
	sll t2, t1, t4
	addi t3, zero, 10
	bne t2, t3, fail
	srl t2, t2, t4
	bne t2, t1, fail
	addi t2, zero, -8
	sra t2, t2, t4
	addi t3, zero, -4
	bne t2, t3, fail

	slt t2, t3, t0
	addi t4, zero, 1
	bne t2, t4, fail
	sltu t2, t3, t0
	bne t2, zero, fail

	xori t2, t0, 3
	addi t3, zero, 4
	bne t2, t3, fail
	ori t2, zero, 0x55
	andi t2, t2, 0x0f
	addi t3, zero, 5
	bne t2, t3, fail

	slli t2, t1, 3
	srli t2, t2, 2
	addi t3, zero, 10
	bne t2, t3, fail
	addi t2, zero, -16
	srai t2, t2, 2
	addi t3, zero, -4
	bne t2, t3, fail

	slti t2, t3, 0
	addi t4, zero, 1
	bne t2, t4, fail
	sltiu t2, t3, 1
	bne t2, zero, fail

	lui t0, 0x12345
	li t1, 0x12345000
	bne t0, t1, fail

	auipc t0, 0
	auipc t1, 0
	addi t1, t1, -4
	bne t0, t1, fail

	addi t0, zero, -1
	addi t1, zero, 1
	blt t0, t1, branch1
	j fail
branch1:
	bge t1, t0, branch2
	j fail
branch2:
	bltu t1, t0, branch3
	j fail
branch3:
	bgeu t0, t1, branch4
	j fail
branch4:
	beq t1, t1, branch5
	j fail
branch5:
	bne t0, t1, jalTest
	j fail

jalTest:
	jal ra, jalTarget
jalReturn:
	j fail
jalTarget:
	la t0, jalReturn
	bne ra, t0, fail

	la t0, jalrTarget
	jalr ra, 0(t0)
jalrReturn:
	j fail
jalrTarget:
	la t1, jalrReturn
	bne ra, t1, fail
	j controlDone

controlDone:
	fence rw, rw
	li t0, 'P'
	sb t0, 0(t6)
	ebreak

fail:
	li t0, 'F'
	sb t0, 0(t6)
	ebreak
