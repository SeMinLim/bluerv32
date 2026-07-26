#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="${root_dir}/tests"
profile="${PROFILE:-rv32i}"

make -C "${root_dir}" bsim PROFILE="${profile}" \
	BSC_DEFINES='-D RV32_TRACE -D RV32_RANDOM_MEMORY'

case "${profile}" in
	rv32i)
		tests=(rv32i_basic rv32i_loadstore)
		;;
	rv32izmmul)
		tests=(rv32i_basic rv32i_loadstore rv32izmmul)
		;;
	*)
		echo "Unsupported PROFILE=${profile}" >&2
		exit 2
		;;
esac

for test_name in "${tests[@]}"; do
	make -C "${test_dir}" ROOTDIR="${root_dir}" PROFILE="${profile}" \
		build TEST="${test_name}"
	binary="${root_dir}/build/${profile}/tests/${test_name}/${test_name}.bin"
	log="${root_dir}/build/${profile}/tests/${test_name}/${test_name}.random.log"
	BLUERV32_BIN="${binary}" \
		"${root_dir}/build/${profile}/sim/bsim" >"${log}" 2>&1
	grep -q 'RV32_UART data=50' "${log}"
	grep -q 'RV32_TRAP .*cause=3' "${log}"
	printf '%s (%s) randomized memory: PASS\n' "${test_name}" "${profile}"
done
