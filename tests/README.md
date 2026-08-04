# Verification

The verification flow is profile-aware and keeps each result under `build/<profile>/`.

```sh
make test-directed PROFILE=rv32i
make test-random PROFILE=rv32i
make test-differential PROFILE=rv32i

make test-directed PROFILE=rv32izmmul
make test-random PROFILE=rv32izmmul
make test-differential PROFILE=rv32izmmul
make test-act4 PROFILE=rv32izmmul ACT4_DIR=/path/to/riscv-arch-test

make test-directed PROFILE=rv32im
make test-random PROFILE=rv32im
make test-differential PROFILE=rv32im
make test-act4 PROFILE=rv32im ACT4_DIR=/path/to/riscv-arch-test
```

The RV32I regression verifies that all M-extension encodings remain illegal. The RV32IZmmul directed set verifies `MUL`, `MULH`, `MULHSU`, and `MULHU`, including signedness, edge values, source/destination overlap, and `x0`; separate negative tests verify that division and remainder encodings remain illegal.

The RV32IM directed set adds `DIV`, `DIVU`, `REM`, and `REMU`, including signed rounding, divide-by-zero results, signed overflow, source/destination overlap, and `x0`. The ACT4 runner generates every applicable self-checking ELF for the selected profile, validates the generated extension set, audits the final instruction streams, and runs the complete set on blueRV32 Bluesim.
