#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
act4_dir="${ACT4_DIR:-}"
act4_jobs="${ACT4_JOBS:-$(nproc)}"
act4_timeout="${ACT4_TIMEOUT:-300}"
riscv_prefix="${RISCV_PREFIX:-riscv64-unknown-elf-}"
act4_cc="${ACT4_CC:-${riscv_prefix}gcc}"
act4_objcopy="${ACT4_OBJCOPY:-${riscv_prefix}objcopy}"
act4_objdump="${ACT4_OBJDUMP:-${riscv_prefix}objdump}"
act4_sail="${ACT4_SAIL:-sail_riscv_sim}"
config_source_dir="${root_dir}/tests/act4/config"
build_dir="${root_dir}/build/act4"
config_dir="${build_dir}/config"
work_dir="${build_dir}/work"
summary_dir="${work_dir}/bluerv32-rv32i"
elf_dir="${summary_dir}/elfs"

if [[ -z "${act4_dir}" ]]; then
	echo "Set ACT4_DIR to a riscv/riscv-arch-test checkout." >&2
	exit 2
fi

for file in "${act4_dir}/Makefile" "${act4_dir}/run_tests.py"; do
	if [[ ! -f "${file}" ]]; then
		echo "Invalid ACT4 checkout; missing file: ${file}" >&2
		exit 2
	fi
done

for command in bsc make python3 "${act4_cc}" "${act4_objcopy}" \
		"${act4_objdump}" "${act4_sail}"; do
	command -v "${command}" >/dev/null || {
		echo "Required ACT4 command not found: ${command}" >&2
		exit 127
	}
done

compiler_major="$("${act4_cc}" -dumpversion | cut -d. -f1)"
if [[ ! "${compiler_major}" =~ ^[0-9]+$ ]] || (( compiler_major < 15 )); then
	echo "ACT4 requires RISC-V GCC 15 or later; found: $("${act4_cc}" -dumpversion)" >&2
	exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${config_dir}" "${work_dir}"

python3 "${root_dir}/tests/act4/prepare_config.py" \
	--act4-dir "${act4_dir}" \
	--source-dir "${config_source_dir}" \
	--output-dir "${config_dir}" \
	--compiler "${act4_cc}" \
	--objdump "${act4_objdump}" \
	--reference-model "${act4_sail}"

{
	printf 'blueRV32 commit: '
	git -C "${root_dir}" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
	printf 'ACT4 commit: '
	git -C "${act4_dir}" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
	printf 'Compiler: '
	"${act4_cc}" -dumpfullversion -dumpversion
	printf 'Sail: '
	"${act4_sail}" --version
} > "${build_dir}/versions.txt"

make -C "${root_dir}" bsim BSC_DEFINES='-D RV32_ACT4'

make -C "${act4_dir}" elfs \
	CONFIG_FILES="${config_dir}/test_config.yaml" \
	WORKDIR="${work_dir}" \
	EXTENSIONS=I \
	EXCLUDE_EXTENSIONS= \
	FAST=True \
	JOBS="${act4_jobs}"

if [[ ! -d "${elf_dir}" ]]; then
	echo "ACT4 did not generate the expected ELF directory: ${elf_dir}" >&2
	exit 2
fi

export BLUERV32_BSIM="${root_dir}/build/sim/bsim"
export BLUERV32_ACT4_IMAGE_DIR="${build_dir}/images"
export ACT4_OBJCOPY="${act4_objcopy}"

python3 "${act4_dir}/run_tests.py" \
	"${root_dir}/tests/act4/run_elf.sh" \
	"${elf_dir}" \
	--jobs "${act4_jobs}" \
	--timeout "${act4_timeout}"

printf '%s\n' \
	'---------------------------------------------------------------------' \
	'[RESULT] ACT4 RV32I certification tests completed successfully.' \
	"Results: ${summary_dir}" \
	"Versions: ${build_dir}/versions.txt" \
	'---------------------------------------------------------------------'
