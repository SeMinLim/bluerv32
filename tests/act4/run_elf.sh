#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
	echo "Usage: $0 TEST.elf" >&2
	exit 2
fi

: "${BLUERV32_BSIM:?Set BLUERV32_BSIM to the ACT4-enabled Bluesim executable.}"
: "${ACT4_OBJCOPY:?Set ACT4_OBJCOPY to the RISC-V objcopy executable.}"

elf="$1"
image_dir="${BLUERV32_ACT4_IMAGE_DIR:-$(dirname "${elf}")/images}"
mkdir -p "${image_dir}"

elf_name="$(basename "${elf}")"
elf_hash="$(printf '%s' "${elf}" | sha256sum | cut -c1-16)"
binary="${image_dir}/${elf_name%.elf}-${elf_hash}.bin"

"${ACT4_OBJCOPY}" -O binary --gap-fill 0 --pad-to 0x10000 "${elf}" "${binary}"

binary_size="$(wc -c < "${binary}")"
if [[ "${binary_size}" -ne 65536 ]]; then
	echo "ACT4 image must be exactly 65536 bytes: ${binary}" >&2
	exit 2
fi

BLUERV32_BIN="${binary}" "${BLUERV32_BSIM}"
