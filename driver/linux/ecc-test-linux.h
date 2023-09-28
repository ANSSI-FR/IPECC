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

#include "../hw_accelerator_driver.h"

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#if defined(WITH_EC_HW_UIO) || defined(WITH_EC_HW_DEVMEM)    
#include <unistd.h>                               
#include <fcntl.h>
#include <stdlib.h>
#include <error.h>
#include <errno.h>
#endif

#if defined(WITH_EC_HW_STANDALONE)
#include <stddef.h>
#endif

/*
 * To help parsing the input file/stream.
 */
typedef enum {
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
} line_t;

/*
 * Operations on curve points supported by the driver.
 */
typedef enum {
	OP_NONE = 0,
	OP_KP = 1,
	OP_PTADD = 2,
	OP_PTDBL = 3,
	OP_PTNEG = 4,
	OP_TST_CHK = 5,
	OP_TST_EQU = 6,
	OP_TST_OPP = 7,
} operation_t;

#define NBMAXSZ   1024

/*
 * Large number type
 */
typedef struct {
	uint8_t val[NBMAXSZ];
	uint32_t sz;
	bool valid;
} large_number_t;

/*
 * Type for curve parameters
 */
typedef struct {
	uint32_t nn;
	large_number_t p;
	large_number_t a;
	large_number_t b;
	large_number_t q;
	uint32_t id;
	bool valid;
	bool set_in_hw;
} curve_t;

/*
 * Type for point defition.
 */
typedef struct {
	large_number_t x;
	large_number_t y;
	bool is_null;
	bool valid;
} point_t;

/* Type for driver tests made on points
 * (are they equal? are they opposite? are they on curve?)
 */
typedef struct {
	bool answer;
	bool valid;
} pttest_t;

/*
 * Type for statistics on tests passed to the driver.
 */
typedef struct {
	uint32_t ok;
	uint32_t nok;
	uint32_t total;
} stats_t;

typedef struct {
	stats_t kp;
	stats_t ptadd;
	stats_t ptdbl;
	stats_t ptneg;
	stats_t test_equ;
	stats_t test_opp;
	stats_t test_crv;
	stats_t all;
	uint32_t nn_min;
	uint32_t nn_max;
	uint32_t nn_avr;
	uint32_t nbcurves;
} all_stats_t;

/*
 * Gereral type for tests passed to the driver.
 */
typedef struct {
	curve_t* curve;
	point_t ptp;
	point_t ptq;
	large_number_t k;
	/* sw_res & hw_res are overloaded for the different
	 * types of driver/IP operations. */
	point_t pt_sw_res;
	point_t pt_hw_res;
	uint32_t blinding;
	/* sw_answer & hw_answer are overloaded for the different
	 * types of driver/IP operations. */
	pttest_t sw_answer;
	pttest_t hw_answer;
	operation_t op;
	bool is_an_exception;
	uint32_t id;
	kp_trace_info_t *ktrc;
} ipecc_test_t;

/*
 * DIV(i, s) returns the number of s-bit limbs required to encode
 * an i-bit number.
 */
#define DIV(i, s) \
	((i) % (s) ? (i) / (s) + 1 : (i) / (s))

/*
 * NN_SZ(nn) returns the number of bytes that a large number supposed
 * to be of size 'nn' bits should occupy at most.
 */
#define NN_SZ(nn)  DIV((nn), 8)

#define INIT_LARGE_NUMBER() \
	{ .sz = 0, .valid = false }

#define INIT_POINT() \
	{ .x = INIT_LARGE_NUMBER(), \
		.y = INIT_LARGE_NUMBER(), \
		.valid = false }

#define INIT_CURVE() \
	{ .p = INIT_LARGE_NUMBER(), \
		.a = INIT_LARGE_NUMBER(), \
		.b = INIT_LARGE_NUMBER(), \
		.q = INIT_LARGE_NUMBER(), \
		.id = 0, \
		.set_in_hw = false, \
		.valid = false }

#define INIT_PTTEST() \
	{ .valid = false }

#define UNVALID_LARGE_NUMBER(l) do { \
	(l).sz = 0; (l).valid = false; \
} while (0)

#define UNVALID_POINT(p)  do { \
	UNVALID_LARGE_NUMBER((p).x); UNVALID_LARGE_NUMBER((p).y); (p).valid = false; \
} while (0)

#define UNVALID_CURVE(c) do { \
	(c).nn = 0; \
	UNVALID_LARGE_NUMBER((c).p); \
	UNVALID_LARGE_NUMBER((c).a); \
	UNVALID_LARGE_NUMBER((c).b); \
	UNVALID_LARGE_NUMBER((c).q); \
	(c).set_in_hw = false; \
	(c).valid = false; \
} while (0)

#define UNVALID_PTTEST(t) do { \
	(t).valid = false; \
} while (0)

#define INT_TO_BOOLEAN(i)   ((i) ? true : false)

#define DISPLAY_MODULO  10

#ifdef VERBOSE
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...) ((void)0)
#endif

#endif /* __TEST_DRIVER_H__ */
