#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
profile="${PROFILE:-rv32i}"
act4_dir="${ACT4_DIR:-}"
act4_jobs="${ACT4_JOBS:-$(nproc)}"
act4_timeout="${ACT4_TIMEOUT:-300}"
riscv_prefix="${RISCV_PREFIX:-riscv64-unknown-elf-}"
act4_cc="${ACT4_CC:-${riscv_prefix}gcc}"
act4_objcopy="${ACT4_OBJCOPY:-${riscv_prefix}objcopy}"
act4_objdump="${ACT4_OBJDUMP:-${riscv_prefix}objdump}"
act4_sail="${ACT4_SAIL:-sail_riscv_sim}"
config_source_dir="${root_dir}/tests/act4/config"
build_dir="${root_dir}/build/${profile}/act4"
config_dir="${build_dir}/config"
work_dir="${build_dir}/work"
audit_dir="${build_dir}/audit"

case "${profile}" in
	rv32i)
		act4_config='bluerv32-rv32i'
		act4_extensions='I'
		;;
	rv32izmmul)
		act4_config='bluerv32-rv32izmmul'
		act4_extensions='I,Zmmul'
		;;
	*)
		echo "Unsupported PROFILE=${profile}" >&2
		exit 2
		;;
esac

summary_dir="${work_dir}/${act4_config}"
elf_dir="${summary_dir}/elfs"
extensions_file="${summary_dir}/extensions.txt"
rvtest_config_file="${summary_dir}/rvtest_config.h"

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

for command in bsc make python3 sha256sum "${act4_cc}" "${act4_objcopy}" \
		"${act4_objdump}" "${act4_sail}"; do
	command -v "${command}" >/dev/null || {
		echo "Required ACT4 command not found: ${command}" >&2
		exit 127
	}
done

compiler_name="$(basename "${act4_cc}")"
compiler_major="$("${act4_cc}" -dumpversion | cut -d. -f1)"
if [[ "${compiler_name}" == *clang* ]]; then
	compiler_family='Clang'
	compiler_required=21
else
	compiler_family='GCC'
	compiler_required=15
fi

if [[ ! "${compiler_major}" =~ ^[0-9]+$ ]] || \
		(( compiler_major < compiler_required )); then
	echo "ACT4 requires ${compiler_family} ${compiler_required} or later; found: $("${act4_cc}" -dumpversion)" >&2
	exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${config_dir}" "${work_dir}"

python3 "${root_dir}/tests/act4/prepare_config.py" \
	--act4-dir "${act4_dir}" \
	--source-dir "${config_source_dir}" \
	--output-dir "${config_dir}" \
	--config-name "${act4_config}" \
	--compiler "${act4_cc}" \
	--objdump "${act4_objdump}" \
	--reference-model "${act4_sail}"

{
	printf 'blueRV32 commit: '
	git -C "${root_dir}" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
	printf 'Profile: %s\n' "${profile}"
	printf 'ACT4 commit: '
	git -C "${act4_dir}" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
	printf 'Compiler: '
	"${act4_cc}" -dumpfullversion -dumpversion
	printf 'Objdump: '
	"${act4_objdump}" --version | head -n 1
	printf 'Sail: '
	"${act4_sail}" --version
} > "${build_dir}/versions.txt"

make -C "${root_dir}" bsim PROFILE="${profile}" BSC_DEFINES='-D RV32_ACT4'

make -C "${act4_dir}" elfs \
	CONFIG_FILES="${config_dir}/test_config.yaml" \
	WORKDIR="${work_dir}" \
	EXTENSIONS="${act4_extensions}" \
	EXCLUDE_EXTENSIONS= \
	FAST=True \
	JOBS="${act4_jobs}"

for file in "${extensions_file}" "${rvtest_config_file}"; do
	if [[ ! -f "${file}" ]]; then
		echo "ACT4 did not generate the expected DUT file: ${file}" >&2
		exit 2
	fi
done

actual_extensions="$(sed '/^[[:space:]]*$/d' "${extensions_file}" | sort -u | paste -sd, -)"
expected_extensions="$(printf '%s\n' "${act4_extensions}" | tr ',' '\n' | sort -u | paste -sd, -)"
if [[ "${actual_extensions}" != "${expected_extensions}" ]]; then
	echo "ACT4 DUT configuration does not match ${profile}: ${actual_extensions}" >&2
	exit 2
fi

for macro in STANDARD_SM_SUPPORTED ZICSR_SUPPORTED ZIFENCEI_SUPPORTED; do
	if grep -E -q "^#define[[:space:]]+${macro}([[:space:]]|$)" \
			"${rvtest_config_file}"; then
		echo "ACT4 generated a forbidden DUT macro: ${macro}" >&2
		exit 2
	fi
done

if [[ ! -d "${elf_dir}" ]]; then
	echo "ACT4 did not generate the expected ELF directory: ${elf_dir}" >&2
	exit 2
fi

mapfile -d '' act4_elfs < <(find "${elf_dir}" -type f -name '*.elf' -print0 | sort -z)
if [[ "${#act4_elfs[@]}" -eq 0 ]]; then
	echo "ACT4 generated no ELF files for ${profile}." >&2
	exit 2
fi

for elf in "${act4_elfs[@]}"; do
	relative_elf="${elf#${elf_dir}/}"
	case "/${relative_elf}/" in
		*'/I/'*)
			;;
		*'/Zmmul/'*)
			if [[ "${profile}" != 'rv32izmmul' ]]; then
				echo "ACT4 generated a Zmmul test for ${profile}: ${relative_elf}" >&2
				exit 2
			fi
			;;
		*)
			echo "ACT4 generated a test outside ${act4_extensions}: ${relative_elf}" >&2
			exit 2
			;;
	esac
done

bash "${root_dir}/tests/act4/audit_elfs.sh" \
	"${profile}" "${act4_objdump}" "${elf_dir}" "${audit_dir}"

export BLUERV32_BSIM="${root_dir}/build/${profile}/sim/bsim"
export BLUERV32_ACT4_IMAGE_DIR="${build_dir}/images"
export ACT4_OBJCOPY="${act4_objcopy}"

python3 "${act4_dir}/run_tests.py" \
	"bash ${root_dir}/tests/act4/run_elf.sh" \
	"${elf_dir}" \
	--jobs "${act4_jobs}" \
	--timeout "${act4_timeout}"

printf '%s\n' \
	'---------------------------------------------------------------------' \
	"[RESULT] ACT4 ${profile} certification tests completed successfully." \
	"Tests: ${#act4_elfs[@]}" \
	"Results: ${summary_dir}" \
	"ELF audit: ${audit_dir}" \
	"Versions: ${build_dir}/versions.txt" \
	'---------------------------------------------------------------------'
