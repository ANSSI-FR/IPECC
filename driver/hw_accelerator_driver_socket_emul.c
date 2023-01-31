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

/* The low level driver for the HW accelerator */
#include "hw_accelerator_driver.h"

#if defined(WITH_EC_HW_ACCELERATOR) && defined(WITH_EC_HW_SOCKET_EMUL)
/**************************************************************************/
/********************** SOCKET EMULATION **********************************/
/**************************************************************************/

typedef enum {
	SET_CURVE    = 0,
	SET_BLINDING = 1,
	IS_ON_CURVE  = 2,
	EQ           = 3,
	OPP          = 4,
	ISZERO       = 5,
	ZERO         = 6,
	UNZERO       = 7,
	NEG          = 8,
	DBL          = 9,
	ADD          = 10,
	SCAL_MUL     = 11,
	SET_SMALL_SCALAR_SZ = 12,
	HW_RESET     = 13,
} driver_command;

/******* Socket emulation of the driver ********************/
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <pthread.h>

/* Our socket */
#define PORT 8080
static volatile int sockfd = -1;

static int open_connection(void)
{
	int ret = -1, sock;
	struct sockaddr_in serv_addr;

	if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		goto err;
	}
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);
	
	if(inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0){
		goto err;
	}
	if(connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0){
		goto err;
	}
	sockfd = sock;

	ret = 0;
err:
	return ret;
}

/* Send data on the line */
static int send_data(const unsigned char *a, unsigned int a_sz)
{
	int ret = -1;
	unsigned char data_sz[4];

	/* Open socket if necessary */
	if(sockfd < 0){
		if(open_connection()){
			goto err;
		}
	}
	/* Send data size on 4 bytes */
	data_sz[0] = (unsigned char)((a_sz >> 24) & 0xff);
	data_sz[1] = (unsigned char)((a_sz >> 16) & 0xff);
	data_sz[2] = (unsigned char)((a_sz >> 8)  & 0xff);
	data_sz[3] = (unsigned char)((a_sz >> 0)  & 0xff);
	if(send(sockfd, data_sz, 4, 0) < 0){
		goto err;
	}
	if((a != NULL) && (a_sz != 0)){
		/* Send data */
		if(send(sockfd, a, a_sz, 0) < 0){
			goto err;
		}
	}

	ret = 0;

err:
	return ret;
}

/* Receive data on the line */
static int recv_data(unsigned char *a, unsigned int *a_sz)
{
	int ret = -1;
	unsigned int recv_sz;
	unsigned char data_sz[4];

	if(a_sz == NULL){
		goto err;
	}

	/* Open socket if necessary */
	if(sockfd < 0){
		if(open_connection()){
			goto err;
		}
	}
	/* Receive the data size */
	if(recv(sockfd, data_sz, 4, 0) < 0){
		goto err;
	}
	recv_sz  = ((unsigned int)data_sz[0] << 24);
	recv_sz |= ((unsigned int)data_sz[1] << 16);
	recv_sz |= ((unsigned int)data_sz[2] << 8);
	recv_sz |= ((unsigned int)data_sz[3] << 0);
	if(recv_sz > (*a_sz)){
		goto err;
	}
	if((recv_sz != 0) && (a == NULL)){
		goto err;
	}
	if((a != NULL) && (recv_sz != 0)){
		/* Receive the data */
		if(recv(sockfd, a, recv_sz, 0) < 0){
			goto err;
		}
	}
	(*a_sz) = recv_sz;

	ret = 0;

err:
	if(ret && (a_sz != NULL)){
		(*a_sz) = 0;
	}
	return ret;
}

/* Reset the hardware */                 
int hw_driver_reset(void) 
{       
	/* "Resetting" the hardware */
	unsigned char cmd[1] = { (unsigned char)HW_RESET };

	/* Send the command (no data associated) */
	if(send_data(cmd, 1)){
		goto err;
	}

	return 0;
err:
	return -1;
}                                   


/* Set the curve parameters a, b, p and q */
int hw_driver_set_curve(const unsigned char *a, unsigned int a_sz, const unsigned char *b, unsigned int b_sz,
  		        const unsigned char *p, unsigned int p_sz, const unsigned char *q, unsigned int q_sz)
{
	unsigned char cmd[1] = { (unsigned char)SET_CURVE };

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(a, a_sz)){
		goto err;
	}
	if(send_data(b, b_sz)){
		goto err;
	}
	if(send_data(p, p_sz)){
		goto err;
	}
	if(send_data(q, q_sz)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Activate the blinding for scalar multiplication */
int hw_driver_set_blinding(unsigned int blinding_size)
{
	unsigned char cmd[1] = { (unsigned char)SET_BLINDING };
	unsigned char bl_sz[4];

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	bl_sz[0] = (unsigned char)((blinding_size >> 24) & 0xff);
	bl_sz[1] = (unsigned char)((blinding_size >> 16) & 0xff);
	bl_sz[2] = (unsigned char)((blinding_size >> 8)  & 0xff);
	bl_sz[3] = (unsigned char)((blinding_size >> 0)  & 0xff);
	if(send_data(bl_sz, 4)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Check if an affine point (x, y) is on the curve that has been previously set in the hardware */
int hw_driver_is_on_curve(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                       	  int *on_curve)
{
	unsigned char cmd[1] = { (unsigned char)IS_ON_CURVE };
	unsigned char resp[1] = { 0 };
	unsigned int resp_sz;

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x, x_sz)){
		goto err;
	}
	if(send_data(y, y_sz)){
		goto err;
	}
	/* Receive the response */
	resp_sz = 1;
	if(recv_data(resp, &resp_sz)){
		goto err;
	}
	(*on_curve) = resp[0];

	return 0;
err:
	return -1;
}

/* Check if affine points (x1, y1) and (x2, y2) are equal */
int hw_driver_eq(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
    	         const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
                 int *is_eq)
{
	unsigned char cmd[1] = { (unsigned char)EQ };
	unsigned char resp[1] = { 0 };
	unsigned int resp_sz;

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x1, x1_sz)){
		goto err;
	}
	if(send_data(y1, y1_sz)){
		goto err;
	}
	if(send_data(x2, x2_sz)){
		goto err;
	}
	if(send_data(y2, y2_sz)){
		goto err;
	}
	/* Receive the response */
	resp_sz = 1;
	if(recv_data(resp, &resp_sz)){
		goto err;
	}
	(*is_eq) = resp[0];

	return 0;
err:
	return -1;
}

/* Check if affine points (x1, y1) and (x2, y2) are opposite */
int hw_driver_opp(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
               	  const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
               	  int *is_opp)
{
	unsigned char cmd[1] = { (unsigned char)OPP };
	unsigned char resp[1] = { 0 };
	unsigned int resp_sz;

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x1, x1_sz)){
		goto err;
	}
	if(send_data(y1, y1_sz)){
		goto err;
	}
	if(send_data(x2, x2_sz)){
		goto err;
	}
	if(send_data(y2, y2_sz)){
		goto err;
	}
	/* Receive the response */
	resp_sz = 1;
	if(recv_data(resp, &resp_sz)){
		goto err;
	}
	(*is_opp) = resp[0];

	return 0;
err:
	return -1;
}

/* Check if the infinity point flag is set in the hardware for
 * point at index idx
 */
int hw_driver_point_iszero(unsigned char idx, int *iszero)
{
	unsigned char cmd[1] = { (unsigned char)ISZERO };
	unsigned char resp[1] = { 0 };
	unsigned int resp_sz;

	/* We only support idx in { 0, 1 } in the 
	 * hardware
	 */
	if(idx > 2){
		goto err;
	}
	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the index on one byte */
	if(send_data(&idx, 1)){
		goto err;
	}
	/* Receive the response */
	resp_sz = 1;
	if(recv_data(resp, &resp_sz)){
		goto err;
	}
	(*iszero) = resp[0];

	return 0;
err:
	return -1;
}
                           
/* Set the infinity point flag in the hardware for
 * point at index idx
 */
int hw_driver_point_zero(unsigned char idx)
{
	unsigned char cmd[1] = { (unsigned char)ZERO };

	/* We only support idx in { 0, 1 } in the 
	 * hardware
	 */
	if(idx > 2){
		goto err;
	}
	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the index on one byte */
	if(send_data(&idx, 1)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Unset the infinity point flag in the hardware for
 * point at index idx
 */
int hw_driver_point_unzero(unsigned char idx)
{
	unsigned char cmd[1] = { (unsigned char)UNZERO };

	/* We only support idx in { 0, 1 } in the 
	 * hardware
	 */
	if(idx > 2){
		goto err;
	}
	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the index on one byte */
	if(send_data(&idx, 1)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Return (out_x, out_y) = -(x, y) */
int hw_driver_neg(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	unsigned char cmd[1] = { (unsigned char)NEG };

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x, x_sz)){
		goto err;
	}
	if(send_data(y, y_sz)){
		goto err;
	}
	/* Receive the response */
	if(recv_data(out_x, out_x_sz)){
		goto err;
	}
	if(recv_data(out_y, out_y_sz)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Return (out_x, out_y) = 2 * (x, y) */
int hw_driver_dbl(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	unsigned char cmd[1] = { (unsigned char)DBL };

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x, x_sz)){
		goto err;
	}
	if(send_data(y, y_sz)){
		goto err;
	}
	/* Receive the response */
	if(recv_data(out_x, out_x_sz)){
		goto err;
	}
	if(recv_data(out_y, out_y_sz)){
		goto err;
	}

	return 0;
err:
	return -1;
}


/* Return (out_x, out_y) = (x1, y1) + (x2, y2) */
int hw_driver_add(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
                  const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	unsigned char cmd[1] = { (unsigned char)ADD };

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x1, x1_sz)){
		goto err;
	}
	if(send_data(y1, y1_sz)){
		goto err;
	}
	if(send_data(x2, x2_sz)){
		goto err;
	}
	if(send_data(y2, y2_sz)){
		goto err;
	}
	/* Receive the response */
	if(recv_data(out_x, out_x_sz)){
		goto err;
	}
	if(recv_data(out_y, out_y_sz)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Return (out_x, out_y) = scalar * (x, y) */
int hw_driver_mul(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  const unsigned char *scalar, unsigned int scalar_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	unsigned char cmd[1] = { (unsigned char)SCAL_MUL };

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	if(send_data(x, x_sz)){
		goto err;
	}
	if(send_data(y, y_sz)){
		goto err;
	}
	if(send_data(scalar, scalar_sz)){
		goto err;
	}
	/* Receive the response */
	if(recv_data(out_x, out_x_sz)){
		goto err;
	}
	if(recv_data(out_y, out_y_sz)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Set the small scalar size in the hardware */
int hw_driver_set_small_scalar_size(unsigned int scalar_size)
{
	unsigned char cmd[1] = { (unsigned char)SET_SMALL_SCALAR_SZ };
	unsigned char scal_sz[4];

	/* First we send the command */
	if(send_data(cmd, 1)){
		goto err;
	}
	/* Send the data */
	scal_sz[0] = (unsigned char)((scalar_size >> 24) & 0xff);
	scal_sz[1] = (unsigned char)((scalar_size >> 16) & 0xff);
	scal_sz[2] = (unsigned char)((scalar_size >> 8)  & 0xff);
	scal_sz[3] = (unsigned char)((scalar_size >> 0)  & 0xff);
	if(send_data(scal_sz, 4)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/**********************************************************/
#else
/*
 * Dummy definition to avoid the empty translation unit ISO C warning
 */
typedef int dummy;
#endif /* WITH_EC_HW_ACCELERATOR */
