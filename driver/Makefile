# VHD_SRC must be set with the ABSOLUTE path where IPECC microcode
# has been built (DO NOT use relative path!)
VHD_DIR=

# CONFIG #############
ARM_CC ?= arm-linux-gnueabihf-gcc
CFLAGS = -Wall -Wextra -Wpedantic -O3 -g3 -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -static
CFLAGS += -DWITH_EC_HW_DEBUG

# Comment the following line if your terminal doesn'ot support ANSI Escape Codes
# (to colorize and control cursor movement on screen)
CFLAGS += -DTERM_CTRL_AND_COLORS
# Uncomment the following line to get [k]P trace debug feature
#CFLAGS += -DKP_TRACE

C_FILES = hw_accelerator_driver_ipecc_platform.c hw_accelerator_driver_ipecc.c
C_FILES_LINUX = $(C_FILES) linux/ecc-test-linux.c linux/curve.c linux/kp.c linux/ptops.c linux/pttests.c
C_FILES_STDOL = $(C_FILES) stdalone/ecc-test-stdl.c


# TARGETS ############
all: ecc-test-linux-uio ecc-test-linux-devmem ecc-test-stdalone

.PHONY: headers
headers:
	@if [ -z "$(VHD_DIR)" ] ; then \
		echo -e "\033[93m *Error*: makefile variable VHD_DIR is not defined.\033[0m" ; \
		echo -e "\033[92m\033[4mSolution\033[24m: Edit ./Makefile and set VHD_DIR to point to the folder path\033[0m" ; \
		echo -e "\033[92m          where the IPECC microcode was built. Alternatively you can\033[0m" ; \
		echo -e "\033[92m          inline definition e.g 'make VHD_DIR=', but whatever the way\033[0m" ; \
		echo -e "\033[92m          don't use a relative path, use only an absolute one.\033[0m" ; \
		exit -1; \
		fi
	@if [ ! -x $(VHD_DIR) ] ; then \
		echo -e "\033[93m*Error*: makefile variable VHD_DIR points to a folder without access permissions.\033[0m" ; \
		echo -e "\033[38;5;226m\033[4mDetails\033[24m: Folder '$(VHD_DIR)' doesn't have the 'x' permission\033[0m" ; \
		exit -1; \
		fi
	@for h in ecc_addr.h ecc_vars.h ecc_states.h ; do \
		if [ ! -r $(VHD_DIR)/$${h} ] ; then \
		  echo -e "\033[93m *Error*: can't access header file '$${h}'. No file of this name\033[0m" ; \
		  echo -e "\033[93m          found in the folder pointed to by makefile variable VHD_DIR.\033[0m" ; \
		  echo -e "\033[92m\033[4mSolution\033[24m: Change dir to that folder and run 'make', which will generate\033[0m" ; \
		  echo -e "\033[92m          the IPECC microcode along with the C header files which are\033[0m" ; \
			echo -e "\033[92m          automatically generated from it.\033[0m" ; \
		  exit -1; \
		fi \
	done

ecc-test-linux-uio: headers $(C_FILES_LINUX) linux/ecc-test-linux.h
	$(ARM_CC) $(CFLAGS) -I$(VHD_DIR) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_UIO $(C_FILES_LINUX) -o ecc-test-linux-uio

ecc-test-linux-devmem: headers $(C_FILES_LINUX) linux/ecc-test-linux.h
	$(ARM_CC) $(CFLAGS) -I$(VHD_DIR) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_DEVMEM $(C_FILES_LINUX) -o ecc-test-linux-devmem

ecc-test-stdalone: headers $(C_FILES_STDOL) stdalone/ecc-test-stdl.h
	$(ARM_CC) $(CFLAGS) -I$(VHD_DIR) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_STANDALONE $(C_FILES_STDOL) -o ecc-test-stdalone

clean:
	@rm -f ecc-test-linux-uio ecc-test-linux-devmem ecc-test-stdalone
