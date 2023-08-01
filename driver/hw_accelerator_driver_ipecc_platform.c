/*
 *  Copyright (C) 2023 - This file is part of IPECC project
 *
 *  Authors:
 *      Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
 *      Ryad BENADJILA <ryadbenadjila@gmail.com>
 *
 *  Contributors:
 *      Adrian THILLARD
 *      Emmanuel PROUFF
 *
 *  This software is licensed under GPL v2 license.
 *  See LICENSE file at the root folder of the project.
 */

#include "hw_accelerator_driver_ipecc_platform.h"

extern int hw_driver_is_debug(void);
extern int hw_driver_get_version_major(void);
extern int hw_driver_get_version_minor(void);
extern unsigned char hw_driver_debug_not_prod;
extern int hw_driver_trng_post_proc_enable(void);

#if defined(WITH_EC_HW_ACCELERATOR) && !defined(WITH_EC_HW_SOCKET_EMUL)

/* The IP "physical" address in RAM.
 *
 * This address should only be used for direct access in standalone
 * mode or using a physical memory access (e.g. through /dev/mem).
 */
#define IPECC_PHYS_BADDR                (0x40000000)
#define IPECC_PHYS_PSEUDO_TRNG_BADDR    (0x40001000)
#define IPECC_PHYS_SZ                   (4096) /* One page size */

#define IPECC_DEV_UIO_IPECC             "/dev/uio4"
#define IPECC_DEV_UIO_PSEUDOTRNG        "/dev/uio5"
/* Setup the driver depending on the environment.
 *
 * If 'pseudotrng_base_addr_p' is not NULL then the setup will also try
 * to open a device for the pseudo TRNG function, and return the mapped
 * address for this device in *pseudotrng_base_addr_p.
 *
 * Thus if the pseudo TRNG function is not needed, simply set NULL value
 * for 'pseudotrng_base_addr_p' argument and the setup won't try to acquire
 * nor map a corresponding hardware device.
 *
 * Now if the IP was synthesized in production (secure) mode, then the pseudo
 * TRNG function naturally does NOT exist and, in case the value passed for
 * parameter 'pseudotrng_base_addr_p' is not NULL, then *pseudotrng_base_addr_p
 * will be set with value NULL.
 */
int hw_driver_setup(volatile unsigned char **base_addr_p, volatile unsigned char **pseudotrng_base_addr_p)
{
	int ret = -1;

	log_print("Entering in hw_driver_setup.\n");

	if (base_addr_p == NULL) {
		ret = -1;
		goto err;
	}
#if defined(WITH_EC_HW_STANDALONE)
	{
		log_print("hw_driver_setup in standalone mode\n");
		/* In standalone mode, the base address
		 * is the physical one.
		 */
		(*base_addr_p)	     = (volatile unsigned char*)IPECC_PHYS_BADDR;
		if (pseudotrng_base_addr_p != NULL) {
			(*pseudotrng_base_addr_p) = (volatile unsigned char*)IPECC_PHYS_PSEUDO_TRNG_BADDR;
		}
	}							
#elif defined(WITH_EC_HW_UIO)
	{						
		int uio_fd0, uio_fd1;
		unsigned int uio_size;
		void *base_address;
		log_print("hw_driver_setup in UIO mode\n");

		/* Handle the main ECC IP */
		/* Open our UIO device
		 * NOTE: O_SYNC here to avoid caching
		 */
		uio_fd0 = open(IPECC_DEV_UIO_IPECC, O_RDWR | O_SYNC);
		if(uio_fd0 == -1){
			printf("Error when opening %s\n", IPECC_DEV_UIO_PSEUDOTRNG);
			perror("open uio");
			ret = -1;
			goto err;
		}
		uio_size = IPECC_PHYS_SZ;
		base_address = mmap(NULL, uio_size, PROT_READ | PROT_WRITE, MAP_SHARED, uio_fd0, 0);
		if(base_address == MAP_FAILED){
			printf("Error during mmap!\n");
			perror("mmap uio");
			ret = -1;
			goto err;
		}
		(*base_addr_p) = base_address;

		if (pseudotrng_base_addr_p != NULL) {

			/* Now handle the pseudo-TRNG device. If the device does not exist (e.g the IP
			 * was not synthesized in debug mode, then the device simply won't exist, in which
			 * case we set *pseudotrng_base_addr_p = NULL.
			 */
			/* Open our UIO device
			 * NOTE: O_SYNC here to avoid caching
			 */
			uio_fd1 = open(IPECC_DEV_UIO_PSEUDOTRNG, O_RDWR | O_SYNC);
			if(uio_fd1 == -1){
				printf("Error when opening %s\n", IPECC_DEV_UIO_PSEUDOTRNG);
				perror("open uio");
				*pseudotrng_base_addr_p = NULL;
				ret = -1;
				goto err;
			}
			uio_size = IPECC_PHYS_SZ;
			base_address = mmap(NULL, uio_size, PROT_READ | PROT_WRITE, MAP_SHARED, uio_fd1, 0);
			if(base_address == MAP_FAILED){
				printf("Error during mmap!\n");
				perror("mmap uio");
				*pseudotrng_base_addr_p = NULL;
				ret = -1;
				goto err;
			}
			(*pseudotrng_base_addr_p) = base_address;
		}
	}
#elif defined(WITH_EC_HW_DEVMEM)
	{
		int devmem_fd;
		unsigned int devmem_size;
		void *base_address;
		log_print("hw_driver_setup in /dev/mem mode\n");
		/* Open our /dev/mem device
		 * NOTE: O_SYNC here to avoid caching
		 */
		devmem_fd = open("/dev/mem", O_RDWR | O_SYNC);
		if(devmem_fd == -1){
			printf("Error when opening /dev/mem\n");
			perror("open devmem");
			ret = -1;
			goto err;
		}
		devmem_size = IPECC_PHYS_SZ;
		/* Map the main ECC IP */
		base_address = mmap(NULL, devmem_size, PROT_READ | PROT_WRITE, MAP_SHARED, devmem_fd, IPECC_PHYS_BADDR);
		if(base_address == MAP_FAILED){
			printf("Error during ECC IP mmap!\n");
			perror("mmap devmem ECC IP");
			ret = -1;
			goto err;
		}
		(*base_addr_p) = base_address;

		if (pseudotrng_base_addr_p != NULL) {

			/* Now handle the pseudo-TRNG device. If the device does not exist (e.g the IP
			 * was not synthesized in debug mode, then the device simply won't exist, in which
			 * case we set *pseudotrng_base_addr_p = NULL.
			 */
			devmem_size = IPECC_PHYS_SZ;
			/* Map the pseudo TRNG source device */
			base_address = mmap(NULL, devmem_size, PROT_READ | PROT_WRITE, MAP_SHARED, devmem_fd, IPECC_PHYS_PSEUDO_TRNG_BADDR);
			if(base_address == MAP_FAILED){
				printf("Error during pseudo TRNG device mmap!\n");
				perror("mmap devmem pseudo TRNG dev");
				*pseudotrng_base_addr_p = NULL;
				ret = -1;
				goto err;
			}
			(*pseudotrng_base_addr_p) = base_address;
		}
	}
#endif
	/* Log print in case of success */
	if ( (*pseudotrng_base_addr_p) != NULL ) {
		log_print("OK, loaded IP @%p and Pseudo TRNG source @%p\n", (*base_addr_p), (*pseudotrng_base_addr_p));
	} else {
		log_print("OK, loaded IP @%p\n", (*base_addr_p));
	}

	/* Is it a 'debug' or a 'production' version of the IP? */
	if (hw_driver_is_debug()) {
		hw_driver_debug_not_prod = 1;
		log_print("Debug mode (version %d.%d)\n", hw_driver_get_version_major(), hw_driver_get_version_minor());
		/* We must activate, in the TRNG, the pulling of raw random bytes by the
		 * post-processing function (as in debug mode it is disabled upon reset). */
		hw_driver_trng_post_proc_enable();
	} else {
		hw_driver_debug_not_prod = 0;
		log_print("Production mode.\n");
	}

	ret = 0;
err:
	return ret;
}

#else
/*
 * Dummy definition to avoid the empty translation unit ISO C warning
 */
typedef int dummy;
#endif /* WITH_EC_HW_ACCELERATOR */
