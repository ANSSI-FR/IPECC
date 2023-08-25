ARM_CC ?= arm-linux-gnueabihf-gcc
CFLAGS = -Wall -Wextra -Wpedantic -O3 -g3 -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -static
CFLAGS += -DWITH_EC_HW_DEBUG

C_FILES = hw_accelerator_driver_ipecc_platform.c hw_accelerator_driver_ipecc.c
C_FILES_LINUX = $(C_FILES) linux/ecc-test-linux.c linux/curve.c linux/kp.c linux/ptops.c linux/pttests.c
C_FILES_STDALONE = $(C_FILES) stdalone/ecc-test-stdl.c

.PHONY: linux-target stdalone-target

all: linux-target stdalone-target

linux-target:
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_UIO $(C_FILES_LINUX) -o ecc-test-uio
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_DEVMEM $(C_FILES_LINUX) -o ecc-test-devmem

stdalone-target:
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_STANDALONE $(C_FILES_STDALONE) -o ecc-test-stdalone

clean:
	@rm -f ecc-test-uio ecc-test-devmem ecc-test-stdalone
