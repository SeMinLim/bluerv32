# Verification

The verification set is intentionally limited to the agreed RV32I reference-core minimum:

- directed instruction tests,
- immediate-boundary tests,
- branch and jump alignment tests,
- load and store sign-extension tests,
- illegal-encoding tests,
- memory backpressure and randomized response latency,
- optional differential instruction traces against Spike,
- and the official ACT4 RV32I Architectural Certification Tests.

```sh
make test-directed
make test-random
make test-differential
make test-act4 ACT4_DIR=/path/to/riscv-arch-test
```

`make test-act4` generates every applicable RV32I self-checking ELF, runs the complete generated set on the blueRV32 Bluesim target, and delegates pass/fail collection to the official ACT4 runner. Results are stored under `build/act4/work/bluerv32-rv32i/`.
