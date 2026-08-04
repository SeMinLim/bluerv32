#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
	echo "Usage: $0 PROFILE OBJDUMP ELF_DIR OUTPUT_DIR" >&2
	exit 2
fi

profile="$1"
objdump="$2"
elf_dir="$3"
output_dir="$4"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${profile}" in
	rv32i|rv32izmmul|rv32im)
		;;
	*)
		echo "Unsupported PROFILE=${profile}" >&2
		exit 2
		;;
esac

if [[ ! -d "${elf_dir}" ]]; then
	echo "ACT4 ELF directory not found: ${elf_dir}" >&2
	exit 2
fi

mkdir -p "${output_dir}"
elf_count=0

while IFS= read -r -d '' elf; do
	relative_elf="${elf#${elf_dir}/}"
	dump_name="$(printf '%s' "${relative_elf}" | sha256sum | cut -d' ' -f1).dump"
	dump_path="${output_dir}/${dump_name}"

	if ! python3 "${script_dir}/audit_elf.py" \
			"${profile}" "${objdump}" "${elf}" "${dump_path}"; then
		echo "ACT4 ELF audit failed: ${relative_elf}" >&2
		exit 1
	fi

	elf_count=$((elf_count + 1))
done < <(find "${elf_dir}" -type f -name '*.elf' -print0 | sort -z)

if [[ "${elf_count}" -eq 0 ]]; then
	echo "ACT4 ELF audit received no files." >&2
	exit 2
fi

printf 'ACT4 %s ELF audit: PASS (%d files)\n' "${profile}" "${elf_count}"
