#include <stdlib.h>
#include <stdio.h>

#include "ipecc.h"
#include "config.h"

/*
 * these functions are defined in helpers.c
 */
extern void write_large_number(uint32_t, uint32_t*, uint32_t, bool);
extern void set_r0_non_null(void);
extern void set_r0_null(void);
extern void set_r1_non_null(void);
extern void set_r1_null(void);
extern void poll_until_ready(void);
extern bool get_r1_null_or_not_null(void);
extern void read_large_number(uint32_t, uint32_t*, uint32_t);
extern void display_large_number(uint32_t, const char*, uint32_t*);
extern void run_test_is_on_curve(void);
extern void run_test_are_pts_equal(void);
extern void run_test_are_pts_opposed(void);
extern bool print_error_if_any(void);
extern void status_detail(void);
extern void print_stats_and_exit();
/*
 * this function is defined in redpit.c
 */
bool cmp_two_pts_coords(uint32_t, struct point_t*, struct point_t*);

extern uint32_t nbcurve;
extern uint32_t nbtest;
extern uint32_t k_valid;

/* test "is point on curve?" */
void ip_set_pt_and_check_on_curve(uint32_t nn, struct point_t* pt_p,
		struct test_t* tst, uint32_t* err)
{
	/*
	 * verify that point P is valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for test \"is on curve\", "
				"point P isn't marked as valid\n%s", KERR, KNRM);
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
	 * run test IS_ON_CURVE command
	 */
	run_test_is_on_curve();
	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
	/*
	 * read-back test answer
	 */
	if (READ_REG(R_STATUS) & STATUS_YES) {
		tst->hw_answer = true;
	} else {
		tst->hw_answer = false;
	}
	tst->hw_valid = true;
	/*
	 * set error flags in passed pointer
	 */
	*err = READ_REG(R_STATUS) & 0xffff0000;
}

void check_test_curve(struct curve_t* crv, struct point_t* pt_p,
		struct test_t* tst, struct stats_t* st)
{
	/*
	 * verify that both software client answer & hardware one
	 * have been marked as valid
	 */
	if (tst->sw_valid == false) {
		printf("%sERROR: can't check correctness of test \"is on curve\", "
				"SW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if (tst->hw_valid == false) {
		printf("%sERROR: can't check correctness of test \"is on curve\", "
				"HW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((tst->sw_valid == false) || (tst->hw_valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	/*
	 * compare hardware answer to test with the one provided
	 * by software client
	 */
	if (tst->sw_answer == tst->hw_answer) {
#ifdef VERBOSE
		printf("HW & SW answers match for test \"is on curve\" (both are %s)\n",
				((tst->hw_answer == true) ? "true" : "false"));
#endif
		(st->ok)++;
	} else {
		printf("%s", KERR);
		printf("---- ERROR when performing test \"is on curve\"\n");
		printf("test #%d.%d\n", nbcurve, nbtest);
		printf("ERROR, mismatch on answer\n");
		printf("HW: %s\n", ((tst->hw_answer == true) ? "true" : "false"));
		printf("SW: %s\n", ((tst->sw_answer == true) ? "true" : "false"));
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
		/*
		 * acknowledge all errors
		 */
		WRITE_REG(W_ERR_ACK, 0xffff0000);
		(st->nok)++;
#ifdef LEAVE_ON_ERROR
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
#endif
	}
}

/* test "are points equal?" */
void ip_set_pts_and_test_equal(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_q, struct test_t* tst, uint32_t* err)
{
	/*
	 * verify that points P & Q have been marked as valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for test \"are pts equal\", "
				"point P isn't marked as valid\n%s", KERR, KNRM);
	}
	if (pt_q->valid == false) {
		printf("%sERROR: can't program IP for test \"are pts equal\", "
				"point Q isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((pt_p->valid == false) || (pt_q->valid == false)) {
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
	 * send point Q info & coordinates (into R1)
	 */
	if (pt_q->is_null == false) {
		/*
		 * send Px
		 */
		write_large_number(LARGE_NB_XR1_ADDR, pt_q->x, nn, false);
		/*
		 * send Py
		 */
		write_large_number(LARGE_NB_YR1_ADDR, pt_q->y, nn, false);
		/*
		 * set R1 as a non null point
		 */
		set_r1_non_null();
	} else {
		/*
		 * set R1 to be the null point
		 */
		set_r1_null();
	}
	/*
	 * run test ARE_POINTS_EQUAL command
	 */
	run_test_are_pts_equal();
	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
	/*
	 * read-back test answer
	 */
	if (READ_REG(R_STATUS) & STATUS_YES) {
		tst->hw_answer = true;
	} else {
		tst->hw_answer = false;
	}
	tst->hw_valid = true;
	/*
	 * set error flags in passed pointer
	 */
	*err = READ_REG(R_STATUS) & 0xffff0000;
}

void check_test_equal(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* pt_q, struct test_t* tst, struct stats_t* st)
{
	/*
	 * verify that both software client answer & hardware one
	 * have been marked as valid
	 */
	if (tst->sw_valid == false) {
		printf("%sERROR: can't check correctness of test \"are pts equal\", "
				"SW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if (tst->hw_valid == false) {
		printf("%sERROR: can't check correctness of test \"are pts equal\", "
				"HW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((tst->sw_valid == false) || (tst->hw_valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	/*
	 * compare hardware answer to test with the one provided
	 * by software client
	 */
	if (tst->sw_answer == tst->hw_answer) {
#ifdef VERBOSE
		printf("HW & SW answers match for test \"are pts equal\" (both are %s)\n",
				((tst->hw_answer == true) ? "true" : "false"));
#endif
		(st->ok)++;
	} else {
		printf("%s", KERR);
		printf("---- ERROR when performing test \"are pts equal\"\n");
		printf("test #%d.%d\n", nbcurve, nbtest);
		printf("ERROR, mismatch on answer\n");
		printf("HW: %s\n", ((tst->hw_answer == true) ? "true" : "false"));
		printf("SW: %s\n", ((tst->sw_answer == true) ? "true" : "false"));
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
		(st->nok)++;
#ifdef LEAVE_ON_ERROR
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
#endif
	}
}

/* test "are points opposed?" */
void ip_set_pts_and_test_oppos(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_q, struct test_t* tst, uint32_t* err)
{
	/*
	 * verify that points P & Q have been marked as valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for test \"are pts oppos\", "
				"point P isn't marked as valid\n%s", KERR, KNRM);
	}
	if (pt_q->valid == false) {
		printf("%sERROR: can't program IP for test \"are pts oppos\", "
				"point Q isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((pt_p->valid == false) || (pt_q->valid == false)) {
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
	 * send point Q info & coordinates (into R1)
	 */
	if (pt_q->is_null == false) {
		/*
		 * send Px
		 */
		write_large_number(LARGE_NB_XR1_ADDR, pt_q->x, nn, false);
		/*
		 * send Py
		 */
		write_large_number(LARGE_NB_YR1_ADDR, pt_q->y, nn, false);
		/*
		 * set R1 as a non null point
		 */
		set_r1_non_null();
	} else {
		/*
		 * set R1 to be the null point
		 */
		set_r1_null();
	}
	/*
	 * run test ARE_POINTS_EQUAL command
	 */
	run_test_are_pts_opposed();
	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
	/*
	 * read-back test answer
	 */
	if (READ_REG(R_STATUS) & STATUS_YES) {
		tst->hw_answer = true;
	} else {
		tst->hw_answer = false;
	}
	tst->hw_valid = true;
	/*
	 * set error flags in passed pointer
	 */
	*err = READ_REG(R_STATUS) & 0xffff0000;
}

void check_test_opposed(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* pt_q, struct test_t* tst, struct stats_t* st)
{
	/*
	 * verify that both software client answer & hardware one
	 * have been marked as valid
	 */
	if (tst->sw_valid == false) {
		printf("%sERROR: can't check correctness of test \"are pts opposed\", "
				"SW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if (tst->hw_valid == false) {
		printf("%sERROR: can't check correctness of test \"are pts opposed\", "
				"HW answer isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((tst->sw_valid == false) || (tst->hw_valid == false)) {
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
	}
	/*
	 * compare hardware answer to test with the one provided
	 * by software client
	 */
	if (tst->sw_answer == tst->hw_answer) {
#ifdef VERBOSE
		printf("HW & SW answers match for test \"are pts opposed\" (both are %s)\n",
				((tst->hw_answer == true) ? "true" : "false"));
#endif
		(st->ok)++;
	} else {
		printf("%s", KERR);
		printf("---- ERROR when performing test \"are pts opposed\"\n");
		printf("test #%d.%d\n", nbcurve, nbtest);
		printf("ERROR, mismatch on answer\n");
		printf("HW: %s\n", ((tst->hw_answer == true) ? "true" : "false"));
		printf("SW: %s\n", ((tst->sw_answer == true) ? "true" : "false"));
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
		(st->nok)++;
#ifdef LEAVE_ON_ERROR
		printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
		print_stats_and_exit();
#endif
	}
}
