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

int ip_set_pts_and_run_ptadd(ipecc_test_t* t)
{
	int is_null;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that points P and Q are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for P + Q computation, assoc. curve not set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, input point P not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->ptq.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, input point Q not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for P + Q computation, X coord. of point P larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for P + Q computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptq.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for P + Q computation, X coord. of point Q larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptq.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for P + Q computation, Y coord. of point Q larger than currrent curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for P + Q computation, missing expected result of test.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_PTADD) {
		printf("%sError: Can't program IP for P + Q computation, operation type mismatch.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Send point P info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R0 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(0)) {
			printf("%sError: Setting point P as the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R0 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(0)) {
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	}
	/*
	 * Send point Q info & coordinates
	 */
	if (t->ptq.is_null == true) {
		/* Set point R1 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(1)) {
			printf("%sError: Setting point Q as the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R1 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(1)) {
			printf("%sError: Setting point Q as diff. from the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	}

	/* Run P + Q command */
	if (hw_driver_add(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->ptq.x.val, t->ptq.x.sz,
				t->ptq.y.val, t->ptq.y.sz, t->pt_hw_res.x.val, &(t->pt_hw_res.x.sz), t->pt_hw_res.y.val,
				&(t->pt_hw_res.y.sz)))
	{
		printf("%sError: P + Q computation by hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_add() already set
	 * the coordinates of P + Q result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point assumed to be R1 */
		printf("%sError: Getting status of P + Q result point (at infinity or not) from hardware triggered an error.%s\n\r", KERR, KNRM);
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
		printf("%sError: Can't check result of P + Q against expected one, computation didn't happen on hardware.%s\n\r", KERR, KNRM);
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
			PRINTF("P + Q = 0 as expected\n\r");
			*res = true;
			(st->ok)++;
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: P + Q mismatch between hardware result and expected one.\n\r"
						 "         P + Q is not 0 however it should be.%s\n\r", KERR, KNRM);
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
			printf("%sError: P + Q mismatch between hardware result and expected one.\n\r"
						 "         P + Q is 0 however it should not be.%s\n\r", KERR, KNRM);
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
				printf("%sError when comparing coordinates of hardware P + Q result with the expected ones.%s\n\r", KERR, KNRM);
				goto err;
			}
			if (*res == true) {
				PRINTF("P + Q results match\n\r");
				(st->ok)++;
			} else {
				/*
				 * Mismatch error (hardware P + Q coords & expected ones differ).
				 */
				printf("%sError: P + Q mismatch between hardware coordinates and those of the expected result.%s\n\r", KERR, KNRM);
				(st->nok)++;
				goto err;
			}
		}
	}
	return 0;
err:
	return -1;
}

int ip_set_pt_and_run_ptdbl(ipecc_test_t* t)
{
	int is_null;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that point P is set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for [2]P computation, assoc. curve not set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for [2]P computation, input point P not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [2]P computation, X coord. of point P larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for [2]P computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for [2]P computation, missing expected result of test.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_PTDBL) {
		printf("%sError: Can't program IP for [2]P computation, operation type mismatch.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Send point P info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R0 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R0 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	}

	/* Run [2]P command */
	if (hw_driver_dbl(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->pt_hw_res.x.val,
				&(t->pt_hw_res.x.sz), t->pt_hw_res.y.val, &(t->pt_hw_res.y.sz)))
	{
		printf("%sError: [2]P computation by hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_dbl() already set
	 * the coordinates of [2]P result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point assumed to be R1 */
		printf("%sError: Getting status [2]P result point (at infinity or not) from hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}
	t->pt_hw_res.is_null = INT_TO_BOOLEAN(is_null);
	t->pt_hw_res.valid = true;

	return 0;
err:
	return -1;
}

int check_ptdbl_result(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that computation was actually done on hardware.
	 */
	if (t->pt_hw_res.valid == false)
	{
		printf("%sError: Can't check result of [2]P against expected one, computation didn't happen on hardware.%s\n\r", KERR, KNRM);
		goto err;
	}

	if (t->pt_sw_res.is_null == true) {
		/*
		 * Expected result is that [2]P = 0 (aka point at infinity).
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * The hardware result is also the null point.
			 */
			PRINTF("[2]P = 0 as expected\n\r");
			*res = true;
			(st->ok)++;
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: [2]P mismatch between hardware result and expected one.\n\r"
						 "         [2]P is not 0 however it should be.%s\n\r", KERR, KNRM);
			*res = false;
			(st->nok)++;
			goto err;
		}
	} else {
		/*
		 * Expected result it that [2]P is different from the point at infinity.
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * Mismatch error (the hardware result is the null point).
			 */
			printf("%sError: [2]P mismatch between hardware result and expected one.\n\r"
						 "         [2]P is 0 however it should not be.%s\n\r", KERR, KNRM);
			*res = false;
			(st->nok)++;
			goto err;
		} else {
			/*
			 * Neither [2]P hardware result nor the expected one are null.
			 * Compare their coordinates.
			 */
			if (cmp_two_pts_coords(&(t->pt_sw_res), &(t->pt_hw_res), res))
			{
				printf("%sError when comparing coordinates of hardware [2]P result with the expected ones.%s\n\r", KERR, KNRM);
				goto err;
			}
			if (*res == true) {
				PRINTF("[2]P results match\n\r");
				(st->ok)++;
			} else {
				/*
				 * Mismatch error (hardware [2]P coords & expected ones differ).
				 */
				printf("%sError: [2]P mismatch between hardware coordinates and those of the expected result.%s\n\r", KERR, KNRM);
				(st->nok)++;
				goto err;
			}
		}
	}
	return 0;
err:
	return -1;
}

int ip_set_pt_and_run_ptneg(ipecc_test_t* t)
{
	int is_null;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that point P is set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for (-P) computation, assoc. curve not set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for (-P) computation, input point P not set.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.x.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for (-P) computation, X coord. of point P larger than current curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if ((t->ptp.y.sz) > (NN_SZ(t->curve->nn))) {
		printf("%sError: Can't program IP for (-P) computation, Y coord. of point P larger than currrent curve size set in hardware.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for (-P) computation, missing expected result of test.%s\n\r", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_PTNEG) {
		printf("%sError: Can't program IP for (-P) computation, operation type mismatch.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Send point P info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R0 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R0 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n\r", KERR, KNRM);
			goto err;
		}
	}

	/*
	 * Run (-P) command
	 */
	if (hw_driver_neg(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->pt_hw_res.x.val,
				&(t->pt_hw_res.x.sz), t->pt_hw_res.y.val, &(t->pt_hw_res.y.sz)))
	{
		printf("%sError: (-P) computation by hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}

	/*
	 * Is the result the null point? (aka point at infinity)
	 * If it is not, there's nothing to do, as hw_driver_neg() already set
	 * the coordinates of (-P) result in the appropriate buffers (namely
	 * t->pt_hw_res.x.val and t->pt_hw_res.y.val).
	 */
	if (hw_driver_point_iszero(1, &is_null)) { /* result point assumed to be R1 */
		printf("%sError: Getting status (-P) result point (at infinity or not) from hardware triggered an error.%s\n\r", KERR, KNRM);
		goto err;
	}
	t->pt_hw_res.is_null = INT_TO_BOOLEAN(is_null);
	t->pt_hw_res.valid = true;

	return 0;
err:
	return -1;
}

int check_ptneg_result(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that computation was actually done on hardware.
	 */
	if (t->pt_hw_res.valid == false)
	{
		printf("%sError: Can't check result of (-P) against expected one, computation didn't happen on hardware.%s\n\r", KERR, KNRM);
		goto err;
	}

	if (t->pt_sw_res.is_null == true) {
		/*
		 * Expected result is that (-P) = 0 (aka point at infinity).
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * The hardware result is also the null point.
			 */
			PRINTF("(-P) = 0 as expected\n\r");
			*res = true;
			(st->ok)++;
		} else {
			/*
			 * Mismatch error (the hardware result is not the null point).
			 */
			printf("%sError: (-P) mismatch between hardware result and expected one.\n\r"
						 "         (-P) is not 0 however it should be.%s\n\r", KERR, KNRM);
			*res = false;
			(st->nok)++;
			goto err;
		}
	} else {
		/*
		 * Expected result it that (-P) is different from the point at infinity.
		 */
		if (t->pt_hw_res.is_null == true) {
			/*
			 * Mismatch error (the hardware result is the null point).
			 */
			printf("%sError: (-P) mismatch between hardware result and expected one.\n\r"
						 "         (-P) is 0 however it should not be.%s\n\r", KERR, KNRM);
			*res = false;
			(st->nok)++;
			goto err;
		} else {
			/*
			 * Neither (-P) hardware result nor the expected one are null.
			 * Compare their coordinates.
			 */
			if (cmp_two_pts_coords(&(t->pt_sw_res), &(t->pt_hw_res), res))
			{
				printf("%sError when comparing coordinates of hardware (-P) result with the expected ones.%s\n\r", KERR, KNRM);
				goto err;
			}
			if (*res == true) {
				PRINTF("(-P) results match\n\r");
				(st->ok)++;
			} else {
				/*
				 * Mismatch error (hardware (-P) coords & expected ones differ).
				 */
				printf("%sError: (-P) mismatch between hardware coordinates and those of the expected result.%s\n\r", KERR, KNRM);
				(st->nok)++;
				goto err;
			}
		}
	}
	return 0;
err:
	return -1;
}
