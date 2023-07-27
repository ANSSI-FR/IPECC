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

/* Test "is point on curve?" */
int ip_set_pt_and_check_on_curve(ipecc_test_t* t)
{
	int hw_answer;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that point P is set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, assoc. curve not set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, input point P not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, X coord. of point P larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, Y coord. of point P larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, missing expected result of test.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_TST_CHK) {
		printf("%sError: Can't program IP for the \"is on curve?\" test, operation type mismatch.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Send point P info & coordinates
	 */
	if (t->ptp.is_null == true) {
		/* Set point R0 as being the null point (aka point at infinity). */
		if (hw_driver_point_zero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	} else {
		/* Set point R0 as NOT being the null point (aka point at infinity). */
		if (hw_driver_point_unzero(0)) { /* input point assumed to be R0 in hardware */
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	/*
	 * Run "is on curve?" test on hardware
	 */
	if (hw_driver_is_on_curve(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, &hw_answer))
	{
		printf("%sError: Test \"is on curve?\" by hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Answer (true or false) to the test has been set by hw_driver_is_on_curve().
	 * Simply mark the hardware resulting answer as valid.
	 */
	t->hw_answer.answer = INT_TO_BOOLEAN(hw_answer);
	t->hw_answer.valid = true;

	return 0;
err:
	return -1;
}

int check_test_oncurve(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that point test was actually done on hardware.
	 */
	if (t->hw_answer.valid == false)
	{
		printf("%sError: Can't check result of \"is on curve?\" test against expected one, test didn't happen on hardware.%s\n", KERR, KNRM);
		goto err;
	}
	/*
	 * Compare hardware answer to the test with the expected one.
	 */
	if (t->sw_answer.answer == t->hw_answer.answer) {
		PRINTF("HW & SW answers match for test \"is on curve?\" (both are %s)\n",
				((t->hw_answer.answer == true) ? "true" : "false"));
		(st->ok)++;
	} else {
		/*
		 * Mismatch error (the hardware answer to the test is different
		 * from the expected one.
		 */
		printf("%sError: mistmatch between hardware result and expected one for \"is on curve?\" test.\n"
					 "         Hardware says %s however it should be %s.%s\n", KERR, 
					 (t->hw_answer.answer == true) ? "true" : "false",
					 (t->sw_answer.answer == true) ? "true" : "false", KNRM);
#if 0
		status_detail();
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
		printf("%s", KNRM);
#endif
		*res = false;
		(st->nok)++;
		goto err;
	}
	return 0;
err:
	return -1;
}

/* Test "are points equal?" */
int ip_set_pts_and_test_equal(ipecc_test_t* t)
{
	int hw_answer;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that points P and Q are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, assoc. curve not set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, input point P not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.valid == false) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, input point Q not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, X coord. of point P larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, Y coord. of point P larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, X coord. of point Q larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, Y coord. of point Q larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, missing expected result of test.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_TST_EQU) {
		printf("%sError: Can't program IP for the \"are pts equal?\" test, operation type mismatch.%s\n", KERR, KNRM);
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
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
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
			printf("%sError: Setting point Q as diff. from the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	/*
	 * Run "are pts equal?" test on hardware
	 */
	if (hw_driver_eq(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->ptq.x.val,
				t->ptq.x.sz, t->ptq.y.val, t->ptq.y.sz, &hw_answer))
	{
		printf("%sError: Test \"are pts equal?\" by hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Answer (true or false) to the test has been set by hw_driver_eq().
	 * Simply mark the hardware resulting answer as valid.
	 */
	t->hw_answer.answer = INT_TO_BOOLEAN(hw_answer);
	t->hw_answer.valid = true;

	return 0;
err:
	return -1;
}

int check_test_equal(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that point test was actually done on hardware.
	 */
	if (t->hw_answer.valid == false)
	{
		printf("%sError: Can't check result of \"are pts equal?\" test against expected one, test didn't happen on hardware.%s\n", KERR, KNRM);
		goto err;
	}
	/*
	 * Compare hardware answer to the test with the expected one.
	 */
	if (t->sw_answer.answer == t->hw_answer.answer) {
		PRINTF("HW & SW answers match for test \"are pts equal?\" (both are %s)\n",
				((t->hw_answer.answer == true) ? "true" : "false"));
		(st->ok)++;
	} else {
		/*
		 * Mismatch error (the hardware answer to the test is different
		 * from the expected one.
		 */
		printf("%sError: mistmatch between hardware result and expected one for \"are pts equal?\" test.\n"
					 "         Hardware says %s however it should be %s.%s\n", KERR, 
					 (t->hw_answer.answer == true) ? "true" : "false",
					 (t->sw_answer.answer == true) ? "true" : "false", KNRM);
#if 0
		status_detail();
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
		printf("%s", KNRM);
		/*
		 * acknowledge all errors
		 */
		WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
		*res = false;
		(st->nok)++;
		goto err;
	}
	return 0;
err:
	return -1;
}

/* Test "are points opposite?" */
int ip_set_pts_and_test_oppos(ipecc_test_t* t)
{
	int hw_answer;
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that points P and Q are both set.
	 * Verify that all large numbers do not exceed curve parameter 'nn' in size.
	 * Verify that expected result of test is set.
	 * Verify that operation type is valid.
	 */
	if (t->curve->set_in_hw == false) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, assoc. curve not set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.valid == false) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, input point P not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.valid == false) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, input point Q not set.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, X coord. of point P larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptp.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, Y coord. of point P larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.x.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, X coord. of point Q larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->ptq.y.sz > NN_SZ(t->curve->nn)) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, Y coord. of point Q larger than currrent curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->pt_sw_res.valid == false) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, missing expected result of test.%s\n", KERR, KNRM);
		goto err;
	}
	if (t->op != OP_TST_EQU) {
		printf("%sError: Can't program IP for the \"are pts opposite?\" test, operation type mismatch.%s\n", KERR, KNRM);
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
			printf("%sError: Setting point P as diff. from the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
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
			printf("%sError: Setting point Q as diff. from the infinity point on hardware triggered an error.%s\n", KERR, KNRM);
			goto err;
		}
	}

	/*
	 * Run "are pts opposite?" test on hardware
	 */
	if (hw_driver_opp(t->ptp.x.val, t->ptp.x.sz, t->ptp.y.val, t->ptp.y.sz, t->ptq.x.val,
				t->ptq.x.sz, t->ptq.y.val, t->ptq.y.sz, &hw_answer))
	{
		printf("%sError: Test \"are pts opposite?\" by hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Answer (true or false) to the test has been set by hw_driver_opp().
	 * Simply mark the hardware resulting answer as valid.
	 */
	t->hw_answer.answer = INT_TO_BOOLEAN(hw_answer);
	t->hw_answer.valid = true;

	return 0;
err:
	return -1;
}

int check_test_oppos(ipecc_test_t* t, stats_t* st, bool* res)
{
	/*
	 * Sanity check.
	 * Verify that point test was actually done on hardware.
	 */
	if (t->hw_answer.valid == false)
	{
		printf("%sError: Can't check result of \"are pts opposite?\" test against expected one, test didn't happen on hardware.%s\n", KERR, KNRM);
		goto err;
	}
	/*
	 * Compare hardware answer to the test with the expected one.
	 */
	if (t->sw_answer.answer == t->hw_answer.answer) {
		PRINTF("HW & SW answers match for test \"are pts opposite?\" (both are %s)\n",
				((t->hw_answer.answer == true) ? "true" : "false"));
		(st->ok)++;
	} else {
		/*
		 * Mismatch error (the hardware answer to the test is different
		 * from the expected one.
		 */
		printf("%sError: mistmatch between hardware result and expected one for \"are pts opposite?\" test.\n"
					 "         Hardware says %s however it should be %s.%s\n", KERR, 
					 (t->hw_answer.answer == true) ? "true" : "false",
					 (t->sw_answer.answer == true) ? "true" : "false", KNRM);
#if 0
		status_detail();
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
		printf("%s", KNRM);
		/*
		 * acknowledge all errors
		 */
		WRITE_REG(W_ERR_ACK, 0xffff0000);
#endif
		*res = false;
		(st->nok)++;
		goto err;
	}
	return 0;
err:
	return -1;
}
