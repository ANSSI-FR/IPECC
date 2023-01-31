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

#if defined(WITH_EC_HW_ACCELERATOR) && !defined(WITH_EC_HW_SOCKET_EMUL)

/* The IP "physical" address in RAM.
 * This address should only be used for direct access in standalone
 * mode or using a physical memory access (e.g. through /dev/mem).
 */
#define IPECC_PHYS_BADDR                (0x40000000)
#define IPECC_PHYS_RST_BADDR            (0x40001000)
#define IPECC_PHYS_SZ                   (4096) /* One page size */

/* Setup the driver depending on the environment */
int hw_driver_setup(volatile unsigned char **base_addr_p, volatile unsigned char **reset_base_addr_p)
{
	int ret = -1;

	if((base_addr_p == NULL) || (reset_base_addr_p == NULL)){
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
		(*reset_base_addr_p) = (volatile unsigned char*)IPECC_PHYS_RST_BADDR;
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
		uio_fd0 = open("/dev/uio0", O_RDWR | O_SYNC);
		if(uio_fd0 == -1){
			printf("Error when opening /dev/uio0\n");
			perror("open uio");
			ret = -1;
			goto err;			      
		}
		uio_size = IPECC_PHYS_SZ;
		base_address = mmap(NULL, uio_size, PROT_READ | PROT_WRITE, MAP_SHARED, uio_fd0, 0);
		if(base_address == MAP_FAILED){
			printf("Error during mmap!\n");
			perror("mmap uio0");
			ret = -1;
			goto err;
		}
		(*base_addr_p) = base_address;
		/* Handle the reset IP */
		/* Open our UIO device				 
		 * NOTE: O_SYNC here to avoid caching	    
		 */
		uio_fd1 = open("/dev/uio1", O_RDWR | O_SYNC);
		if(uio_fd1 == -1){
			printf("Error when opening /dev/uio1\n");
			perror("open uio1");
			ret = -1;
			goto err;			      
		}
		uio_size = IPECC_PHYS_SZ;
		base_address = mmap(NULL, uio_size, PROT_READ | PROT_WRITE, MAP_SHARED, uio_fd1, 0);
		if(base_address == MAP_FAILED){
			printf("Error during mmap!\n");
			perror("mmap uio");
			ret = -1;
			goto err;
		}
		(*reset_base_addr_p) = base_address;
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
			printf("Error when opening /dev/devmem\n");
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
		devmem_size = IPECC_PHYS_SZ;
		/* Map the reset IP */
		base_address = mmap(NULL, devmem_size, PROT_READ | PROT_WRITE, MAP_SHARED, devmem_fd, IPECC_PHYS_RST_BADDR);
		if(base_address == MAP_FAILED){
			printf("Error during reset IP mmap!\n");
			perror("mmap devmem reset IP");
			ret = -1;
			goto err;
		}
		(*reset_base_addr_p) = base_address;
	}
#endif
	/* Log print in case of success */
	log_print("OK, loaded IP @%p and RESET @%p\n", (*base_addr_p), (*reset_base_addr_p));

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
