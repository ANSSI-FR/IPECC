#include <stdlib.h>
#include <stdio.h>

#include "ipecc.h"
#include "config.h"

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
extern void run_kp(void);
extern void run_pt_add(void);
extern void run_pt_dbl(void);
extern void run_pt_neg(void);
extern bool print_error_if_any(void);
extern void status_detail(void);
extern void print_stats_and_exit();
extern void debug_read_large_number(uint32_t, uint32_t*, uint32_t);
extern void set_breakpoint(uint32_t, uint32_t);
extern void resume_execution(void);
extern void poll_until_dbghalted(void);
extern void debug_write_opcode(uint32_t, uint32_t);
extern void single_step(void);
extern void clear_sw_ecc_fp_dram(uint32_t);
extern void load_ecc_fp_dram(uint32_t);
extern void diff_ecc_fp_dram(uint32_t);
/*
 * this function is defined in redpit.c
 */
bool cmp_two_pts_coords(uint32_t, struct point_t*, struct point_t*);
#endif

extern uint32_t nbcurve;
extern uint32_t nbtest;
extern bool k_valid;

int ip_set_pts_and_run_ptadd(uint32_t nn, struct point_t* pt_p,
		struct point_t* pt_q, struct point_t* pt_pplusq, uint32_t* err)
{
	/*
	 * verify that points P & Q are valid
	 */
	if (pt_p->valid == false) {
		printf("%sERROR: can't program IP for P + Q computation, "
				"point P isn't marked as valid\n%s", KERR, KNRM);
	}
	if (pt_q->valid == false) {
		printf("%sERROR: can't program IP for P + Q computation, "
				"point Q isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((pt_p->valid == false) || (pt_q->valid == false)) {
		return -1;
	}
	/*
	 * send point P info & coordinates (into R0)
	 */
	if (pt_p->is_null == false) {
#if 0
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
#endif
	} else {
#if 0
		/*
		 * set R0 to be the null point
		 */
		set_r0_null();
#endif
	}
	/*
	 * send point Q info & coordinates (into R1)
	 */
	if (pt_q->is_null == false) {
#if 0
		/*
		 * send Qx
		 */
		write_large_number(LARGE_NB_XR1_ADDR, pt_q->x, nn, false);
		/*
		 * send Qy
		 */
		write_large_number(LARGE_NB_YR1_ADDR, pt_q->y, nn, false);
		/*
		 * set R1 as a non null point
		 */
		set_r1_non_null();
#endif
	} else {
#if 0
		/*
		 * set R1 to be the null point
		 */
		set_r1_null();
#endif
	}

	/*
	 * run P + Q (PT_ADD) command
	 */
#if 0
	run_pt_add();

	/*
	 * poll until job's done
	 */
	poll_until_ready();
	/*
	 * print it if IP raised an error
	 */
	print_error_if_any();
#endif

#if 0
	/*
	 * read-back P + Q result coords (from R1) if result is not null
	 */
	if (get_r1_null_or_not_null() == R1_NOT_NULL)
	{
		/*
		 * read coordinate X
		 */
		read_large_number(LARGE_NB_XR1_ADDR, pt_pplusq->x, nn);
		/*
		 * read coordinate Y
		 */
		read_large_number(LARGE_NB_YR1_ADDR, pt_pplusq->y, nn);
		/*
		 * set result not to be null in passed pointer
		 */
		pt_pplusq->is_null = false;
	} else {
		/*
		 * set result as null in passed pointer
		 */
		pt_pplusq->is_null = true;
	}
#endif
	/*
	 * mark HW resulting point as valid 
	 */
	pt_pplusq->valid = true;
	/*
	 * set error flags in passed pointer
	 */
#if 0
	*err = READ_REG(R_STATUS) & 0xffff0000;
}
#endif

void check_ptadd_result(struct curve_t* crv, struct point_t* pt_p,
		struct point_t* pt_q, struct point_t* sw_pplusq, struct point_t* hw_pplusq,
		struct stats_t* st)
{
	if (sw_pplusq->valid == false) {
		printf("%sERROR: can't check correctness of P + Q computation, "
				"SW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if (hw_pplusq->valid == false) {
		printf("%sERROR: can't check correctness of P + Q computation, "
				"HW point isn't marked as valid\n%s", KERR, KNRM);
	}
	if ((sw_pplusq->valid == false) || (hw_pplusq->valid == false)) {
		return -1;
	}
	if (sw_pplusq->is_null == true) {
		if (hw_pplusq->is_null == true) {
#ifdef VERBOSE
			printf("P + Q = 0 as expected\n");
#endif
			(st->ok)++;
		} else {
			printf("%s", KERR);
			printf("---- ERROR when computing P + Q\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: P + Q is not 0 but should be\n");
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
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		}
	} else {
		if (hw_pplusq->is_null == true) {
			printf("%s", KERR);
			printf("---- ERROR when computing P + Q\n");
			printf("test #%d.%d\n", nbcurve, nbtest);
			printf("ERROR: P + Q = 0 but shouldn't be\n");
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
			(st->nok)++;
#ifdef LEAVE_ON_ERROR
			printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
			print_stats_and_exit();
#endif
		} else {
			/*
			 * compare software client & hardware IP coordinates
			 */
			if (cmp_two_pts_coords(crv->nn, sw_pplusq, hw_pplusq) == true) {
#ifdef VERBOSE
				printf("results match\n");
				display_large_number(crv->nn, "SW: (P+Q)x = 0x", sw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y = 0x", sw_pplusq->y);
				display_large_number(crv->nn, "HW: (P+Q)x = 0x", hw_pplusq->x);
				display_large_number(crv->nn, "    (P+Q)y = 0x", hw_pplusq->y);
#endif
				(st->ok)++;
			} else {
				printf("%s", KERR);
				printf("---- ERROR when computing P + Q\n");
				printf("test #%d.%d\n", nbcurve, nbtest);
				printf("ERROR: HW/SW mismatch\n");
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
				(st->nok)++;
#ifdef LEAVE_ON_ERROR
				printf("%sstopped on test %d.%d%s\n", KERR, nbcurve, nbtest, KNRM);
				print_stats_and_exit();
#endif
			}
		}
	}
}

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

