#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -e "${root_dir}/.github/workflows" ]]; then
	echo '.github/workflows must not exist in blueRV32.' >&2
	exit 1
fi

if [[ -e "${root_dir}/processor/Divider.bsv" ]]; then
	echo 'Divider.bsv must not be added before the RV32IM profile.' >&2
	exit 1
fi

if grep -R -n --exclude='lint.sh' 'RISCOF' \
		"${root_dir}/README.md" "${root_dir}/tests"; then
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
	profiles.mk \
	processor/Defines.bsv \
	processor/Decode.bsv \
	processor/Execute.bsv \
	processor/Multiplier.bsv \
	processor/Processor.bsv \
	processor/RFile.bsv \
	system/BRAMSubWord.bsv \
	system/Top.bsv \
	system/Uart.bsv \
	tests/directed/rv32izmmul.s \
	tests/directed/rv32izmmul_diff.s \
	tests/directed/rv32izmmul_div_illegal.s \
	tests/directed/rv32izmmul_divu_illegal.s \
	tests/directed/rv32izmmul_rem_illegal.s \
	tests/directed/rv32izmmul_remu_illegal.s \
	tests/act4/README.md \
	tests/act4/audit_elfs.sh \
	tests/act4/config/bluerv32-rv32i.yaml \
	tests/act4/config/bluerv32-rv32izmmul.yaml \
	tests/act4/config/link.ld \
	tests/act4/config/rvmodel_macros.h \
	tests/act4/prepare_config.py \
	tests/act4/run.sh \
	tests/act4/run_elf.sh; do
	test -f "${root_dir}/${file}"
done

grep -q 'SUPPORTED_PROFILES := rv32i rv32izmmul' "${root_dir}/profiles.mk"
grep -q 'PROFILE_MARCH := rv32i_zmmul' "${root_dir}/profiles.mk"
grep -q 'PROFILE_BSC_DEFINES := -D RV32_ZMMUL' "${root_dir}/profiles.mk"
grep -q 'build/$(PROFILE)' "${root_dir}/Makefile"
grep -q 'RV32_ZMMUL' "${root_dir}/processor/Defines.bsv"
grep -q 'RV32_ZMMUL' "${root_dir}/processor/Decode.bsv"
grep -q 'RV32_ZMMUL' "${root_dir}/processor/Processor.bsv"
grep -q 'primMul' "${root_dir}/processor/Multiplier.bsv"
grep -q 'MultiplyHighSignedUnsigned' "${root_dir}/processor/Multiplier.bsv"
grep -q 'MARCH ?= $(PROFILE_MARCH)' "${root_dir}/software/Makefile"
grep -q 'march=$(PROFILE_MARCH)' "${root_dir}/tests/Makefile"
grep -q 'RV32I_Zmmul' "${root_dir}/tests/differential/run.sh"
grep -q -- '--config-name' "${root_dir}/tests/act4/prepare_config.py"
grep -q 'EXTENSIONS="${act4_extensions}"' "${root_dir}/tests/act4/run.sh"
grep -q 'rv32izmmul)' "${root_dir}/tests/act4/audit_elfs.sh"
grep -q '__bss_start' "${root_dir}/tests/act4/config/link.ld"
grep -q '__bss_end' "${root_dir}/tests/act4/config/link.ld"
grep -q '__stack_bottom' "${root_dir}/tests/act4/config/link.ld"
grep -q '__stack_top' "${root_dir}/tests/act4/config/link.ld"
grep -q '\.text\.rvmodel' "${root_dir}/tests/act4/config/link.ld"
grep -q '\.tohost' "${root_dir}/tests/act4/config/link.ld"

python3 - "${root_dir}" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])

expected_profiles = {
	"bluerv32-rv32i.yaml": ["I"],
	"bluerv32-rv32izmmul.yaml": ["I", "Zmmul"],
}
for filename, expected in expected_profiles.items():
	text = (root / "tests/act4/config" / filename).read_text(encoding="utf-8")
	block = text.split("implemented_extensions:", 1)[1].split("\nparams:", 1)[0]
	extensions = re.findall(r"name:\s*([A-Za-z0-9]+)", block)
	if extensions != expected:
		raise SystemExit(f"Unexpected extensions in {filename}: {extensions}")

macro_text = (root / "tests/act4/config/rvmodel_macros.h").read_text(encoding="utf-8")
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
	raise SystemExit("RVMODEL_FENCEI must not be defined")
if "#ifdef ZIFENCEI_SUPPORTED" not in macro_text:
	raise SystemExit("Missing Zifencei configuration guard")

linker_text = (root / "tests/act4/config/link.ld").read_text(encoding="utf-8")
required_linker_tokens = [
	".text.init",
	".text.rvtest",
	".rodata",
	".data",
	".bss",
	"__bss_start",
	"__bss_end",
	"__stack_bottom",
	"__stack_top",
	".text.rvmodel",
	".tohost",
]
for token in required_linker_tokens:
	if token not in linker_text:
		raise SystemExit(f"Missing ACT4 linker token: {token}")

if linker_text.index(".tohost") < linker_text.index(".text.rvmodel"):
	raise SystemExit("ACT4 .tohost must follow .text.rvmodel")
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
	rv32i "${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/i-pass" >/dev/null
bash "${root_dir}/tests/act4/audit_elfs.sh" \
	rv32izmmul "${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/z-pass" >/dev/null

cat > "${audit_tmp}/objdump" <<'EOF_OBJDUMP'
#!/usr/bin/env bash
printf '00000000:\t02000033\tmul\tx0,x0,x0\n'
EOF_OBJDUMP
chmod +x "${audit_tmp}/objdump"
if bash "${root_dir}/tests/act4/audit_elfs.sh" \
		rv32i "${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/i-mul" \
		>/dev/null 2>&1; then
	echo 'RV32I ACT4 audit did not reject MUL.' >&2
	exit 1
fi
bash "${root_dir}/tests/act4/audit_elfs.sh" \
	rv32izmmul "${audit_tmp}/objdump" "${audit_tmp}/elfs" "${audit_tmp}/z-mul" >/dev/null

cat > "${audit_tmp}/objdump" <<'EOF_OBJDUMP'
#!/usr/bin/env bash
printf '00000000:\t02004033\tdiv\tx0,x0,x0\n'
EOF_OBJDUMP
chmod +x "${audit_tmp}/objdump"
for profile in rv32i rv32izmmul; do
	if bash "${root_dir}/tests/act4/audit_elfs.sh" \
			"${profile}" "${audit_tmp}/objdump" "${audit_tmp}/elfs" \
			"${audit_tmp}/${profile}-div" >/dev/null 2>&1; then
		echo "${profile} ACT4 audit did not reject DIV." >&2
		exit 1
	fi
done

g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
	"${root_dir}/cpp/main.cpp"

printf 'Repository lint: PASS\n'
