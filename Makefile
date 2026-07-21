ROOTDIR := $(abspath .)
APP ?= minisudoku
BOARD ?= ulx3s

BSC ?= bsc
YOSYS ?= yosys
NEXTPNR ?= nextpnr-ecp5
ECPPACK ?= ecppack
PROGRAMMER ?= ujprog
PYTHON ?= python3

BUILD_DIR := $(ROOTDIR)/build/hardware
BSIM_DIR := $(ROOTDIR)/build/sim
SOFTWARE_BIN := $(ROOTDIR)/build/software/$(APP)/$(APP).bin
TOP_SOURCE := $(ROOTDIR)/system/Top.bsv
TOP_MODULE := mkTop
BSIM_TOP_MODULE := mkTop_bsim
BSV_PATH := $(ROOTDIR)/processor:$(ROOTDIR)/system
CONSTRAINTS := $(ROOTDIR)/ulx3s/ulx3s.lpf
JSON_NETLIST := $(BUILD_DIR)/$(TOP_MODULE).json
TEXTCFG := $(BUILD_DIR)/$(TOP_MODULE).config
BITSTREAM := $(BUILD_DIR)/$(TOP_MODULE).bit
YOSYS_REPORT := $(BUILD_DIR)/$(TOP_MODULE).yosys.rpt
NEXTPNR_REPORT := $(BUILD_DIR)/$(TOP_MODULE).nextpnr.json
NEXTPNR_LOG := $(BUILD_DIR)/$(TOP_MODULE).nextpnr.log

BSC_BIN := $(shell command -v $(BSC) 2>/dev/null)
BLUESPECDIR ?= $(abspath $(dir $(BSC_BIN))/../lib)
BSC_VERILOG_DIR ?= $(BLUESPECDIR)/Verilog
BSC_RTL_FILES := \
	BRAM2.v \
	ClockDiv.v \
	FIFO1.v \
	FIFO2.v \
	MakeResetA.v \
	RevertReg.v \
	SizedFIFO.v \
	SyncFIFO.v \
	SyncResetA.v

BSCFLAGS_COMMON := -show-schedule -show-range-conflict -aggressive-conditions
BSCFLAGS_SYNTH := \
	-bdir $(BUILD_DIR) \
	-vdir $(BUILD_DIR) \
	-simdir $(BUILD_DIR) \
	-info-dir $(BUILD_DIR) \
	-fdir $(BUILD_DIR)
BSCFLAGS_BSIM := \
	-bdir $(BSIM_DIR) \
	-vdir $(BSIM_DIR) \
	-simdir $(BSIM_DIR) \
	-info-dir $(BSIM_DIR) \
	-fdir $(BSIM_DIR) \
	-D BSIM \
	-l pthread

.PHONY: all help software list-software check-bsc check-fpga-tools \
	verilog netlist pnr bitstream synth bsim runsim program clean

all: bsim

help:
	@printf '%s\n' \
		'make software APP=minisudoku' \
		'make runsim APP=minisudoku' \
		'make synth BOARD=ulx3s' \
		'make program BOARD=ulx3s' \
		'make list-software'

software:
	+$(MAKE) -C software ROOTDIR=$(ROOTDIR) APP=$(APP)

list-software:
	+$(MAKE) -C software ROOTDIR=$(ROOTDIR) list

check-bsc:
	@command -v $(BSC) >/dev/null || { echo 'bsc not found' >&2; exit 127; }
	@test -d "$(BSC_VERILOG_DIR)" || { \
		echo "BSC Verilog library not found: $(BSC_VERILOG_DIR)" >&2; \
		echo 'Set BLUESPECDIR or BSC_VERILOG_DIR.' >&2; \
		exit 2; \
	}

check-fpga-tools:
	@command -v $(YOSYS) >/dev/null || { echo 'yosys not found' >&2; exit 127; }
	@command -v $(NEXTPNR) >/dev/null || { echo 'nextpnr-ecp5 not found' >&2; exit 127; }
	@command -v $(ECPPACK) >/dev/null || { echo 'ecppack not found' >&2; exit 127; }
	@test "$(BOARD)" = 'ulx3s' || { echo "Unsupported BOARD=$(BOARD)" >&2; exit 2; }

verilog: check-bsc
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	$(BSC) $(BSCFLAGS_COMMON) $(BSCFLAGS_SYNTH) -remove-dollar \
		-p +:$(BSV_PATH) -verilog -u -g $(TOP_MODULE) $(TOP_SOURCE)
	cp $(CONSTRAINTS) $(BUILD_DIR)/
	@for file in $(BSC_RTL_FILES); do \
		test -f "$(BSC_VERILOG_DIR)/$$file" || { \
			echo "Missing BSC RTL file: $(BSC_VERILOG_DIR)/$$file" >&2; \
			exit 2; \
		}; \
		cp "$(BSC_VERILOG_DIR)/$$file" "$(BUILD_DIR)/"; \
	done

netlist: verilog check-fpga-tools
	cd $(BUILD_DIR) && $(YOSYS) \
		-p "synth_ecp5 -top $(TOP_MODULE) -json $(notdir $(JSON_NETLIST)); tee -q -o $(notdir $(YOSYS_REPORT)) stat -top $(TOP_MODULE)" \
		*.v

pnr: netlist
	$(NEXTPNR) \
		--85k \
		--package CABGA381 \
		--speed 6 \
		--json $(JSON_NETLIST) \
		--textcfg $(TEXTCFG) \
		--lpf $(BUILD_DIR)/$(notdir $(CONSTRAINTS)) \
		--report $(NEXTPNR_REPORT) \
		--log $(NEXTPNR_LOG)

bitstream: pnr
	$(ECPPACK) --idcode 0x41113043 $(TEXTCFG) $(BITSTREAM)

synth: bitstream
	@printf 'Bitstream:      %s\nYosys report:   %s\nnextpnr report: %s\n' \
		'$(BITSTREAM)' '$(YOSYS_REPORT)' '$(NEXTPNR_REPORT)'

bsim: software check-bsc
	rm -rf $(BSIM_DIR)
	mkdir -p $(BSIM_DIR)
	$(BSC) $(BSCFLAGS_COMMON) $(BSCFLAGS_BSIM) \
		-p +:$(BSV_PATH) -sim -u -g $(BSIM_TOP_MODULE) $(TOP_SOURCE)
	$(BSC) $(BSCFLAGS_COMMON) $(BSCFLAGS_BSIM) \
		-sim -e $(BSIM_TOP_MODULE) -o $(BSIM_DIR)/bsim \
		$(BSIM_DIR)/*.ba $(ROOTDIR)/cpp/main.cpp

runsim: bsim
	cd $(ROOTDIR) && BLUERV32_BIN=$(SOFTWARE_BIN) $(BSIM_DIR)/bsim \
		2> $(ROOTDIR)/build/software/$(APP)/output.log \
		| tee $(ROOTDIR)/build/software/$(APP)/system.log

program: bitstream
	@command -v $(PROGRAMMER) >/dev/null || { echo 'programmer not found: $(PROGRAMMER)' >&2; exit 127; }
	$(PROGRAMMER) $(BITSTREAM)

clean:
	rm -rf $(ROOTDIR)/build
