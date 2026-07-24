# ACT4 RV32I Certification Tests

This directory integrates the official ACT4 framework with the blueRV32 Bluesim target. It replaces the former RISCOF launch point.

The integration:

1. prepares the blueRV32 DUT configuration and 64 KiB Sail memory map,
2. asks ACT4 to generate only `I` self-checking ELFs,
3. builds Bluesim with `RV32_ACT4` so ACT4 support code may execute from data BRAM,
4. converts every ELF to the blueRV32 64 KiB image format,
5. runs the complete generated set and invokes the official ACT4 result collector.

Required external tools:

- a current `riscv/riscv-arch-test` checkout,
- `mise` or an equivalent ACT4 Python/Ruby environment,
- RISC-V GCC 15 and Binutils 2.44 or later,
- Sail RISC-V 0.13,
- and the Bluespec Compiler.

```sh
make test-act4 ACT4_DIR=/path/to/riscv-arch-test
```

Optional controls:

```sh
ACT4_JOBS=4
ACT4_TIMEOUT=300
RISCV_PREFIX=/path/to/bin/riscv64-unknown-elf-
ACT4_SAIL=/path/to/bin/sail_riscv_sim
```

Results are written under `build/act4/work/bluerv32-rv32i/`, and the exact blueRV32, ACT4, compiler, and Sail versions are recorded in `build/act4/versions.txt`.

The UDB file contains an ACT4 compilation envelope with Sm, Zicsr, and Zifencei because the current ACT4 environment is machine-mode-oriented. Privileged tests are disabled, boot and CSR-dependent paths are bypassed, and `fence.i` is replaced with `nop`; the instruction stream executed by blueRV32 remains RV32I.
