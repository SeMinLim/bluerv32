#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="${root_dir}/tests"
profile="${PROFILE:-rv32i}"

make -C "${root_dir}" bsim PROFILE="${profile}" BSC_DEFINES='-D RV32_TRACE'

common_cases=(
	'rv32i_basic:3:pass'
	'rv32i_immediate:3:pass'
	'rv32i_loadstore:3:pass'
	'rv32i_illegal:2:trap'
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

case "${profile}" in
	rv32i)
		profile_cases=(
			'rv32i_m_illegal:2:trap'
		)
		;;
	rv32izmmul)
		profile_cases=(
			'rv32izmmul:3:pass'
			'rv32izmmul_div_illegal:2:trap'
			'rv32izmmul_divu_illegal:2:trap'
			'rv32izmmul_rem_illegal:2:trap'
			'rv32izmmul_remu_illegal:2:trap'
		)
		;;
	rv32im)
		profile_cases=(
			'rv32izmmul:3:pass'
			'rv32im:3:pass'
		)
		;;
	*)
		echo "Unsupported PROFILE=${profile}" >&2
		exit 2
		;;
esac

cases=("${common_cases[@]}" "${profile_cases[@]}")

for entry in "${cases[@]}"; do
	IFS=':' read -r test_name expected_cause result_type <<<"${entry}"
	make -C "${test_dir}" ROOTDIR="${root_dir}" PROFILE="${profile}" \
		build TEST="${test_name}"

	binary="${root_dir}/build/${profile}/tests/${test_name}/${test_name}.bin"
	log="${root_dir}/build/${profile}/tests/${test_name}/${test_name}.log"
	BLUERV32_BIN="${binary}" \
		"${root_dir}/build/${profile}/sim/bsim" >"${log}" 2>&1

	grep -q "RV32_TRAP .*cause=${expected_cause}" "${log}"
	if [[ "${result_type}" == 'pass' ]]; then
		grep -q 'RV32_UART data=50' "${log}"
		if grep -q 'RV32_UART data=46' "${log}"; then
			echo "${test_name}: FAIL" >&2
			exit 1
		fi
	fi
	printf '%s (%s): PASS\n' "${test_name}" "${profile}"
done
