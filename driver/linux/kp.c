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
#include "ecc-test-linux.h"

extern int cmp_two_pts_coords(point_t*, point_t*, bool*);

int ip_set_pt_and_run_kp(ipecc_test_t* t)
{
	int is_null;
#ifdef KP_TRACE
	unsigned int i;
#endif
	/*
	 * Sanity check.
	 * Verify that curve is is set.
	 * Verify that point P and scalar k are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for [k]P computation, assoc. curve not set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, input point P not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->k.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, scalar k not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, X coord. of point P larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->k.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [k]P computation, scalar larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->blinding) >= (t->curve->nn)) {
		printf("%sError: Can't program IP for [k]P computation, blinding size larger than (or equal) to the current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for [k]P computation, missing expected result of test.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_KP) {
		printf("%sError: Can't program IP for [k]P computation, operation type mismatch.%s\n\r", KERR, KNRM);
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
			printf("%sError: Setting base point as the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R1 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(1)) {
			printf("%sError: Setting base point as not the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	}

	t->pt_hw_res.x.sz = t->pt_hw_res.y.sz = t->ptp.x.sz;

	/* (RE-)initialize struct kp_trace_info_t fields
	 * before calling driver API.
	 */
	for (i=0;i<DIV(t->ktrc->nn, 32); i++) {
		t->ktrc->lambda[i] = 0;
		t->ktrc->lambda_valid = false;
		t->ktrc->phi0[i] = 0;
		t->ktrc->phi0_valid = false;
		t->ktrc->phi1[i] = 0;
		t->ktrc->phi1_valid = false;
		t->ktrc->alpha[i] = 0;
		t->ktrc->alpha_valid = false;
	}
	t->ktrc->nb_steps = 0;
	t->ktrc->msgsz = 0;
	t->ktrc->msgsz_max = KP_TRACE_PRINTF_SZ;
#if 0
	/* Clear [k]P trace log buffer (hoping a DMA will do this...) */
	bzero(t->ktrc->msg, KP_TRACE_PRINTF_SZ);
#endif
	t->ktrc->nn = t->curve->nn;

	/* Run [k]P command */
	if (hw_driver_mul(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->k.val, t->k.sz,
			t->pt_hw_res.x.val, &(t->pt_hw_res.x.sz), t->pt_hw_res.y.val, &(t->pt_hw_res.y.sz), t->ktrc))
	{
		printf("%sError: [k]P computation by hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_mul() already set
	 * the coordinates of [k]P result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point is R1 */
		printf("%sError: Getting status of [k]P result point (at infinity or not) from hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}
	t->pt_hw_res.is_null = INT_TO_BOOLEAN(is_null);
	t->pt_hw_res.valid = true;

	return 0;
err:
	return -1;
}

int check_kp_result(ipecc_test_t* t, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that computation was actually done on hardware.
	 */
	if (t->pt_hw_res.valid == false)
	{
		printf("%sError: Can't check result of [k]P against expected one, computation didn't happen on hardware.%s\n\r", KERR, KNRM);
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
			PRINTF("[k]P = 0 as expected\n\r");
			*res = true;
			/* (st->ok)++; */
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: [k]P mistmatch between hardware result and expected one.\n\r"
						 "       [k]P is not 0 however it should be.%s\n\r", KERR, KNRM);
			*res = false;
			/* (st->nok)++; */
			goto err;
		}
	} else {
		/*
		 * Expected result is that [k]P is different from the point at infinity.
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * Mismatch error (the hardware result is the null point).
			 */
			printf("%sError: [k]P mistmatch between hardware result and expected one.\n\r"
						 "       [k]P is 0 however it should not be.%s\n\r", KERR, KNRM);
			*res = false;
			/* (st->nok)++; */
			goto err;
		} else {
			/*
			 * Neither [k]P hardware result nor the expected one are null.
			 * Compare their coordinates.
			 */
			if (cmp_two_pts_coords(&(t->pt_sw_res), &(t->pt_hw_res), res))
			{
				printf("%sError when comparing coordinates of hardware [k]P result with the expected ones.%s\n\r", KERR, KNRM);
				goto err;
			}
#if 0
			printf("t->pt_hw_res.x = 0x%02x%02x\n\r", (t->pt_hw_res).x.val[0], (t->pt_hw_res).x.val[1]);
			printf("t->pt_hw_res.y = 0x%02x%02x\n\r", (t->pt_hw_res).y.val[0], (t->pt_hw_res).y.val[1]);
#endif
			if (*res == true) {
				PRINTF("[k]P results match\n\r");	
				/* (st->ok)++; */
			} else {
				/*
				 * Mismatch error (hardware [k]P coords & expected ones differ).
				 */
				printf("%sError: [k]P mistmatch between hardware coordinates and those of the expected result.%s\n\r", KERR, KNRM);
				/* (st->nok)++; */
				goto err;
			}
		}
	}

	return 0;
err:
	return -1;
}

void print_large_number(const char* msg, large_number_t* lg)
{
	uint32_t i;

	printf("%s%s", KCYN, msg);
	for(i=0; i<lg->sz; i++) {
		printf("%02x", lg->val[i]);
	}
	printf("%s\n\r", KNRM);
}

int kp_error_log(ipecc_test_t* t)
{
	printf("%sERROR ON TEST %d.%d%s\n\r", KRED, t->curve->id, t->id, KNRM);
	printf("%sCurve and point definition:\n\r", KCYN);
	printf("nn=%d%s\n\r", t->curve->nn, KNRM);
	print_large_number("p=0x", &(t->curve->p));
	print_large_number("a=0x", &(t->curve->a));
	print_large_number("b=0x", &(t->curve->b));
	if (t->curve->q.valid == true) {
		print_large_number("q=0x", &(t->curve->q));
	}
	print_large_number("Px=0x", &(t->ptp.x));
	print_large_number("Py=0x", &(t->ptp.y));
	print_large_number("k=0x", &(t->k));
	print_large_number("Expected kPx=0x", &(t->pt_sw_res.x));
	print_large_number("Expected kPy=0x", &(t->pt_sw_res.y));
	printf("%s<DEBUG LOG TRACE OF [k]P:%s\n\r", KRED, KNRM);
	printf("%s%s%s", KWHT, t->ktrc->msg, KNRM);
	printf("%sEND OF DEBUG LOG TRACE>%s\n\r", KRED, KNRM);

	return 0;
}
