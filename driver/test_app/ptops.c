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
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "test_app.h"

extern int cmp_two_pts_coords(point_t*, point_t*, bool*);

int ip_set_pts_and_run_ptadd(ipecc_test_t* t)
{
	int is_null;
	/*
	 * Sanity check.
	 * Verify that curve is is set.
	 * Verify that points P and Q are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for P + Q computation, assoc. curve not set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, input point P not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, input point Q not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for P + Q computation, X coord. of point P larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for P + Q computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for P + Q computation, X coord. of point Q larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for P + Q computation, Y coord. of point Q larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, missing expected result of test.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_PTADD) {
		printf("%sError: Can't program IP for P + Q computation, operation type mismatch.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Send point P info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R0 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(0)) {
			printf("%sError: Setting point P as the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R0 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(0)) {
			printf("%sError: Setting point P as not the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	/*
	 * Send point Q info & coordinates
	 */
	if (t->ptq.is_null == true) {
		/* Set point R1 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(1)) {
			printf("%sError: Setting point Q as the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R1 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(1)) {
			printf("%sError: Setting point Q as not the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	/* Run P + Q command */
	if (hw_driver_add(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->ptq.x.val, t->ptq.x.sz,
				t->ptq.y.val, t->ptq.y.sz, t->pt_hw_res.x.val, &(t->pt_hw_res.x.sz), t->pt_hw_res.y.val,
				&(t->pt_hw_res.y.sz)))
	{
		printf("%sError: P + Q computation by hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_add() already set
	 * the coordinates of P + Q result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point is R1 */
		printf("%sError: Getting status of P + Q result point (at infinity or not) from hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}
	t->pt_hw_res.is_null = INT_TO_BOOLEAN(is_null);
	t->pt_hw_res.valid = true;

	return 0;
err:
	return -1;
}

int check_ptadd_result(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that computation was actually done on hardware.
	 */
	if (t->pt_hw_res.valid == false)
	{
		printf("%sError: Can't check result of P + Q against expected one, computation didn't happen on hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.is_null == true) {
		/*
		 * Expected result is that P + Q = 0 (aka point at infinity).
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * The hardware result is also the null point.
			 */
			PRINTF("P + Q = 0 as expected\n");
			*res = true;
			(st->ok)++;
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: P + Q mistmatch between hardware result and expected one.\n"
						 "         P + Q is not 0 however it should be.%s\n", KERR, KNRM);
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
			if (pt_q->is_null == true) {
				printf("Q=0\n");
			} else {
				display_large_number(crv->nn, "Qx=0x", pt_q->x);
				display_large_number(crv->nn, "Qy=0x", pt_q->y);
			}
			if (sw_pplusq->is_null == true) {
				printf("SW: P + Q = 0\n");
			} else {
				display_large_number(crv->nn, "SW: (P+Q)x=0x", sw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y=0x", sw_pplusq->y);
			}
			if (hw_pplusq->is_null == true) {
				printf("HW: P + Q = 0\n");
			} else {
				display_large_number(crv->nn, "HW: (P+Q)x=0x", hw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y=0x", hw_pplusq->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
			*res = false;
			(st->nok)++;
			goto err;
		}
	} else {
		/*
		 * Expected result it that P + Q is different from the point at infinity.
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * Mismatch error (the hardware result is the null point).
			 */
			printf("%sError: P + Q mistmatch between hardware result and expected one.\n"
						 "         P + Q is 0 however it should not be.%s\n", KERR, KNRM);
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
			if (pt_q->is_null == true) {
				printf("Q=0\n");
			} else {
				display_large_number(crv->nn, "Qx=0x", pt_q->x);
				display_large_number(crv->nn, "Qy=0x", pt_q->y);
			}
			if (sw_pplusq->is_null == true) {
				printf("SW: P + Q = 0\n");
			} else {
				display_large_number(crv->nn, "SW: (P+Q)x=0x", sw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y=0x", sw_pplusq->y);
			}
			if (hw_pplusq->is_null == true) {
				printf("HW: P + Q = 0\n");
			} else {
				display_large_number(crv->nn, "HW: (P+Q)x=0x", hw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y=0x", hw_pplusq->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
			*res = false;
			(st->nok)++;
			goto err;
		} else {
			/*
			 * Neither P + Q hardware result nor the expected one are null.
			 * Compare their coordinates.
			 */
			if (cmp_two_pts_coords(&(t->pt_sw_res), &(t->pt_hw_res), res))
			{
				printf("%sError when comparing coordinates of hardware P + Q result with the expected ones.%s\n", KERR, KNRM);
				goto err;
			}
			if (*res == true) {
				PRINTF("P + Q results match\n");
#if 0
				display_large_number(crv->nn, "SW: (P+Q)x = 0x", sw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y = 0x", sw_pplusq->y);
				display_large_number(crv->nn, "HW: (P+Q)x = 0x", hw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y = 0x", hw_pplusq->y);
#endif
				(st->ok)++;
			} else {
				/*
				 * Mismatch error (hardware [k]P coords & expected ones differ).
				 */
				printf("%sError: P + Q mistmatch between hardware coordinates and those of the expected result.%s\n", KERR, KNRM);
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
				if (pt_q->is_null == true) {
					printf("Q=0\n");
				} else {
					display_large_number(crv->nn, "Qx=0x", pt_q->x);
					display_large_number(crv->nn, "Qy=0x", pt_q->y);
				}
				if (sw_pplusq->is_null == true) {
					printf("SW: P + Q = 0\n");
				} else {
					display_large_number(crv->nn, "SW: (P+Q)x=0x", sw_pplusq->x);
					display_large_number(crv->nn, "    (P+Q)y=0x", sw_pplusq->y);
				}
				if (hw_pplusq->is_null == true) {
					printf("HW: P + Q = 0\n");
				} else {
					display_large_number(crv->nn, "HW: (P+Q)x=0x", hw_pplusq->x);
					display_large_number(crv->nn, "    (P+Q)y=0x", hw_pplusq->y);
				}
				printf("%s", KNRM);
				WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
				(st->nok)++;
				goto err;
			}
		}
	}
	return 0;
err:
	return -1;
}

#if 0
void ip_set_pt_and_run_ptdbl(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_twop, uint32_t* err)
{
	/*
	 * verify that point P is valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for [2]P computation, "
				"point P isn't marked as valid\n%s", KERR, KNRM);
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	/*
	 * send point P info & coordinates (into R0)
	 */
	if (pt_p->is_null == false) {
		/*
		 * send Px
		 */
		write_large_number(LARGE_NB_XR0_ADDR, pt_p->x, nn, false);
		/*
		 * send Py
		 */
		write_large_number(LARGE_NB_YR0_ADDR, pt_p->y, nn, false);
		/*
		 * set R0 as a non null point
		 */
		set_r0_non_null();
	} else {
		/*
		 * set R0 to be the null point
		 */
		set_r0_null();
	}
	/*
	 * run [2]P (PT_DBL) command
	 */
	run_pt_dbl();
	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
	/*
	 * read-back [2]P result coords (from R1) if result is not null
	 */
	if (get_r1_null_or_not_null() == R1_NOT_NULL)
	{
		/*
		 * read coordinate X
		 */
		read_large_number(LARGE_NB_XR1_ADDR, pt_twop->x, nn);
		/*
		 * read coordinate Y
		 */
		read_large_number(LARGE_NB_YR1_ADDR, pt_twop->y, nn);
		/*
		 * set result not to be null in passed pointer
		 */
		pt_twop->is_null = false;
	} else {
		/*
		 * set result as null in passed pointer
		 */
		pt_twop->is_null = true;
	}
	/*
	 * mark HW resulting point as valid 
	 */
	pt_twop->valid = true;
	/*
	 * set error flags in passed pointer
	 */
	*err = READ_REG(R_STATUS) & 0xffff0000;
}

void check_ptdbl_result(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* sw_twop, struct point_t* hw_twop, struct stats_t* st)
{
	if (sw_twop->valid == false) {
		printf("%sERROR: can't check correctness of [2]P computation, "
				"SW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if (hw_twop->valid == false) {
		printf("%sERROR: can't check correctness of [2]P computation, "
				"HW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((sw_twop->valid == false) || (hw_twop->valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	if (sw_twop->is_null == true) {
		if (hw_twop->is_null == true) {
#ifdef VERBOSE
			printf("[2]P = 0 as expected\n");
#endif
			(st->ok)++;
		} else {
			printf("%s", KERR);
			printf("---- ERROR when computing [2]P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: [2]P is not 0 but should be\n");
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
			if (sw_twop->is_null == true) {
				printf("SW: 2[P] = 0\n");
			} else {
				display_large_number(crv->nn, "SW: [2]Px=0x", sw_twop->x);
				display_large_number(crv->nn, "    [2]Py=0x", sw_twop->y);
			}
			if (hw_twop->is_null == true) {
				printf("HW: [2]P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: [2]Px=0x", hw_twop->x);
				display_large_number(crv->nn, "    [2]Py=0x", hw_twop->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		}
	} else {
		if (hw_twop->is_null == true) {
			printf("%s", KERR);
			printf("---- ERROR when computing [2]P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: [2]P = 0 but shouldn't be\n");
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
			if (sw_twop->is_null == true) {
				printf("SW: [2]P = 0\n");
			} else {
				display_large_number(crv->nn, "SW: [2]Px=0x", sw_twop->x);
				display_large_number(crv->nn, "    [2]Py=0x", sw_twop->y);
			}
			if (hw_twop->is_null == true) {
				printf("HW: [2]P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: [2]Px=0x", hw_twop->x);
				display_large_number(crv->nn, "    [2]Py=0x", hw_twop->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
			(st->nok)++;
		} else {
			/*
			 * compare software client & hardware IP coordinates
			 */
			if (cmp_two_pts_coords(crv->nn, sw_twop, hw_twop) == true) {
#ifdef VERBOSE
				printf("results match\n");
				display_large_number(crv->nn, "SW: [2]Px = 0x", sw_twop->x);
				display_large_number(crv->nn, "    [2]Py = 0x", sw_twop->y);
				display_large_number(crv->nn, "HW: [2]Px = 0x", hw_twop->x);
				display_large_number(crv->nn, "    [2]Py = 0x", hw_twop->y);
#endif
				(st->ok)++;
			} else {
				printf("%s", KERR);
				printf("---- ERROR when computing [2]P\n");
				printf("test #%d.%d\n", nbcurve, nbtest);
				printf("ERROR: HW/SW mismatch\n");
				status_detail();
				printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
				display_large_number(crv->nn, "p=0x", crv->p);
				display_large_number(crv->nn, "a=0x", crv->a);
				display_large_number(crv->nn, "b=0x", crv->b);
				display_large_number(crv->nn, "q=0x", crv->q);
				display_large_number(crv->nn, "SW: [2]Px = 0x", sw_twop->x);
				display_large_number(crv->nn, "    [2]Py = 0x", sw_twop->y);
				display_large_number(crv->nn, "HW: [2]Px = 0x", hw_twop->x);
				display_large_number(crv->nn, "    [2]Py = 0x", hw_twop->y);
				printf("%s", KNRM);
				WRITE_REG(W_ERR_ACK, 0xffff0000);
				(st->nok)++;
#ifdef LEAVE_ON_ERROR
				printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
				print_stats_and_exit();
#endif
			}
		}
	}
}

void ip_set_pt_and_run_ptneg(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_negp, uint32_t* err)
{
	/*
	 * verify that point P is valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for -P computation, "
				"point P isn't marked as valid\n%s", KERR, KNRM);
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	/*
	 * send point P info & coordinates (into R0)
	 */
	if (pt_p->is_null == false) {
		/*
		 * send Px
		 */
		write_large_number(LARGE_NB_XR0_ADDR, pt_p->x, nn, false);
		/*
		 * send Py
		 */
		write_large_number(LARGE_NB_YR0_ADDR, pt_p->y, nn, false);
		/*
		 * set R0 as a non null point
		 */
		set_r0_non_null();
	} else {
		/*
		 * set R0 to be the null point
		 */
		set_r0_null();
	}
	/*
	 * run -P (PT_NEG) command
	 */
	run_pt_neg();
	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
	/*
	 * read-back -P result coords (from R1) if result is not null
	 */
	if (get_r1_null_or_not_null() == R1_NOT_NULL)
	{
		/*
		 * read coordinate X
		 */
		read_large_number(LARGE_NB_XR1_ADDR, pt_negp->x, nn);
		/*
		 * read coordinate Y
		 */
		read_large_number(LARGE_NB_YR1_ADDR, pt_negp->y, nn);
		/*
		 * set result not to be null in passed pointer
		 */
		pt_negp->is_null = false;
	} else {
		/*
		 * set result as null in passed pointer
		 */
		pt_negp->is_null = true;
	}
	/*
	 * mark HW resulting point as valid 
	 */
	pt_negp->valid = true;
	/*
	 * set error flags in passed pointer
	 */
	*err = READ_REG(R_STATUS) & 0xffff0000;
}

void check_ptneg_result(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* sw_negp, struct point_t* hw_negp, struct stats_t* st)
{
	if (sw_negp->valid == false) {
		printf("%sERROR: can't check correctness of -P computation, "
				"SW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if (hw_negp->valid == false) {
		printf("%sERROR: can't check correctness of -P computation, "
				"HW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((sw_negp->valid == false) || (hw_negp->valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	if (sw_negp->is_null == true) {
		if (hw_negp->is_null == true) {
#ifdef VERBOSE
			printf("-P = 0 as expected\n");
#endif
			(st->ok)++;
		} else {
			printf("%s", KERR);
			printf("---- ERROR when computing -P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: -P is not 0 but should be\n");
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
			if (sw_negp->is_null == true) {
				printf("SW: -P = 0\n");
			} else {
				display_large_number(crv->nn, "SW: -Px=0x", sw_negp->x);
				display_large_number(crv->nn, "    -Py=0x", sw_negp->y);
			}
			if (hw_negp->is_null == true) {
				printf("HW: -P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: -Px=0x", hw_negp->x);
				display_large_number(crv->nn, "    -Py=0x", hw_negp->y);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		}
	} else {
		if (hw_negp->is_null == true) {
			printf("%s", KERR);
			printf("---- ERROR when computing -P\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: -P = 0 but shouldn't be\n");
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
			if (sw_negp->is_null == true) {
				printf("SW: -P = 0\n");
			} else {
				display_large_number(crv->nn, "SW: -Px=0x", sw_negp->x);
				display_large_number(crv->nn, "    -Py=0x", sw_negp->y);
			}
			if (hw_negp->is_null == true) {
				printf("HW: -P = 0\n");
			} else {
				display_large_number(crv->nn, "HW: -Px=0x", hw_negp->x);
				display_large_number(crv->nn, "    -Py=0x", hw_negp->y);
				printf("%s", KNRM);
			}
			printf("%s", KNRM);
			WRITE_REG(W_ERR_ACK, 0xffff0000);
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		} else {
			/*
			 * compare software client & hardware IP coordinates
			 */
			if (cmp_two_pts_coords(crv->nn, sw_negp, hw_negp) == true) {
#ifdef VERBOSE
				printf("results match\n");
				display_large_number(crv->nn, "SW: -Px = 0x", sw_negp->x);
				display_large_number(crv->nn, "    -Py = 0x", sw_negp->y);
				display_large_number(crv->nn, "HW: -Px = 0x", hw_negp->x);
				display_large_number(crv->nn, "    -Py = 0x", hw_negp->y);
#endif
				(st->ok)++;
			} else {
				printf("%s", KERR);
				printf("---- ERROR when computing -P\n");
				printf("test #%d.%d\n", nbcurve, nbtest);
				printf("ERROR: HW/SW mismatch\n");
				printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
				status_detail();
				display_large_number(crv->nn, "p=0x", crv->p);
				display_large_number(crv->nn, "a=0x", crv->a);
				display_large_number(crv->nn, "b=0x", crv->b);
				display_large_number(crv->nn, "q=0x", crv->q);
				display_large_number(crv->nn, "SW: -Px = 0x", sw_negp->x);
				display_large_number(crv->nn, "    -Py = 0x", sw_negp->y);
				display_large_number(crv->nn, "HW: -Px = 0x", hw_negp->x);
				display_large_number(crv->nn, "    -Py = 0x", hw_negp->y);
				printf("%s", KNRM);
				WRITE_REG(W_ERR_ACK, 0xffff0000);
				(st->nok)++;
#ifdef LEAVE_ON_ERROR
				printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
				print_stats_and_exit();
#endif
			}
		}
	}
}
#endif
