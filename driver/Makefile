ARM_CC ?= arm-linux-gnueabihf-gcc
CFLAGS = -Wall -Wextra -Wpedantic -O3 -g3 -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -static
CFLAGS += -DWITH_EC_HW_DEBUG

C_FILES = hw_accelerator_driver_ipecc_platform.c hw_accelerator_driver_ipecc.c
C_FILES_LINUX = $(C_FILES) linux/ecc-test-linux.c linux/curve.c linux/kp.c linux/ptops.c linux/pttests.c
C_FILES_STDOL = $(C_FILES) stdalone/ecc-test-stdl.c

#.PHONY: linux-targets stdalone-target
all: linux-targets stdalone-target

linux-targets: ecc-test-linux-uio ecc-test-linux-devmem

stdalone-target: ecc-test-stdalone

ecc-test-linux-uio: $(C_FILES_LINUX) linux/ecc-test-linux.h
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_UIO $(C_FILES_LINUX) -o ecc-test-linux-uio

ecc-test-linux-devmem: $(C_FILES_LINUX) linux/ecc-test-linux.h
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_DEVMEM $(C_FILES_LINUX) -o ecc-test-linux-devmem

ecc-test-stdalone: $(C_FILES_STDOL) stdalone/ecc-test-stdl.h
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_STANDALONE $(C_FILES_STDOL) -o ecc-test-stdalone

clean:
	@rm -f ecc-test-linux-uio ecc-test-linux-devmem ecc-test-stdalone
