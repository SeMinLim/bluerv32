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
tests/
├── directed/              Directed RV32I and fault tests
├── differential/          Optional Spike trace comparison
└── act4/                  ACT4 DUT configuration and complete runner
build/software/<app>/      Generated ELF, BIN, dump, and simulation logs
build/hardware/            Generated Verilog, reports, and bitstream
```

## Memory map

```text
0x0000_0000 - 0x0000_7fff   32 KiB instruction BRAM
0x0000_8000 - 0x0000_ffff   32 KiB data BRAM
0x1000_0000                  Byte-wide UART transmit register
```

The RISC-V GNU toolchain generates one exactly 64 KiB binary. The first 32 KiB
is loaded into instruction BRAM and the second 32 KiB into data BRAM.

## Requirements

- Bluespec Compiler (`bsc`)
- RISC-V GNU toolchain, default prefix `riscv64-unknown-elf-`
- Yosys, `nextpnr-ecp5`, and `ecppack` for ULX3S synthesis
- `ujprog` for ULX3S programming
- Spike for optional differential testing
- ACT4, Sail RISC-V 0.13, and RISC-V GCC 15/Binutils 2.44 or later for certification testing

## Install the RISC-V GNU toolchain

On Ubuntu or Debian, install the bare-metal compiler and binary utilities with:

```bash
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

Verify that the tools used by blueRV32 are available:

```bash
riscv64-unknown-elf-gcc --version
riscv64-unknown-elf-objcopy --version
riscv64-unknown-elf-objdump --version
```

The `riscv64-unknown-elf-` toolchain prefix can generate RV32I software because
blueRV32 supplies `-march=rv32i -mabi=ilp32`. For other platforms or a source
build, follow the official [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) instructions.

The distribution package is sufficient for the normal blueRV32 software flow,
but ACT4 currently requires RISC-V GCC 15 and Binutils 2.44 or later. Build a
current multilib toolchain when the packaged version is older.

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
```

`test-random` applies pseudo-random request backpressure and response latency.
`test-differential` compares retired PC/instruction traces with Spike and is
optional rather than a certification prerequisite.

### ACT4 RV32I certification tests

Install the current ACT4 dependencies described by the official
[`riscv-arch-test`](https://github.com/riscv/riscv-arch-test) project, clone the
repository, and trust its `mise` configuration when using `mise`:

```bash
git clone https://github.com/riscv/riscv-arch-test.git
cd riscv-arch-test
mise trust .mise.toml
cd /path/to/bluerv32
```

Generate and run every applicable RV32I self-checking ELF on blueRV32 Bluesim:

```bash
make test-act4 ACT4_DIR=/path/to/riscv-arch-test
```

`make test-arch` is retained as an alias. Results are stored under
`build/act4/work/bluerv32-rv32i/`, and the exact blueRV32, ACT4, compiler, and
Sail versions are recorded in `build/act4/versions.txt`.

The ACT4 UDB file uses a machine-mode-oriented compilation envelope because the
current framework requires it. Privileged tests are disabled, boot and
CSR-dependent paths are bypassed, and `fence.i` is replaced with `nop`; the
instruction stream executed by blueRV32 remains RV32I.
