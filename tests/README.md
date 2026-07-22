# Verification

The verification set is intentionally limited to the agreed RV32I reference-core
minimum:

- directed instruction tests,
- immediate-boundary tests,
- branch and jump alignment tests,
- load and store sign-extension tests,
- illegal-encoding tests,
- memory backpressure and randomized response latency,
- differential instruction traces against Spike,
- and the official RISCOF architectural-test launch point.

```sh
make test-directed
make test-random
make test-differential
make test-arch
```
