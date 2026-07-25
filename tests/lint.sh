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
	tests/act4/audit_elfs.sh \
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
grep -q 'region\["attributes"\]' "${root_dir}/tests/act4/prepare_config.py"
grep -q 'include_priv_tests: false' "${root_dir}/tests/act4/prepare_config.py"
grep -q 'EXTENSIONS=I' "${root_dir}/tests/act4/run.sh"
grep -q 'ACT4 DUT configuration is not RV32I-only' "${root_dir}/tests/act4/run.sh"
grep -q 'ACT4 generated a forbidden DUT macro' "${root_dir}/tests/act4/run.sh"
grep -q 'ACT4 generated no RV32I ELF files' "${root_dir}/tests/act4/run.sh"
grep -q 'generated a non-I test' "${root_dir}/tests/act4/run.sh"
grep -q 'audit_elfs.sh' "${root_dir}/tests/act4/run.sh"
grep -q 'run_tests.py' "${root_dir}/tests/act4/run.sh"

python3 - "${root_dir}/tests/act4/config/bluerv32-rv32i.yaml" \
		"${root_dir}/tests/act4/config/rvmodel_macros.h" <<'PY'
from pathlib import Path
import re
import sys

udb_path = Path(sys.argv[1])
macro_path = Path(sys.argv[2])
udb_text = udb_path.read_text(encoding="utf-8")
macro_text = macro_path.read_text(encoding="utf-8")

extension_block = udb_text.split("implemented_extensions:", 1)[1].split("\nparams:", 1)[0]
extensions = re.findall(r"name:\s*([A-Za-z0-9]+)", extension_block)
if extensions != ["I"]:
	raise SystemExit(f"ACT4 UDB configuration must declare only I: {extensions}")

required_macros = [
	"RVMODEL_INTERRUPT_LATENCY",
	"RVMODEL_TIMER_INT_SOON_DELAY",
	"RVMODEL_MAX_CYCLES_PER_TIMER_TICK",
	"RVMODEL_SET_MEXT_INT",
	"RVMODEL_CLR_MEXT_INT",
	"RVMODEL_SET_MSW_INT",
	"RVMODEL_CLR_MSW_INT",
	"RVMODEL_SET_SEXT_INT",
	"RVMODEL_CLR_SEXT_INT",
	"RVMODEL_SET_SSW_INT",
	"RVMODEL_CLR_SSW_INT",
]
for name in required_macros:
	if f"#define {name}" not in macro_text:
		raise SystemExit(f"Missing ACT4 macro: {name}")

for name in ("STANDARD_SM_SUPPORTED", "ZICSR_SUPPORTED"):
	if f"#undef {name}" not in macro_text:
		raise SystemExit(f"Missing ACT4 path blocker: {name}")

if "#define RVMODEL_FENCEI" in macro_text:
	raise SystemExit("RVMODEL_FENCEI must not be defined after ACT4 utils.h is processed")
if "#ifdef ZIFENCEI_SUPPORTED" not in macro_text:
	raise SystemExit("Missing Zifencei configuration guard")
PY

bash -n "${root_dir}/tests/run_directed.sh"
bash -n "${root_dir}/tests/run_random_memory.sh"
bash -n "${root_dir}/tests/differential/run.sh"
bash -n "${root_dir}/tests/act4/audit_elfs.sh"
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

audit_tmp="$(mktemp -d)"
trap 'rm -rf "${audit_tmp}"' EXIT
mkdir -p "${audit_tmp}/elfs"
touch "${audit_tmp}/elfs/test.elf"

cat > "${audit_tmp}/objdump" <<'EOF_OBJDUMP'
#!/usr/bin/env bash
printf '00000000:\t00000013\taddi\tx0,x0,0\n'
EOF_OBJDUMP
chmod +x "${audit_tmp}/objdump"
bash "${root_dir}/tests/act4/audit_elfs.sh" \
	"${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/pass" >/dev/null

cat > "${audit_tmp}/objdump" <<'EOF_OBJDUMP'
#!/usr/bin/env bash
printf '00000000:\t0000100f\tfence.i\n'
EOF_OBJDUMP
chmod +x "${audit_tmp}/objdump"
if bash "${root_dir}/tests/act4/audit_elfs.sh" \
		"${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/fail" \
		>/dev/null 2>&1; then
	echo 'ACT4 ELF audit did not reject fence.i.' >&2
	exit 1
fi

g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
	"${root_dir}/cpp/main.cpp"

printf 'Repository lint: PASS\n'
