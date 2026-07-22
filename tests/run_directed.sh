#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="${root_dir}/tests"

make -C "${root_dir}" bsim BSC_DEFINES='-D RV32_TRACE'

cases=(
	'rv32i_basic:3:pass'
	'rv32i_immediate:3:pass'
	'rv32i_loadstore:3:pass'
	'rv32i_illegal:2:trap'
	'rv32i_m_illegal:2:trap'
	'rv32i_ecall:8:trap'
	'rv32i_load_misaligned:4:trap'
	'rv32i_store_misaligned:6:trap'
	'rv32i_branch_misaligned:0:trap'
	'rv32i_jal_misaligned:0:trap'
	'rv32i_jump_misaligned:0:trap'
	'rv32i_instruction_access:1:trap'
	'rv32i_load_access:5:trap'
	'rv32i_store_access:7:trap'
)

for entry in "${cases[@]}"; do
	IFS=':' read -r test_name expected_cause result_type <<<"${entry}"
	make -C "${test_dir}" build TEST="${test_name}"

	binary="${root_dir}/build/tests/${test_name}/${test_name}.bin"
	log="${root_dir}/build/tests/${test_name}/${test_name}.log"
	BLUERV32_BIN="${binary}" "${root_dir}/build/sim/bsim" >"${log}" 2>&1

	grep -q "RV32_TRAP .*cause=${expected_cause}" "${log}"
	if [[ "${result_type}" == 'pass' ]]; then
		grep -q 'RV32_UART data=50' "${log}"
		if grep -q 'RV32_UART data=46' "${log}"; then
			echo "${test_name}: FAIL" >&2
			exit 1
		fi
	fi
	printf '%s: PASS\n' "${test_name}"
done
