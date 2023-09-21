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

#ifndef __HW_ACCELERATOR_DRIVER_H__
#define __HW_ACCELERATOR_DRIVER_H__

#include <stdint.h>

#if defined(WITH_EC_HW_ACCELERATOR)

/* Hardware/external accelerator driver abstraction
 *
 * NOTE: big numbers are in BIG ENDIAN format, and their size is in bytes. No particular
 * hypothesis must be taken on the address or size alignment of the buffers, or on the zero padding.
 *
 * For instance, the representation of the big number 0xabcdef can be either { 0xab, 0xcd, 0xef } on three
 * bytes, or {0x00, 0x00, 0xab, 0xcd, 0xef } on five bytes.
 */

#ifdef KP_TRACE
#include <stdbool.h>
#endif

/* Supported command types */
typedef enum {  
        PT_ADD = 0,
        PT_DBL = 1,
        PT_CHK = 2,
        PT_EQU = 3,
        PT_OPP = 4,
        PT_KP  = 5,
        PT_NEG = 6,
} ip_ecc_command;

/* Reset the hardware */
int hw_driver_reset(void);

/* To know if the IP is in 'debug' or 'production' mode */
int hw_driver_is_debug(unsigned int*);

/* Get all three version nbs of the IP (major, minor & patch) */
int hw_driver_get_version_tags(uint32_t*, uint32_t*, uint32_t*);

/* Enable TRNG post-processing logic (a call upon is required in Debug mode
 * or the TRNG won't ever provide a single byte). */
int hw_driver_trng_post_proc_enable(void);

/* Enable TRNG post-processing logic */
int hw_driver_trng_post_proc_disable(void);

/* Set the curve parameters a, b, p and q */
int hw_driver_set_curve(const unsigned char *a, unsigned int a_sz, const unsigned char *b, unsigned int b_sz,
			const unsigned char *p, unsigned int p_sz, const unsigned char *q, unsigned int q_sz);

/* Activate the blinding for scalar multiplication */
int hw_driver_set_blinding(unsigned int blinding_size);

/* Disable the blinding for scalar multiplication */
int hw_driver_disable_blinding(void);

/* Activate the shuffling for scalar multiplication */
int hw_driver_set_shuffling(void);

/* Disable the shuffling for scalar multiplication */
int hw_driver_disable_shuffling(void);

/* Activate and configure the periodic Z-remasking countermeasure
 * (the 'period' arguement is expressed in number of bits of the scalar */
int hw_driver_set_zremask(unsigned int period);

/* Disable the periodic Z-remasking countermeasure for scalar multiplication */
int hw_driver_disable_zremask(void);

/* Debug feature: disable the XY-shuffling countermeasure */
int hw_driver_disable_xyshuf(void);

/* Debug feature: re-enble the XY-shuffling countermeasure */
int hw_driver_enable_xyshuf(void);

/* Check if an affine point (x, y) is on the curve that has been previously set in the hardware */
int hw_driver_is_on_curve(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
			  int *on_curve);

/* Check if affine points (x1, y1) and (x2, y2) are equal */
int hw_driver_eq(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
		 const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
		 int *is_eq);

/* Check if affine points (x1, y1) and (x2, y2) are opposite */
int hw_driver_opp(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
		  const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
		  int *is_opp);

/* Check if the infinity point flag is set in the hardware for
 * point at index idx
 */
int hw_driver_point_iszero(unsigned char idx, int *iszero);

/* Set the infinity point flag in the hardware for
 * point at index idx
 */
int hw_driver_point_zero(unsigned char idx);

/* Unset the infinity point flag in the hardware for
 * point at index idx
 */
int hw_driver_point_unzero(unsigned char idx);

/* Return (out_x, out_y) = -(x, y) */
int hw_driver_neg(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
		  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz);

/* Return (out_x, out_y) = 2 * (x, y) */
int hw_driver_dbl(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz);


/* Return (out_x, out_y) = (x1, y1) + (x2, y2) */
int hw_driver_add(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
		  const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz);


#ifdef KP_TRACE

typedef struct {
	unsigned int r0z;
	unsigned int r1z;
	unsigned int kap;
	unsigned int kapp;
	unsigned int zu;
	unsigned int zc;
	unsigned int jnbbit;
} kp_exp_flags_t;

/* The following 'kp_trace_info' structure allows any calling program (stat. linked with
 * the driver) to get a certain number of IP internal states/infos collected during a [k]P
 * computation through breakpoints and step-by-step execution (this includes e.g values of
 * a few random numbers/masks, coordinates of intermiediate points, etc).
 */
typedef struct {
	/* Main security parameter nn */
	unsigned int nn;
	/* Random values (along with a valig flag for each) */
	unsigned int* lambda;
	bool lambda_valid;
	unsigned int* phi0;
	bool phi0_valid;
	unsigned int* phi1;
	bool phi1_valid;
	unsigned int* alpha;
	bool alpha_valid;
	/* Nb of trace steps (roughly the nb of opcodes for this [k]P run) */
	unsigned int nb_steps;
	/* Temporary value of XR0, YR0, XR1 and YR1 */
	unsigned int* nb_xr0;
	unsigned int* nb_yr0;
	unsigned int* nb_xr1;
	unsigned int* nb_yr1;
	unsigned int* nb_zr01;
	/* A huge char buffer to printf all required infos. */
	char* msg;
	uint32_t msgsz;
	uint32_t msgsz_max;
} kp_trace_info_t;
#endif

/* The size of the statically allocated buffer that field
 * 'msgsz_max' of struct 'kp_trace_info_t' above should not
 * exceed. */
#define KP_TRACE_PRINTF_SZ   (16*1024*1024)    /* 16 MB */

/* Return (out_x, out_y) = scalar * (x, y) */
int hw_driver_mul(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
		  const unsigned char *scalar, unsigned int scalar_sz,
		  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz,
			kp_trace_info_t* ktrc);

/* Set the small scalar size in the hardware */
int hw_driver_set_small_scalar_size(unsigned int bit_sz);

/* Complete bypass the TRNG function (both entropy source,
 * post-processing, and server) */
int hw_driver_bypass_full_trng_DBG(unsigned int bit);

/* Disable token feature */
int hw_driver_disable_token_DBG(void);

/* (Re-)enable token feature */
int hw_driver_enable_token_DBG(void);

/* Patching microcode in the IP */
int hw_driver_patch_microcode_DBG(uint32_t*, uint32_t, uint32_t);

/*
 * Error/printf formating
 */
#define TERM_COLORS

#ifdef TERM_COLORS
#define KNRM  "\x1B[0m"
#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"
#define KYEL  "\x1B[33m"
#define KBLU  "\x1B[34m"
#define KMAG  "\x1B[35m"
#define KCYN  "\x1B[36m"
#define KWHT  "\x1B[37m"
#define KORA  "\033[93m"
#define KUNK  "\033[91m"
#else
#define KNRM  ""
#define KRED  ""
#define KGRN  ""
#define KYEL  ""
#define KBLU  ""
#define KMAG  ""
#define KCYN  ""
#define KWHT  ""
#define KORA  ""
#define KUNK  ""
#endif /* TERM_COLORS */

#endif /* !WITH_EC_HW_ACCELERATOR */

#endif /* __HW_ACCELERATOR_DRIVER_H__ */
