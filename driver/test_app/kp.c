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

int ip_set_pt_and_run_kp(ipecc_test_t* t)
{
	int is_null;
	/*
	 * Sanity check.
	 * Verify that curve is is set.
	 * Verify that point P and scalar k are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for [k]P computation, assoc. curve not set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, input point P not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->k.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, scalar k not set.%s\n", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, X coord. of point P larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((t->k.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, scalar larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((t->blinding) >= (t->curve->nn)) {
		printf("%sError: Can't program IP for [k]P computation, blinding size larger than (or equal) to the current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, missing expected result of test.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_KP) {
		printf("%sError: Can't program IP for [k]P computation, operation type mismatch.%s\n", KERR, KNRM);
		goto err;
	}
	/*
	 * Configure blinding
	 */
	if (t->blinding) {
		hw_driver_set_blinding(t->blinding);
	} else {
		hw_driver_disable_blinding();
	}

	/*
	 * Send point info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R1 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(1)) {
			printf("%sError: Setting base point as the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R1 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(1)) {
			printf("%sError: Setting base point as not the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	t->pt_hw_res.x.sz = t->pt_hw_res.y.sz = t->ptp.x.sz;

	/* Run [k]P command */
	if (hw_driver_mul(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->k.val, t->k.sz,
			t->pt_hw_res.x.val, &(t->pt_hw_res.x.sz), t->pt_hw_res.y.val, &(t->pt_hw_res.y.sz)))
	{
		printf("%sError: [k]P computation by hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_mul() already set
	 * the coordinates of [k]P result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point is R1 */
		printf("%sError: Getting status of [k]P result point (at infinity or not) from hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}
	t->pt_hw_res.is_null = INT_TO_BOOLEAN(is_null);
	t->pt_hw_res.valid = true;

	return 0;
err:
	return -1;
}

int check_kp_result(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that computation was actually done on hardware.
	 */
	if (t->pt_hw_res.valid == false)
	{
		printf("%sError: Can't check result of [k]P against expected one, computation didn't happen on hardware.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Compare hardware result of [k]P against the expected one.
	 */
	if (t->pt_sw_res.is_null == true) {
		/*
		 * Expected result is that [k]P = 0 (aka point at infinity).
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * The hardware result is also the null point.
			 */
			PRINTF("[k]P = 0 as expected\n");
			*res = true;
			(st->ok)++;
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: [k]P mistmatch between hardware result and expected one.\n"
						 "         [k]P is not 0 however it should be.%s\n", KERR, KNRM);
#if 0
			status_detail();
			printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
			display_large_number(crv->nn, "p=0x", crv->p);
			display_large_number(crv->nn, "a=0x", crv->a);
			display_large_number(crv->nn, "b=0x", crv->b);
			display_large_number(crv->nn, "q=0x", crv->q);
			if (ptp->is_null == true) {
				printf("P=0\n");
			} else {
				display_large_number(crv->nn, "Px=0x", ptp->x);
				display_large_number(crv->nn, "Py=0x", ptp->y);
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
			*res = false;
			(st->nok)++;
			goto err;
		}
	} else {
		/*
		 * Expected result it that [k]P is different from the point at infinity.
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * Mismatch error (the hardware result is the null point).
			 */
			printf("%sError: [k]P mistmatch between hardware result and expected one.\n"
						 "         [k]P is 0 however it should not be.%s\n", KERR, KNRM);
#if 0
			status_detail();
			printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
			display_large_number(crv->nn, "p=0x", crv->p);
			display_large_number(crv->nn, "a=0x", crv->a);
			display_large_number(crv->nn, "b=0x", crv->b);
			display_large_number(crv->nn, "q=0x", crv->q);
			if (ptp->is_null == true) {
				printf("P=0\n");
			} else {
				display_large_number(crv->nn, "Px=0x", ptp->x);
				display_large_number(crv->nn, "Py=0x", ptp->y);
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
			*res = false;
			(st->nok)++;
			goto err;
		} else {
			/*
			 * Neither [k]P hardware result nor the expected one are null.
			 * Compare their coordinates.
			 */
			if (cmp_two_pts_coords(&(t->pt_sw_res), &(t->pt_hw_res), res))
			{
				printf("%sError when comparing coordinates of hardware [k]P result with the expected ones.%s\n", KERR, KNRM);
				goto err;
			}
			if (*res == true) {
				PRINTF("[k]P results match\n");
#if 0
				display_large_number(crv->nn, "SW: kPx = 0x", sw_kp->x);
				display_large_number(crv->nn, "    kPy = 0x", sw_kp->y);
				display_large_number(crv->nn, "HW: kPx = 0x", hw_kp->x);
				display_large_number(crv->nn, "    kPy = 0x", hw_kp->y);
#endif
				(st->ok)++;
			} else {
				/*
				 * Mismatch error (hardware [k]P coords & expected ones differ).
				 */
				printf("%sError: [k]P mistmatch between hardware coordinates and those of the expected result.%s\n", KERR, KNRM);
#if 0
				status_detail();
				printf("nn=%d (HW = %d)\n", crv->nn, READ_REG(R_PRIME_SIZE));
				display_large_number(crv->nn, "p=0x", crv->p);
				display_large_number(crv->nn, "a=0x", crv->a);
				display_large_number(crv->nn, "b=0x", crv->b);
				display_large_number(crv->nn, "q=0x", crv->q);
				if (ptp->is_null == true) {
					printf("P=0\n");
				} else {
					display_large_number(crv->nn, "Px=0x", ptp->x);
					display_large_number(crv->nn, "Py=0x", ptp->y);
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
				goto err;
			}
		}
	}

	return 0;
err:
	return -1;
}

