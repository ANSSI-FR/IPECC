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

#if defined(WITH_EC_HW_ACCELERATOR)

/* Hardware/external accelerator driver abstraction
 *
 * NOTE: big numbers are in BIG ENDIAN format, and their size is in bytes. No particular
 * hypothesis must be taken on the address or size alignment of the buffers, or on the zero padding.
 *
 * For instance, the representation of the big number 0xabcdef can be either { 0xab, 0xcd, 0xef } on three
 * bytes, or {0x00, 0x00, 0xab, 0xcd, 0xef } on five bytes.
 */

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

/* Get major version of the IP */
int hw_driver_get_version_major(unsigned int*);

/* Get minor version of the IP */
int hw_driver_get_version_minor(unsigned int*);

/* Enable TRNG post-processing logic */
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

/* Return (out_x, out_y) = scalar * (x, y) */
int hw_driver_mul(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
		  const unsigned char *scalar, unsigned int scalar_sz,
		  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz);

/* Set the small scalar size in the hardware */
int hw_driver_set_small_scalar_size(unsigned int bit_sz);

/* Enable TRNG post-processing (a call upon is required in Debug mode
 * or the TRNG won't ever provide a single byte). */
int hw_driver_trng_post_proc_enable(void);

#endif /* !WITH_EC_HW_ACCELERATOR */

#endif /* __HW_ACCELERATOR_DRIVER_H__ */
