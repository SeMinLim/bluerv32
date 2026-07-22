#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="${root_dir}/tests"

command -v spike >/dev/null || { echo 'spike not found' >&2; exit 127; }

make -C "${test_dir}" build TEST=rv32i_diff
make -C "${root_dir}" bsim BSC_DEFINES='-D RV32_TRACE'

elf="${root_dir}/build/tests/rv32i_diff/rv32i_diff.elf"
binary="${root_dir}/build/tests/rv32i_diff/rv32i_diff.bin"
core_log="${root_dir}/build/tests/rv32i_diff/core.log"
spike_log="${root_dir}/build/tests/rv32i_diff/spike.log"

BLUERV32_BIN="${binary}" "${root_dir}/build/sim/bsim" >"${core_log}" 2>&1
spike --isa=RV32I --pc=0 -m0x0:0x2000 -l "${elf}" \
	>/dev/null 2>"${spike_log}" || true

python3 "${test_dir}/differential/compare_spike.py" \
	"${core_log}" "${spike_log}"
