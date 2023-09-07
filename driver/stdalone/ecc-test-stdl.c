#include "hw_accelerator_driver.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
//#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#ifdef WITH_EC_HW_STANDALONE_XILINX
#include "platform.h"
#include "xil_printf.h"
#endif

/* Include our test suite */
#include "ecc-test-stdl.h"

#define _BYTE_CEIL(b) (((b) == 0) ? 1 : (((b) + 8 - 1) / 8))

#define EG(a, b) do {						\
	if(a){							\
		printf("Error: line %d: %s\n\r", __LINE__, b);	\
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
	printf("\n\r");
}

static inline int print_point(const char *prefix, const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz){
	printf("%s", prefix);
	hexdump("x=0x", x, x_sz);
	printf("%s", prefix);
	hexdump("y=0x", y, y_sz);

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
	printf("Iszero R0: %d, Iszero R1: %d\n\r", iszero0, iszero1);

	ret = 0;
err:
	return ret;
}

/* Macros for pointers access when we truncate our data */
#define END_OF_BUF(a, end_sz) (((a) == NULL) ? (a) : ((a) + ((a##_sz) - (end_sz))))
#define SIZE_OF_BUF(a, sz)    (((a) == NULL) ? (0) : (sz))

int main(int argc, char *argv[])
{
#if 1
	int ret;
	unsigned int i, j;

	(void)argc;
	(void)argv;

	/* The output */
	unsigned char Poutx[1024], Pouty[1024];

	printf("Welcome to the driver test!\n\r");

	/* Parse all our tests and execute them */
	for(i = 0; i < (sizeof(ipecc_all_tests) / sizeof(ipecc_test)); i++){
		unsigned int szx, szy;

		ipecc_test t = ipecc_all_tests[i];
		printf("========");
		for (j=0; j<strlen(t.name); j++) {
			printf("=");
		}
		printf("\n\r== Test %s\n\r", t.name);
		printf("========");
		for (j=0; j<strlen(t.name); j++) {
			printf("=");
		}
		printf("\n\r");
		/* Set the blinding if necessary */
		if(t.blinding){
			ret = hw_driver_set_blinding(t.blinding); EG(ret, "blinding");
		}
		szx = sizeof(Poutx);
		szy = sizeof(Pouty);
		/*** Common stuff ****/
		/* Unzero the infinity flags */
		ret = hw_driver_point_unzero(0); EG(ret, "unzero 0");
		ret = hw_driver_point_unzero(1); EG(ret, "unzero 1");
		/* Set the curve */
		if(t.nn_sz){
			unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
printf("nn=%d\n\r", 8 * new_sz);
hexdump("a=0x", END_OF_BUF(t.a, new_sz), new_sz);
hexdump("b=0x", END_OF_BUF(t.b, new_sz), new_sz);
hexdump("p=0x", END_OF_BUF(t.p, new_sz), new_sz);
hexdump("q=0x", END_OF_BUF(t.q, new_sz), new_sz);
			ret = hw_driver_set_curve(END_OF_BUF(t.a, new_sz), new_sz, END_OF_BUF(t.b, new_sz), new_sz, END_OF_BUF(t.p, new_sz), new_sz, END_OF_BUF(t.q, new_sz), new_sz); EG(ret, "set_curve");
		}
		else{
			ret = hw_driver_set_curve(t.a, t.a_sz, t.b, t.b_sz, t.p, t.p_sz, t.q, t.q_sz); EG(ret, "set_curve");
		}
		/* Set the small scalar size if necessary */
		if(t.small_scal_sz){
			ret = hw_driver_set_small_scalar_size(t.small_scal_sz); EG(ret, "small_scalar_size");
		}
		/*** Specific commands stuff ***/
		/* What kind of operation do we have to perform? */
		switch(t.cmd){
			case PT_ADD:{
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				/* Set infinity point for input if necessary */
				if((t.Qx == NULL) && (t.Qy == NULL)){
					ret = hw_driver_point_zero(1); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_add(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), END_OF_BUF(t.Qx, new_sz), SIZE_OF_BUF(t.Qx, new_sz), END_OF_BUF(t.Qy, new_sz), SIZE_OF_BUF(t.Qy, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_add");
				}
				else{
					ret = hw_driver_add(t.Px, t.Px_sz, t.Py, t.Py_sz, t.Qx, t.Qx_sz, t.Qy, t.Qy_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_add");
				}
				/* Print the result */
				ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
				ret = print_zeros();
				break;
			}
			case PT_DBL:{
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_dbl(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_dbl");
				}
				else{
					ret = hw_driver_dbl(t.Px, t.Px_sz, t.Py, t.Py_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_dbl");
				}
				/* Print the result */
				ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
				ret = print_zeros();
				break;
			}
			case PT_CHK:{
				int oncurve;
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_is_on_curve(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), &oncurve); EG(ret, "driver_is_on_curve");
				}
				else{
					ret = hw_driver_is_on_curve(t.Px, t.Px_sz, t.Py, t.Py_sz, &oncurve); EG(ret, "driver_is_on_curve");
				}
				printf("Is on curve: %d\n\r", oncurve);
				break;
			}
			case PT_EQU:{
				int equal;
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				/* Set infinity point for input if necessary */
				if((t.Qx == NULL) && (t.Qy == NULL)){
					ret = hw_driver_point_zero(1); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_eq(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), END_OF_BUF(t.Qx, new_sz), SIZE_OF_BUF(t.Qx, new_sz), END_OF_BUF(t.Qy, new_sz), SIZE_OF_BUF(t.Qy, new_sz), &equal); EG(ret, "driver_eq");
				}
				else{
					ret = hw_driver_eq(t.Px, t.Px_sz, t.Py, t.Py_sz, t.Qx, t.Qx_sz, t.Qy, t.Qy_sz, &equal); EG(ret, "driver_eq");
				}
				printf("Are equal: %d\n\r", equal);
				break;
			}
			case PT_OPP:{
				int opposite;
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				/* Set infinity point for input if necessary */
				if((t.Qx == NULL) && (t.Qy == NULL)){
					ret = hw_driver_point_zero(1); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_opp(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), END_OF_BUF(t.Qx, new_sz), SIZE_OF_BUF(t.Qx, new_sz), END_OF_BUF(t.Qy, new_sz), SIZE_OF_BUF(t.Qy, new_sz), &opposite); EG(ret, "driver_opp");
				}
				else{
					ret = hw_driver_opp(t.Px, t.Px_sz, t.Py, t.Py_sz, t.Qx, t.Qx_sz, t.Qy, t.Qy_sz, &opposite); EG(ret, "driver_opp");
				}
				printf("Are opposite: %d\n\r", opposite);
				break;
			}
			case PT_KP:{
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(1); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
hexdump("k=0x", END_OF_BUF(t.k, new_sz), new_sz);
hexdump("Px=0x", END_OF_BUF(t.Px, new_sz), new_sz);
hexdump("Py=0x", END_OF_BUF(t.Py, new_sz), new_sz);
					ret = hw_driver_mul(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), END_OF_BUF(t.k, new_sz), SIZE_OF_BUF(t.k, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_mul");
				}
				else{
					ret = hw_driver_mul(t.Px, t.Px_sz, t.Py, t.Py_sz, t.k, t.k_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_mul");
				}
				/* Print the result */
				ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
				ret = print_zeros();
				break;
			}
			case PT_NEG:{
				/* Set infinity point for input if necessary */
				if((t.Px == NULL) && (t.Py == NULL)){
					ret = hw_driver_point_zero(0); EG(ret, "point_zero");
				}
				if(t.nn_sz){
					unsigned int new_sz = _BYTE_CEIL(t.nn_sz);
					ret = hw_driver_neg(END_OF_BUF(t.Px, new_sz), SIZE_OF_BUF(t.Px, new_sz), END_OF_BUF(t.Py, new_sz), SIZE_OF_BUF(t.Py, new_sz), Poutx, &szx, Pouty, &szy); EG(ret, "driver_neg");
				}
				else{
					ret = hw_driver_neg(t.Px, t.Px_sz, t.Py, t.Py_sz, Poutx, &szx, Pouty, &szy); EG(ret, "driver_neg");
				}
				/* Print the result */
				ret = print_point("Pout", Poutx, szx, Pouty, szy); EG(ret, "print_point");
				ret = print_zeros();
				break;
			}
			default:{
				printf("Error: unkown IPECC commanf %d\n\r", t.cmd);
				exit(-1);
			}
		}
	}
#endif

#if 0
	int ret, oncurve;

	(void)argc;
	(void)argv;

	/* The output */
	unsigned char Poutx[32], Pouty[32];

	printf("Welcome to the driver test!\n\r");


       const unsigned char a[] = {
               0xf1, 0xfd, 0x17, 0x8c, 0x0b, 0x3a, 0xd5, 0x8f,
               0x10, 0x12, 0x6d, 0xe8, 0xce, 0x42, 0x43, 0x5b,
               0x39, 0x61, 0xad, 0xbc, 0xab, 0xc8, 0xca, 0x6d,
               0xe8, 0xfc, 0xf3, 0x53, 0xd8, 0x6e, 0x9c, 0x00
       };
       const unsigned char b[] = {
               0xee, 0x35, 0x3f, 0xca, 0x54, 0x28, 0xa9, 0x30,
               0x0d, 0x4a, 0xba, 0x75, 0x4a, 0x44, 0xc0, 0x0f,
               0xdf, 0xec, 0x0c, 0x9a, 0xe4, 0xb1, 0xa1, 0x80,
               0x30, 0x75, 0xed, 0x96, 0x7b, 0x7b, 0xb7, 0x3f
       };
       const unsigned char p[] = {
               0xf1, 0xfd, 0x17, 0x8c, 0x0b, 0x3a, 0xd5, 0x8f,
               0x10, 0x12, 0x6d, 0xe8, 0xce, 0x42, 0x43, 0x5b,
               0x39, 0x61, 0xad, 0xbc, 0xab, 0xc8, 0xca, 0x6d,
               0xe8, 0xfc, 0xf3, 0x53, 0xd8, 0x6e, 0x9c, 0x03
       };
       const unsigned char q[] = {
               0xf1, 0xfd, 0x17, 0x8c, 0x0b, 0x3a, 0xd5, 0x8f,
               0x10, 0x12, 0x6d, 0xe8, 0xce, 0x42, 0x43, 0x5b,
               0x53, 0xdc, 0x67, 0xe1, 0x40, 0xd2, 0xbf, 0x94,
               0x1f, 0xfd, 0xd4, 0x59, 0xc6, 0xd6, 0x55, 0xe1
       };

       const unsigned char Px[] = {
               0xb6, 0xb3, 0xd4, 0xc3, 0x56, 0xc1, 0x39, 0xeb,
               0x31, 0x18, 0x3d, 0x47, 0x49, 0xd4, 0x23, 0x95,
               0x8c, 0x27, 0xd2, 0xdc, 0xaf, 0x98, 0xb7, 0x01,
               0x64, 0xc9, 0x7a, 0x2d, 0xd9, 0x8f, 0x5c, 0xff
       };
       const unsigned char Py[] = {
               0x61, 0x42, 0xe0, 0xf7, 0xc8, 0xb2, 0x04, 0x91,
               0x1f, 0x92, 0x71, 0xf0, 0xf3, 0xec, 0xef, 0x8c,
               0x27, 0x01, 0xc3, 0x07, 0xe8, 0xe4, 0xc9, 0xe1,
               0x83, 0x11, 0x5a, 0x15, 0x54, 0x06, 0x2c, 0xfb,
       };

       const unsigned char scal0[] = {
               0x00, 0x00, 0x02
       };

       const unsigned char scal1[] = {
               0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02
       };

       const unsigned char scal3[] = {
               0x00, 0x00, 0x03
       };
       const unsigned char scal_zero[] = {
               0x00
       };

	printf("==== SET CURVE ====\n\r");
	ret = hw_driver_set_curve(a, sizeof(a), b, sizeof(b), p, sizeof(p), q, sizeof(q));
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	printf("==== ON CURVE ====\n\r");
	ret = hw_driver_is_on_curve(Px, sizeof(Px), Py, sizeof(Py), &oncurve);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	printf("On curve: %d\n\r", oncurve);
	printf("==== SCAL MUL ====\n\r");
	unsigned int szx = sizeof(Poutx);
	unsigned int szy = sizeof(Pouty);
	ret = hw_driver_mul(Px, sizeof(Px), Py, sizeof(Py), scal0, sizeof(scal0), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px ", Poutx, 32);
	hexdump("Py ", Pouty, 32);

	printf("==== SCAL MUL  ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_mul(Px, sizeof(Px), Py, sizeof(Py), scal1, sizeof(scal1), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);

	printf("==== DBL       ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_dbl(Px, sizeof(Px), Py, sizeof(Py), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);

	printf("==== ADD       ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_add(Px, sizeof(Px), Py, sizeof(Py), Poutx, szx, Pouty, szy, Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);

	printf("==== SCAL MUL  ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_mul(Px, sizeof(Px), Py, sizeof(Py), scal3, sizeof(scal3), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);

	printf("==== NEG       ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_neg(Px, sizeof(Px), Py, sizeof(Py), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);

	printf("==== ADD       ====\n\r");
	szx = sizeof(Poutx);
	szy = sizeof(Pouty);
	ret = hw_driver_add(Px, sizeof(Px), Py, sizeof(Py), Poutx, szx, Pouty, szy, Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}

	printf("==============\n\r");
	ret = hw_driver_point_zero(1);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_mul(Px, sizeof(Px), Py, sizeof(Py), scal3, sizeof(scal3), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	printf("==============\n\r");
	ret = hw_driver_point_unzero(0);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_point_unzero(1);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_mul(Px, sizeof(Px), Py, sizeof(Py), scal_zero, sizeof(scal3), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}

	printf("==============\n\r");
	ret = hw_driver_point_zero(0);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_point_zero(1);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_add(Px, sizeof(Px), Py, sizeof(Py), Poutx, szx, Pouty, szy, Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	printf("==============\n\r");
	ret = hw_driver_point_zero(0);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_point_unzero(1);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_dbl(Px, sizeof(Px), Py, sizeof(Py), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	printf("==============\n\r");
	ret = hw_driver_point_zero(0);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_point_unzero(1);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	ret = hw_driver_neg(Px, sizeof(Px), Py, sizeof(Py), Poutx, &szx, Pouty, &szy);
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
	hexdump("Px: ", Poutx, 32);
	hexdump("Py: ", Pouty, 32);
	ret = print_zeros();
	if(ret){
		printf("Error!\n\r");
		exit(-1);
	}
#endif

	return 0;
}
