#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if grep -R -n -E '\b(Mul|MUL|mul)\b' "${root_dir}/processor"; then
	echo 'M-extension logic is not permitted in the RV32I core.' >&2
	exit 1
fi

if grep -R -n -E '\brv32im\b|\bmul\b' \
		"${root_dir}/software" "${root_dir}/tests/directed"; then
	echo 'RV32I software and directed tests must not require the M extension.' >&2
	exit 1
fi

if grep -R -n 'RISCOF' "${root_dir}/README.md" "${root_dir}/tests"; then
	echo 'Deprecated architectural-test integration must not remain in blueRV32.' >&2
	exit 1
fi

for legacy_file in \
	processor/BranchPredictor.bsv \
	processor/Scoreboard.bsv; do
	if [[ -e "${root_dir}/${legacy_file}" ]]; then
		echo "Legacy processor file must be removed: ${legacy_file}" >&2
		exit 1
	fi
done

if [[ -e "${root_dir}/tests/arch-test" ]]; then
	echo 'The obsolete tests/arch-test directory must be removed.' >&2
	exit 1
fi

for file in \
	processor/Defines.bsv \
	processor/Decode.bsv \
	processor/Execute.bsv \
	processor/Processor.bsv \
	processor/RFile.bsv \
	system/BRAMSubWord.bsv \
	system/Top.bsv \
	system/Uart.bsv \
	tests/act4/README.md \
	tests/act4/config/bluerv32-rv32i.yaml \
	tests/act4/config/link.ld \
	tests/act4/config/rvmodel_macros.h \
	tests/act4/prepare_config.py \
	tests/act4/run.sh \
	tests/act4/run_elf.sh; do
	test -f "${root_dir}/${file}"
done

grep -q 'Word addr;' "${root_dir}/processor/Defines.bsv"
grep -q 'EnvironmentCallInst' "${root_dir}/processor/Decode.bsv"
grep -q 'BreakpointInst' "${root_dir}/processor/Decode.bsv"
grep -q 'Fence' "${root_dir}/processor/Decode.bsv"
grep -q 'MARCH ?= rv32i' "${root_dir}/software/Makefile"
grep -q 'BINARY_SIZE := 65536' "${root_dir}/software/Makefile"
grep -q 'BINARY_LIMIT := 0x10000' "${root_dir}/software/Makefile"
grep -q 'BINARY_SIZE := 65536' "${root_dir}/tests/Makefile"
grep -q 'BINARY_LIMIT := 0x10000' "${root_dir}/tests/Makefile"
grep -q '#define INSTRUCTION_MEMORY_SIZE 32768' "${root_dir}/cpp/main.cpp"
grep -q '#define DATA_MEMORY_SIZE 32768' "${root_dir}/cpp/main.cpp"
grep -q 'typedef 15 MemoryAddrSize;' "${root_dir}/system/Top.bsv"
grep -q "memorySizeBytes = 16'h8000" "${root_dir}/system/Top.bsv"
grep -q 'RV32_ACT4' "${root_dir}/system/Top.bsv"
grep -q 'instructionFromDataOn' "${root_dir}/system/Top.bsv"
grep -q 'include_priv_tests: false' "${root_dir}/tests/act4/prepare_config.py"
grep -q 'EXTENSIONS=I' "${root_dir}/tests/act4/run.sh"
grep -q 'run_tests.py' "${root_dir}/tests/act4/run.sh"
grep -q 'RVMODEL_FENCEI nop' "${root_dir}/tests/act4/config/rvmodel_macros.h"

bash -n "${root_dir}/tests/run_directed.sh"
bash -n "${root_dir}/tests/run_random_memory.sh"
bash -n "${root_dir}/tests/differential/run.sh"
bash -n "${root_dir}/tests/act4/run.sh"
bash -n "${root_dir}/tests/act4/run_elf.sh"

python3 - "${root_dir}/tests/differential/compare_spike.py" \
		"${root_dir}/tests/act4/prepare_config.py" <<'PY'
from pathlib import Path
import sys

for filename in sys.argv[1:]:
	path = Path(filename)
	compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY

g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
	"${root_dir}/cpp/main.cpp"

printf 'Repository lint: PASS\n'
