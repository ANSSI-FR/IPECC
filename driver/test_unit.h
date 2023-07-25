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

#ifndef __TEST_UNIT_H__
#define __TEST_UNIT_H__

#include "hw_accelerator_driver.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>

/* Our basic test structure */
typedef struct {
	const char *name;
	const unsigned char *p;
	unsigned int p_sz;
	const unsigned char *q;
	unsigned int q_sz;
	const unsigned char *a;
	unsigned int a_sz;
	const unsigned char *b;
	unsigned int b_sz;
	const unsigned char *Px;
	unsigned int Px_sz;
	const unsigned char *Py;
	unsigned int Py_sz;
	const unsigned char *Qx;
	unsigned int Qx_sz;
	const unsigned char *Qy;
	unsigned int Qy_sz;
	const unsigned char *k;
	unsigned int k_sz;
#if 0
	const unsigned char *Outx;
	unsigned int Outx_sz;
	const unsigned char *Outy;
	unsigned int Outy_sz;
#endif
	unsigned int nn_sz;
	unsigned int small_scal_sz;
	unsigned int blinding;
	ip_ecc_command cmd;     
} ipecc_test;

/* NULL values */
#define BIG_XNULL NULL
#define BIG_YNULL NULL

#define IPECC_TEST_VECTOR_NOQ(n, suffix, p_suffix, scalar, nn_sz_, small_scal_sz_, blinding_, cmd_) \
	{ .name = n, .p = BIG_##P##suffix, .p_sz = sizeof(BIG_##P##suffix), .a = BIG_##A##suffix, .a_sz = sizeof(BIG_##A##suffix), .b = BIG_##B##suffix, .b_sz = sizeof(BIG_##B##suffix), .q = BIG_##Q##suffix, .q_sz = sizeof(BIG_##Q##suffix), .Px = BIG_##X##p_suffix, .Px_sz = sizeof(BIG_##X##p_suffix), .Py = BIG_##Y##p_suffix, .Py_sz = sizeof(BIG_##Y##p_suffix), .Qx = NULL, .Qx_sz = 0, .Qy = NULL, .Qy_sz = 0, .k = scalar, .k_sz = sizeof(scalar), .nn_sz = nn_sz_, .small_scal_sz = small_scal_sz_, .blinding = blinding_, .cmd = cmd_ }

#define IPECC_TEST_VECTOR_Q(n, suffix, p_suffix, q_suffix, scalar, nn_sz_, small_scal_sz_, blinding_, cmd_) \
	{ .name = n, .p = BIG_##P##suffix, .p_sz = sizeof(BIG_##P##suffix), .a = BIG_##A##suffix, .a_sz = sizeof(BIG_##A##suffix), .b = BIG_##B##suffix, .b_sz = sizeof(BIG_##B##suffix), .q = BIG_##Q##suffix, .q_sz = sizeof(BIG_##Q##suffix), .Px = BIG_##X##p_suffix, .Px_sz = sizeof(BIG_##X##p_suffix), .Py = BIG_##Y##p_suffix, .Py_sz = sizeof(BIG_##Y##p_suffix), .Qx = BIG_##X##q_suffix, .Qx_sz = sizeof(BIG_##X##q_suffix), .Qy = BIG_##Y##q_suffix, .Qy_sz = sizeof(BIG_##Y##q_suffix), .k = scalar, .k_sz = sizeof(scalar), .nn_sz = nn_sz_, .small_scal_sz = small_scal_sz_, .blinding = blinding_, .cmd = cmd_ }

#define SIZE_24_BITS	32
#define SIZE_127_BITS	127
#define SIZE_FULL	0

#endif /* __TEST_UNIT_H__ */
