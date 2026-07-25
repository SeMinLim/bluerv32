# ACT4 RV32I Certification Tests

This directory integrates the official ACT4 framework with the blueRV32 Bluesim target.

The integration:

1. prepares an `I`-only blueRV32 DUT configuration and 64 KiB Sail memory map,
2. asks ACT4 to generate only `I` self-checking ELFs,
3. builds Bluesim with `RV32_ACT4` so ACT4 support code may execute from data BRAM,
4. rejects generated DUT macros for Sm, Zicsr, or Zifencei,
5. audits every ELF for CSR, privileged, M, C, and `fence.i` instructions,
6. converts every audited ELF to the blueRV32 64 KiB image format,
7. runs the complete generated set and invokes the official ACT4 result collector.

Required external tools:

- a current `riscv/riscv-arch-test` checkout,
- `mise` or an equivalent ACT4 Python/Ruby environment,
- RISC-V GCC 15 and Binutils 2.44 or later, or Clang/LLVM 20 or later,
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
ACT4_CC=/path/to/bin/riscv64-unknown-elf-gcc
ACT4_OBJCOPY=/path/to/bin/riscv64-unknown-elf-objcopy
ACT4_OBJDUMP=/path/to/bin/riscv64-unknown-elf-objdump
ACT4_SAIL=/path/to/bin/sail_riscv_sim
```

Results are written under `build/act4/work/bluerv32-rv32i/`. Disassembly audits are stored under `build/act4/audit/`, and the exact blueRV32, ACT4, compiler, object-tool, and Sail versions are recorded in `build/act4/versions.txt`.

The DUT configuration declares only the `I` extension. ACT4 still requires interrupt-operation macros to exist at assembly time, so blueRV32 provides inert stubs while privileged tests remain disabled. The runner independently verifies the generated extension list, generated preprocessor macros, ELF locations, and final instruction streams before starting Bluesim.
