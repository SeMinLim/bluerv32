ROOTDIR := $(abspath ..)
TEST ?= rv32i_basic
RISCV_PREFIX ?= riscv64-unknown-elf-
BINARY_SIZE := 65536
BINARY_LIMIT := 0x10000

CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

TESTS := \
	rv32i_basic \
	rv32i_immediate \
	rv32i_loadstore \
	rv32i_illegal \
	rv32i_m_illegal \
	rv32i_ecall \
	rv32i_load_misaligned \
	rv32i_store_misaligned \
	rv32i_branch_misaligned \
	rv32i_jal_misaligned \
	rv32i_jump_misaligned \
	rv32i_instruction_access \
	rv32i_load_access \
	rv32i_store_access \
	rv32i_diff

SOURCE := $(CURDIR)/directed/$(TEST).s
BUILD_DIR := $(ROOTDIR)/build/tests/$(TEST)
ELF := $(BUILD_DIR)/$(TEST).elf
BIN := $(BUILD_DIR)/$(TEST).bin
DUMP := $(BUILD_DIR)/$(TEST).dump
LINKER := $(ROOTDIR)/software/runtime/bare-link.ld

FLAGS := \
	-march=rv32i \
	-mabi=ilp32 \
	-mcmodel=medany \
	-msmall-data-limit=0 \
	-mstrict-align \
	-nostdlib \
	-nostartfiles \
	-static \
	-Wl,-T,$(LINKER) \
	-Wl,--build-id=none

.PHONY: build check directed random differential arch-test clean

build: check $(BIN) $(DUMP)

check:
	@case " $(TESTS) " in *" $(TEST) "*) ;; *) echo "Unknown TEST=$(TEST)" >&2; exit 2 ;; esac
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
	bash $(CURDIR)/run_directed.sh

random:
	bash $(CURDIR)/run_random_memory.sh

differential:
	bash $(CURDIR)/differential/run.sh

arch-test:
	bash $(CURDIR)/arch-test/run.sh

clean:
	rm -rf $(ROOTDIR)/build/tests
