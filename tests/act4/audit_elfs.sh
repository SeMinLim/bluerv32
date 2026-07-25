#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
	echo "Usage: $0 OBJDUMP ELF_DIR OUTPUT_DIR" >&2
	exit 2
fi

objdump="$1"
elf_dir="$2"
output_dir="$3"

if [[ ! -d "${elf_dir}" ]]; then
	echo "ACT4 ELF directory not found: ${elf_dir}" >&2
	exit 2
fi

mkdir -p "${output_dir}"

forbidden_regex='[[:space:]](fence\.i|csrrw|csrrs|csrrc|csrrwi|csrrsi|csrrci|mret|sret|uret|dret|mnret|wfi|sfence\.vma|hfence\.[a-z0-9_.]+|mul|mulh|mulhsu|mulhu|div|divu|rem|remu|c\.[a-z0-9_.]+)([[:space:]]|$)'
elf_count=0

while IFS= read -r -d '' elf; do
	relative_elf="${elf#${elf_dir}/}"
	dump_name="$(printf '%s' "${relative_elf}" | sha256sum | cut -d' ' -f1).dump"
	dump_path="${output_dir}/${dump_name}"

	"${objdump}" -d -M no-aliases,numeric "${elf}" > "${dump_path}"

	if grep -E -i -q "${forbidden_regex}" "${dump_path}"; then
		echo "ACT4 generated a non-RV32I instruction: ${relative_elf}" >&2
		grep -E -i "${forbidden_regex}" "${dump_path}" >&2
		exit 1
	fi

	elf_count=$((elf_count + 1))
done < <(find "${elf_dir}" -type f -name '*.elf' -print0 | sort -z)

if [[ "${elf_count}" -eq 0 ]]; then
	echo "ACT4 ELF audit received no files." >&2
	exit 2
fi

printf 'ACT4 RV32I ELF audit: PASS (%d files)\n' "${elf_count}"
