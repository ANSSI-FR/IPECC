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

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "test_app.h"

#if 0
/*
 * these functions are defined in helpers.c
 */
extern void set_no_blinding(void);
extern void set_blinding(uint32_t nbbld);
extern void write_large_number(uint32_t, uint32_t*, uint32_t, bool);
extern void set_r0_non_null(void);
extern void set_r0_null(void);
extern void set_r1_non_null(void);
extern void set_r1_null(void);
extern void run_kp(void);
extern void poll_until_ready(void);
extern bool get_r1_null_or_not_null(void);
extern void read_large_number(uint32_t, uint32_t*, uint32_t);
extern void display_large_number(uint32_t, const char*, uint32_t*);
extern void run_pt_add(void);
extern void run_pt_dbl(void);
extern void run_pt_neg(void);
extern bool print_error_if_any(void);
extern void status_detail(void);
extern void print_stats_and_exit();
extern void debug_read_large_number(uint32_t, uint32_t*, uint32_t);
extern void set_breakpoint(uint32_t, uint32_t);
extern void unset_breakpoint(uint32_t);
extern void resume_execution(void);
extern void poll_until_dbghalted(void);
extern void debug_write_opcode(uint32_t, uint32_t);
extern void single_step(void);
extern void clear_sw_ecc_fp_dram(uint32_t);
extern void load_ecc_fp_dram(uint32_t);
extern void diff_ecc_fp_dram(uint32_t);
extern void dbgwrite_one_limb_hw_ecc_fp_dram(uint32_t, uint32_t, uint32_t, uint32_t);
extern uint32_t dbgread_one_limb_hw_ecc_fp_dram(uint32_t, uint32_t, uint32_t);
extern uint32_t ge_power_of_2(uint32_t);
extern char* get_debug_str_state(uint32_t id);
extern void write_large_number(uint32_t, uint32_t*, uint32_t, bool);
extern void dbgread_all_limbs_hw_ecc_fp_dram(uint32_t lgnb, uint32_t* nbbuf,
		uint32_t nmax, uint32_t w);
extern void display_all_limbs_large_number(const char*, uint32_t* nbbuf, uint32_t w);
extern void debug_write_large_number(uint32_t, uint32_t*, uint32_t);
extern void dbgwrite_all_limbs_hw_ecc_fp_dram(uint32_t, uint32_t*, uint32_t, uint32_t);
extern void dbgread_all_limbs_of_number(uint32_t, uint32_t, uint32_t*, uint32_t);
extern void print_all_limbs_of_number(const char*, uint32_t, uint32_t*);
extern void get_exp_flags(struct flags_t*);
extern void read_and_display_xyr0(uint32_t, struct flags_t*);
extern void read_and_display_xyr1(uint32_t, struct flags_t*);
extern void read_and_display_zr01(uint32_t);
extern void set_trng_complete_bypass(uint32_t);
extern void unset_trng_complete_bypass(void);
#endif

#if 0
/*
 * this function is defined in redpit.c
 */
extern bool cmp_two_pts_coords(uint32_t, struct point_t*, struct point_t*);
#endif

extern uint32_t nbcurve;
extern uint32_t nbtest;
extern bool k_valid;

uint32_t w;

int ip_set_pt_and_run_kp(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_kp, uint32_t* nb_k, uint32_t nbbld, uint32_t* err)
{
	int ret;
	/*
	 * Sanity check. Verify that point P and scalar k are both set.
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for [k]P computation, "
				"point P isn't marked as valid\n%s", KERR, KNRM);
	}
	if (k_valid == false) {
		printf("%sERROR: can't program IP for [k]P computation, "
				"scalar k isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((pt_p->valid == false) || (k_valid == false)) {
		return -1;
	}
	/*
	 * Configure blinding
	 */
	if (nbbld) {
		hw_driver_set_blinding(nbbld);
	} else {
		hw_driver_disable_blinding();
	}

	/*
	 * Send point info & coordinates
	 */
	if (pt_p->is_null == false) {
		/* Set point R1 as being the null point
		 * (aka point at infinity. */
		hw_driver_point_zero(1);
	} else {
		/* Set point R1 as NOT being the null point
		 * (aka point at infinity. */
		hw_driver_point_unzero(1);
	}

	/*
	 * run [k]P command
	 */
	ret = hw_driver_mul(pt_p->x, pt_p->x_sz, pt_p->y, pt_p->y_sz,
	/*
	 * read-back [k]P result coords if result is not null
	 */
#if 0
	if (get_r1_null_or_not_null() == R1_NOT_NULL)
	{
		/*
		 * read coordinate X
		 */
		read_large_number(LARGE_NB_XR1_ADDR, pt_kp->x, nn);
		/*
		 * read coordinate Y
		 */
		read_large_number(LARGE_NB_YR1_ADDR, pt_kp->y, nn);
		/*
		 * set result not to be null in passed pointer
		 */
		pt_kp->is_null = false;
	} else {
		/*
		 * set result as null in passed pointer
		 */
		pt_kp->is_null = true;
	}
#endif
	pt_kp->valid = true;
	/*
	 * set error flags in passed pointer
	 */
#if 0
	*err = READ_REG(R_STATUS) & 0xffff0000;
#endif
} /* ip_set_pt_and_run_kp() */


void check_kp_result(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* hw_kp, struct point_t* sw_kp, uint32_t* nb_k,
		uint32_t nbbld, struct stats_t* st)
{
	if (sw_kp->valid == false) {
		printf("%sERROR: can't check correctness of [k]P computation, "
				"SW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if (hw_kp->valid == false) {
		printf("%sERROR: can't check correctness of [k]P computation, "
				"HW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((sw_kp->valid == false) || (hw_kp->valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	if (sw_kp->is_null == true) {
		if (hw_kp->is_null == true) {
#ifdef VERBOSE
			printf("[k]P = 0 as expected\n");
#endif
			(st->ok)++;
		} else {
			printf("%s", KERR);
			printf("---- ERROR when computing [k]P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: [k]P is not 0 but should be\n");
#if 0
			status_detail();
			printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
			display_large_number(crv->nn, "p=0x", crv->p);
			display_large_number(crv->nn, "a=0x", crv->a);
			display_large_number(crv->nn, "b=0x", crv->b);
			display_large_number(crv->nn, "q=0x", crv->q);
			if (pt_p->is_null == true) {
				printf("P=0\n");
			} else {
				display_large_number(crv->nn, "Px=0x", pt_p->x);
				display_large_number(crv->nn, "Py=0x", pt_p->y);
			}
			display_large_number(crv->nn, "k=0x", nb_k);
			if (nbbld) {
				printf("nbbld=%d\n", nbbld);
			}
			if (sw_kp->is_null == true) {
				printf("SW: [k]P = 0\n");
			} else {
				display_large_number(crv->nn, "SW: [k]Px=0x", sw_kp->x);
				display_large_number(crv->nn, "    [k]Py=0x", sw_kp->y);
			}
			if (hw_kp->is_null == true) {
				printf("HW: [k]P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: [k]Px=0x", hw_kp->x);
				display_large_number(crv->nn, "    [k]Py=0x", hw_kp->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		}
	} else {
		if (hw_kp->is_null == true) {
			printf("%s", KERR);
			printf("---- ERROR when computing [k]P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: [k]P = 0 but shouldn't be\n");
#if 0
			status_detail();
			printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
			display_large_number(crv->nn, "p=0x", crv->p);
			display_large_number(crv->nn, "a=0x", crv->a);
			display_large_number(crv->nn, "b=0x", crv->b);
			display_large_number(crv->nn, "q=0x", crv->q);
			if (pt_p->is_null == true) {
				printf("P=0\n");
			} else {
				display_large_number(crv->nn, "Px=0x", pt_p->x);
				display_large_number(crv->nn, "Py=0x", pt_p->y);
			}
			display_large_number(crv->nn, "k=0x", nb_k);
			if (nbbld) {
				printf("nbbld=%d\n", nbbld);
			}
			if (sw_kp->is_null == true) {
				printf("SW: [k]P = 0\n");
			} else {
				display_large_number(crv->nn, "SW: [k]Px=0x", sw_kp->x);
				display_large_number(crv->nn, "    [k]Py=0x", sw_kp->y);
			}
			if (hw_kp->is_null == true) {
				printf("HW: [k]P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: [k]Px=0x", hw_kp->x);
				display_large_number(crv->nn, "    [k]Py=0x", hw_kp->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		} else {
#if 0
			if (cmp_two_pts_coords(crv->nn, sw_kp, hw_kp) == true) {
#endif
			if (true) {
#ifdef VERBOSE
				printf("results match\n");
				display_large_number(crv->nn, "SW: kPx = 0x", sw_kp->x);
				display_large_number(crv->nn, "    kPy = 0x", sw_kp->y);
				display_large_number(crv->nn, "HW: kPx = 0x", hw_kp->x);
				display_large_number(crv->nn, "    kPy = 0x", hw_kp->y);
#endif
				(st->ok)++;
			} else {
				printf("%s", KERR);
				printf("---- ERROR when computing [k]P\n");
				printf("test #%d.%d\n", nbcurve, nbtest);
				printf("ERROR: HW/SW mismatch\n");
#if 0
				status_detail();
				printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
				display_large_number(crv->nn, "p=0x", crv->p);
				display_large_number(crv->nn, "a=0x", crv->a);
				display_large_number(crv->nn, "b=0x", crv->b);
				display_large_number(crv->nn, "q=0x", crv->q);
				if (pt_p->is_null == true) {
					printf("P=0\n");
				} else {
					display_large_number(crv->nn, "Px=0x", pt_p->x);
					display_large_number(crv->nn, "Py=0x", pt_p->y);
				}
				display_large_number(crv->nn, "k=0x", nb_k);
				if (nbbld) {
					printf("nbbld=%d\n", nbbld);
				}
				if (sw_kp->is_null == true) {
					printf("SW: [k]P = 0\n");
				} else {
					display_large_number(crv->nn, "SW: [k]Px=0x", sw_kp->x);
					display_large_number(crv->nn, "    [k]Py=0x", sw_kp->y);
				}
				if (hw_kp->is_null == true) {
					printf("HW: [k]P = 0\n");
				} else {
					display_large_number(crv->nn, "HW: [k]Px=0x", hw_kp->x);
					display_large_number(crv->nn, "    [k]Py=0x", hw_kp->y);
				}
				printf("%s", KNRM);
				WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
				(st->nok)++;
#ifdef LEAVE_ON_ERROR
				printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
#if 0
				print_stats_and_exit();
#endif
#endif
			}
		}
	}
}

