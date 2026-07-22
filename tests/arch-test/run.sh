#!/usr/bin/env bash
set -euo pipefail

: "${RISCOF_CONFIG:?Set RISCOF_CONFIG to a blueRV32-compatible RISCOF configuration.}"
: "${RISCV_ARCH_TEST_SUITE:?Set RISCV_ARCH_TEST_SUITE to the RV32I architectural-test suite.}"
: "${RISCV_ARCH_TEST_ENV:?Set RISCV_ARCH_TEST_ENV to the architectural-test environment.}"

command -v riscof >/dev/null || { echo 'riscof not found' >&2; exit 127; }

riscof run \
	--config "${RISCOF_CONFIG}" \
	--suite "${RISCV_ARCH_TEST_SUITE}" \
	--env "${RISCV_ARCH_TEST_ENV}"
