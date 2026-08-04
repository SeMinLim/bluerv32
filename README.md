# blueRV32

**A reference-quality boilerplate codebase for synthesizable RV32 processor development in Bluespec SystemVerilog.**

blueRV32 provides a clear multi-cycle processor, bare-metal software flow, Bluesim execution environment, ULX3S synthesis flow, and profile-aware verification environment.

## Core profiles

| Profile | ISA | Status |
|---|---|---|
| `rv32i` | RV32I | complete |
| `rv32izmmul` | RV32I + Zmmul | complete |
| `rv32im` | RV32I + M | implemented |

The RV32I profile implements the complete 40-instruction base integer ISA. The RV32IZmmul profile adds `MUL`, `MULH`, `MULHSU`, and `MULHU` while keeping `DIV`, `DIVU`, `REM`, and `REMU` illegal. The RV32IM profile implements all eight RV32 M-extension multiplication, division, and remainder instructions. All profiles intentionally exclude `C`, `Zicsr`, and `Zifencei`.

## Repository hierarchy

```text
profiles.mk                 Build-time core profile definitions
processor/
├── Defines.bsv             Architectural and processor-state types
├── Decode.bsv              Strict instruction decoding
├── Divider.bsv             Iterative RV32IM divider
├── Execute.bsv             RV32I ALU and control execution
├── Multiplier.bsv          Registered Zmmul multiplier
├── Processor.bsv           Multi-cycle processor control
└── RFile.bsv               Architectural register file
system/                     BRAM, UART, address decoding, and top modules
software/
├── runtime/                Bare-metal startup and linker script
├── microbench/             RV32 microbenchmark
├── pipesafe/               Dependency-safe pipeline test
├── pipeunsafe1/            RAW dependency test
├── pipeunsafe2/            Load-use dependency test
└── minisudoku/             Bare-metal C benchmark
cpp/                        Bluesim binary loader and UART bridge
ulx3s/                      ULX3S-85F constraints
tests/
├── directed/               Profile-aware directed and fault tests
├── differential/           Optional Spike trace comparison
└── act4/                   ACT4 configurations and complete runner
build/<profile>/            Isolated software, simulation, test, and FPGA outputs
```

## Memory map

```text
0x0000_0000 - 0x0000_7fff   32 KiB instruction BRAM
0x0000_8000 - 0x0000_ffff   32 KiB data BRAM
0x1000_0000                  Byte-wide UART transmit register
```

The software flow produces one exactly 64 KiB binary. The first 32 KiB is loaded into instruction BRAM and the second 32 KiB into data BRAM.

## Requirements

- Bluespec Compiler (`bsc`)
- RISC-V GNU toolchain, default prefix `riscv64-unknown-elf-`
- Yosys, `nextpnr-ecp5`, and `ecppack` for ULX3S synthesis
- `ujprog` for ULX3S programming
- Spike for optional differential testing
- ACT4 and Sail RISC-V 0.13 for architectural certification testing

On Ubuntu or Debian, the normal software flow can use:

```sh
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

The `riscv64-unknown-elf-` prefix can generate all profiles because blueRV32 supplies `-march=rv32i`, `-march=rv32i_zmmul`, or `-march=rv32im` with `-mabi=ilp32`.

## Build and simulate

```sh
make runsim PROFILE=rv32i APP=minisudoku
make runsim PROFILE=rv32izmmul APP=minisudoku
make runsim PROFILE=rv32im APP=minisudoku
```

Generated files are isolated by profile:

```text
build/<profile>/software/<app>/<app>.elf
build/<profile>/software/<app>/<app>.bin
build/<profile>/software/<app>/<app>.dump
build/<profile>/software/<app>/output.log
build/<profile>/software/<app>/system.log
```

## ULX3S-85F

```sh
make synth PROFILE=rv32i BOARD=ulx3s
make synth PROFILE=rv32izmmul BOARD=ulx3s
make synth PROFILE=rv32im BOARD=ulx3s
make program PROFILE=rv32im BOARD=ulx3s
```

`Multiplier.bsv` uses a generic full-product multiplication expression so Yosys may infer the target FPGA multiplier resources without embedding ECP5-specific primitives in the processor source. `Divider.bsv` uses a 32-cycle radix-2 shift/subtract datapath and does not infer a combinational division operator.

## Verification

The blueRV32 RV32I and RV32IZmmul profiles have passed all applicable RISC-V Architectural Certification Tests (ACTs) using the official ACT4 framework. ACT4 is the current official framework for RISC-V architectural certification testing, replacing the deprecated RISCOF flow.

```sh
make lint

make test-directed PROFILE=rv32i
make test-random PROFILE=rv32i
make test-differential PROFILE=rv32i

make test-directed PROFILE=rv32izmmul
make test-random PROFILE=rv32izmmul
make test-differential PROFILE=rv32izmmul

make test-directed PROFILE=rv32im
make test-random PROFILE=rv32im
make test-differential PROFILE=rv32im
```

Spike differential testing is optional rather than an ACT4 prerequisite.

### ACT4

```sh
git clone https://github.com/riscv/riscv-arch-test.git

make test-act4 PROFILE=rv32i \
	ACT4_DIR=/path/to/riscv-arch-test
make test-act4 PROFILE=rv32izmmul \
	ACT4_DIR=/path/to/riscv-arch-test
make test-act4 PROFILE=rv32im \
	ACT4_DIR=/path/to/riscv-arch-test
```

`make test-arch` is retained as an alias. Results and exact tool versions are stored under `build/<profile>/act4/`. The runner validates the DUT extension set and audits every generated ELF before Bluesim execution.
