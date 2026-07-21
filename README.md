# blueRV32

**A straightforward Bluespec SystemVerilog codebase for building, simulating, and synthesizing a 32-bit RISC-V bare-metal processor and its software.**

blueRV32 combines a synthesizable RISC-V processor, a small BRAM-based system, bare-metal software generation with the RISC-V GNU toolchain, Bluesim execution, and an ULX3S-85F hardware target.

The current processor is the original educational RV32I baseline. It is intentionally preserved during this first repository-organization step and is not yet a complete reference-quality RV32I or RV32IM implementation.

## Repository hierarchy

```text
processor/                 RISC-V processor implementation
system/                    BRAM, UART, SoC integration, and simulation top
software/
├── runtime/               Bare-metal startup and linker script
├── microbench/            Mixed processor microbenchmarks
├── pipesafe/              Dependency-safe pipeline test
├── pipeunsafe1/           RAW dependency test
├── pipeunsafe2/           Load-use dependency test
└── minisudoku/            Bare-metal C benchmark
cpp/                       Bluesim binary loader and UART bridge
ulx3s/                     ULX3S-85F constraints
build/software/<app>/      Generated ELF, BIN, dump, and simulation logs
build/hardware/            Generated Verilog, reports, and bitstream
```

## Requirements

- Bluespec Compiler (`bsc`)
- RISC-V GNU toolchain, default prefix `riscv64-unknown-elf-`
- Yosys, `nextpnr-ecp5`, and `ecppack` for ULX3S synthesis
- `ujprog` for ULX3S programming

Override `RISCV_PREFIX` when another installed GNU toolchain prefix is used.

## Bare-metal software

```bash
make list-software
make software APP=minisudoku
make software APP=microbench
```

Generated files are stored separately from the source code.

```text
build/software/minisudoku/minisudoku.elf
build/software/minisudoku/minisudoku.bin
build/software/minisudoku/minisudoku.dump
```

The default software ISA setting is `rv32im` because the existing `minisudoku` and `microbench` programs contain the `mul` instruction. It can be overridden through `MARCH` in `software/Makefile` invocations.

## Bluesim

```bash
make runsim APP=pipesafe
make runsim APP=pipeunsafe1
make runsim APP=pipeunsafe2
make runsim APP=minisudoku
```

The selected binary is generated first, loaded into the simulated 4 KiB instruction memory and 4 KiB data memory, and then executed by the BSV processor.

## ULX3S-85F synthesis

```bash
make synth BOARD=ulx3s
```

The hardware flow is:

```text
BSV → bsc → Verilog → Yosys → nextpnr-ecp5 → ecppack
```

The resulting files include:

```text
build/hardware/mkTop.bit
build/hardware/mkTop.yosys.rpt
build/hardware/mkTop.nextpnr.json
build/hardware/mkTop.nextpnr.log
```

Program the generated bitstream with:

```bash
make program BOARD=ulx3s
```
