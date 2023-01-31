SHELL := /bin/bash

# External dependency
CUSTOM_VHD=../ecc_customize.vhd
ECCPKG_VHD=../ecc_pkg.vhd

# Outfiles
OUT_ASM=ecc_curve_iram.s
OUT_VHD=ecc_curve_iram.vhd
OUT_VHD_ADDR_TMP=ecc_curve_iram_addr.vhd
OUT_ADDR_VHD=ecc_addr.vhd
OUT_DISASS=ecc_curve_iram_disass.s

# Assembly source files
ASM_SRC=asm_src
ASM_LABELS=$(ASM_SRC)/ecc_addr.txt
PFX_SRC_FILES=monty-cst check-on-curve blinding adpa setup double switch3P joye-adpa zaddu zaddc subtractP exit eucl-inv cst-time-inv addition ptops fpops zdbl znegc
ASM_SRC_FILES:=$(addsuffix .s,$(PFX_SRC_FILES))
ASM_SRC_FILES:=$(addprefix $(ASM_SRC)/,$(ASM_SRC_FILES))
ASM_VAR_DEFINITIONS=$(ASM_SRC)/vardefs.csv

all: asm

$(OUT_ASM): $(ASM_SRC_FILES)
	@# Create the concatenated ASM program
	@echo "  -> Creating ASM main program $@"
	@cat $^ >| $@
	@# Handle exported labels if necessary
	@if [ -a $(ASM_LABELS) ]; then \
		echo "  -> $(ASM_LABELS) (list of labels to be exported) detected, patching exports in $(OUT_ASM)"; \
		for l in `cat $(ASM_LABELS)`; do \
			regexp="$${l}(:)?(\s*)(#.*)*$$"; \
			sed -E -i "s/$$regexp/$${l}_export\1\2\3/g" $(OUT_ASM); \
		done; \
	fi

# Compile the assembly sources
asm: $(OUT_VHD)
$(OUT_VHD): $(OUT_ASM) $(ECCPKG_VHD) $(CUSTOM_VHD) $(ASM_VAR_DEFINITIONS)
	@# Assemble file
	@python3 ipecc_assembler.py -a $^
	@mv $(OUT_VHD_ADDR_TMP) $(OUT_ADDR_VHD)

# Disassemble if asked to
disass: $(OUT_DISASS)
$(OUT_DISASS):	$(OUT_VHD) $(ECCPKG_VHD) $(CUSTOM_VHD) $(ASM_VAR_DEFINITIONS)
	@if [ -a $(OUT_VHD) ]; then \
		python3 ipecc_assembler.py -d $(OUT_VHD) $(ECCPKG_VHD) $(CUSTOM_VHD) $(ASM_VAR_DEFINITIONS); \
	else \
		echo "File $(OUT_VHD) does not exit. Please compile it before trying to disassemble!"; \
	fi

.PHONY: latex
latex: $(ASM_SRC_FILES)
	@$(MAKE) -s PFX_SRC_FILES="$(PFX_SRC_FILES)" ASM_SRC="$(ASM_SRC)" ASM_VAR_DEFINITIONS="$(ASM_VAR_DEFINITIONS)" -C latex/

clean:
	@rm -f ecc_curve_iram.s
	@rm -f $(OUT_VHD) $(OUT_VHD_ADDR_TMP) $(OUT_ADDR_VHD)
	@rm -f $(OUT_DISASS)
	@make -s -C latex/ clean
