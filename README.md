# blueRV32

**A straightforward reference RV32I processor and bare-metal execution platform in Bluespec SystemVerilog.**

blueRV32 implements the complete 40-instruction RV32I base integer ISA with a
32-bit address interface, strict instruction decoding, aligned memory accesses,
memory fault responses, and precise external execution-environment traps. The
reference core intentionally excludes `M`, `C`, `Zicsr`, and `Zifencei`.

## Processor

The reference processor is a clear multi-cycle implementation with explicit
fetch, decode, execute, memory-response, and writeback stages. It supports:

- all RV32I arithmetic, logical, shift, branch, jump, load, and store instructions,
- `FENCE` as a conservative in-order fence,
- precise `ECALL` and `EBREAK` traps,
- illegal-instruction detection,
- instruction, load, and store alignment checks,
- instruction and data access-fault responses,
- and architectural `x0`, PC, JAL, and JALR behavior.

## Repository hierarchy

```text
processor/                 RV32I processor implementation
system/                    BRAM, UART, address decoding, and simulation top
software/
├── runtime/               Bare-metal startup and linker script
├── microbench/            RV32I microbenchmark
├── pipesafe/              Dependency-safe pipeline test
├── pipeunsafe1/           RAW dependency test
├── pipeunsafe2/           Load-use dependency test
└── minisudoku/            RV32I bare-metal C benchmark
cpp/                       Bluesim binary loader and UART bridge
ulx3s/                     ULX3S-85F constraints
tests/                     Directed, random-latency, differential, and arch tests
build/software/<app>/      Generated ELF, BIN, dump, and simulation logs
build/hardware/            Generated Verilog, reports, and bitstream
```

## Memory map

```text
0x0000_0000 - 0x0000_0fff   4 KiB instruction BRAM
0x0000_1000 - 0x0000_1fff   4 KiB data BRAM
0x1000_0000                  Byte-wide UART transmit register
```

The RISC-V GNU toolchain generates one exactly 8 KiB binary. The first 4 KiB is
loaded into instruction BRAM and the second 4 KiB into data BRAM.

## Requirements

- Bluespec Compiler (`bsc`)
- RISC-V GNU toolchain, default prefix `riscv64-unknown-elf-`
- Yosys, `nextpnr-ecp5`, and `ecppack` for ULX3S synthesis
- `ujprog` for ULX3S programming
- Spike for differential testing
- RISCOF and the official RISC-V architectural-test suite for certification tests

## Build and simulate

```bash
make list-software
make software APP=minisudoku
make runsim APP=minisudoku
```

Generated software files are stored under:

```text
build/software/<app>/<app>.elf
build/software/<app>/<app>.bin
build/software/<app>/<app>.dump
```

## ULX3S-85F

```bash
make synth BOARD=ulx3s
make program BOARD=ulx3s
```

## Verification

```bash
make lint
make test-directed
make test-random
make test-differential
make test-arch
```

`test-random` applies pseudo-random request backpressure and response latency.
`test-differential` compares retired PC/instruction traces with Spike. The
architectural-test target requires an external blueRV32-compatible RISCOF
configuration and official RV32I suite.
