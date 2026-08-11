#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="${root_dir}/tests"
profile="${PROFILE:-rv32i}"
spike_timeout="${SPIKE_TIMEOUT:-10}"
riscv_prefix="${RISCV_PREFIX:-riscv64-unknown-elf-}"
objcopy="${RISCV_OBJCOPY:-${riscv_prefix}objcopy}"
spike_pc_offset='0x1000'

command -v spike >/dev/null || { echo 'spike not found' >&2; exit 127; }
command -v "${objcopy}" >/dev/null || { echo "${objcopy} not found" >&2; exit 127; }

case "${profile}" in
	rv32i)
		test_name='rv32i_diff'
		spike_isa='RV32I'
		;;
	rv32izmmul)
		test_name='rv32izmmul_diff'
		spike_isa='RV32I_Zmmul'
		;;
	rv32im)
		test_name='rv32im_diff'
		spike_isa='RV32IM'
		;;
	*)
		echo "Unsupported PROFILE=${profile}" >&2
		exit 2
		;;
esac

make -C "${test_dir}" ROOTDIR="${root_dir}" PROFILE="${profile}" \
	build TEST="${test_name}"
make -C "${root_dir}" bsim PROFILE="${profile}" BSC_DEFINES='-D RV32_TRACE'

build_dir="${root_dir}/build/${profile}/tests/${test_name}"
elf="${build_dir}/${test_name}.elf"
spike_elf="${build_dir}/${test_name}.spike.elf"
binary="${build_dir}/${test_name}.bin"
core_log="${build_dir}/core.log"
spike_log="${build_dir}/spike.log"

BLUERV32_BIN="${binary}" \
	"${root_dir}/build/${profile}/sim/bsim" >"${core_log}" 2>&1

core_instruction_count="$(grep -c 'RV32_COMMIT ' "${core_log}" || true)"
if [[ "${core_instruction_count}" -eq 0 ]]; then
	echo 'No blueRV32 commit trace was produced.' >&2
	exit 1
fi
spike_instruction_limit=$((core_instruction_count + 1))

"${objcopy}" --change-addresses "${spike_pc_offset}" "${elf}" "${spike_elf}"

timeout "${spike_timeout}" spike --isa="${spike_isa}" --disable-dtb \
	--pcs="0:${spike_pc_offset}" -m"${spike_pc_offset}:0x10000" -l \
	--instructions="${spike_instruction_limit}" "${spike_elf}" \
	>/dev/null 2>"${spike_log}" || true

python3 "${test_dir}/differential/compare_spike.py" \
	"${core_log}" "${spike_log}" "${spike_pc_offset}"
