ROOTDIR ?= $(abspath ..)
PROFILE ?= rv32i
include $(ROOTDIR)/profiles.mk

TEST ?= rv32i_basic
RISCV_PREFIX ?= riscv64-unknown-elf-
BINARY_SIZE := 65536
BINARY_LIMIT := 0x10000

CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

COMMON_TESTS := \
	rv32i_basic \
	rv32i_immediate \
	rv32i_loadstore \
	rv32i_illegal \
	rv32i_ecall \
	rv32i_load_misaligned \
	rv32i_store_misaligned \
	rv32i_branch_misaligned \
	rv32i_jal_misaligned \
	rv32i_jump_misaligned \
	rv32i_instruction_access \
	rv32i_load_access \
	rv32i_store_access

ifeq ($(PROFILE),rv32i)
PROFILE_TESTS := rv32i_m_illegal rv32i_diff
else ifeq ($(PROFILE),rv32izmmul)
PROFILE_TESTS := \
	rv32izmmul \
	rv32izmmul_div_illegal \
	rv32izmmul_divu_illegal \
	rv32izmmul_rem_illegal \
	rv32izmmul_remu_illegal \
	rv32izmmul_diff
endif

TESTS := $(COMMON_TESTS) $(PROFILE_TESTS)
SOURCE := $(CURDIR)/directed/$(TEST).s
BUILD_DIR := $(ROOTDIR)/build/$(PROFILE)/tests/$(TEST)
ELF := $(BUILD_DIR)/$(TEST).elf
BIN := $(BUILD_DIR)/$(TEST).bin
DUMP := $(BUILD_DIR)/$(TEST).dump
LINKER := $(ROOTDIR)/software/runtime/bare-link.ld

FLAGS := \
	-march=$(PROFILE_MARCH) \
	-mabi=ilp32 \
	-mcmodel=medany \
	-msmall-data-limit=0 \
	-mstrict-align \
	-nostdlib \
	-nostartfiles \
	-static \
	-Wl,-T,$(LINKER) \
	-Wl,--build-id=none

.PHONY: build check directed random differential act4 arch-test clean

build: check $(BIN) $(DUMP)

check:
	@case " $(TESTS) " in *" $(TEST) "*) ;; *) echo "Unknown TEST=$(TEST) for PROFILE=$(PROFILE)" >&2; exit 2 ;; esac
	@test -f "$(SOURCE)" || { echo "Test source not found: $(SOURCE)" >&2; exit 2; }
	@command -v "$(CC)" >/dev/null || { echo "$(CC) not found" >&2; exit 127; }
	@command -v "$(OBJCOPY)" >/dev/null || { echo "$(OBJCOPY) not found" >&2; exit 127; }
	@command -v "$(OBJDUMP)" >/dev/null || { echo "$(OBJDUMP) not found" >&2; exit 127; }

$(ELF): $(SOURCE) $(LINKER)
	mkdir -p $(BUILD_DIR)
	$(CC) $(FLAGS) $< -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary --gap-fill 0 --pad-to $(BINARY_LIMIT) $< $@
	@test "$$(wc -c < $@)" -eq $(BINARY_SIZE)

$(DUMP): $(ELF)
	$(OBJDUMP) -d -Mno-aliases $< > $@

directed:
	PROFILE=$(PROFILE) bash $(CURDIR)/run_directed.sh

random:
	PROFILE=$(PROFILE) bash $(CURDIR)/run_random_memory.sh

differential:
	PROFILE=$(PROFILE) bash $(CURDIR)/differential/run.sh

act4:
	PROFILE=$(PROFILE) bash $(CURDIR)/act4/run.sh

arch-test: act4

clean:
	rm -rf $(ROOTDIR)/build/$(PROFILE)/tests
