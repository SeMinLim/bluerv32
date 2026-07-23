ROOTDIR ?= $(abspath ..)
APPS := microbench minisudoku pipesafe pipeunsafe1 pipeunsafe2
APP ?= minisudoku
MARCH ?= rv32i
MABI ?= ilp32
RISCV_PREFIX ?= riscv64-unknown-elf-
BINARY_SIZE := 65536
BINARY_LIMIT := 0x10000

CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

APP_DIR := $(CURDIR)/$(APP)
BUILD_DIR := $(ROOTDIR)/build/software/$(APP)
ELF := $(BUILD_DIR)/$(APP).elf
BIN := $(BUILD_DIR)/$(APP).bin
DUMP := $(BUILD_DIR)/$(APP).dump
LINKER := $(CURDIR)/runtime/bare-link.ld
C_SOURCES := $(wildcard $(APP_DIR)/*.c)
S_SOURCES := $(wildcard $(APP_DIR)/*.s)
STARTUP := $(if $(strip $(C_SOURCES)),$(CURDIR)/runtime/entry.s,)

COMMON_FLAGS := \
	-O2 \
	-march=$(MARCH) \
	-mabi=$(MABI) \
	-mcmodel=medany \
	-msmall-data-limit=0 \
	-mstrict-align \
	-ffreestanding \
	-fno-builtin \
	-fno-stack-protector \
	-fdata-sections \
	-ffunction-sections \
	-nostdlib \
	-nostartfiles \
	-static
LDFLAGS := \
	-Wl,-T,$(LINKER) \
	-Wl,--gc-sections \
	-Wl,--build-id=none
OBJDUMP_FLAGS := -d -Mno-aliases

.PHONY: all check clean list

all: check $(BIN) $(DUMP)
	@printf 'ELF:  %s\nBIN:  %s\nDUMP: %s\n' '$(ELF)' '$(BIN)' '$(DUMP)'

check:
	@case " $(APPS) " in *" $(APP) "*) ;; *) echo "Unknown APP=$(APP)" >&2; exit 2 ;; esac
	@test -n "$(strip $(C_SOURCES) $(S_SOURCES))" || { echo "No source found for APP=$(APP)" >&2; exit 2; }
	@command -v "$(CC)" >/dev/null || { echo "$(CC) not found" >&2; exit 127; }
	@command -v "$(OBJCOPY)" >/dev/null || { echo "$(OBJCOPY) not found" >&2; exit 127; }
	@command -v "$(OBJDUMP)" >/dev/null || { echo "$(OBJDUMP) not found" >&2; exit 127; }

$(ELF): $(C_SOURCES) $(S_SOURCES) $(STARTUP) $(LINKER)
	mkdir -p $(BUILD_DIR)
	$(CC) $(COMMON_FLAGS) $(STARTUP) $(C_SOURCES) $(S_SOURCES) \
		$(LDFLAGS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary --gap-fill 0 --pad-to $(BINARY_LIMIT) $< $@
	@test "$$(wc -c < $@)" -eq $(BINARY_SIZE) || { echo "Unexpected binary size: $@" >&2; exit 2; }

$(DUMP): $(ELF)
	$(OBJDUMP) $(OBJDUMP_FLAGS) $< > $@

list:
	@printf '%s\n' $(APPS)

clean:
	rm -rf $(ROOTDIR)/build/software
