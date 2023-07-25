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

#include "hw_accelerator_driver.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

/* Include our test suite */
#include "test_unit.h"

#define _BYTE_CEIL(b) (((b) == 0) ? 1 : (((b) + 8 - 1) / 8))

#define EG(a, b) do {						\
	if(a){							\
		printf("Error: line %d: %s\n", __LINE__, b);	\
		/* Reset the IP */				\
		hw_driver_reset();				\
		/*exit(-1);*/					\
	}							\
} while(0)

static inline void hexdump(const char *str, const unsigned char *in, unsigned int sz)
{
	unsigned int i;

	printf("%s", str);
	for(i = 0; i < sz; i++){
		printf("%02x", in[i]);
	}
	printf("\n");
}

static inline int print_point(const char *prefix, const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz){
	printf("%s", prefix);
	hexdump("x: ", x, x_sz);
	printf("%s", prefix);
	hexdump("y: ", y, y_sz);

	return 0;
}

static inline int print_zeros(void)
{
	int ret, iszero0, iszero1;

	ret = hw_driver_point_iszero(0, &iszero0);
	if(ret){
		goto err;
	}
	ret = hw_driver_point_iszero(1, &iszero1);
	if(ret){
		goto err;
	}
	printf("Iszero R0: %d, Iszero R1: %d\n", iszero0, iszero1);

	ret = 0;
err:
	return ret;
}

/* Macros for pointers access when we truncate our data */
#define END_OF_BUF(a, end_sz) (((a) == NULL) ? (a) : ((a) + ((a##_sz) - (end_sz))))
#define SIZE_OF_BUF(a, sz)    (((a) == NULL) ? (0) : (sz))

int unit_test(ipecc_test *t)
{
	int ret;

	/* The output */
	unsigned char Poutx[1024], Pouty[1024];

	unsigned int szx, szy;

	printf("== Test %s\n", t->name);
	/* Set the blinding if necessary */
	if(t->blinding){
		printf("Blinding...\n");
		ret = hw_driver_set_blinding(t->blinding); EG(ret, "blinding");
	}
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	/*** Common stuff ****/
	/* Unzero the infinity flags */
	ret = hw_driver_point_unzero(0); EG(ret, "unzero 0");
	ret = hw_driver_point_unzero(1); EG(ret, "unzero 1");
#if 0
	/* Set the curve */
	if(t->nn_sz){
		unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
hexdump("a:", END_OF_BUF(t->a, new_sz), new_sz);
hexdump("b:", END_OF_BUF(t->b, new_sz), new_sz);
hexdump("p:", END_OF_BUF(t->p, new_sz), new_sz);
hexdump("q:", END_OF_BUF(t->q, new_sz), new_sz);
		ret = hw_driver_set_curve(END_OF_BUF(t->a, new_sz), new_sz, END_OF_BUF(t->b, new_sz), new_sz, END_OF_BUF(t->p, new_sz), new_sz, END_OF_BUF(t->q, new_sz), new_sz); EG(ret, "set_curve");
	}
	else{
		ret = hw_driver_set_curve(t->a, t->a_sz, t->b, t->b_sz, t->p, t->p_sz, t->q, t->q_sz); EG(ret, "set_curve");
	}
	/* Set the small scalar size if necessary */
	if(t->small_scal_sz){
		ret = hw_driver_set_small_scalar_size(t->small_scal_sz); EG(ret, "small_scalar_size");
	}
#endif
	/*** Specific commands stuff ***/
	/* What kind of operation do we have to perform? */
	switch(t->cmd){
		case PT_ADD:{
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			/* Set infinity point for input if necessary */
			if((t->Qx == NULL) && (t->Qy == NULL)){
				ret = hw_driver_point_zero(1); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_add(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), END_OF_BUF(t->Qx, new_sz), SIZE_OF_BUF(t->Qx, new_sz), END_OF_BUF(t->Qy, new_sz), SIZE_OF_BUF(t->Qy, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_add");
			}
			else{
				ret = hw_driver_add(t->Px, t->Px_sz, t->Py, t->Py_sz, t->Qx, t->Qx_sz, t->Qy, t->Qy_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_add");
			}
			/* Print the result */
			ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
			ret = print_zeros();
			break;
		}
		case PT_DBL:{
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_dbl(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_dbl");
			}
			else{
				ret = hw_driver_dbl(t->Px, t->Px_sz, t->Py, t->Py_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_dbl");
			}
			/* Print the result */
			ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
			ret = print_zeros();
			break;
		}
		case PT_CHK:{
			int oncurve;
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_is_on_curve(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), &oncurve); EG(ret, "driver_is_on_curve");
			}
			else{
				ret = hw_driver_is_on_curve(t->Px, t->Px_sz, t->Py, t->Py_sz, &oncurve); EG(ret, "driver_is_on_curve");
			}
			printf("Is on curve: %d\n", oncurve);
			break;
		}
		case PT_EQU:{
			int equal;
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			/* Set infinity point for input if necessary */
			if((t->Qx == NULL) && (t->Qy == NULL)){
				ret = hw_driver_point_zero(1); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_eq(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), END_OF_BUF(t->Qx, new_sz), SIZE_OF_BUF(t->Qx, new_sz), END_OF_BUF(t->Qy, new_sz), SIZE_OF_BUF(t->Qy, new_sz), &equal); EG(ret, "driver_eq");
			}
			else{
				ret = hw_driver_eq(t->Px, t->Px_sz, t->Py, t->Py_sz, t->Qx, t->Qx_sz, t->Qy, t->Qy_sz, &equal); EG(ret, "driver_eq");
			}
			printf("Are equal: %d\n", equal);
			break;
		}
		case PT_OPP:{
			int opposite;
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			/* Set infinity point for input if necessary */
			if((t->Qx == NULL) && (t->Qy == NULL)){
				ret = hw_driver_point_zero(1); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_opp(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), END_OF_BUF(t->Qx, new_sz), SIZE_OF_BUF(t->Qx, new_sz), END_OF_BUF(t->Qy, new_sz), SIZE_OF_BUF(t->Qy, new_sz), &opposite); EG(ret, "driver_opp");
			}
			else{
				ret = hw_driver_opp(t->Px, t->Px_sz, t->Py, t->Py_sz, t->Qx, t->Qx_sz, t->Qy, t->Qy_sz, &opposite); EG(ret, "driver_opp");
			}
			printf("Are opposite: %d\n", opposite);
			break;
		}
		case PT_KP:{
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(1); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
hexdump("scal:", END_OF_BUF(t->k, new_sz), new_sz);
hexdump("Px:", END_OF_BUF(t->Px, new_sz), new_sz);
hexdump("Py:", END_OF_BUF(t->Py, new_sz), new_sz);
				ret = hw_driver_mul(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), END_OF_BUF(t->k, new_sz), SIZE_OF_BUF(t->k, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_mul");
			}
			else{
				ret = hw_driver_mul(t->Px, t->Px_sz, t->Py, t->Py_sz, t->k, t->k_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_mul");
			}
			/* Print the result */
			ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
			ret = print_zeros();
			break;
		}
		case PT_NEG:{
			/* Set infinity point for input if necessary */
			if((t->Px == NULL) && (t->Py == NULL)){
				ret = hw_driver_point_zero(0); EG(ret, "point_zero");
			}
			if(t->nn_sz){
				unsigned int new_sz = _BYTE_CEIL(t->nn_sz);
				ret = hw_driver_neg(END_OF_BUF(t->Px, new_sz), SIZE_OF_BUF(t->Px, new_sz), END_OF_BUF(t->Py, new_sz), SIZE_OF_BUF(t->Py, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_neg");
			}
			else{
				ret = hw_driver_neg(t->Px, t->Px_sz, t->Py, t->Py_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_neg");
			}
			/* Print the result */
			ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
			ret = print_zeros();
			break;
		}
		default:{
			printf("Error: unknown IPECC command %d\n", t->cmd);
			exit(-1);
		}
	} /* switch t->cmd */ 

	return 0;
}
