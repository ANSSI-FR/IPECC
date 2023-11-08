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
#include "../hw_accelerator_driver_ipecc_platform.h"
#include "ecc-test-linux.h"
#include <signal.h>

#if 0
static uint32_t microcode[499] = {
0x91007bfd,	0x9400741d,	0x11000018,	0x110003fb,	0x110077fc,	0x26000111,
0x1200f2b5,	0x58007bdb,	0x58006fdb,	0x510003fc,	0x26000111,	0x110057f3,
0x12004f16,	0x11455ab3,	0x1200771d,	0x1200771d,	0x12007716,	0x91455abd,
0x58000661,	0xc0000000,	0x66000016,	0x80000000,	0x580018d1,	0x18001cf0,
0x580004cf,	0x18004e74,	0x580044d1,	0x18004270,	0x12003f16,	0x11455aaf,
0x58004691,	0x11003c4f,	0x12003f16,	0x11455aaf,	0x12004316,	0x11455ab0,
0x52004716,	0x11455ab1,	0x11003e2f,	0x12003f16,	0x11455aaf,	0x12004016,
0x11445ab0,	0x12003c16,	0x11445aaf,	0x120041f5,	0x28000000,	0x510013e4,
0x110017e5,	0x1500000c,	0x11000fe8,	0x11007fe9,	0x1d00000f,	0x170031ec,
0x91007fef,	0x56003004,	0x11502095,	0x11d124b5,	0x1e00300c,	0x14002008,
0x94802409,	0x52001144,	0x12801565,	0x11007fea,	0x11007feb,	0x1500001a,
0x19006810,	0x1500001b,	0x17001344,	0x97001765,	0x51007fec,	0x1500000a,
0x1500000b,	0x19001008,	0x13001405,	0x13801004,	0x1700114c,	0x1700156d,
0x1400280a,	0x14802c0b,	0x1700114e,	0x1700156f,	0x13002c0b,	0x1380280a,
0x13006c1b,	0x1380681a,	0x1700334c,	0x1700376d,	0x17003b4e,	0x17003f6f,
0x1c000028,	0x1d000029,	0x1700310c,	0x1700352d,	0x11007fe8,	0x11007fe9,
0x1c000050,	0x1d000051,	0x17003a0e,	0x17003e2f,	0x11007ff0,	0x11007ff1,
0x1c000074,	0x1d000075,	0x17002a8a,	0x17002eab,	0x11007ff4,	0x11007ff5,
0x11007ffa,	0x11007ffb,	0x16003022,	0x11007fe4,	0x91007fe5,	0x5a000015,
0x12005416,	0x11445ab5,	0x80000000,	0x58001a66,	0x18001e67,	0x51001bfb,
0x11001ffc,	0x58007a7a,	0x2600007f,	0x11001be4,	0x51001fe5,	0x26000195,
0x2100009c,	0x18005675,	0x58006aba,	0x180056b6,	0x586c1ac6,	0x18005ab7,
0x586d1ee7,	0x28000000,	0x510013ee,	0x110017ef,	0x18001266,	0x18001667,
0x18007a7a,	0x66000195,	0x51006bfb,	0x2600014e,	0x110013e6,	0x110017e7,
0x66000103,	0x6600010a,	0x11003be4,	0x91003fe5,	0x5e00342d,	0x1380300c,
0x1e003c4f,	0x1380380e,	0x16003022,	0x16003841,	0x1e002c6b,	0x9380280a,
0x524710c8,	0x114522a8,	0x12002016,	0x11705aa8,	0x124814f0,	0x114542b0,
0x12004016,	0x11715ab0,	0x80000000,	0x660000a7,	0x80000000,	0x187f235a,
0x18002108,	0x18004211,	0x584a1109,	0x11641bf4,	0x11631ff5,	0x184b5106,
0x526544d1,	0x114546b1,	0x12584524,	0x116612a4,	0x125924c9,	0x114526a9,
0x184c5527,	0x125a1888,	0x114522a8,	0x185b4105,	0x525c14e5,	0x516716a5,
0x28000000,	0x525d1895,	0x114556b5,	0x12005416,	0x11705ab5,	0x125e1cb0,
0x114542b0,	0x12004016,	0x11715ab0,	0x115f14f4,	0x12005316,	0x11455ab4,
0x80000000,	0x580056a8,	0x18004211,	0x58601117,	0x18611909,	0x520026f9,
0x114566b9,	0x18621739,	0x11005d29,	0x12002716,	0x11455aa9,	0x12004531,
0x114546b1,	0x114d47e4,	0x124e5c88,	0x114522a8,	0x18004110,	0x58005288,
0x12004330,	0x114542b0,	0x114f43e5,	0x52002128,	0x114522a8,	0x114023e6,
0x120022e9,	0x114526a9,	0x18005129,	0x1842575a,	0x52002730,	0x114542b0,
0x114143e7,	0x80000000,	0x56002864,	0x18007a76,	0x58006ad9,	0x18005ace,
0x586811d0,	0x18003ace,	0x586915d1,	0x18006b55,	0x58006eb6,	0x18005755,
0x580072b4,	0x110067fa,	0x110043e4,	0x110047e5,	0x11005be6,	0x510053e7,
0x610000bb,	0x51007fea,	0x11007feb,	0x11007fec,	0x11007fed,	0x11007fee,
0x11007fef,	0x11006bfb,	0x2600014e,	0x66000103,	0x6600010a,	0x66000014,
0x80000000,	0x52005416,	0x11445ab5,	0x180056aa,	0x58001946,	0x18002aab,
0x58001d67,	0x28000000,	0x58001bc6,	0x18001fc7,	0x52001816,	0x11445aa6,
0x12001c16,	0x11445aa7,	0x28000000,	0x51006ff9,	0x110073fa,	0x11007bf7,
0x11007ff1,	0x11007fef,	0x11007bf0,	0x120067d4,	0x2200013f,	0x12006bd4,
0x2200013f,	0x19006404,	0x24000128,	0x1b006419,	0x19005c04,	0x24000125,
0x19003c04,	0x24000125,	0x1b005c17,	0x1b003c0f,	0x2100011b,	0x11005f97,
0x12003f6f,	0x21000122,	0x19006804,	0x24000135,	0x1b00681a,	0x19004404,
0x24000132,	0x19004004,	0x24000132,	0x1b004411,	0x1b004010,	0x21000128,
0x11004791,	0x12004370,	0x2100012f,	0x12006754,	0x2300013b,	0x110053f9,
0x12005e37,	0x12003e0f,	0x21000117,	0x12006b3a,	0x120046f1,	0x120041f0,
0x21000117,	0x120067d4,	0x2200014c,	0x120047f4,	0x23000148,	0x12004794,
0x2300014a,	0x12004791,	0x23000148,	0x21000145,	0x11004791,	0x23000148,
0x110047f5,	0x28000000,	0x11005ff1,	0x21000141,	0x51007bd7,	0x120002f1,
0x11007bf9,	0x18006679,	0x51006ffa,	0x19004404,	0x24000156,	0x21000157,
0x18006759,	0x18006b5a,	0x53004411,	0x2200015b,	0x21000153,	0x110067f5,
0x28000000,	0x510013ee,	0x110017ef,	0x11001bfc,	0x11001fec,	0x18003a64,
0x18003e65,	0x18007266,	0x18003267,	0x18007a7a,	0x6100009c,	0x11006bfb,
0x2600014e,	0x66000103,	0x6600010a,	0x51003be4,	0x11003fe5,	0x116a73e6,
0x916b33e7,	0x66000195,	0x11001bfc,	0x11001fec,	0x110013e6,	0x110017e7,
0x110073e4,	0x910033e5,	0x510013e6,	0x120000a7,	0x12001c16,	0x91445aa7,
0x52001016,	0x11445aa4,	0x12001816,	0x11445aa6,	0x920010d4,	0x52001416,
0x11445aa5,	0x12001c16,	0x11445aa7,	0x92001cb5,	0x52001416,	0x11445aa5,
0x12001c16,	0x11445aa7,	0x110014f5,	0x12005416,	0x91445ab5,	0x51001bfc,
0x11001fec,	0x110013e6,	0x110017e7,	0x26000016,	0x110073e6,	0x110033e7,
0x910057f5,	0x66000195,	0x80000000,	0x51751be8,	0x11761fe9,	0x110023e6,
0x110027e7,	0x12001f16,	0x11455aa7,	0x12001c16,	0x11785aa7,	0x58006b48,
0x18001ce9,	0x58002117,	0x18002530,	0x11002519,	0x51005fe8,	0x180018d7,
0x11001934,	0x12005316,	0x11455ab4,	0x51005e11,	0x12004716,	0x11455ab1,
0x18005294,	0x11005ef5,	0x12005716,	0x11455ab5,	0x110056f7,	0x12005f16,
0x11455ab7,	0x12006716,	0x11455ab9,	0x11001f55,	0x12005716,	0x11455ab5,
0x180056b5,	0x58000508,	0x11004210,	0x12004316,	0x11455ab0,	0x11004210,
0x12004316,	0x11455ab0,	0x11564207,	0x12001f16,	0x11455aa7,	0x52005234,
0x114552b4,	0x11005291,	0x12004716,	0x11455ab1,	0x115747e6,	0x52005739,
0x114566b9,	0x117d67fa,	0x11005d08,	0x12002316,	0x11455aa8,	0x18002115,
0x11004637,	0x12005f16,	0x11455ab7,	0x527356e4,	0x114512a4,	0x52004491,
0x114546b1,	0x18004511,	0x527444e5,	0x114516a5,	0x110013f0,	0x110017f1,
0x11001bf6,	0x11001ff4,	0x11795be6,	0x117a53e7,	0x117b43e4,	0x117c47e5,
0x28000000,	0x514657f0,	0x114957f4,	0x12000215,	0x114556b5,	0x115257f5,
0x115343f5,	0x117743f5,	0x115453e4,	0x115553e6,	0x80000000,	0xd5000012,
0x57001a46,	0x17001e47,	0x91007ff2,	0x6600007f,	0x186e12c4,	0x186f16e5,
0xc0000000
};
#endif

/* Helper for curve set */
extern int ip_set_curve(curve_t*);
/* Point operations helpers */
/*   [k]P */
extern int ip_set_pt_and_run_kp(ipecc_test_t*, kp_trace_info_t*);
extern int check_kp_result(ipecc_test_t*, bool*, kp_trace_info_t*);
extern int kp_error_log(ipecc_test_t*);
/*   P + Q */
extern int ip_set_pts_and_run_ptadd(ipecc_test_t*);
extern int check_ptadd_result(ipecc_test_t*, bool*);
/*   [2]P */
extern int ip_set_pt_and_run_ptdbl(ipecc_test_t*);
extern int check_ptdbl_result(ipecc_test_t*, bool*);
/*   (-P) */
extern int ip_set_pt_and_run_ptneg(ipecc_test_t*);
extern int check_ptneg_result(ipecc_test_t*, bool*);
/* Point tests helpers */
/*   is P on curve? */
extern int ip_set_pt_and_check_on_curve(ipecc_test_t*);
extern int check_test_oncurve(ipecc_test_t*, bool* res);
/*   are P & Q equal? */
extern int ip_set_pts_and_test_equal(ipecc_test_t*);
extern int check_test_equal(ipecc_test_t*, bool* res);
/*   are P & Q opposite? */
extern int ip_set_pts_and_test_oppos(ipecc_test_t*);
extern int check_test_oppos(ipecc_test_t*, bool* res);

/* Curve definition */
static curve_t curve = INIT_CURVE();

/* Definition of NBMAXSZ (in ecc-test-linux.h) is done in bytes,
 * here we use int, shence the divisions by 4 below.
 */
unsigned int debug_lambda[NBMAXSZ/4];
unsigned int debug_phi0[NBMAXSZ/4];
unsigned int debug_phi1[NBMAXSZ/4];
unsigned int debug_alpha[NBMAXSZ/4];
unsigned int debug_xr0[NBMAXSZ/4];
unsigned int debug_yr0[NBMAXSZ/4];
unsigned int debug_xr1[NBMAXSZ/4];
unsigned int debug_yr1[NBMAXSZ/4];
unsigned int debug_zr01[NBMAXSZ/4];
char debug_msg[KP_TRACE_PRINTF_SZ];

/*
 * struct to debug [k]P computation
 */
kp_trace_info_t kp_trace_info =
{
	.lambda = debug_lambda,
	.lambda_valid = false,
	.phi0 = debug_phi0,
	.phi0_valid = false,
	.phi1 = debug_phi1,
	.phi1_valid = false,
	.alpha = debug_alpha,
	.alpha_valid = false,
	.nb_steps = 0,
	.nb_xr0 = debug_xr0,
	.nb_yr0 = debug_yr0,
	.nb_xr1 = debug_xr1,
	.nb_yr1 = debug_yr1,
	.nb_zr01 = debug_zr01,
	.msg = debug_msg,
	.msgsz = 0,
	.msgsz_max = KP_TRACE_PRINTF_SZ
};

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
	.id = 0,
#ifdef KP_TRACE
	.ktrc = &kp_trace_info
#else
	.ktrc = NULL
#endif
};

/* Statistics */
static all_stats_t stats = {
	.kp = { .ok = 0, .nok = 0, .total = 0 },
	.ptadd = { .ok = 0, .nok = 0, .total = 0 },
	.ptdbl = { .ok = 0, .nok = 0, .total = 0 },
	.ptneg = { .ok = 0, .nok = 0, .total = 0 },
	.test_equ = { .ok = 0, .nok = 0, .total = 0 },
	.test_opp = { .ok = 0, .nok = 0, .total = 0 },
	.test_crv = { .ok = 0, .nok = 0, .total = 0 },
	.all = { .ok = 0, .nok = 0, .total = 0 },
	.nn_min = 0xffffffffUL,
	.nn_max = 0,
	.nn_avr = 0,
	.nbcurves = 0
};

/*
 * Pointer 'line' will be allocated by getline, but freed by us
 * as recommanded in the man GETLINE(3) page (see function
 * print_stats_and_exit() hereafter).
 */
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

static void print_stats_regularly(all_stats_t* st, bool force)
{
	static bool once = true;

	if (((st->all.total % DISPLAY_MODULO) == DISPLAY_MODULO - 1) || (force)) {
		if (once) {
			printf("\n\n\n\n\n");
			once = false;
		}
		/* nn min, max */
		printf("%s%s%s%s%s%s%s%s%s%s%s%s",
				KERASELINE, KMVUP1LINE, KERASELINE, KMVUP1LINE, KERASELINE, KMVUP1LINE,
				KERASELINE, KMVUP1LINE, KERASELINE, KMVUP1LINE, KERASELINE, KBOLD);
		if (st->nbcurves)  {
			printf("nn min|average|max: %s%u%s%s|%s%u%s%s|%s%u%s%s\n",
					KORA, st->nn_min, KNRM, KBOLD, KVIO, (st->nn_avr)/(st->nbcurves),
					KNRM, KBOLD, KORA, st->nn_max, KNRM, KNOBOLD);
		} else {
			printf("nn min|average|max: %s%u%s%s|%s%s%s%s|%s%u%s%s\n",
					KORA, st->nn_min, KNRM, KBOLD, KVIO, ".", KNRM, KBOLD, KORA, st->nn_max, KNRM, KNOBOLD);
		}
		/* Label line */
		printf("%s         %s[k]P     P+Q    [2]P      -P"
				"    P==Q    P==-Q   PonC   %sTotal%s%s\n", KBOLD, KWHT, KCYN, KNRM, KNOBOLD);
		/* OK line */
		printf("%s%s   ok: %*d  %*d  %*d  %*d  %*d  %*d  %*d  %s%*d%s%s\n",
				KBOLD,
				KGRN, 6, st->kp.ok, 6, st->ptadd.ok, 6, st->ptdbl.ok, 6, st->ptneg.ok,
				6, st->test_equ.ok, 6, st->test_opp.ok, 6, st->test_crv.ok, KCYN, 6, st->all.ok,
				KNRM, KNOBOLD);
		/* NOK line */
		printf("%s%s  nok: %*d  %*d  %*d  %*d  %*d  %*d  %*d  %s%*d%s%s\n",
				KBOLD, KRED,
				6, st->kp.nok, 6, st->ptadd.nok, 6, st->ptdbl.nok, 6, st->ptneg.nok,
				6, st->test_equ.nok, 6, st->test_opp.nok, 6, st->test_crv.nok, KCYN,
				6, st->all.nok, KNRM, KNOBOLD);
		/* Total line */
		printf("%stotal: %*d  %*d  %*d  %*d  %*d  %*d  %*d  %s%*d%s%s\n",
				KBOLD,
				6, st->kp.total, 6, st->ptadd.total, 6, st->ptdbl.total, 6, st->ptneg.total,
				6, st->test_equ.total, 6, st->test_opp.total, 6, st->test_crv.total, KCYN,
				6, st->all.total, KNRM, KNOBOLD);
	}
}

void print_stats_and_exit(ipecc_test_t* t, all_stats_t* s, const char* msg, unsigned int linenum)
{
	print_stats_regularly(s, true);
	printf("Stopped on test %d.%d%s\n\r", t->curve->id, t->id, KNRM);
#ifndef KP_TRACE
	printf("You can compile with -DKP_TRACE to get debug info from [k]P tracing log (see Makefile).\n");
#endif
	if (line) {
		free(line);
	}
	/* Remove color on terminal, make the cursor visible again
	 * and set normal (no bold) font
	 */
	printf("%s%s%s", KNRM, KCURSORVIS, KNOBOLD);
	error_at_line(-1, EXIT_FAILURE, __FILE__, linenum, "%s", msg);
}

/* Irq handler for the SIGINT (Ctrl-C) signal to restore the cursor,
 * a normal color and no bold font in the terminal before leaving.
 */
void int_handler(int dummy)
{
	(void)(dummy); /* To avoid unused parameter warning from gcc */
	if (stats.all.total > 0) {
		print_stats_regularly(&stats, true);
	}
	/* Remove color on terminal, make the cursor visible again
	 * and set normal (no bold) font
	 */
	printf("%s%s%s", KNRM, KCURSORVIS, KNOBOLD);
	exit(EXIT_SUCCESS);
}

/*
 * Convert one hexadecimal digit into an integer.
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
		printf("%sError: '%c' not an hexadecimal digit%s\n\r", KERR, c, KNRM);
		goto err;
	}
	return 0;
err:
	return -1;
}

/*
 * Extract an hexadecimal string (without the 0x) from a position in a line 
 * (pointed to by parameter 'pc') convert it in binary form and fill buffer
 * 'nb_x' with it, parsing exactly 'nbchar' - 2 characters.
 *
 * Also set the size (in bytes) of the output buffer.
 */
static int hex_to_large_num(const char *pc, unsigned char* nb_x, unsigned int valnn, const ssize_t nbchar)
{
	int i, j;
	unsigned int k;
	uint8_t tmp;

	/* Format bytes of large number; */
	j = 0;
	for (i = nbchar - 2 ; i>=0 ; i--) {
	//for (i = 0; i < nbchar - 1 ; i++) {
		if (hex2dec(pc[i], &tmp)) {
			printf("%sError while trying to convert character string '%s'"
					" into an hexadecimal number%s\n\r", KERR, pc, KNRM);
			goto err;
		} else {
			nb_x[DIV(valnn, 8) - 1 - j/2] = ( (j % 2) ? nb_x[DIV(valnn, 8) - 1 - j/2] : 0) + ( tmp * (0x1U << (4*(j % 2))) );
			j++;
		}
	}
	 /* Fill possible remaining buffer space with 0s.
	 */
	for (k = 1 + (j-1)/2; k < DIV(valnn, 8); k++) {
		nb_x[k] = 0;
	}
	for (k=0; k<DIV(valnn, 8); k++) {
		PRINTF(" %02x", nb_x[k]);
	}
	PRINTF("\n\r");

	return 0;
err:
	return -1;
}

/* Same as strtol() but as mentioned in the man STRTOL(3) page,
 * 'errno' is set to 0 before the call, and then checked after to
 * catch if an error occurred (see below 'print_stats_and_exit()'
 * function).
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

int cmp_two_pts_coords(point_t* p0, point_t* p1, bool* res)
{
	uint32_t i;

	/*
	 * If four coordinates sizes do not match, that's an error
	 * (don't even compare).
	 */
	if ( (p0->x.sz != p0->y.sz) || (p0->x.sz != p1->x.sz) || (p0->y.sz != p1->x.sz)
			|| (p0->y.sz != p1->y.sz) || (p1->x.sz != p1->y.sz) )
	{
		printf("%sError: can't compare coord. buffers that are not of the same byte size to begin with.%s\n\r",
				KERR, KNRM);
		goto err;
	}
	/* Compare the X & Y coordinates one byte after the other. */
	*res = true;
	for (i = 0; i < p0->x.sz; i++) {
		if ((p0->x.val[i] != p1->x.val[i]) || (p0->y.val[i] != p1->y.val[i])) {
			*res = false;
			break;
		}
	}
	return 0;
err:
	return -1;
}

int main(int argc, char *argv[])
{
	uint32_t i;
	line_t line_type_expected = EXPECT_NONE;
	size_t len = 0;
	ssize_t nread;
	uint32_t debug_not_prod;
	uint32_t vmajor, vminor, vpatch;

	(void)argc;
	(void)argv;

	bool result_pts_are_equal;
	bool result_tests_are_identical;

	/* Move the claptrap below rather in --help it it exists one day. */
#if 0
	printf("Reads test-vectors from standard-input, has them computed by hardware,\n\r");
	printf("then checks that result matches what was expected.\n\r");
	printf("Text format for tests is described in the IPECC doc.\n\r");
	printf("(c.f Appendix \"Simulating & testing the IP\").%s\n\r", KNRM);
#endif

#if 1
	/* Is it a 'debug' or a 'production' version of the IP? */
	if (hw_driver_is_debug(&debug_not_prod)) {
		printf("%sError: Probing 'debug or production mode' triggered an error.%s\n\r", KERR, KNRM);
		exit(EXIT_FAILURE);
	}

	if (debug_not_prod){
		if (hw_driver_get_version_tags(&vmajor, &vminor, &vpatch)){
			printf("%sError: Probing revision numbers triggered an error.%s\n\r", KERR, KNRM);
			exit(EXIT_FAILURE);
		}
		log_print("IP in debug mode (HW version %d.%d.%d)\n\r", vmajor, vminor, vpatch);
		/*
		 * We must activate, in the TRNG, the pulling of raw random bytes by the
		 * post-processing function (because in debug mode it is disabled upon
		 * reset).
		 */
		if (hw_driver_trng_post_proc_enable()){
			printf("%sError: Enabling TRNG post-processing on hardware triggered an error.%s\n\r", KERR, KNRM);
			exit(EXIT_FAILURE);
		}
	} else {
		if (hw_driver_get_version_tags(&vmajor, &vminor, &vpatch)){
			printf("%sError: Probing revision numbers triggered an error.%s\n\r", KERR, KNRM);
			exit(EXIT_FAILURE);
		}
		log_print("IP in production mode (HW version %d.%d.%d)\n\r", vmajor, vminor, vpatch);
	}
#endif

	/* Add here possible extra configuration for the IP
	 * ************************************************
	 *
	 * (e.g if you want to disable shuffling or enable periodic Z-remask
	 *  when in debug mode, etc)
	 */
#if 0
	/* Example of how to disable XY-shuffling (if DEBUG mode) */
	if (hw_driver_disable_xyshuf()) {
		printf("Error: hw_driver_disable_xyshuf() returned exception\n\r");
		exit(EXIT_FAILURE);
	}
	printf("%sXY-shuffling disabled%s\n\r", KWHT, KNRM);
#endif

#if 0
	/* Example of how to disable shuffling (if DEBUG mode) */
	if (hw_driver_disable_shuffling()) {
		printf("Error: hw_driver_disable_shuffling() returned exception\n\r");
		exit(EXIT_FAILURE);
	}
	printf("%sShuffling disabled%s\n\r", KWHT, KNRM);
#endif

#if 0
	/* Example of how to disable periodic Z-remask (if DEBUG mode) */
	if (hw_driver_disable_zremask()) {
		printf("Error: hw_driver_disable_zremask() returned exception\n\r");
		exit(EXIT_FAILURE);
	}
	printf("%sZ-remask disabled%s\n\r", KWHT, KNRM);
#endif

#if 0	
	/* Example of a microcode patch */
	if (hw_driver_patch_microcode_DBG(microcode, 499, 1)) {
		printf("Error: hw_driver_patch_microcode_DBG() returned exception\n\r");
		exit(EXIT_FAILURE);
	}
	printf("%sMicrocode was patched%s\n\r", KWHT, KNRM);
#endif

#if 0
	/* Example of how to completely disable TRNG and replace it with zeros
	 * (this revealed a bu, needs a FIXME) - Indeed it should have all [k]P
	 * computationbs wrong due to the Z-maksing, however they are still correct.
	 */
	if (hw_driver_bypass_full_trng_DBG(0)) {
		printf("Error: hw_driver_bypass_full_trng_DBG() returned exception\n\r");
		exit(EXIT_FAILURE);
	}
	printf("%sTRNG bypassed using all 0 values instead%s\n\r", KWHT, KNRM);
#endif

	/* Before entering the main loop, hook up the SIGINT signal
	 * to our own handler.
	 */
	signal(SIGINT, int_handler);

	/* Make cursor invisible from the terminal window.
	 */
	printf("%s", KCURSORINVIS);

	/* Main infinite loop, parsing lines from standard input to extract:
	 *   - input vectors
	 *   - type of operation
	 *   - expected result,
	 * then having the same computation done by hardware, and then
	 * checking the result of hardware against the expected one.
	 */

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
		 * machine on input vector test format.
		 */
		switch (line_type_expected) {

			case EXPECT_NONE:{
				/*
				 * Parse line.
				 */
				if ( (strncmp(line, "== NEW CURVE #", strlen("== NEW CURVE #"))) == 0 ) {
					/*
					 * Extract the curve nb, after '#' character.
					 */
					strtol_with_err(line + strlen("== NEW CURVE #"), &curve.id); /* NEW CURVE #x */
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
				} else if ( (strncmp(line, "== TEST P+Q #", strlen("== TEST P+Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST P+Q #") + i) == '.') {
							*(line + strlen("== TEST P+Q #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST P+Q #") + i + 1, &test.id);
					test.op = OP_PTADD;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "== TEST [2]P #", strlen("== TEST [2]P #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST [2]P #") + i) == '.') {
							*(line + strlen("== TEST [2]P #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST [2]P #") + i + 1, &test.id);
					test.op = OP_PTDBL;
					test.ptp.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "== TEST -P #", strlen("== TEST -P #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST -P #") + i) == '.') {
							*(line + strlen("== TEST -P #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST -P #") + i + 1, &test.id);
					test.op = OP_PTNEG;
					test.ptp.valid = false;
					test.pt_sw_res.valid = false;
					test.pt_hw_res.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "== TEST isPoncurve #", strlen("== TEST isPoncurve #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST isPoncurve #") + i) == '.') {
							*(line + strlen("== TEST isPoncurve #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST isPoncurve #") + i + 1, &test.id);
					test.op = OP_TST_CHK;
					test.ptp.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "== TEST isP==Q #", strlen("== TEST isP==Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST isP==Q #") + i) == '.') {
							*(line + strlen("== TEST isP==Q #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST isP==Q #") + i + 1, &test.id);
					test.op = OP_TST_EQU;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
					line_type_expected = EXPECT_PX;
				} else if ( (strncmp(line, "== TEST isP==-Q #", strlen("== TEST isP==-Q #"))) == 0 ) {
					/*
					 * Extract the computation nb, after '#' character.
					 */
					/* Determine position of the dot in the line. */
					for (i=0; ; i++) {
						if (*(line + strlen("== TEST isP==-Q #") + i) == '.') {
							*(line + strlen("== TEST isP==-Q #") + i) = '\0';
							break;
						}
					}
					strtol_with_err(line + strlen("== TEST isP==-Q #") + i + 1, &test.id);
					test.op = OP_TST_OPP;
					test.ptp.valid = false;
					test.ptq.valid = false;
					test.sw_answer.valid = false;
					test.hw_answer.valid = false;
					line_type_expected = EXPECT_PX;
				} else {
					printf("%sError: Could not find any of the expected commands from "
							"input file/stream.\n\r", KERR);
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
					PRINTF("%snn=%d\n\r%s", KINF, curve.nn, KNRM);
					line_type_expected = EXPECT_P;
					stats.nbcurves++;
					if (curve.nn > stats.nn_max) {
						stats.nn_max = curve.nn;
					}
					if (curve.nn < stats.nn_min) {
						stats.nn_min = curve.nn;
					}
					stats.nn_avr += curve.nn;
				} else {
					printf("%sError: Could not find the expected token \"nn=\" "
							"from input file/stream.\n\r", KERR);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NN)'", __LINE__);
				}
				break;
			}

			case EXPECT_P:{
				/* Parse line to extract value of p */
				if ( (strncmp(line, "p=0x", strlen("p=0x"))) == 0 ) {
					PRINTF("%sp=0x%s%s", KINF, line + strlen("p=0x"), KNRM);
					/*
					 * Process the hexadecimal value of p to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("p=0x"), test.curve->p.val, test.curve->nn, nread - strlen("p=0x")))
					{
						printf("%sError: Value of main curve parameter 'p' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P')", __LINE__);
					}
					test.curve->p.sz = DIV(test.curve->nn, 8);
					test.curve->p.valid = true;
					line_type_expected = EXPECT_A;
				} else {
					printf("%sError: Could not find the expected token \"p=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P')", __LINE__);
				}
				break;
			}

			case EXPECT_A:{
				/* Parse line to extract value of a */
				if ( (strncmp(line, "a=0x", strlen("a=0x"))) == 0 ) {
					PRINTF("%sa=0x%s%s", KINF, line + strlen("a=0x"), KNRM);
					/*
					 * Process the hexadecimal value of a to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("a=0x"), test.curve->a.val, test.curve->nn, nread - strlen("a=0x")))
					{
						printf("%sError: Value of curve parameter 'a' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_A')", __LINE__);
					}
					test.curve->a.sz = DIV(test.curve->nn, 8);
					test.curve->a.valid = true;
					line_type_expected = EXPECT_B;
				} else {
					printf("%sError: Could not find the expected token \"a=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_A')", __LINE__);
				}
				break;
			}

			case EXPECT_B:{
				/* Parse line to extract value of b/ */
				if ( (strncmp(line, "b=0x", strlen("b=0x"))) == 0 ) {
					PRINTF("%sb=0x%s%s", KINF, line + strlen("b=0x"), KNRM);
					/*
					 * Process the hexadecimal value of b to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("b=0x"), test.curve->b.val, test.curve->nn, nread - strlen("b=0x")))
					{
						printf("%sError: Value of curve parameter 'b' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
					}
					test.curve->b.sz = DIV(test.curve->nn, 8);
					test.curve->b.valid = true;
					line_type_expected = EXPECT_Q;
				} else {
					printf("%sError: Could not find the expected token \"b=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
				}
				break;
			}

			case EXPECT_Q:{
				/* Parse line to extract value of q. */
				if ( (strncmp(line, "q=0x", strlen("q=0x"))) == 0 )
				{
					PRINTF("%sq=0x%s%s", KINF, line + strlen("q=0x"), KNRM);
					/*
					 * Process the hexadecimal value of q to create the list
					 * of bytes to transfer to the IP (also set the size of
					 * the number).
					 */
					if (hex_to_large_num(
							line + strlen("q=0x"), test.curve->q.val, test.curve->nn, nread - strlen("q=0x")))
					{
						printf("%sError: Value of curve parameter 'q' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_Q')", __LINE__);
					}
					test.curve->q.sz = DIV(test.curve->nn, 8);
					test.curve->q.valid = true;
					test.curve->valid = true;
					/*
					 * Transfer curve parameters to the IP.
					 */
					if (ip_set_curve(test.curve))
					{
						printf("%sError: Could not transmit curve parameters to driver.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_Q')", __LINE__);
					}
					line_type_expected = EXPECT_NONE;
				} else {
					printf("%sError: Could not find the expected token \"q=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_B')", __LINE__);
				}
				break;
			}

			case EXPECT_PX:{
				/* Parse line to extract value of Px */
				if ( (strncmp(line, "Px=0x", strlen("Px=0x"))) == 0 ) {
					PRINTF("%sPx=0x%s%s", KINF, line + strlen("Px=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Px to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Px=0x"), test.ptp.x.val, test.curve->nn, nread - strlen("Px=0x")))
					{
						printf("%sError: Value of point coordinate 'Px' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
					}
					/*
					 * Position point P not to be null
					 */
					test.ptp.x.sz = DIV(test.curve->nn, 8);
					test.ptp.is_null = false;
					line_type_expected = EXPECT_PY;
				} else if ( (strncmp(line, "P=0", strlen("P=0"))) == 0 ) {
					PRINTF("%sP=0\n\r%s", KINF, KNRM);
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
						printf("%sError: unknown or undefined type of operation.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"Px=0x\" "
							"or \"P=0\" from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PX')", __LINE__);
				}
				break;
			}

			case EXPECT_PY:{
				/* Parse line to extract value of Py */
				if ( (strncmp(line, "Py=0x", strlen("Py=0x"))) == 0 ) {
					PRINTF("%sPy=0x%s%s", KINF, line + strlen("Py=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Py to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Py=0x"), test.ptp.y.val, test.curve->nn, nread - strlen("Py=0x")))
					{
						printf("%sError: Value of point coordinate 'Py' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
					}
					test.ptp.y.sz = DIV(test.curve->nn, 8);
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
						printf("%sError: unknown or undefined type of operation.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
					}
				} else {
					printf("%sError: Could not find the expected token \"Py=0x\" "
								"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_PY')", __LINE__);
				}
				break;
			}

			case EXPECT_QX:{
				/* Parse line to extract value of Qx. */
				if ( (strncmp(line, "Qx=0x", strlen("Qx=0x"))) == 0 ) {
					PRINTF("%sQx=0x%s%s", KINF, line + strlen("Qx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Qx to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Qx=0x"), test.ptq.x.val, test.curve->nn, nread - strlen("Qx=0x")))
					{
						printf("%sError: Value of point coordinate 'Qx' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
					}
					/*
					 * Position point Q not to be null.
					 */
					test.ptq.x.sz = DIV(test.curve->nn, 8);
					test.ptq.is_null = false;
					line_type_expected = EXPECT_QY;
				} else if ( (strncmp(line, "Q=0", strlen("Q=0"))) == 0 ) {
					PRINTF("%sQ=0\n\r%s", KINF, KNRM);
					/*
					 * Position point Q to be null.
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
						printf("%sError: unknown or undefined type of operation.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"Qx=0x\" "
							"or \"Q=0\" from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QX')", __LINE__);
				}
				break;
			}

			case EXPECT_QY:{
				/*
				 * Parse line to extract value of Py.
				 */
				if ( (strncmp(line, "Qy=0x", strlen("Qy=0x"))) == 0 ) {
					PRINTF("%sQy=0x%s%s", KINF, line + strlen("Qy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of Py to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("Qy=0x"), test.ptq.y.val, test.curve->nn, nread - strlen("Qy=0x")))
					{
						printf("%sError: Value of point coordinate 'Qy' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
					}
					test.ptq.y.sz = DIV(test.curve->nn, 8);
					test.ptq.valid = true;
					if (test.op == OP_PTADD) {
						line_type_expected = EXPECT_P_PLUS_QX;
					} else if (test.op == OP_TST_EQU) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else if (test.op == OP_TST_OPP) {
						line_type_expected = EXPECT_TRUE_OR_FALSE;
					} else {
						printf("%sError: unknown or undefined type of operation.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
					}
				} else {
					printf("%sError: Could not find the expected token \"Qy=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_QY')", __LINE__);
				}
				break;
			}

			case EXPECT_K:{
				/*
				 * Parse line to extract value of k.
				 */
				if ( (strncmp(line, "k=0x", strlen("k=0x"))) == 0 ) {
					PRINTF("%sk=0x%s%s", KINF, line + strlen("k=0x"), KNRM);
					/*
					 * Process the hexadecimal value of k to create the list
					 * of bytes to transfer to the IP.
					 */
					if (hex_to_large_num(
							line + strlen("k=0x"), test.k.val, test.curve->nn, nread - strlen("k=0x")))
					{
						printf("%sError: Value of scalar number 'k' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_K')", __LINE__);
					}
					test.k.sz = DIV(test.curve->nn, 8);
					test.k.valid = true;
					line_type_expected = EXPECT_KPX_OR_BLD;
				} else {
					printf("%sError: Could not find the expected token \"k=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_K')", __LINE__);
				}
				break;
			}

			case EXPECT_KPX_OR_BLD:{
				/*
				 * Parse line to extract possible nb of blinding bits.
				 * */
				if ( (strncmp(line, "nbbld=", strlen("nbbld="))) == 0 ) {
					PRINTF("%snbbld=%s%s", KINF, line + strlen("nbbld="), KNRM);
					if (strtol_with_err(line + strlen("nbbld="), &test.blinding))
					{
						printf("%sError: while converting \"nbbld=\" argument to a number.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/* Keep line_type_expected to EXPECT_KPX_OR_BLD to parse point [k]P coordinates */
				} else if ( (strncmp(line, "kPx=0x", strlen("kPx=0x"))) == 0 ) {
					PRINTF("%skPx=0x%s%s", KINF, line + strlen("kPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of kPx for comparison with HW.
					 */
					if (hex_to_large_num(
							line + strlen("kPx=0x"), test.pt_sw_res.x.val, test.curve->nn, nread - strlen("kPx=0x")))
					{
						printf("%sError: Value of point coordinate 'kPx' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/*
					 * Record that expected result point [k]P should not be null.
					 */
					test.pt_sw_res.x.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.is_null = false;
					line_type_expected = EXPECT_KPY;
				} else if ( (strncmp(line, "kP=0", strlen("kP=0"))) == 0 ) {
					PRINTF("%sExpected result point [k]P = 0\n\r%s", KINF, KNRM);
					/*
					 * Record that expected result point [k]P should be null.
					 */
					test.pt_sw_res.is_null = true;
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a [k]P computation test on hardware.
					 */
					if (ip_set_pt_and_run_kp(&test, &kp_trace_info))
					{
						stats.kp.nok++;
						stats.kp.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of scalar multiplication on hardware triggered an error.%s\n\r", KERR, KNRM);
						kp_error_log(&test);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/*
					 * Check IP result against the expected one (which is the point at infinity)
					 */
					if (check_kp_result(&test, &result_pts_are_equal, &kp_trace_info))
					{
						/*
						 * Dump [k]P trace log.
						 */
						kp_error_log(&test);
						stats.kp.nok++;
						stats.kp.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare [k]P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.kp.ok++;
					stats.kp.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
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
							"or \"kPx=0x\" or \"kP=0\" in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPX_OR_BLD')", __LINE__);
				}
				break;
			}

			case EXPECT_KPY:{
				/* Parse line to extract value of [k]Py (y of result) */
				if ( (strncmp(line, "kPy=0x", strlen("kPy=0x"))) == 0 ) {
					PRINTF("%skPy=0x%s%s", KINF, line + strlen("kPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of kPy for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("kPy=0x"), test.pt_sw_res.y.val, test.curve->nn, nread - strlen("kPy=0x")))
					{
						printf("%sError: Value of point coordinate 'kPy' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPY')", __LINE__);
					}
					test.pt_sw_res.y.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a [k]P computation test on harware.
					 */
					if (ip_set_pt_and_run_kp(&test, &kp_trace_info))
					{
						stats.kp.nok++;
						stats.kp.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of scalar multiplication on hardware triggered an error.%s\n\r", KERR, KNRM);
						kp_error_log(&test);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPY')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_kp_result(&test, &result_pts_are_equal, &kp_trace_info))
					{
						/*
						 * Dump [k]P trace log.
						 */
						kp_error_log(&test);
						stats.kp.nok++;
						stats.kp.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare [k]P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPY')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.kp.ok++;
					stats.kp.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find the expected token \"kPy=0x\" "
							"in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPY')", __LINE__);
				}
				break;
			}

			case EXPECT_P_PLUS_QX:{
				/*
				 * Parse line to extract value of (P+Q).x
				 */
				if ( (strncmp(line, "PplusQx=0x", strlen("PplusQx=0x"))) == 0 ) {
					PRINTF("%s(P+Q)x=0x%s%s", KINF, line + strlen("PplusQx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of (P+Q).x for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("PplusQx=0x"), test.pt_sw_res.x.val, test.curve->nn, nread - strlen("PplusQx=0x")))
					{
						printf("%sError: Value of point coordinate '(P+Q).x' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QX')", __LINE__);
					}
					test.pt_sw_res.x.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.is_null = false;
					line_type_expected = EXPECT_P_PLUS_QY;
				} else if ( (strncmp(line, "PplusQ=0", strlen("PplusQ=0"))) == 0 ) {
					PRINTF("%s(P+Q)=0%s", KINF, KNRM);
					test.pt_sw_res.is_null = true;
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a P + Q computation test on hardware.
					 */
					if (ip_set_pts_and_run_ptadd(&test))
					{
						stats.ptadd.nok++;
						stats.ptadd.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of P + Q on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QX')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptadd_result(&test, &result_pts_are_equal))
					{
						stats.ptadd.nok++;
						stats.ptadd.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare P + Q hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QX')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptadd.ok++;
					stats.ptadd.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find one of the expected tokens \"PplusQx=0x\" "
							"or \"(P+Q)=0\" in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_KPY')", __LINE__);
				}
				break;
			}

			case EXPECT_P_PLUS_QY:{
				/*
				 * Parse line to extract value of (P+Q).y
				 */
				if ( (strncmp(line, "PplusQy=0x", strlen("PplusQy=0x"))) == 0 ) {
					PRINTF("%s(P+Q)y=0x%s%s", KINF, line + strlen("PplusQy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of (P+Q).y for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("PplusQy=0x"), test.pt_sw_res.y.val, test.curve->nn,
							nread - strlen("PplusQy=0x")))
					{
						printf("%sError: Value of point coordinate '(P+Q).y' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QY')", __LINE__);
					}
					test.pt_sw_res.y.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a P + Q computation test on harware.
					 */
					if (ip_set_pts_and_run_ptadd(&test))
					{
						stats.ptadd.nok++;
						stats.ptadd.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of P + Q on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QY')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptadd_result(&test, &result_pts_are_equal))
					{
						stats.ptadd.nok++;
						stats.ptadd.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare P + Q hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QY')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptadd.ok++;
					stats.ptadd.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find the expected token \"PplusQy=0x\" "
							"in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_P_PLUS_QY')", __LINE__);
				}
				break;
			}

			case EXPECT_TWOP_X:{
				/*
				 * Parse line to extract value of [2]P.x
				 */
				if ( (strncmp(line, "twoPx=0x", strlen("twoPx=0x"))) == 0 ) {
					PRINTF("%s[2]P.x=0x%s%s", KINF, line + strlen("twoPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of [2]P.x for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("twoPx=0x"), test.pt_sw_res.x.val, test.curve->nn,
							nread - strlen("twoPx=0x")))
					{
						printf("%sError: Value of point coordinate '[2]P.x' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_X')", __LINE__);
					}
					test.pt_sw_res.x.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.is_null = false;
					line_type_expected = EXPECT_TWOP_Y;
				} else if ( (strncmp(line, "twoP=0", strlen("twoP=0"))) == 0 ) {
					PRINTF("%s[2]P=0\n\r%s", KINF, KNRM);
					test.pt_sw_res.is_null = true;
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a [2]P computation test on hardware.
					 */
					if (ip_set_pt_and_run_ptdbl(&test))
					{
						stats.ptdbl.nok++;
						stats.ptdbl.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of [2]P on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_X')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptdbl_result(&test, &result_pts_are_equal))
					{
						stats.ptdbl.nok++;
						stats.ptdbl.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare [2]P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_X')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptdbl.ok++;
					stats.ptdbl.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find one of the expected tokens \"twoPx=0x\" "
							"or \"twoP=0\" from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_X')", __LINE__);
				}
				break;
			}

			case EXPECT_TWOP_Y:{
				/*
				 * Parse line to extract value of [2]P.y
				 */
				if ( (strncmp(line, "twoPy=0x", strlen("twoPy=0x"))) == 0 ) {
					PRINTF("%s[2]P.y=0x%s%s", KINF, line + strlen("twoPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of [2]P.y for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("twoPy=0x"), test.pt_sw_res.y.val, test.curve->nn,
							nread - strlen("twoPy=0x")))
					{
						printf("%sError: Value of point coordinate '[2]P.y' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_Y')", __LINE__);
					}
					test.pt_sw_res.y.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a [2]P computation test on hardware.
					 */
					if (ip_set_pt_and_run_ptdbl(&test))
					{
						stats.ptdbl.nok++;
						stats.ptdbl.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of [2]P on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_Y')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptdbl_result(&test, &result_pts_are_equal))
					{
						stats.ptdbl.nok++;
						stats.ptdbl.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare [2]P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_Y')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptdbl.ok++;
					stats.ptdbl.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find the expected token \"twoPy=0x\" "
							"in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TWOP_Y')", __LINE__);
				}
				break;
			}

			case EXPECT_NEGP_X:{
				/*
				 * Parse line to extract value of -P.x
				 */
				if ( (strncmp(line, "negPx=0x", strlen("negPx=0x"))) == 0 ) {
					PRINTF("%s-P.x=0x%s%s", KINF, line + strlen("negPx=0x"), KNRM);
					/*
					 * Process the hexadecimal value of -P.x for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("negPx=0x"), test.pt_sw_res.x.val, test.curve->nn,
							nread - strlen("negPx=0x")))
					{
						printf("%sError: Value of point coordinate '(-P).x' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_X')", __LINE__);
					}
					test.pt_sw_res.x.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.is_null = false;
					line_type_expected = EXPECT_NEGP_Y;
				} else if ( (strncmp(line, "negP=0", strlen("negP=0"))) == 0 ) {
					PRINTF("%s-P=0\n\r%s", KINF, KNRM);
					test.pt_sw_res.is_null = true;
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a -P computation test on hardware.
					 */
					if (ip_set_pt_and_run_ptneg(&test))
					{
						stats.ptneg.nok++;
						stats.ptneg.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of -P on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_X')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptneg_result(&test, &result_pts_are_equal))
					{
						stats.ptneg.nok++;
						stats.ptneg.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare -P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_X')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptneg.ok++;
					stats.ptneg.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find one of the expected tokens \"negPx=0x\" "
							"or \"negP=0\" in input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_X')", __LINE__);
				}
				break;
			}

			case EXPECT_NEGP_Y:{
				/*
				 * Parse line to extract value of -P.y
				 */
				if ( (strncmp(line, "negPy=0x", strlen("negPy=0x"))) == 0 ) {
					PRINTF("%s-P.y=0x%s%s", KINF, line + strlen("negPy=0x"), KNRM);
					/*
					 * Process the hexadecimal value of -P.y for comparison with HW
					 */
					if (hex_to_large_num(
							line + strlen("negPy=0x"), test.pt_sw_res.y.val, test.curve->nn,
							nread - strlen("negPy=0x")))
					{
						printf("%sError: Value of point coordinate '(-P).y' could not be extracted "
								"from input file/stream.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_Y')", __LINE__);
					}
					test.pt_sw_res.y.sz = DIV(test.curve->nn, 8);
					test.pt_sw_res.valid = true;
					/*
					 * Set and execute a -P computation test on hardware.
					 */
					if (ip_set_pt_and_run_ptneg(&test))
					{
						stats.ptneg.nok++;
						stats.ptneg.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Computation of -P on hardware triggered an error.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_Y')", __LINE__);
					}
					/*
					 * Check IP result against the expected one.
					 */
					if (check_ptneg_result(&test, &result_pts_are_equal))
					{
						stats.ptneg.nok++;
						stats.ptneg.total++;
						stats.all.nok++;
						stats.all.total++;
						printf("%sError: Couldn't compare -P hardware result w/ the expected one.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_Y')", __LINE__);
					}
					/*
					 * Stats
					 */
					stats.ptneg.ok++;
					stats.ptneg.total++;
					stats.all.ok++;
					stats.all.total++;
					line_type_expected = EXPECT_NONE;
					print_stats_regularly(&stats, false);
#if 0
					/*
					 * Mark the next test to come as not being an exception (a priori)
					 * so that [k]P duration statistics only consider [k]P computations
					 * with no exception
					 */
					test.is_an_exception = false;
#endif
				} else {
					printf("%sError: Could not find the expected token \"negPy=0x\" "
							"from input file/stream.%s\n\r", KERR, KNRM);
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_NEGP_Y')", __LINE__);
				}
				break;
			}

			case EXPECT_TRUE_OR_FALSE:{
				/*
				 * Parse line to extract test answer (true or false)
				 */
				if ( (strncasecmp(line, "true", strlen("true"))) == 0 ) {
					PRINTF("%sanswer is true\n\r%s", KINF, KNRM);
					switch (test.op) {
						case OP_TST_CHK:
						case OP_TST_EQU:
						case OP_TST_OPP:
							test.sw_answer.answer = true;
							test.sw_answer.valid = true;
							break;
						default:{
							printf("%sError: Invalid test type.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
							break;
						}
					}
				} else if ( (strncasecmp(line, "false", strlen("false"))) == 0 ) {
					PRINTF("%sanswer is false\n\r%s", KINF, KNRM);
					switch (test.op) {
						case OP_TST_CHK:
						case OP_TST_EQU:
						case OP_TST_OPP:
							test.sw_answer.answer = false;
							test.sw_answer.valid = true;
							break;
						default:
							printf("%sError: Invalid test type.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
							break;
					}
				} else {
					printf("%sError: Could not find one of the expected tokens \"true\" "
							"or \"false\" from input file/stream for test \"%s\".%s\n\r", KERR, KNRM,
							( test.op == OP_TST_CHK ? "OP_TST_CHK" : (test.op == OP_TST_EQU ? "OP_TST_EQU" :
							  (test.op == OP_TST_OPP ? "OP_TST_OPP" : "UNKNOWN_TEST"))));
					print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
				}
				/*
				 * Set and execute one or two points on which to perform the test on hardware.
				 */
				switch (test.op) {
					case OP_TST_CHK:{
						if (ip_set_pt_and_check_on_curve(&test))
						{
							stats.test_crv.nok++;
							stats.test_crv.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Point test \"is on curve?\" on hardware triggered an error.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					case OP_TST_EQU:{
						if (ip_set_pts_and_test_equal(&test))
						{
							stats.test_equ.nok++;
							stats.test_equ.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Point test \"are pts equal?\" on hardware triggered an error.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					case OP_TST_OPP:{
						if (ip_set_pts_and_test_oppos(&test))
						{
							stats.test_opp.nok++;
							stats.test_opp.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Point test \"are pts opposite?\" on hardware triggered an error.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					default:{
						printf("%sError: Invalid test type.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						break;
					}
				}
				/*
				 * Check IP answer to the test against the expected one.
				 */
				switch (test.op) {
					case OP_TST_CHK:{
						if (check_test_oncurve(&test, &result_tests_are_identical))
						{
							stats.test_crv.nok++;
							stats.test_crv.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Couldn't compare hardware result to test \"is on curve?\" "
									"w/ the expected one.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					case OP_TST_EQU:{
						if (check_test_equal(&test, &result_tests_are_identical))
						{
							stats.test_equ.nok++;
							stats.test_equ.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Couldn't compare hardware result to test \"are pts equal?\" "
									"w/ the expected one.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					case OP_TST_OPP:{
						if (check_test_oppos(&test, &result_tests_are_identical))
						{
							stats.test_opp.nok++;
							stats.test_opp.total++;
							stats.all.nok++;
							stats.all.total++;
							printf("%sError: Couldn't compare hardware result to test \"are pts opposite?\" "
									"w/ the expected one.%s\n\r", KERR, KNRM);
							print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						}
						break;
					}
					default:{
						printf("%sError: Invalid test type.%s\n\r", KERR, KNRM);
						print_stats_and_exit(&test, &stats, "(debug info: in state 'EXPECT_TRUE_OR_FALSE')", __LINE__);
						break;
					}
				}
				stats.all.ok++;
				stats.all.total++;
				switch (test.op) {
					case OP_TST_CHK:{
						stats.test_crv.ok++;
						stats.test_crv.total++;
						break;
					}
					case OP_TST_EQU:{
						stats.test_equ.ok++;
						stats.test_equ.total++;
						break;
					}
					case OP_TST_OPP:{
						stats.test_opp.ok++;
						stats.test_opp.total++;
						break;
					}
					default:{
						break;
					}
				}
				line_type_expected = EXPECT_NONE;
				print_stats_regularly(&stats, false);
#if 0
				/*
				 * Mark the next test to come as not being an exception (a priori)
				 * so that [k]P duration statistics only consider [k]P computations
				 * with no exception
				 */
				test.is_an_exception = false;
#endif
				break;
			}

			default:{
				break;
			}
		} /* switch type of line */

		if (line_type_expected == EXPECT_NONE) {
			/*
			 * Reset a certain number of flags.
			 */
			test.ptp.valid = false;
			test.ptq.valid = false;
			test.pt_sw_res.valid = false;
			test.pt_hw_res.valid = false;
			test.sw_answer.valid = false;
			test.hw_answer.valid = false;
			test.k.valid = false;
			test.blinding = 0;
			test.op = OP_NONE;
			test.is_an_exception = false;
		}

	} /* while nread */

	/* End of main inf. loop
	 * (e.g TCP socket shutdown by 'nc -N' or Ctrl-C, or std input simply was closed).
	 *
	 * Before leaving, print stats, restore the cursor, a normal
	 * color and a not bold font in the terminal.
	 */
	int_handler(0);

	return EXIT_SUCCESS;
}
