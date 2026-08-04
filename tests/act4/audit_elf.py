#!/usr/bin/env python3

import argparse
import re
import subprocess
from pathlib import Path


FORBIDDEN_COMMON = {
	"fence.i",
	"csrrw",
	"csrrs",
	"csrrc",
	"csrrwi",
	"csrrsi",
	"csrrci",
	"mret",
	"sret",
	"uret",
	"dret",
	"mnret",
	"wfi",
	"sfence.vma",
}

MULTIPLY_INSTRUCTIONS = {
	"mul",
	"mulh",
	"mulhsu",
	"mulhu",
}

DIVIDE_INSTRUCTIONS = {
	"div",
	"divu",
	"rem",
	"remu",
}

FORBIDDEN_BY_PROFILE = {
	"rv32i": FORBIDDEN_COMMON | MULTIPLY_INSTRUCTIONS | DIVIDE_INSTRUCTIONS,
	"rv32izmmul": FORBIDDEN_COMMON | DIVIDE_INSTRUCTIONS,
	"rv32im": FORBIDDEN_COMMON,
}


def runCommand(command: list[str]) -> str:
	result = subprocess.run(
		command,
		check=True,
		capture_output=True,
		text=True,
	)
	return result.stdout


def getMappingSymbols(symbolText: str) -> dict[str, list[tuple[int, str]]]:
	mappingSymbols: dict[str, list[tuple[int, str]]] = {}

	for line in symbolText.splitlines():
		fields = line.split()
		if len(fields) < 5 or fields[-1] not in ("$x", "$d"):
			continue

		section = ""
		for field in fields[1:-2]:
			if field.startswith("."):
				section = field
		if section == "":
			continue

		address = int(fields[0], 16)
		mappingSymbols.setdefault(section, []).append(
			(address, fields[-1][1])
		)

	for symbols in mappingSymbols.values():
		symbols.sort()

	return mappingSymbols


def getMappingState(symbols: list[tuple[int, str]], address: int) -> str:
	state = "x"
	for symbolAddress, symbolState in symbols:
		if symbolAddress > address:
			break
		state = symbolState
	return state


def isForbidden(profile: str, mnemonic: str) -> bool:
	mnemonic = mnemonic.lower()
	return (
		mnemonic in FORBIDDEN_BY_PROFILE[profile]
		or mnemonic.startswith("hfence.")
		or mnemonic.startswith("c.")
	)


def auditElf(profile: str, objdump: str, elf: Path, dumpPath: Path) -> None:
	symbolText = runCommand([objdump, "-t", str(elf)])
	mappingSymbols = getMappingSymbols(symbolText)
	disassembly = runCommand([
		objdump,
		"-d",
		"-M",
		"no-aliases,numeric",
		str(elf),
	])
	dumpPath.write_text(disassembly, encoding="utf-8")

	currentSection = ""
	violations: list[str] = []
	sectionPattern = re.compile(r"^Disassembly of section ([^:]+):$")
	instructionPattern = re.compile(
		r"^\s*([0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+"
		r"([A-Za-z0-9_.]+)(?:\s|$)"
	)

	for line in disassembly.splitlines():
		sectionMatch = sectionPattern.match(line)
		if sectionMatch is not None:
			currentSection = sectionMatch.group(1)
			continue

		instructionMatch = instructionPattern.match(line)
		if instructionMatch is None:
			continue

		address = int(instructionMatch.group(1), 16)
		mnemonic = instructionMatch.group(2)
		symbols = mappingSymbols.get(currentSection, [])
		if getMappingState(symbols, address) != "x":
			continue
		if isForbidden(profile, mnemonic):
			violations.append(line)

	if violations:
		joined = "\n".join(violations)
		raise RuntimeError(
			f"ACT4 generated an instruction outside {profile}: {elf}\n{joined}"
		)


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Audit executable ACT4 instructions using RISC-V mapping symbols."
	)
	parser.add_argument(
		"profile",
		choices=("rv32i", "rv32izmmul", "rv32im"),
	)
	parser.add_argument("objdump")
	parser.add_argument("elf", type=Path)
	parser.add_argument("dump", type=Path)
	args = parser.parse_args()

	auditElf(args.profile, args.objdump, args.elf, args.dump)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
