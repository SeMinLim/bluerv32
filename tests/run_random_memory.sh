#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="${root_dir}/tests"

make -C "${root_dir}" bsim \
	BSC_DEFINES='-D RV32_TRACE -D RV32_RANDOM_MEMORY'

for test_name in rv32i_basic rv32i_loadstore; do
	make -C "${test_dir}" build TEST="${test_name}"
	binary="${root_dir}/build/tests/${test_name}/${test_name}.bin"
	log="${root_dir}/build/tests/${test_name}/${test_name}.random.log"
	BLUERV32_BIN="${binary}" "${root_dir}/build/sim/bsim" >"${log}" 2>&1
	grep -q 'RV32_UART data=50' "${log}"
	grep -q 'RV32_TRAP .*cause=3' "${log}"
	printf '%s randomized memory: PASS\n' "${test_name}"
done
