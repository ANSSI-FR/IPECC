ARM_CC ?= arm-linux-gnueabihf-gcc
CFLAGS = -Wall -Wextra -O3 -g3 -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -static
CFLAGS += -DWITH_EC_HW_DEBUG

C_FILES = hw_accelerator_driver_ipecc_platform.c hw_accelerator_driver_ipecc.c test_app/test_app.c
C_EMUL_FILES = hw_accelerator_driver_socket_emul.c test_driver.c

all:
	$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_UIO $(C_FILES) -o test_uio

#$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_STANDALONE $(C_FILES) -o test_standalone
#$(ARM_CC) $(CFLAGS) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_DEVMEM $(C_FILES) -o test_devmem

emulator:
	$(CC) -DWITH_EC_HW_ACCELERATOR -DWITH_EC_HW_SOCKET_EMUL $(C_EMUL_FILES) -o test_emul

clean:
	@rm -f test_standalone test_uio test_devmem test_emul
