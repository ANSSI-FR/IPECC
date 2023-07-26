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

#include "../hw_accelerator_driver.h"
#include "test_app.h"
#if 0
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <error.h>
#endif


//extern int test_unit(ipecc_test*);

//static ipecc_test test;

extern int ip_set_curve(curve_t*);
extern int ip_set_pt_and_run_kp(ipecc_test_t*);
extern int check_kp_result(ipecc_test_t*, stats_t*);

char* line = NULL;
/* scalar (k in [k]P) */
bool k_valid;
uint32_t nbcurve, nbtest;

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

static void print_stats_regularly(stats_t* st)
{
	if ((st->total % DISPLAY_MODULO) == 0) {
		printf("%s%8d%s %s%8d%s %8d\n",
				KGRN, st->ok, KNRM, KRED, st->nok, KNRM, st->total);
	}
}

void print_stats_and_exit(ipecc_test_t* t, stats_t* s, const char* msg, unsigned int linenum)
{
	printf("Stopped on test %d.%d%s\n", t->curve->id, t->id, KNRM);
	printf("OK = %d\n", s->ok);
	printf("nOK = %d\n", s->nok);
	printf("total = %d\n", s->total);
	printf("--\n");
	if (line) {
		free(line);
	}
	error_at_line(-1, EXIT_FAILURE, __FILE__, linenum, "%s", msg);
}

/*
 * convert an hexadecimal digit to integer
 */
static int hex2dec(const char c, unsigned char *nb)
{
	if ( (c >= 'a') && (c <= 'f') ) {
		*nb = c - 'a' + 10;
	} else if ( (c >= 'A') && (c <= 'F') ) {
		*nb = c - 'A' + 10;
	} else if ( (c >= '0') && (c <= '9') ) {
		*nb = c - '0';
	} else {
		printf("%sError: '%c' not an hexadecimal digit%s\n", KERR, c, KNRM);
		goto err;
	}
	return c - '0';
err:
	return -1;
}

/*
 * Extract an hexadecimal string (without the 0x) from a position in a line 
 * (pointed to by parameter 'pc') convert it in binary form and fill buffer
 * 'nb_x' with it, parsing exactly 'nbchar' characters.
 *
 * Also set the size (in bytes) of the output buffer.
 */
static int hex_to_large_num(const char *pc, unsigned char* nb_x, unsigned int *nb_x_sz, const ssize_t nbchar)
{
	int i, j;
	uint8_t tmp;

#if 0
	/* Clear content of nb_x. */
	for (j=0; j<NBMAXSZ; j++) {
		nb_x[j] = 0;
	}
#endif
	/* Format bytes of large number; */
	j = 0;
	for (i = nbchar - 1 ; i>=0 ; i--) {
		if (hex2dec(pc[i], &tmp)) {
			printf("%sError while trying to convert character string '%s'"
					" into an hexadecimal number%s\n", KERR, pc, KNRM);
			goto err;
		} else {
#if 0
			if ((j % 2) == 0) {
				nb_x[j / 2] = 0;
			}
#endif
			nb_x[j/2] = ( (j % 2) ? nb_x[j/2] : 0) + ( tmp * (0x1U << (4*(j % 2))) );
			j++;
		}
	}
	/* Set the size of the number */
	*nb_x_sz = (unsigned int)(((j % 2) == 0) ? (j/2) : (j/2) + 1);

	return 0;
err:
	return -1;
}

/*
 * Same as strtol() but as mentioned in 'man (3) STRTOL', 'errno'
 * is set to 0 before the call, and then checked after to catch
 * if an error occurred.
 */
static int strtol_with_err(const char *nptr, unsigned int* nb)
{
	errno = 0;
	*nb = strtol(nptr, NULL, 10);
	if (errno) {
		return -1;
	} else {
		return 0;
	}
}

/* Curve definition */
static curve_t curve = INIT_CURVE();
/* Main test structure */
static ipecc_test_t test = {
	.curve = &curve,
	.ptp = INIT_POINT(),
	.ptq = INIT_POINT(),
	.k = INIT_LARGE_NUMBER(),
	.pt_sw_res = INIT_POINT(),
	.pt_hw_res = INIT_POINT(),
	.blinding = 0,
	.sw_answer = INIT_PTTEST(),
	.hw_answer = INIT_PTTEST(),
	.op = OP_NONE,
	.is_an_exception = false,
	.id = 0
};

/* Statistics */
static stats_t stats = {
	.ok = 0, .nok = 0, .total = 0
};

int main(int argc, char *argv[])
{
	uint32_t i;
	line_t line_type_expected;
	size_t len = 0;
	ssize_t nread;

	(void)argc;
	(void)argv;

#if 0
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
#endif


	printf("Welcome to the IPECC comprehensive test tool!\n");

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
				test.is_an_exception = true;
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
					strtol_with_err(line + strlen("NEW CURVE #"), &curve.id); /* NEW CURVE #x */
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
					strtol_with_err(line + strlen("== TEST [k]P #") + i + 1, &test.id);
					test.op = OP_KP;
					test.ptp.valid = false;
					test.k.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
					line_type_expected = EXPECT_PX;
					/*
					 * Blinding will be applied only if input file/stream test says so
					 * (otherwise default is no blinding).
					 */
					test.blinding = 0;
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
					strtol_with_err(line + strlen("P+Q #") + i + 1, &test.id);
					test.op = OP_PTADD;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
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
					strtol_with_err(line + strlen("[2]P #") + i + 1, &test.id);
					test.op = OP_PTDBL;
					test.ptp.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
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
					strtol_with_err(line + strlen("-P #") + i + 1, &test.id);
					test.op = OP_PTNEG;
					test.ptp.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
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
					strtol_with_err(line + strlen("isPoncurve #") + i + 1, &test.id);
					test.op = OP_TST_CHK;
					test.ptp.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
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
					strtol_with_err(line + strlen("isP==Q #") + i + 1, &test.id);
					test.op = OP_TST_EQU;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
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
					strtol_with_err(line + strlen("isP==-Q #") + i + 1, &test.id);
					test.op = OP_TST_OPP;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
					line_type_expected = EXPECT_PX;
				} else {
					printf("%sError: Could not find any of the expected commands from "
							"input file/stream.\n", KERR);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NONE')", __LINE__);
				}
				break;
			}

			case EXPECT_NN:{
				/*
				 * Parse line to extract value of nn
				 */
				if ( (strncmp(line, "nn=", strlen("nn="))) == 0 )
				{
					strtol_with_err(&line[3], &curve.nn);
					line_type_expected = EXPECT_P;
				} else {
					printf("%sError: Could not find the expected token \"nn=\" "
							"from input file/stream.\n", KERR);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NN)'", __LINE__);
				}
				break;
			}

			case EXPECT_P:{
				/* Parse line to extract value of p */
				if ( (strncmp(line, "p=0x", strlen("p=0x"))) == 0 ) {
					PRINTF("%sp=0x%s%s", KWHT, line + strlen("p=0x"), KNRM);
					/*
					 * Process the hexadecimal value of p to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("p=0x"), test.curve->p.val, &(test.curve->p.sz), nread - strlen("p=0x")))
					{
						printf("%sError: Value of main curve parameter 'p' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P')", __LINE__);
					}
					test.curve->p.valid = true;
					line_type_expected = EXPECT_A;
				} else {
					printf("%sError: Could not find the expected token \"p=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P')", __LINE__);
				}
				break;
			}

			case EXPECT_A:{
				/* Parse line to extract value of a */
				if ( (strncmp(line, "a=0x", strlen("a=0x"))) == 0 ) {
					PRINTF("%sa=0x%s%s", KWHT, line + strlen("a=0x"), KNRM);
					/*
					 * Process the hexadecimal value of a to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("a=0x"), test.curve->a.val, &(test.curve->a.sz), nread - strlen("a=0x")))
					{
						printf("%sError: Value of curve parameter 'a' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_A')", __LINE__);
					}
					test.curve->a.valid = true;
					line_type_expected = EXPECT_B;
				} else {
					printf("%sError: Could not find the expected token \"a=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_A')", __LINE__);
				}
				break;
			}

			case EXPECT_B:{
				/* Parse line to extract value of b/ */
				if ( (strncmp(line, "b=0x", strlen("b=0x"))) == 0 ) {
					PRINTF("%sb=0x%s%s", KWHT, line + strlen("b=0x"), KNRM);
					/*
					 * Process the hexadecimal value of b to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("b=0x"), test.curve->b.val, &(test.curve->b.sz), nread - strlen("b=0x")))
					{
						printf("%sError: Value of curve parameter 'b' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
					}
					test.curve->b.valid = true;
					line_type_expected = EXPECT_Q;
				} else {
					printf("%sError: Could not find the expected token \"b=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
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
					if (hex_to_large_num(
							line + strlen("q=0x"), test.curve->q.val, &(test.curve->q.sz), nread - strlen("q=0x")))
					{
						printf("%sError: Value of curve parameter 'q' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_Q')", __LINE__);
					}
					test.curve->q.valid = true;
					test.curve->valid = true;
					/*
					 * Transfer curve parameters to the IP.
					 */
					if (ip_set_curve(test.curve))
					{
						printf("%sError: Could not transmit curve parameters to driver.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_Q')", __LINE__);
					}
					line_type_expected = EXPECT_NONE;
				} else {
					printf("%sError: Could not find the expected token \"q=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
				}
				break;
			}

			case EXPECT_PX:{
				/* Parse line to extract value of Px */
				if ( (strncmp(line, "Px=0x", strlen("Px=0x"))) == 0 ) {
					PRINTF("%sPx=0x%s%s", KWHT, line + strlen("Px=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Px to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Px=0x"), test.ptp.x.val, &(test.ptp.x.sz), nread - strlen("Px=0x")))
					{
						printf("%sError: Value of point coordinate 'Px' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
					}
					/*
					 * Position point P not to be null
					 */
					test.ptp.is_null = false;
					line_type_expected = EXPECT_PY;
				} else if ( (strncmp(line, "P=0", strlen("P=0"))) == 0 ) {
					PRINTF("%sP=0%s\n", KWHT, KNRM);
					/*
					 * Position point P to be null
					 */
					test.ptp.is_null = true;
					test.ptp.valid = true;
					if (test.op == OP_KP) {
						line_type_expected = EXPECT_K;
					} else if (test.op == OP_PTADD) {
						line_type_expected = EXPECT_QX;
					} else if (test.op == OP_PTDBL) {
						line_type_expected = EXPECT_TWOP_X;
					} else if (test.op == OP_PTNEG) {
						line_type_expected = EXPECT_NEGP_X;
					} else if (test.op == OP_TST_CHK) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if ((test.op == OP_TST_EQU) || (test.op == OP_TST_OPP)) {
						line_type_expected = EXPECT_QX;
					} else {
						printf("%sError: unknown or undefined type of operation.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"Px=0x\" "
							"or \"P=0\" from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
				}
				break;
			}

			case EXPECT_PY:{
				/* Parse line to extract value of Py */
				if ( (strncmp(line, "Py=0x", strlen("Py=0x"))) == 0 ) {
					PRINTF("%sPy=0x%s%s", KWHT, line + strlen("Py=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Py to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Py=0x"), test.ptp.y.val, &(test.ptp.y.sz), nread - strlen("Py=0x")))
					{
						printf("%sError: Value of point coordinate 'Py' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
					}
					test.ptp.valid = true;
					if (test.op == OP_KP) {
						line_type_expected = EXPECT_K;
					} else if (test.op == OP_PTADD) {
						line_type_expected = EXPECT_QX;
					} else if (test.op == OP_PTDBL) {
						line_type_expected = EXPECT_TWOP_X;
					} else if (test.op == OP_PTNEG) {
						line_type_expected = EXPECT_NEGP_X;
					} else if (test.op == OP_TST_CHK) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if ((test.op == OP_TST_EQU) || (test.op == OP_TST_OPP)) {
						line_type_expected = EXPECT_QX;
					} else {
						printf("%sError: unknown or undefined type of operation.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
					}
				} else {
					printf("%sError: Could not find the expected token \"Py=0x\" "
								"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
				}
				break;
			}

			case EXPECT_QX:{
				/* Parse line to extract value of Qx */
				if ( (strncmp(line, "Qx=0x", strlen("Qx=0x"))) == 0 ) {
					PRINTF("%sQx=0x%s%s", KWHT, line + strlen("Qx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Qx to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Qx=0x"), test.ptq.x.val, &(test.ptq.x.sz), nread - strlen("Qx=0x")))
					{
						printf("%sError: Value of point coordinate 'Qx' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
					}
					/*
					 * position point Q not to be null
					 */
					test.ptq.is_null = false;
					line_type_expected = EXPECT_QY;
				} else if ( (strncmp(line, "Q=0", strlen("Q=0"))) == 0 ) {
					PRINTF("%sQ=0%s\n", KWHT, KNRM);
					/*
					 * position point Q to be null
					 */
					test.ptq.is_null = true;
					test.ptq.valid = true;
					if (test.op == OP_PTADD) {
						line_type_expected = EXPECT_P_PLUS_QX;
					} else if (test.op == OP_TST_EQU) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if (test.op == OP_TST_OPP) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else {
						printf("%sError: unknown or undefined type of operation.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"Qx=0x\" "
							"or \"Q=0\" from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
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
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Qy=0x"), test.ptq.y.val, &(test.ptq.y.sz), nread - strlen("Qy=0x")))
					{
						printf("%sError: Value of point coordinate 'Qy' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
					}
					test.ptq.valid = true;
					if (test.op == OP_PTADD) {
						line_type_expected = EXPECT_P_PLUS_QX;
					} else if (test.op == OP_TST_EQU) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if (test.op == OP_TST_OPP) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else {
						printf("%sError: unknown or undefined type of operation.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
					}
				} else {
					printf("%sError: Could not find the expected token \"Qy=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
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
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("k=0x"), test.k.val, &(test.k.sz), nread - strlen("k=0x")))
					{
						printf("%sError: Value of scalar number 'k' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_K')", __LINE__);
					}
					test.k.valid = true;
					line_type_expected = EXPECT_KPX_OR_BLD;
				} else {
					printf("%sError: Could not find the expected token \"k=0x\" "
							"from input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_K')", __LINE__);
				}
				break;
			}

			case EXPECT_KPX_OR_BLD:{
				/*
				 * Parse line to extract possible nb of blinding bits.
				 * */
				if ( (strncmp(line, "nbbld=", strlen("nbbld="))) == 0 ) {
					PRINTF("%snbbld=%s%s", KWHT, line + strlen("nbbld="), KNRM);
					if (strtol_with_err(line + strlen("nbbld="), &test.blinding))
					{
						printf("%sError: while converting \"nbbld=\" argument to a number.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/* Keep line_type_expected to EXPECT_KPX_OR_BLD to parse point [k]P coordinates */
				} else if ( (strncmp(line, "kPx=0x", strlen("kPx=0x"))) == 0 ) {
					PRINTF("%skPx=0x%s%s", KWHT, line + strlen("kPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of kPx for comparison with HW.
					 */
					if (hex_to_large_num(
							line + strlen("kPx=0x"), test.pt_sw_res.x.val, &(test.pt_sw_res.x.sz),
							nread - strlen("kPx=0x")))
					{
						printf("%sError: Value of point coordinate 'kPx' could not be extracted "
								"from input file/stream.%s\n", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/*
					 * Record that expected result point [k]P should not be null.
					 */
					test.pt_sw_res.is_null = false;
					line_type_expected = EXPECT_KPY;
				} else if ( (strncmp(line, "kP=0", strlen("kP=0"))) == 0 ) {
					PRINTF("%sExpected result point [k]P = 0%s\n", KWHT, KNRM);
					/*
					 * Record that expected result point [k]P should be null.
					 */
					test.pt_sw_res.is_null = true;
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a [k]P computation test.
					 */
					ip_set_pt_and_run_kp(&test); //, &err_flags);
					/*
					 * analyze errors
					 */
#if 0
					if (err_flags & STATUS_ERR_IN_PT_NOT_ON_CURVE) {
						printf("Error: input point IS NOT on curve\n");
					}
					if (err_flags & STATUS_ERR_OUT_PT_NOT_ON_CURVE) {
						printf("Error: output point IS NOT on curve\n");
					}
#endif
					/*
					 * Check IP result against the one given by client
					 *   (software client said k[P] should be null)
					 */
					check_kp_result(&test, &stats);
					/*
					 * Stats
					 */
					stats.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P timing statistics only consider [k]P computations
					 * with no exception.
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find one of the expected tokens \"nbbld=\" "
							"or \"kPx=0x\" or \"kP=0\" in input file/stream.%s\n", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
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
						printf("Error: input point IS NOT on curve\n");
					}
					if (err_flags & STATUS_ERR_OUT_PT_NOT_ON_CURVE) {
						printf("Error: output point IS NOT on curve\n");
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
					printf("%sError: Could not find the expected token \"kPy=0x\" "
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
					printf("%sError: Could not find one of the expected tokens \"PplusQx=0x\" "
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
					printf("%sError: Could not find the expected token \"PplusQy=0x\" "
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
					printf("%sError: Could not find one of the expected tokens \"twoPx=0x\" "
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
					printf("%sError: Could not find the expected token \"twoPy=0x\" "
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
					printf("%sError: Could not find one of the expected tokens \"negPx=0x\" "
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
					printf("%sError: Could not find the expected token \"negPy=0x\" "
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
							printf("%sError: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
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
							printf("%sError: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
									KERR);
							printf("Stopped on test %d.%d%s\n", nbcurve, nbtest, KNRM);
							print_stats_and_exit(&stats);
							break;
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"true\" "
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
						printf("%sError: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
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
						printf("%sError: test is none of OP_TST_CHK | OP_TST_EQU | OP_TST_OPP\n",
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

#if 0
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
			nnbld = 0; /* new addition */
			is_an_exception = 0; /* new addition */
		}
#endif
	} /* while nread */

	return EXIT_SUCCESS;
}
