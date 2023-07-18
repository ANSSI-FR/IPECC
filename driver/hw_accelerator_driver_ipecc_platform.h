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

#ifndef __HW_ACCELERATOR_DRIVER_PLATFORM_H__
#define __HW_ACCELERATOR_DRIVER_PLATFORM_H__

#if defined(WITH_EC_HW_ACCELERATOR) && !defined(WITH_EC_HW_SOCKET_EMUL)

/* Hardware accelerator driver platform specific stuff.
 *
 * The physical address of the IP should be 0x40000000, but depending on
 * the OS/environment access method (standalone, Linux with /dev/mem, Linux with
 * UIO, etc.) this may change. Anyhow, the relative mapping of the registers should
 * remain fixed once this base address is known.
 */
#if defined(WITH_EC_HW_STANDALONE) && (defined(WITH_EC_HW_UIO) || defined(WITH_EC_HW_DEVMEM))
#error "WITH_EC_HW_STANDALONE, WITH_EC_HW_UIO and WITH_EC_HW_DEVMEM are mutually exclusive!"
#endif
#if defined(WITH_EC_HW_UIO) && (defined(WITH_EC_HW_STANDALONE) || defined(WITH_EC_HW_DEVMEM))
#error "WITH_EC_HW_STANDALONE, WITH_EC_HW_UIO and WITH_EC_HW_DEVMEM are mutually exclusive!"
#endif
#if defined(WITH_EC_HW_DEVMEM) && (defined(WITH_EC_HW_UIO) || defined(WITH_EC_HW_STANDALONE))
#error "WITH_EC_HW_STANDALONE, WITH_EC_HW_UIO and WITH_EC_HW_DEVMEM are mutually exclusive!"
#endif
#if !defined(WITH_EC_HW_STANDALONE) && !defined(WITH_EC_HW_UIO) && !defined(WITH_EC_HW_DEVMEM)
#error "One of WITH_EC_HW_STANDALONE, WITH_EC_HW_UIO or WITH_EC_HW_DEVMEM must be set for the driver!"
#endif

#if defined(WITH_EC_HW_UIO) || defined(WITH_EC_HW_DEVMEM)    
#include <stdio.h>
#include <unistd.h>                               
#include <fcntl.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>
#endif

#if defined(WITH_EC_HW_STANDALONE)
#include <stddef.h>
#endif

/* Log handling on the platform
 * (usually printf, adapt)
 */
#if defined(WITH_EC_HW_DEBUG)
#include <stdio.h>
#define log_print(...) printf(__VA_ARGS__)
#else
#define log_print(...)
#endif

/* Setup the driver depending on the environment,
 * and set the base address of the driver mapping.
 */
int hw_driver_setup(volatile unsigned char **base_addr_p, volatile unsigned char **reset_base_addr_p);

#endif /* WITH_EC_HW_ACCELERATOR */

#endif /* __HW_ACCELERATOR_DRIVER_PLATFORM_H__ */
