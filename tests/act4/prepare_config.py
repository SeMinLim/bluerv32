#!/usr/bin/env python3

import argparse
import json
import shutil
from pathlib import Path


def stripJsonComments(text: str) -> str:
	result: list[str] = []
	idx = 0
	inString = False
	escaped = False

	while idx < len(text):
		char = text[idx]
		nextChar = text[idx + 1] if idx + 1 < len(text) else ""

		if inString:
			result.append(char)
			if escaped:
				escaped = False
			elif char == "\\":
				escaped = True
			elif char == '"':
				inString = False
			idx += 1
			continue

		if char == '"':
			inString = True
			result.append(char)
			idx += 1
			continue

		if char == "/" and nextChar == "/":
			idx += 2
			while idx < len(text) and text[idx] != "\n":
				idx += 1
			continue

		if char == "/" and nextChar == "*":
			idx += 2
			while idx + 1 < len(text) and not (
				text[idx] == "*" and text[idx + 1] == "/"
			):
				idx += 1
			idx += 2
			continue

		result.append(char)
		idx += 1

	return "".join(result)


def patchSailConfig(sourcePath: Path, outputPath: Path) -> None:
	configText = sourcePath.read_text(encoding="utf-8")
	config = json.loads(stripJsonComments(configText))
	memory = config["memory"]
	regions = memory["regions"]
	mainRegions = [
		region for region in regions
		if region["attrs"]["mem_type"] == "MainMemory"
	]

	if len(mainRegions) != 1:
		raise RuntimeError("Expected exactly one MainMemory region in the ACT4 Sail config.")

	mainRegion = mainRegions[0]
	mainRegion["base"]["value"] = "0x00000000"
	mainRegion["size"]["value"] = "0x00010000"
	mainRegion["attrs"]["executable"] = True
	mainRegion["attrs"]["readable"] = True
	mainRegion["attrs"]["writable"] = True
	mainRegion["attrs"]["misaligned_exceptions"] = {
		"load_store": {"Some": "AlignmentException"},
		"fetch": {"Some": "AlignmentException"},
	}
	memory["regions"] = [mainRegion]
	memory["dtb_address"]["value"] = "0x00000000"

	platform = config.get("platform", {})
	for peripheralName in ("clint", "simple_interrupt_generator"):
		peripheral = platform.get(peripheralName)
		if peripheral is not None:
			peripheral["supported"] = False
			peripheral["base"]["value"] = "0x00000000"
			peripheral["size"]["value"] = "0x00000000"

	outputPath.write_text(
		json.dumps(config, indent=2, sort_keys=True) + "\n",
		encoding="utf-8",
	)


def writeFrameworkConfig(
	outputPath: Path,
	compiler: str,
	objdump: str,
	referenceModel: str,
) -> None:
	content = "\n".join([
		"name: bluerv32-rv32i",
		f"compiler_exe: {json.dumps(compiler)}",
		f"objdump_exe: {json.dumps(objdump)}",
		f"ref_model_exe: {json.dumps(referenceModel)}",
		"udb_config: bluerv32-rv32i.yaml",
		"linker_script: link.ld",
		"dut_include_dir: .",
		"include_priv_tests: false",
		"",
	])
	outputPath.write_text(content, encoding="utf-8")


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Prepare the blueRV32 ACT4 configuration directory."
	)
	parser.add_argument("--act4-dir", required=True, type=Path)
	parser.add_argument("--source-dir", required=True, type=Path)
	parser.add_argument("--output-dir", required=True, type=Path)
	parser.add_argument("--compiler", required=True)
	parser.add_argument("--objdump", required=True)
	parser.add_argument("--reference-model", required=True)
	args = parser.parse_args()

	sailSource = (
		args.act4_dir / "config" / "sail" / "sail-RVI20U32" / "sail.json"
	)
	if not sailSource.is_file():
		raise FileNotFoundError(f"ACT4 Sail config not found: {sailSource}")

	args.output_dir.mkdir(parents=True, exist_ok=True)
	for fileName in ("bluerv32-rv32i.yaml", "link.ld", "rvmodel_macros.h"):
		shutil.copy2(args.source_dir / fileName, args.output_dir / fileName)

	patchSailConfig(sailSource, args.output_dir / "sail.json")
	writeFrameworkConfig(
		args.output_dir / "test_config.yaml",
		args.compiler,
		args.objdump,
		args.reference_model,
	)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
