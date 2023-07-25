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

#ifndef __TEST_DRIVER_H__
#define __TEST_DRIVER_H__

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <errno.h>
#include <stdint.h>
#include <stdbool.h>

#define NBMAXSZ   1024

/*
 * type for curve parameters
 */
struct curve_t
{
	uint32_t nn;
	uint8_t p[NBMAXSZ];
	uint32_t p_sz;
	uint8_t a[NBMAXSZ];
	uint32_t a_sz;
	uint8_t b[NBMAXSZ];
	uint32_t b_sz;
	uint8_t q[NBMAXSZ];
	uint32_t q_sz;
	bool valid;
};

/*
 * type for point defition
 */
struct point_t
{
	uint8_t x[NBMAXSZ];
	uint32_t x_sz;
	uint8_t y[NBMAXSZ];
	uint32_t y_sz;
	bool is_null;
	bool valid;
};

enum line_type {
	EXPECT_NONE = 0,
	EXPECT_CURVE = 1,
	EXPECT_NN = 2,
	EXPECT_P = 3,
	EXPECT_A = 4,
	EXPECT_B = 5,
	EXPECT_Q = 6,
	EXPECT_PX = 7,
	EXPECT_PY = 8,
	EXPECT_QX = 9,
	EXPECT_QY = 10,
	EXPECT_K = 11,
	EXPECT_KPX_OR_BLD = 12,
	EXPECT_KPY = 13,
	EXPECT_P_PLUS_QX = 14,
	EXPECT_P_PLUS_QY = 15,
	EXPECT_TWOP_X = 16,
	EXPECT_TWOP_Y = 17,
	EXPECT_NEGP_X = 18,
	EXPECT_NEGP_Y = 19,
	EXPECT_TRUE_OR_FALSE = 20
};

enum operation_type {
	OP_NONE = 0,
	OP_KP = 1,
	OP_PTADD = 2,
	OP_PTDBL = 3,
	OP_PTNEG = 4,
	OP_TST_CHK = 5,
	OP_TST_EQU = 6,
	OP_TST_OPP = 7
};

struct pt_test_t {
	bool sw_answer;
	bool sw_valid;
	bool hw_answer;
	bool hw_valid;
};

struct stats_t {
	uint32_t ok;
	uint32_t nok;
	uint32_t total;
};

#define TERM_COLORS

#ifdef TERM_COLORS
#define KNRM  "\x1B[0m"
#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"
#define KYEL  "\x1B[33m"
#define KBLU  "\x1B[34m"
#define KMAG  "\x1B[35m"
#define KCYN  "\x1B[36m"
#define KWHT  "\x1B[37m"
#else
#define KNRM  ""
#define KRED  ""
#define KGRN  ""
#define KYEL  ""
#define KBLU  ""
#define KMAG  ""
#define KCYN  ""
#define KWHT  ""
#endif /* TERM_COLORS */

#define KERR  KCYN

#define DISPLAY_MODULO  1000

#ifdef VERBOSE
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...) ((void)0)
#endif

#endif /* __TEST_DRIVER_H__ */
