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

#include "hw_accelerator_driver.h"
//#include "test_unit.h"
#include "test_driver.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

//extern int test_unit(ipecc_test*);

//static ipecc_test test;

char* line = NULL;

#define max(a,b) do { \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; }) \
 while (0)

static bool line_is_empty(char *l)
{
	uint32_t c;
	bool ret = true;
	for (c=0; ;c++) {
		if ((l[c] == '\r') || (l[c] == '\n')) {
			break;
		} else if ((l[c] != ' ') && (l[c] != '\t')) {
			ret = false;
			break;
		}
	}
	return ret;
}

static void print_stats_and_exit(struct stats_t* s)
{
	printf("OK = %d\n", s->ok);
	printf("nOK = %d\n", s->nok);
	printf("total = %d\n", s->total);
	printf("--\n");
	free(line);
	exit(EXIT_FAILURE);
}

/*
 * convert an hexadecimal digit to integer
 */
static uint8_t hex2dec(char c)
{
	if ( (c >= 'a') && (c <= 'f') ) {
		return c - 'a' + 10;
	} else if ( (c >= 'A') && (c <= 'F') ) {
		return c - 'A' + 10;
	}
	return c - '0';
}

/*
 * Extract an hexadecimal string (without the 0x) from a position in a line 
 * (pointed to by parameter 'pc') convert it in binary form and fill buffer
 * 'nb_x' with it, parsing exactly 'nbchar' characters.
 *
 * Also set the size (in bytes) of the output buffer.
 */
static void hex_to_large_num(char *pc, unsigned char* nb_x, unsigned int *nb_x_sz, ssize_t nbchar)
{
	int i, j;

	/* Clear content of nb_x. */
	for (j=0; j<NBMAXSZ; j++) {
		nb_x[j] = 0;
	}
	/* Format bytes of large number; */
	j = 0;
	for (i = nbchar - 1 ; i>=0 ; i--) {
		nb_x[j / 2] += hex2dec(pc[i]) * (0x1U << (4*(j % 2)));
		j++;
	}
	/* Set the size of the number */
	*nb_x_sz = (unsigned int)(((j % 2) == 0) ? (j/2) : (j/2) + 1);
}

int main(int argc, char *argv[])
{
	int ret;
	uint32_t i;
	enum line_type line_type_expected;
	size_t len = 0;
	ssize_t nread;
	bool test_is_an_exception = false;
	uint32_t nbcurve, nbtest;
	enum operation_type op;
	uint32_t nbbld;

	(void)argc;
	(void)argv;

	/* Curve definition */
	struct curve_t curve;
	/* Intput points coords & scalar (part of input test vector) */
	struct point_t p;
	struct point_t q;
	uint8_t nb_k[NBMAXSZ];
	uint32_t nb_k_sz;
	/* Output points (part of input test vector) */
	struct point_t sw_kp;
	struct point_t sw_pplusq;
	struct point_t sw_twop;
	struct point_t sw_negp;
	/* Output points (computed by hardware) */
	struct point_t hw_kp;
	struct point_t hw_pplusq;
	struct point_t hw_twop;
	struct point_t hw_negp;
	/* Tests metadata */
	struct pt_test_t tst_chk;
	struct pt_test_t tst_equ;
	struct pt_test_t tst_opp;
	/* scalar (k in [k]P) */
	bool k_valid;
	/* statistics (nb of passed tests, nb of errors, etc) */
	struct stats_t stats;

	/* init some flags */
	/* curve validity */
	curve.valid = 0;
	/* points validity */
	p.valid = false;
	q.valid = false;
	sw_pplusq.valid = false;
	hw_pplusq.valid = false;
	sw_kp.valid = false;
	hw_kp.valid = false;
	sw_twop.valid = false;
	hw_twop.valid = false;
	sw_negp.valid = false;
	hw_negp.valid = false;
	/* tests validity */
	tst_chk.sw_valid = false;
	tst_chk.hw_valid = false;
	tst_equ.sw_valid = false;
	tst_equ.hw_valid = false;
	tst_opp.sw_valid = false;
	tst_opp.hw_valid = false;
	op = OP_NONE;
	/* stats */
	stats.ok = 0;
	stats.nok = 0;
	stats.total = 0;
	/* scalar for [k]P */
	k_valid = false;


	printf("Welcome to the IPECC extensive test tool!\n");

	/* Main infinite loop, parsing lines from standard input to extract:
	 *   - input vectors
	 *   - type of operation
	 *   - expected result,
	 * then have the same computation done by hardware, and then check
	 * the result of hardware against the expected one.
	 */
	line_type_expected = EXPECT_NONE;
	while (((nread = getline(&line, &len, stdin))) != -1) {
		/*
		 * Allow comment lines starting with #
		 * (simply assert exception flag if it starts with "# EXCEPTION"
		 * because in this case this comment is meaningful).
		 */
		if (line[0] == '#') {
			if ( (strncmp(line, "# EXCEPTION", strlen("# EXCEPTION"))) == 0 ) {
				test_is_an_exception = true;
			}
			continue;
		}
		/*
		 * Allow empty lines
		 */
		if (line_is_empty(line) == true) {
			continue;
		}
		/*
		 * Process line according to some kind of finite state
		 * machine or input vector test format
		 */
		switch (line_type_expected) {

			case EXPECT_NONE:{
				/*
				 * Parse line.
				 */
				if ( (strncmp(line, "NEW CURVE #", strlen("NEW CURVE #"))) == 0 ) {
					/*
					 * Extract the curve nb, after '#' character.
					 */
					nbcurve = atoi(line + strlen("NEW CURVE #")); /* NEW CURVE #x */
					line_type_expected = EXPECT_NN;
					curve.valid = false;
				} else if ( (strncmp(line, "== TEST [k]P #", strlen("== TEST [k]P #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST [k]P #") + i) == '.') {
							*(line + strlen("== TEST [k]P #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("== TEST [k]P #") + i + 1);
					op = OP_KP;
					p.valid = false;
					k_valid = false;
					sw_kp.valid = false;
					hw_kp.valid = false;
					line_type_expected = EXPECT_PX;
					/*
					 * Blinding will be applied only if test file says so
					 * (otherwise default is no blinding).
					 */
					nbbld = 0;
				} else if ( (strncmp(line, "P+Q #", strlen("P+Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("P+Q #") + i) == '.') {
							*(line + strlen("P+Q #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("P+Q #") + i + 1);
					op = OP_PTADD;
					p.valid = false;
					q.valid = false;
					sw_pplusq.valid = false;
					hw_pplusq.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "[2]P #", strlen("[2]P #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("[2]P #") + i) == '.') {
							*(line + strlen("[2]P #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("[2]P #") + i + 1);
					op = OP_PTDBL;
					p.valid = false;
					sw_twop.valid = false;
					hw_twop.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "-P #", strlen("-P #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("-P #") + i) == '.') {
							*(line + strlen("-P #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("-P #") + i + 1);
					op = OP_PTNEG;
					p.valid = false;
					sw_negp.valid = false;
					hw_negp.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "isPoncurve #", strlen("isPoncurve #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("isPoncurve #") + i) == '.') {
							*(line + strlen("isPoncurve #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("isPoncurve #") + i + 1);
					op = OP_TST_CHK;
					p.valid = false;
					tst_chk.sw_valid = false;
					tst_chk.hw_valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "isP==Q #", strlen("isP==Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("isP==Q #") + i) == '.') {
							*(line + strlen("isP==Q #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("isP==Q #") + i + 1);
					op = OP_TST_EQU;
					p.valid = false;
					q.valid = false;
					tst_equ.sw_valid = false;
					tst_equ.hw_valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "isP==-Q #", strlen("isP==-Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("isP==-Q #") + i) == '.') {
							*(line + strlen("isP==-Q #") + i) = '\0';
							break;
						}
					}
					nbtest = atoi(line + strlen("isP==-Q #") + i + 1);
					op = OP_TST_OPP;
					p.valid = false;
					q.valid = false;
					tst_opp.sw_valid = false;
					tst_opp.hw_valid = false;
					line_type_expected = EXPECT_PX;
				} else {
					printf("%sERROR: could not find any of the expected command "
							"(for debug: while in state EXPECT_NONE)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_NN:{
				/*
				 * Parse line to extract value of nn
				 */
				if ( (strncmp(line, "nn=", strlen("nn="))) == 0 )
				{
					curve.nn = atoi(&line[3]);
					line_type_expected = EXPECT_P;
				} else {
					printf("%sERROR: could not find the expected token \"nn=\" "
							"(for debug: while in state EXPECT_NN)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_P:{
				/* Parse line to extract value of p */
				if ( (strncmp(line, "p=0x", strlen("p=0x"))) == 0 ) {
					PRINTF("%sp=0x%s%s", KWHT, line + strlen("p=0x"), KNRM);
					/*
					 * Process the hexadecimal value of p to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("p=0x"), curve.p, &curve.p_sz, nread - strlen("p=0x"));
					line_type_expected = EXPECT_A;
				} else {
					printf("%sERROR: could not find the expected token \"p=0x\" "
							"(for debug: while in state EXPECT_P)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_A:{
				/* Parse line to extract value of a */
				if ( (strncmp(line, "a=0x", strlen("a=0x"))) == 0 ) {
					PRINTF("%sa=0x%s%s", KWHT, line + strlen("a=0x"), KNRM);
					/*
					 * Process the hexadecimal value of a to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("a=0x"), curve.a, &curve.a_sz, nread - strlen("a=0x"));
					line_type_expected = EXPECT_B;
				} else {
					printf("%sERROR: could not find the expected token \"a=0x\" "
							"(for debug: while in state EXPECT_A)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_B:{
				/* Parse line to extract value of b/ */
				if ( (strncmp(line, "b=0x", strlen("b=0x"))) == 0 ) {
					PRINTF("%sb=0x%s%s", KWHT, line + strlen("b=0x"), KNRM);
					/*
					 * Process the hexadecimal value of b to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("b=0x"), curve.b, &curve.b_sz, nread - strlen("b=0x"));
					line_type_expected = EXPECT_Q;
				} else {
					printf("%sERROR: could not find the expected token \"b=0x\" "
							"(for debug: while in state EXPECT_B)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_Q:{
				/* Parse line to extract value of q. */
				if ( (strncmp(line, "q=0x", strlen("q=0x"))) == 0 )
				{
					PRINTF("%sq=0x%s%s", KWHT, line + strlen("q=0x"), KNRM);
					/*
					 * Process the hexadecimal value of q to create the list
					 * of bytes to transfer to the IP (also set the size of
					 * the number).
					 */
					hex_to_large_num(
							line + strlen("q=0x"), curve.q, &curve.q_sz, nread - strlen("q=0x"));
					/*
					 * Transfer curve parameters to the IP.
					 */
					ip_set_pt_and_run_kp(curve.nn, &p, &hw_kp, nb_k, nbbld, &err_flags);
					//ret = hw_driver_set_curve(test.a, test.a_sz, test.b, test.b_sz, test.p, test.p_sz, test.q, test.q_sz);
					if (ret) {
						printf("%sERROR: could not transmit curve parameters (NEW CURVE %d)%s\n", KERR, nbcurve, KNRM);
						print_stats_and_exit(&stats);
					} else {
						curve.valid = true;
					}
					line_type_expected = EXPECT_NONE;
				} else {
					printf("%sERROR: could not find the expected token \"q=0x\" "
							"(for debug: while in state EXPECT_Q)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_PX:{
				/* Parse line to extract value of Px */
				if ( (strncmp(line, "Px=0x", strlen("Px=0x"))) == 0 ) {
					PRINTF("%sPx=0x%s%s", KWHT, line + strlen("Px=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Px to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("Px=0x"), p.x, , &p.x_sz, nread - strlen("Px=0x"));
					/*
					 * Position point P not to be null
					 */
					p.is_null = false;
					line_type_expected = EXPECT_PY;
				} else if ( (strncmp(line, "P=0", strlen("P=0"))) == 0 ) {
					PRINTF("%sP=0%s\n", KWHT, KNRM);
					/*
					 * Position point P to be null
					 */
					p.is_null = true;
					p.valid = true;
					/*
					 * The unit test API expects two null-dereferencing coordinate-pointers
					 * as identifying a zero point (aka point at infinity).
					 */
					test.Px = NULL;
					test.Py = NULL;
					if (op == OP_KP) {
						line_type_expected = EXPECT_K;
					} else if (op == OP_PTADD) {
						line_type_expected = EXPECT_QX;
					} else if (op == OP_PTDBL) {
						line_type_expected = EXPECT_TWOP_X;
					} else if (op == OP_PTNEG) {
						line_type_expected = EXPECT_NEGP_X;
					} else if (op == OP_TST_CHK) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if ((op == OP_TST_EQU) || (op == OP_TST_OPP)) {
						line_type_expected = EXPECT_QX;
					}
				} else {
					printf("%sERROR: could not find one of the expected tokens \"Px=0x\" "
							"or \"P=0\" (for debug: while in state EXPECT_PX)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_PY:{
				/* Parse line to extract value of Py */
				if ( (strncmp(line, "Py=0x", strlen("Py=0x"))) == 0 ) {
					PRINTF("%sPy=0x%s%s", KWHT, line + strlen("Py=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Py to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("Py=0x"), p.y &p.y_sz, nread - strlen("Py=0x"));
					p.valid = true;
					if (op == OP_KP) {
						line_type_expected = EXPECT_K;
					} else if (op == OP_PTADD) {
						line_type_expected = EXPECT_QX;
					} else if (op == OP_PTDBL) {
						line_type_expected = EXPECT_TWOP_X;
					} else if (op == OP_PTNEG) {
						line_type_expected = EXPECT_NEGP_X;
					} else if (op == OP_TST_CHK) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if ((op == OP_TST_EQU) || (op == OP_TST_OPP)) {
						line_type_expected = EXPECT_QX;
					}
				} else {
					printf("%sERROR: could not find the expected token \"Py=0x\" "
							"(for debug: while in state EXPECT_PY)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_QX:{
				/* Parse line to extract value of Qx */
				if ( (strncmp(line, "Qx=0x", strlen("Qx=0x"))) == 0 ) {
					PRINTF("%sQx=0x%s%s", KWHT, line + strlen("Qx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Qx to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("Qx=0x"), q.x, &q.x_sz, nread - strlen("Qx=0x"));
					/*
					 * position point Q not to be null
					 */
					q.is_null = false;
					line_type_expected = EXPECT_QY;
				} else if ( (strncmp(line, "Q=0", strlen("Q=0"))) == 0 ) {
					PRINTF("%sQ=0%s\n", KWHT, KNRM);
					/*
					 * position point Q to be null
					 */
					q.is_null = true;
					/*
					 * The unit test API expects two null-dereferencing coordinate-pointers
					 * as identifying a zero point (aka point at infinity).
					 */
					test.Qx = NULL;
					test.Qy = NULL;
					q.valid = true;
					if (op == OP_PTADD) {
						line_type_expected = EXPECT_P_PLUS_QX;
					} else if (op == OP_TST_EQU) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if (op == OP_TST_OPP) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					}
				} else {
					printf("%sERROR: could not find one of the expected tokens \"Qx=0x\" "
							"or \"Q=0\" (for debug: while in state EXPECT_QX)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_QY:{
				/*
				 * Parse line to extract value of Py.
				 */
				if ( (strncmp(line, "Qy=0x", strlen("Qy=0x"))) == 0 ) {
					PRINTF("%sQy=0x%s%s", KWHT, line + strlen("Qy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Py to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("Qy=0x"), q.y, &q.y_sz, nread - strlen("Qy=0x"));
					q.valid = true;
					if (op == OP_PTADD) {
						line_type_expected = EXPECT_P_PLUS_QX;
					} else if (op == OP_TST_EQU) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if (op == OP_TST_OPP) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					}
				} else {
					printf("%sERROR: could not find the expected token \"Qy=0x\" "
							"(for debug: while in state EXPECT_QY)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_K:{
				/*
				 * Parse line to extract value of k.
				 */
				if ( (strncmp(line, "k=0x", strlen("k=0x"))) == 0 ) {
					PRINTF("%sk=0x%s%s", KWHT, line + strlen("k=0x"), KNRM);
					/*
					 * Process the hexadecimal value of k to create the list
					 * of 32-bit limbs to transfer to the IP.
					 */
					hex_to_large_num(
							line + strlen("k=0x"), nb_k, &nb_k_sz, nread - strlen("k=0x"));
					k_valid = true;
					line_type_expected = EXPECT_KPX_OR_BLD;
				} else {
					printf("%sERROR: could not find the expected token \"k=0x\" "
							"(for debug: while in state EXPECT_K)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_KPX_OR_BLD:{
				/*
				 * Parse line to extract possible nb of blinding bits.
				 * */
				if ( (strncmp(line, "nbbld=", strlen("nbbld="))) == 0 ) {
					PRINTF("%snbbld=%s%s", KWHT, line + strlen("nbbld="), KNRM);
					nbbld = atoi(line + strlen("nbbld="));
					/* keep line_type_expected to EXPECT_KPX_OR_BLD to parse point P */
				} else if ( (strncmp(line, "kPx=0x", strlen("kPx=0x"))) == 0 ) {
					PRINTF("%skPx=0x%s%s", KWHT, line + strlen("kPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of kPx for comparison with HW.
					 */
					hex_to_large_num(
							line + strlen("kPx=0x"), sw_kp.x, &sw_kp.x_sz, nread - strlen("kPx=0x"));
					/*
					 * record that expected result point [k]P should not be null.
					 */
					sw_kp.is_null = false;
					line_type_expected = EXPECT_KPY;
				} else if ( (strncmp(line, "kP=0", strlen("kP=0"))) == 0 ) {
					PRINTF("%sexpected result point [k]P = 0%s\n", KWHT, KNRM);
					/*
					 * record that expected result point [k]P should be null.
					 */
					sw_kp.is_null = true;
					sw_kp.valid = true;
					/*
					 * Set and execure a [k]P computation test.
					 */
					test.name = "";
					test.p = curve.p;
					test.p_sz = curve.p_sz;
					test.a = curve.a;
					test.a_sz = curva.a_sz;
					test.b = curve.b;
					test.b_sz = curve.b_sz;
					test.q = curve.q;
					test.q_sz = curve.q_sz;
					test.Px = sw_kp.x;
					test.Px_sz = sw_kp.x_sz;
					test.Py = sw_kp.y;
					test.Py_sz = sw_kp.y_sz;
					test.k = nb_k;
					test.k_sz = nb_k_sz;
					test.nn_sz = max(curve.p_sz, curve.q_sz);
					test.blinding = 0;
					test.cmd = PT_KP;
					test.small_scal_sz = 0;
					test_unit(&test);
					//ip_set_pt_and_run_kp(curve.nn, &p, &hw_kp, nb_k, nbbld, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & STATUS_ERR_IN_PT_NOT_ON_CURVE) {
						printf("ERROR: input point IS NOT on curve\n");
					}
					if (err_flags & STATUS_ERR_OUT_PT_NOT_ON_CURVE) {
						printf("ERROR: output point IS NOT on curve\n");
					}
					/*
					 * check IP result against the one given by client
					 *   (software client said kP should be null)
					 */
					check_kp_result(&curve, &p, &hw_kp, &sw_kp, nb_k, nbbld, &stats);
					/*
					 * stats
					 */
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find one of the expected tokens \"nbbld=\" "
							"or \"kPx=0x\" or \"kP=0\" (for debug: while in state EXPECT_KPX_OR_BLD)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

#if 0
			case EXPECT_KPY:{
				/* Parse line to extract value of [k]Py (y of result) */
				if ( (strncmp(line, "kPy=0x", strlen("kPy=0x"))) == 0 ) {
					PRINTF("%skPy=0x%s%s", KWHT, line + strlen("kPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of kPy for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("kPy=0x"), sw_kp.y, nread - strlen("kPy=0x"));
					sw_kp.valid = true;
					/***************************
					 * do a [k]P COMPUTATION NOW
					 ***************************/
					/*
					 * transfer point & scalar to the IP.
					 */
					ip_set_pt_and_run_kp(curve.nn, &p, &hw_kp, nb_k, nbbld, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & STATUS_ERR_IN_PT_NOT_ON_CURVE) {
						printf("ERROR: input point IS NOT on curve\n");
					}
					if (err_flags & STATUS_ERR_OUT_PT_NOT_ON_CURVE) {
						printf("ERROR: output point IS NOT on curve\n");
					}
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * check IP result against the one given by client
					 */
					check_kp_result(&curve, &p, &hw_kp, &sw_kp, nb_k, nbbld, &stats);
					/*
					 * stats
					 */
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find the expected token \"kPy=0x\" "
							"(for debug: while in state EXPECT_KPY)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_P_PLUS_QX:{
				/*
				 * Parse line to extract value of (P+Q).x
				 */
				if ( (strncmp(line, "PplusQx=0x", strlen("PplusQx=0x"))) == 0 ) {
					PRINTF("%s(P+Q)x=0x%s%s", KWHT, line + strlen("PplusQx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of (P+Q).x for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("PplusQx=0x"), sw_pplusq.x, nread - strlen("PplusQx=0x"));
					sw_pplusq.is_null = false;
					line_type_expected = EXPECT_P_PLUS_QY;
				} else if ( (strncmp(line, "PplusQ=0", strlen("PplusQ=0"))) == 0 ) {
					PRINTF("%s(P+Q)=0%s\n", KWHT, KNRM);
					sw_pplusq.is_null = true;
					sw_pplusq.valid = true;
					/*****************
					 * do a PT_ADD NOW
					 *****************/
					/*
					 * transfer points to add to the IP and run PT_ADD command
					 */
					ip_set_pts_and_run_ptadd(curve.nn, &p, &q, &hw_pplusq, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptadd_result(&curve, &p, &q, &sw_pplusq, &hw_pplusq, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find one of the expected tokens \"PplusQx=0x\" "
							"or \"(P+Q)=0\" (for debug: while in state EXPECT_P_PLUS_QX)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_P_PLUS_QY:{
				/*
				 * Parse line to extract value of (P+Q).y
				 */
				if ( (strncmp(line, "PplusQy=0x", strlen("PplusQy=0x"))) == 0 ) {
					PRINTF("%s(P+Q)y=0x%s%s", KWHT, line + strlen("PplusQy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of (P+Q).y for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("PplusQy=0x"), sw_pplusq.y, nread - strlen("PplusQx=0x"));
					sw_pplusq.valid = true;
					/*****************
					 * do a PT_ADD NOW
					 *****************/
					/*
					 * transfer points to add to the IP and run PT_ADD command
					 */
					ip_set_pts_and_run_ptadd(curve.nn, &p, &q, &hw_pplusq, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptadd_result(&curve, &p, &q, &sw_pplusq, &hw_pplusq, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find the expected token \"PplusQy=0x\" "
							"(for debug: while in state EXPECT_P_PLUS_QY)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_TWOP_X:{
				/*
				 * Parse line to extract value of [2]P.x
				 */
				if ( (strncmp(line, "twoPx=0x", strlen("twoPx=0x"))) == 0 ) {
					PRINTF("%s[2]P.x=0x%s%s", KWHT, line + strlen("twoPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of [2]P.x for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("twoPx=0x"), sw_twop.x, nread - strlen("twoPx=0x"));
					sw_twop.is_null = false;
					line_type_expected = EXPECT_TWOP_Y;
				} else if ( (strncmp(line, "twoP=0", strlen("twoP=0"))) == 0 ) {
					PRINTF("%s[2]P=0%s\n", KWHT, KNRM);
					sw_twop.is_null = true;
					sw_twop.valid = true;
					/*****************
					 * do a PT_DBL NOW
					 *****************/
					/*
					 * transfer point to double to the IP and run PT_DBL command
					 */
					ip_set_pt_and_run_ptdbl(curve.nn, &p, &hw_twop, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptdbl_result(&curve, &p, &sw_twop, &hw_twop, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find one of the expected tokens \"twoPx=0x\" "
							"or \"twoP=0\" (for debug: while in state EXPECT_TWOP_X)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_TWOP_Y:{
				/*
				 * Parse line to extract value of [2]P.y
				 */
				if ( (strncmp(line, "twoPy=0x", strlen("twoPy=0x"))) == 0 ) {
					PRINTF("%s[2]P.y=0x%s%s", KWHT, line + strlen("twoPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of [2]P.y for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("twoPy=0x"), sw_twop.y, nread - strlen("twoPy=0x"));
					sw_twop.valid = true;
					/*****************
					 * do a PT_DBL NOW
					 *****************/
					/*
					 * transfer point to double to the IP and run PT_DBL command
					 */
					ip_set_pt_and_run_ptdbl(curve.nn, &p, &hw_twop, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptdbl_result(&curve, &p, &sw_twop, &hw_twop, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find the expected token \"twoPy=0x\" "
							"(for debug: while in state EXPECT_TWOP_Y)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_NEGP_X:{
				/*
				 * Parse line to extract value of -P.x
				 */
				if ( (strncmp(line, "negPx=0x", strlen("negPx=0x"))) == 0 ) {
					PRINTF("%s-P.x=0x%s%s", KWHT, line + strlen("negPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of -P.x for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("negPx=0x"), sw_negp.x, nread - strlen("negPx=0x"));
					sw_negp.is_null = false;
					line_type_expected = EXPECT_NEGP_Y;
				} else if ( (strncmp(line, "negP=0", strlen("negP=0"))) == 0 ) {
					PRINTF("%s-P=0%s\n", KWHT, KNRM);
					sw_negp.is_null = true;
					sw_negp.valid = true;
					/*****************
					 * do a PT_NEG NOW
					 *****************/
					/*
					 * transfer point to double to the IP and run PT_NEG command
					 */
					ip_set_pt_and_run_ptneg(curve.nn, &p, &hw_negp, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptneg_result(&curve, &p, &sw_negp, &hw_negp, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find one of the expected tokens \"negPx=0x\" "
							"or \"negP=0\" (for debug: while in state EXPECT_NEGP_X)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_NEGP_Y:{
				/*
				 * Parse line to extract value of -P.y
				 */
				if ( (strncmp(line, "negPy=0x", strlen("negPy=0x"))) == 0 ) {
					PRINTF("%s-P.y=0x%s%s", KWHT, line + strlen("negPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of -P.y for comparison with HW
					 */
					hex_to_large_num(
							line + strlen("negPy=0x"), sw_negp.y, nread - strlen("negPy=0x"));
					sw_negp.valid = true;
					/*****************
					 * do a PT_NEG NOW
					 *****************/
					/*
					 * transfer point to double to the IP and run PT_DBL command
					 */
					ip_set_pt_and_run_ptneg(curve.nn, &p, &hw_negp, &err_flags);
					/*
					 * analyze errors
					 */
					if (err_flags & 0xffff0000) {
						printf("ERROR flags in R_STATUS: 0x%08x\n", err_flags);
					}
					/*
					 * analyze results
					 */
					check_ptneg_result(&curve, &p, &sw_negp, &hw_negp, &stats);
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
					/*
					 * mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test_is_an_exception = false;
				} else {
					printf("%sERROR: could not find the expected token \"negPy=0x\" "
							"(for debug: while in state EXPECT_NEGP_Y)\n", KERR);
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				break;
			}

			case EXPECT_TRUE_OR_FALSE:{
				/*
				 * Parse line to extract test answer (true or false)
				 */
				if ( (strncmp(line, "true", strlen("true"))) == 0 ) {
					PRINTF("%sanswer is true%s\n", KWHT, KNRM);
					switch (op) {
						case OP_TST_CHK:
							tst_chk.sw_answer = true;
							tst_chk.sw_valid = true;
							break;
						case OP_TST_EQU:
							tst_equ.sw_answer = true;
							tst_equ.sw_valid = true;
							break;
						case OP_TST_OPP:
							tst_opp.sw_answer = true;
							tst_opp.sw_valid = true;
							break;
						default:
							printf("%sERROR: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
									KERR);
							printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
							print_stats_and_exit(&stats);
							break;
					}
				} else if ( (strncmp(line, "false", strlen("false"))) == 0 ) {
					PRINTF("%sanswer is false%s\n", KWHT, KNRM);
					switch (op) {
						case OP_TST_CHK:
							tst_chk.sw_answer = false;
							tst_chk.sw_valid = true;
							break;
						case OP_TST_EQU:
							tst_equ.sw_answer = false;
							tst_equ.sw_valid = true;
							break;
						case OP_TST_OPP:
							tst_opp.sw_answer = false;
							tst_opp.sw_valid = true;
							break;
						default:
							printf("%sERROR: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
									KERR);
							printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
							print_stats_and_exit(&stats);
							break;
					}
				} else {
					printf("%sERROR: could not find one of the expected tokens \"true\" "
							"or \"false\" (for debug: while in state EXPECT_TRUE_OR_FALSE) for test %s\n", KERR,
							( op == OP_TST_CHK ? "OP_TST_CHK" : (op == OP_TST_EQU ? "OP_TST_EQU" :
							  (op == OP_TST_OPP ? "OP_TST_OPP" : "UNKNOWN_TEST"))));
					printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
					print_stats_and_exit(&stats);
				}
				/******************
				 * do a PT TEST NOW
				 ******************/
				/*
				 * transfer one or two points on which to perform the test to the IP.
				 * and run appropriate test command
				 */
				switch (op) {
					case OP_TST_CHK:{
						ip_set_pt_and_check_on_curve(curve.nn, &p, &tst_chk, &err_flags);
						break;
					}
					case OP_TST_EQU:{
						ip_set_pts_and_test_equal(curve.nn, &p, &q, &tst_equ, &err_flags);
						break;
					}
					case OP_TST_OPP:{
						ip_set_pts_and_test_oppos(curve.nn, &p, &q, &tst_opp, &err_flags);
						break;
					}
					default:{
						printf("%sERROR: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
								KERR);
						printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
						print_stats_and_exit(&stats);
						break;
					}
				}
				/*
				 * analyze results
				 */
				switch (op) {
					case OP_TST_CHK:{
						check_test_curve(&curve, &p, &tst_chk, &stats);
						break;
					}
					case OP_TST_EQU:{
						check_test_equal(&curve, &p, &q, &tst_equ, &stats);
						break;
					}
					case OP_TST_OPP:{
						check_test_opposed(&curve, &p, &q, &tst_opp, &stats);
						break;
					}
					default:{
						printf("%sERROR: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
								KERR);
						printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
						print_stats_and_exit(&stats);
						break;
					}
				}
				stats.total++;
				line_type_expected = EXPECT_NONE;
				print_stats_regularly(&stats);
				/*
				 * mark the next test to come as not being an exception (a priori)
				 * so that [k]P duration statistics only consider [k]P computations
				 * with no exception
				 */
				test_is_an_exception = false;
				break;
			}
#endif
			default:{
				break;
			}
		} /* switch type of line */

		if (line_type_expected == EXPECT_NONE) {
			/*
			 * reset a certain num of flags
			 */
			p.valid = false;
			q.valid = false;
			sw_pplusq.valid = false;
			hw_pplusq.valid = false;
			sw_kp.valid = false;
			hw_kp.valid = false;
			sw_twop.valid = false;
			hw_twop.valid = false;
			sw_negp.valid = false;
			hw_negp.valid = false;
			tst_chk.sw_valid = false;
			tst_chk.hw_valid = false;
			tst_equ.sw_valid = false;
			tst_equ.hw_valid = false;
			tst_opp.sw_valid = false;
			tst_opp.hw_valid = false;
			k_valid = false;
			op = OP_NONE;
		}
	} /* while nread */

	return 0;
}
