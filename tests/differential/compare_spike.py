#!/usr/bin/env python3
import re
import sys
from pathlib import Path


CORE_PATTERN = re.compile(
	r"RV32_COMMIT pc=([0-9a-fA-F]{8}) inst=([0-9a-fA-F]{8})"
)
SPIKE_PATTERN = re.compile(
	r"0x([0-9a-fA-F]{16})\s+\(0x([0-9a-fA-F]{8})\)"
)


def readCoreTrace(path):
	trace = []
	for line in Path(path).read_text(errors="replace").splitlines():
		match = CORE_PATTERN.search(line)
		if match is not None:
			trace.append((int(match.group(1), 16), int(match.group(2), 16)))
	return trace


def readSpikeTrace(path):
	trace = []
	for line in Path(path).read_text(errors="replace").splitlines():
		match = SPIKE_PATTERN.search(line)
		if match is not None:
			pc = int(match.group(1), 16) & 0xffffffff
			instruction = int(match.group(2), 16)
			trace.append((pc, instruction))
	return trace


def main():
	if len(sys.argv) != 3:
		print( "Usage: compare_spike.py CORE_LOG SPIKE_LOG" )
		return 2

	coreTrace = readCoreTrace(sys.argv[1])
	spikeTrace = readSpikeTrace(sys.argv[2])
	if len(coreTrace) == 0:
		print( "No blueRV32 commit trace was found." )
		return 1
	if len(spikeTrace) < len(coreTrace):
		print( "Spike produced fewer retired instructions than blueRV32." )
		return 1

	for index, coreEntry in enumerate(coreTrace):
		spikeEntry = spikeTrace[index]
		if coreEntry != spikeEntry:
			print(
				"Trace mismatch at instruction %d: core=(%08x,%08x) "
				"spike=(%08x,%08x)" % (
					index,
					coreEntry[0],
					coreEntry[1],
					spikeEntry[0],
					spikeEntry[1],
				)
			)
			return 1

	print( "Differential trace: PASS (%d instructions)" % len(coreTrace) )
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
