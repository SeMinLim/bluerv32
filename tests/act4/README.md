# ACT4 Architectural Certification Tests

This directory integrates the official ACT4 framework with the blueRV32 Bluesim target for all public profiles.

| Profile | ACT4 extensions | Allowed M-extension instructions |
|---|---|---|
| `rv32i` | `I` | none |
| `rv32izmmul` | `I,Zmmul` | `MUL`, `MULH`, `MULHSU`, `MULHU` |
| `rv32im` | `I,M` | `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU` |

The integration prepares the selected DUT configuration and 1 MiB unified Sail memory map, generates all applicable self-checking ELFs, rejects privileged and CSR paths, audits the final instruction streams, converts each ELF to the blueRV32 ACT4 image format, and invokes the official ACT4 result collector.

Required external tools are a current `riscv/riscv-arch-test` checkout, its Python/Ruby environment, RISC-V GCC 15 and Binutils 2.44 or Clang/LLVM 21, Sail RISC-V 0.13, and the Bluespec Compiler.

```sh
make test-act4 PROFILE=rv32i ACT4_DIR=/path/to/riscv-arch-test
make test-act4 PROFILE=rv32izmmul ACT4_DIR=/path/to/riscv-arch-test
make test-act4 PROFILE=rv32im ACT4_DIR=/path/to/riscv-arch-test
```

Optional controls:

```sh
ACT4_JOBS=4
ACT4_TIMEOUT=300
RISCV_PREFIX=/path/to/bin/riscv64-unknown-elf-
ACT4_CC=/path/to/compiler
ACT4_OBJCOPY=/path/to/objcopy
ACT4_OBJDUMP=/path/to/objdump
ACT4_SAIL=/path/to/sail_riscv_sim
```

Results are written under `build/<profile>/act4/`. The audit permits exactly the instruction extensions selected by the profile while continuing to reject compressed, CSR, privileged, and `fence.i` instructions.
