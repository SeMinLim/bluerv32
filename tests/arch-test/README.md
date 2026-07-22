# RISC-V Architectural Tests

`run.sh` is the launch point for the official RISCOF-based RV32I architectural
test suite. It deliberately keeps the external suite and its generated files
outside this repository.

The following variables are required:

```sh
RISCOF_CONFIG=/path/to/config.ini
RISCV_ARCH_TEST_SUITE=/path/to/riscv-test-suite/rv32i_m/I
RISCV_ARCH_TEST_ENV=/path/to/riscv-test-suite/env
```

The selected RISCOF configuration must use the blueRV32 Bluesim target and its
8 KiB binary loader. Test completion and signatures must be collected before a
release is described as architectural-test compliant.
