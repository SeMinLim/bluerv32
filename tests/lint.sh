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

for legacy_file in \
	processor/BranchPredictor.bsv \
	processor/Scoreboard.bsv; do
	if [[ -e "${root_dir}/${legacy_file}" ]]; then
		echo "Legacy processor file must be removed: ${legacy_file}" >&2
		exit 1
	fi
done

for file in \
	processor/Defines.bsv \
	processor/Decode.bsv \
	processor/Execute.bsv \
	processor/Processor.bsv \
	processor/RFile.bsv \
	system/BRAMSubWord.bsv \
	system/Top.bsv \
	system/Uart.bsv; do
	test -f "${root_dir}/${file}"
done

grep -q 'Word addr;' "${root_dir}/processor/Defines.bsv"
grep -q 'EnvironmentCallInst' "${root_dir}/processor/Decode.bsv"
grep -q 'BreakpointInst' "${root_dir}/processor/Decode.bsv"
grep -q 'Fence' "${root_dir}/processor/Decode.bsv"
grep -q 'MARCH ?= rv32i' "${root_dir}/software/Makefile"

bash -n "${root_dir}/tests/run_directed.sh"
bash -n "${root_dir}/tests/run_random_memory.sh"
bash -n "${root_dir}/tests/differential/run.sh"
bash -n "${root_dir}/tests/arch-test/run.sh"

python3 - "${root_dir}/tests/differential/compare_spike.py" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY

g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
	"${root_dir}/cpp/main.cpp"

printf 'Repository lint: PASS\n'
