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

#if defined(WITH_EC_HW_ACCELERATOR) && !defined(WITH_EC_HW_SOCKET_EMUL)
/**************************************************************************/
/******************************* IPECC ************************************/
/**************************************************************************/

#include <stdint.h>
#include <stdio.h>

/* Platform specific elements */
#include "hw_accelerator_driver_ipecc_platform.h"

/***********************************************************/
/* We default to 32-bit hardware IP */
#if !defined(EC_HW_ACCELERATOR_WORD32) && !defined(EC_HW_ACCELERATOR_WORD64)
#define EC_HW_ACCELERATOR_WORD32
#endif
#if defined(EC_HW_ACCELERATOR_WORD32) && defined(EC_HW_ACCELERATOR_WORD64)
#error "EC_HW_ACCELERATOR_WORD32 and EC_HW_ACCELERATOR_WORD64 cannot be both defined!"
#endif

#if defined(EC_HW_ACCELERATOR_WORD32)
typedef volatile uint32_t ip_ecc_word;
#define IPECC_WORD_FMT "%08x"
#else
typedef volatile uint64_t ip_ecc_word;
#define IPECC_WORD_FMT "%016x"
#endif

/****************************/
/* IPECC register addresses */
/****************************/

/* GET and SET the control, status and other internal
 * registers of the IP. These are 32-bit or 64-bit wide
 * depending on the IP configuration.
 */

#if defined(EC_HW_ACCELERATOR_WORD64)
/* In 64 bits, reverse words endianness */
#define IPECC_GET_REG(reg)		((*((ip_ecc_word*)((reg)))) & 0xffffffff)
#define IPECC_SET_REG(reg, val)		((*((ip_ecc_word*)((reg)))) = (((((ip_ecc_word)(val)) & 0xffffffff) << 32) | (((ip_ecc_word)(val)) >> 32)))
#else
#define IPECC_GET_REG(reg)		 (*((ip_ecc_word*)((reg))))
#define IPECC_SET_REG(reg, val)		((*((ip_ecc_word*)((reg)))) = ((ip_ecc_word)(val)))
#endif

/***********************************************************/
/***********************************************************/
/* The base address of our hardware: this must be
 * configured by the software somehow.
 *
 * This is configured by the lower layer that implements platform
 * specific routines.
 */
static volatile uint64_t *ipecc_baddr = NULL;
static volatile uint64_t *ipecc_reset_baddr = NULL;

/* NOTE: addresses in the IP are 64-bit aligned */
#define IPECC_ALIGNED(a) ((a) / sizeof(uint64_t))

/* write-only registers */
#define IPECC_W_CTRL			(ipecc_baddr + IPECC_ALIGNED(0x000))
#define IPECC_W_WRITE_DATA		(ipecc_baddr + IPECC_ALIGNED(0x008))
#define IPECC_W_R0_NULL 		(ipecc_baddr + IPECC_ALIGNED(0x010))
#define IPECC_W_R1_NULL 		(ipecc_baddr + IPECC_ALIGNED(0x018))
#define IPECC_W_PRIME_SIZE 		(ipecc_baddr + IPECC_ALIGNED(0x020))
#define IPECC_W_BLINDING 		(ipecc_baddr + IPECC_ALIGNED(0x028))
#define IPECC_W_SHUFFLE     (ipecc_baddr + IPECC_ALIGNED(0x030))
#define IPECC_W_ZREMASK     (ipecc_baddr + IPECC_ALIGNED(0x038))
#define IPECC_W_TOKEN       (ipecc_baddr + IPECC_ALIGNED(0x040))
#define IPECC_W_IRQ     		(ipecc_baddr + IPECC_ALIGNED(0x048))
#define IPECC_W_ERR_ACK			(ipecc_baddr + IPECC_ALIGNED(0x050))
#define IPECC_W_SMALL_SCALAR		(ipecc_baddr + IPECC_ALIGNED(0x058))
#define IPECC_W_SOFT_RESET  	(ipecc_baddr + IPECC_ALIGNED(0x060))
/*	-- reserved                                                           0x068...0x0f8  */
#define IPECC_W_DBG_HALT    (ipecc_baddr + IPECC_ALIGNED(0x100))
#define IPECC_W_DBG_BKPT 		(ipecc_baddr + IPECC_ALIGNED(0x108))
#define IPECC_W_DBG_STEPS 		(ipecc_baddr + IPECC_ALIGNED(0x110))
#define IPECC_W_DBG_TRIG_ACT 		(ipecc_baddr + IPECC_ALIGNED(0x118))
#define IPECC_W_DBG_TRIG_UP		(ipecc_baddr + IPECC_ALIGNED(0x120))
#define IPECC_W_DBG_TRIG_DOWN 		(ipecc_baddr + IPECC_ALIGNED(0x128))
#define IPECC_W_DBG_OP_ADDR   		(ipecc_baddr + IPECC_ALIGNED(0x130))
#define IPECC_W_DBG_WR_OPCODE 		(ipecc_baddr + IPECC_ALIGNED(0x138))
#define IPECC_W_DBG_TRNG_CTRL 		(ipecc_baddr + IPECC_ALIGNED(0x140))
#define IPECC_W_DBG_TRNG_CFG 		(ipecc_baddr + IPECC_ALIGNED(0x148))
#define IPECC_W_DBG_FP_WADDR  		(ipecc_baddr + IPECC_ALIGNED(0x150))
#define IPECC_W_DBG_FP_WDATA 		(ipecc_baddr + IPECC_ALIGNED(0x158))
#define IPECC_W_DBG_FP_RADDR  		(ipecc_baddr + IPECC_ALIGNED(0x160))
#define IPECC_W_DBG_CFG_XYSHUF  		(ipecc_baddr + IPECC_ALIGNED(0x168))
#define IPECC_W_DBG_CFG_AXIMSK  		(ipecc_baddr + IPECC_ALIGNED(0x170))
#define IPECC_W_DBG_CFG_TOKEN  		(ipecc_baddr + IPECC_ALIGNED(0x178))
#define IPECC_W_DBG_RESET_TRNG_CNT    (ipecc_baddr + IPECC_ALIGNED(0x180))
/*	-- reserved                                                           0x188...0x1f8  */


/* Fields for W_CTRL */
#define IPECC_W_CTRL_PT_KP		((uint32_t)0x1 << 0)
#define IPECC_W_CTRL_PT_ADD		((uint32_t)0x1 << 1)
#define IPECC_W_CTRL_PT_DBL		((uint32_t)0x1 << 2)
#define IPECC_W_CTRL_PT_CHK		((uint32_t)0x1 << 3)
#define IPECC_W_CTRL_PT_NEG		((uint32_t)0x1 << 4)
#define IPECC_W_CTRL_PT_EQU		((uint32_t)0x1 << 5)
#define IPECC_W_CTRL_PT_OPP		((uint32_t)0x1 << 6)
/* bits 7-11 reserved */
#define IPECC_W_CTRL_RD_TOKEN   ((uint32_t)0x1 << 12
#define IPECC_W_CTRL_WRITE_NB		((uint32_t)0x1 << 16)
#define IPECC_W_CTRL_READ_NB		((uint32_t)0x1 << 17)
#define IPECC_W_CTRL_WRITE_K		((uint32_t)0x1 << 18)
#define IPECC_W_CTRL_NBADDR_MSK		(0xfff)
#define IPECC_W_CTRL_NBADDR_POS		(20)

/* Fields for W_R0_NULL */
#define IPECC_W_R0_NULL      ((uint32_t)0x1 << 0)

/* Fields for W_R1_NULL */
#define IPECC_W_R1_NULL      ((uint32_t)0x1 << 0)

/* Fields for W_BLINDING */
#define IPECC_W_BLINDING_EN		((uint32_t)0x1 << 0)
#define IPECC_W_BLINDING_BITS_MSK	(0xfffffff)
#define IPECC_W_BLINDING_BITS_POS	(4)

/* Fields for W_SHUFFLE */
#define IPECC_W_SHUFFLE_EN    ((uint32_t)0x1 << 0)

/* Fields for W_ZREMASK */
#define IPECC_W_ZREMASK_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_ZREMASK_BITS_MSK	(0xffff)
#define IPECC_W_ZREMASK_BITS_POS	(16)

/* Fields for W_TOKEN */
/* no field here: action is performed simply by writing to the
   register address, whatever the value written */

/* Fields for W_IRQ */
/* enable IRQ (1) or disable (0) */
#define IPECC_W_IRQ_EN    ((uint32_t)0x1 << 0)

/* Fields for W_ERR_ACK */
/* These are the same as for the ERR_ bits in R_STATUS (see below) */

/* Fields for W_SMALL_SCALAR  */
#define IPECC_W_SMALL_SCALAR_K_POS    (0)
#define IPECC_W_SMALL_SCALAR_K_MSK    (0xffff)

/* Fields for W_SOFT_RESET */
/* no field here: action is performed simply by writing to the
   register address, whatever the value written */

/* Fields for W_DBG_HALT */
#define IPECC_W_DBG_HALT_DO_HALT   ((uint32_t)0x1 << 0)

/* Fields for W_DBG_BKPT */
#define IPECC_W_DBG_BKPT_EN     ((uint32_t)0x1 << 0)
#define IPECC_W_DBG_BKPT_ID_POS    (1)
#define IPECC_W_DBG_BKPT_ID_MSK    (0x3)
#define IPECC_W_DBG_BKPT_ADDR_POS   (4)
#define IPECC_W_DBG_BKPT_ADDR_MSK   (0xfff)
#define IPECC_W_DBG_BKPT_NBIT_POS   (16)
#define IPECC_W_DBG_BKPT_NBIT_MSK   (0xfff)
#define IPECC_W_DBG_BKPT_STATE_POS     (28)
#define IPECC_W_DBG_BKPT_STATE_MSK     (0xf)

/* Fields for W_DBG_STEPS */
#define IPECC_W_DBG_STEPS_RUN_NB_OP    ((uint32_t)0x1 << 0)
#define IPECC_W_DBG_STEPS_NB_OP_POS    (8)
#define IPECC_W_DBG_STEPS_NB_OP_MSK    (0xffff)
#define IPECC_W_DBG_STEPS_RESUME     ((uint32_t)0x1 << 28)

/* Fields for W_DBG_TRIG_ACT */
/* enable trig (1) or disable it (0) */
#define IPECC_W_DBG_TRIG_ACT_EN     ((uint32_t)0x1 << 0)

/* Fields for W_DBG_TRIG_UP & W_DBG_TRIG_DOWN*/
#define IPECC_W_DBG_TRIG_POS    (0)
#define IPECC_W_DBG_TRIG_MSK    (0xffffffff)

/* Fields for W_DBG_OP_ADDR */
#define IPECC_W_DBG_OP_ADDR_POS   (0)
#define IPECC_W_DBG_OP_ADDR_MSK   (0xffff)

/* Fields for W_DBG_WR_OPCODE */
#define IPECC_W_DBG_WR_OPCODE_POS   (0)
#define IPECC_W_DBG_WR_OPCODE_MSK   (0xffffffff)

/* Fields for W_DBG_TRNG_CTRL */
/* Reset the raw FIFO (1) */
#define IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_RAW		((uint32_t)0x1 << 0)
#define IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_IRN		((uint32_t)0x1 << 1)
/* Activate raw FIFO reading (1) */
#define IPECC_W_DBG_TRNG_CTRL_READ_FIFO_RAW		((uint32_t)0x1 << 4)
/* Deactivate RNG Post-Processing (1) */
#define IPECC_W_DBG_TRNG_CTRL_DEACTIVATE_PP		((uint32_t)0x1 << 8)
/* Reading offset in bits inside the FIFO on 20 bits */
#define IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_MSK		(0xfffff)
#define IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_POS		(12)

/* Fields for W_DBG_TRNG_CFG */
/* Von Neumann debiaser activate (1) / deactivate (0) */
#define IPECC_W_DBG_TRNG_CFG_ACTIVE_DEBIAS		((uint32_t)0x1 << 0)
/* TA value (in nb of system clock cycles) */
#define IPECC_W_DBG_TRNG_CFG_TA_POS			(4)
#define IPECC_W_DBG_TRNG_CFG_TA_MSK			(0xfffff)
/* latency (in nb of system clock cycles) between each phase of
   one-bit generation in the TRNG */
#define IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_POS		(24)
#define IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_MSK		(0xf)
/* Complete bypass of the TRNG (1) or not (0) */
#define IPECC_W_DBG_TRNG_CFG_TRNG_BYPASS			((uint32_t)0x1 << 1)
/* Deterministic bit value produced when complete bypass is on */
#define IPECC_W_DBG_TRNG_CFG_TRNG_BYPASS_BIT		((uint32_t)0x1 << 2)

/* Fields for  IPECC_W_DBG_FP_WADDR */
#define IPECC_W_DBG_FP_WADDR_POS     (0)
#define IPECC_W_DBG_FP_WADDR_MSK     (0xffffffff)

/* Fields for  IPECC_W_DBG_FP_WDATA */
#define IPECC_W_DBG_FP_WDATA_POS     (0)
#define IPECC_W_DBG_FP_WDATA_MSK     (0xffffffff)

/* Fields for  IPECC_W_DBG_FP_RADDR */
#define IPECC_W_DBG_FP_RADDR_POS     (0)
#define IPECC_W_DBG_FP_RADDR_MSK     (0xffffffff)

/* Fields for  IPECC_W_DBG_CFG_NOXYSHUF */
#define IPECC_W_DBG_CFG_XYSHUF_EN    ((uint32_t)0x1 << 0)

/* Fields for  IPECC_W_DBG_CFG_AXIMSK */
#define IPECC_W_DBG_CFG_AXIMSK_EN    ((uint32_t)0x1 << 0)

/* Fields for  IPECC_W_DBG_CFG_TOKEN */
#define IPECC_W_DBG_CFG_TOKEN_EN    ((uint32_t)0x1 << 0)

/* Fields for  IPECC_W_DBG_RESET_TRNG_CNT */
/* no field here: action is performed simply by writing to the
   register address, whatever the value written */

/***********************************************************/
/***********************************************************/
/* read-only registers */
#define IPECC_R_STATUS  		(ipecc_baddr + IPECC_ALIGNED(0x000))
#define IPECC_R_READ_DATA  		(ipecc_baddr + IPECC_ALIGNED(0x008))
#define IPECC_R_CAPABILITIES  		(ipecc_baddr + IPECC_ALIGNED(0x010))
#define IPECC_R_PRIME_SIZE  		(ipecc_baddr + IPECC_ALIGNED(0x018))
#define IPECC_R_HW_VERSION      (ipecc_baddr + IPECC_ALIGNED(0x020))
/*	-- reserved                                                           0x028...0x0f8 */
#define IPECC_R_DBG_CAPABILITIES_0	(ipecc_baddr + IPECC_ALIGNED(0x100))
#define IPECC_R_DBG_CAPABILITIES_1	(ipecc_baddr + IPECC_ALIGNED(0x108))
#define IPECC_R_DBG_CAPABILITIES_2	(ipecc_baddr + IPECC_ALIGNED(0x110))
#define IPECC_R_DBG_STATUS  		(ipecc_baddr + IPECC_ALIGNED(0x118))
#define IPECC_R_DBG_TIME       (ipecc_baddr + IPECC_ALIGNED(0x120))
/* Time to fill the RNG raw FIFO in cycles */
#define IPECC_R_DBG_RAWDUR      (ipecc_baddr + IPECC_ALIGNED(0x128))
#define IPECC_R_DBG_FLAGS      (ipecc_baddr + IPECC_ALIGNED(0x130))
#define IPECC_R_DBG_TRNG_STATUS     (ipecc_baddr + IPECC_ALIGNED(0x138))
/* Read TRNG data */
#define IPECC_R_DBG_TRNG_DATA      (ipecc_baddr + IPECC_ALIGNED(0x140))
#define IPECC_R_DBG_FP_RDATA  		(ipecc_baddr + IPECC_ALIGNED(0x148))
#define IPECC_R_DBG_IRN_CNT_AXI  		(ipecc_baddr + IPECC_ALIGNED(0x150))
#define IPECC_R_DBG_IRN_CNT_EFP  		(ipecc_baddr + IPECC_ALIGNED(0x158))
#define IPECC_R_DBG_IRN_CNT_CUR  		(ipecc_baddr + IPECC_ALIGNED(0x160))
#define IPECC_R_DBG_IRN_CNT_SHF  		(ipecc_baddr + IPECC_ALIGNED(0x168))
#define IPECC_R_DBG_FP_RDATA_RDY  		(ipecc_baddr + IPECC_ALIGNED(0x170))
#define IPECC_R_DBG_TRNG_DIAG_0  		(ipecc_baddr + IPECC_ALIGNED(0x178))
#define IPECC_R_DBG_TRNG_DIAG_1  		(ipecc_baddr + IPECC_ALIGNED(0x180))
#define IPECC_R_DBG_TRNG_DIAG_2  		(ipecc_baddr + IPECC_ALIGNED(0x188))
#define IPECC_R_DBG_TRNG_DIAG_3  		(ipecc_baddr + IPECC_ALIGNED(0x190))
#define IPECC_R_DBG_TRNG_DIAG_4  		(ipecc_baddr + IPECC_ALIGNED(0x198))
#define IPECC_R_DBG_TRNG_DIAG_5  		(ipecc_baddr + IPECC_ALIGNED(0x1a0))
#define IPECC_R_DBG_TRNG_DIAG_6  		(ipecc_baddr + IPECC_ALIGNED(0x1a8))
#define IPECC_R_DBG_TRNG_DIAG_7  		(ipecc_baddr + IPECC_ALIGNED(0x1b0))
#define IPECC_R_DBG_TRNG_DIAG_8  		(ipecc_baddr + IPECC_ALIGNED(0x1b8))
/*	-- reserved                                                           0x1c0...0x1f8 */

/* Fields for R_STATUS */
#define IPECC_R_STATUS_BUSY		((uint32_t)0x1 << 0)
#define IPECC_R_STATUS_KP		((uint32_t)0x1 << 4)
#define IPECC_R_STATUS_MTY		((uint32_t)0x1 << 5)
#define IPECC_R_STATUS_POP		((uint32_t)0x1 << 6)
#define IPECC_R_STATUS_R_OR_W		((uint32_t)0x1 << 8)
#define IPECC_R_STATUS_INIT		((uint32_t)0x1 << 9)
#define IPECC_R_STATUS_ENOUGH_RND	((uint32_t)0x1 << 10)
#define IPECC_R_STATUS_NNDYNACT		((uint32_t)0x1 << 11)
#define IPECC_R_STATUS_YES		((uint32_t)0x1 << 13)
#define IPECC_R_STATUS_R0_IS_NULL	((uint32_t)0x1 << 14)
#define IPECC_R_STATUS_R1_IS_NULL	((uint32_t)0x1 << 15)
#define IPECC_R_STATUS_ERRID_MSK	(0xffff)
#define IPECC_R_STATUS_ERRID_POS	(16)

/* Fields for R_CAPABILITIES */
#define IPECC_R_CAPABILITIES_DBG_N_PROD	((uint32_t)0x1 << 0)
#define IPECC_R_CAPABILITIES_SHF	((uint32_t)0x1 << 4)
#define IPECC_R_CAPABILITIES_NNDYN	((uint32_t)0x1 << 8)
#define IPECC_R_CAPABILITIES_W64	((uint32_t)0x1 << 9)
#define IPECC_R_CAPABILITIES_NNMAX_MSK	(0xfffff)
#define IPECC_R_CAPABILITIES_NNMAX_POS	(12)

/* Fields for R_HW_VERSION */
#define IPECC_R_HW_VERSION_MAJOR_POS    (16)
#define IPECC_R_HW_VERSION_MAJOR_POS    (0xffff)
#define IPECC_R_HW_VERSION_MINOR_POS    (0)
#define IPECC_R_HW_VERSION_MINOR_POS    (0xffff)

/* Fields for R_DBG_CAPABILITIES_0 */
#define IPECC_R_DBG_CAPABILITIES_0_WW_POS    (0)
#define IPECC_R_DBG_CAPABILITIES_0_WW_MSK    (32)

/* Fields for R_DBG_CAPABILITIES_1 */
#define IPECC_R_DBG_CAPABILITIES_1_NBOPCODES_POS    (0)
#define IPECC_R_DBG_CAPABILITIES_1_NBOPCODES_MSK    (0xffff)
#define IPECC_R_DBG_CAPABILITIES_1_OPCODE_SZ_POS    (16)
#define IPECC_R_DBG_CAPABILITIES_1_OPCODE_SZ_MSK    (0xffff)

/* Fields for R_DBG_CAPABILITIES_2 */
#define IPECC_R_DBG_CAPABILITIES_2_RAW_RAMSZ_POS    (0)
#define IPECC_R_DBG_CAPABILITIES_2_RAW_RAMSZ_MSK    (0xffffffff)

/* Fields for R_DBG_STATUS */
#define IPECC_R_DBG_STATUS_HALTED    (((uint32_t)0x1 << 0)
#define IPECC_R_DBG_STATUS_BKID_POS     (1)
#define IPECC_R_DBG_STATUS_BKID_MSK     (0x3)
#define IPECC_R_DBG_STATUS_BK_HIT     (((uint32_t)0x1 << 3)
#define IPECC_R_DBG_STATUS_PC_POS     (4)
#define IPECC_R_DBG_STATUS_PC_MSK     (0xfff)
#define IPECC_R_DBG_STATUS_STATE_POS     (28)
#define IPECC_R_DBG_STATUS_STATE_MSK     (0xf)

/* Fields for R_DBG_TIME */
#define IPECC_R_DBG_TIME_POS     (0)
#define IPECC_R_DBG_TIME_MSK     (0xffffffff)

/* Fields for R_DBG_RAWDUR */
#define IPECC_R_DBG_RAWDUR_POS     (0)
#define IPECC_R_DBG_RAWDUR_MSK     (0xffffffff)

/* Fields for R_DBG_FLAGS */
#define IPECC_R_DBG_FLAGS_P_NOT_SET		((uint32_t)0x1 << 0)
#define IPECC_R_DBG_FLAGS_P_NOT_SET_MTY	((uint32_t)0x1 << 1)
#define IPECC_R_DBG_FLAGS_A_NOT_SET		((uint32_t)0x1 << 2)
#define IPECC_R_DBG_FLAGS_A_NOT_SET_MTY	((uint32_t)0x1 << 3)
#define IPECC_R_DBG_FLAGS_B_NOT_SET		((uint32_t)0x1 << 4)
#define IPECC_R_DBG_FLAGS_K_NOT_SET		((uint32_t)0x1 << 5)
#define IPECC_R_DBG_FLAGS_NNDYN_NOERR		((uint32_t)0x1 << 6)
#define IPECC_R_DBG_FLAGS_NOT_BLN_OR_Q_NOT_SET	((uint32_t)0x1 << 7)

/* Fields for R_DBG_TRNG_STATUS */
#define IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_FULL		((uint32_t)0x1 << 0)
#define IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_OFFSET_MSK	(0xffffff)
#define IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_OFFSET_POS	(8)

/* Fields for R_DBG_TRNG_DATA */
#define  IPECC_R_DBG_TRNG_DATA_BIT_POS    (0)
#define  IPECC_R_DBG_TRNG_DATA_BIT_MSK    (0x1)

/* Fields for R_DBG_FP_RDATA */
#define  IPECC_R_DBG_FP_RDATA_WWDATA_POS    (0)
#define  IPECC_R_DBG_FP_RDATA_WWDATA_MSK    (0xffffffff)

/* Fields for R_DBG_IRN_CNT_AXI, R_DBG_IRN_CNT_EFP,
 * R_DBG_IRN_CNT_CUR & R_DBG_IRN_CNT_SHF */
#define  IPECC_R_DBG_IRN_CNT_COUNT_POS    (0)
#define  IPECC_R_DBG_IRN_CNT_COUNT_MSK    (0xffffffff)

/* Fields for R_DBG_FP_RDATA_RDY */
#define IPECC_R_DBG_FP_RDATA_RDY     ((uint32_t)0x1 << 0)

/* Fields for R_DBG_TRNG_DIAG_0 */
#define IPECC_R_DBG_TRNG_DIAG_0_STARV_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_0_STARV_MSK     (0xffffffff)

/* Fields for R_DBG_TRNG_DIAG_[1357] */
#define IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK     (0xffffffff)

/* Fields for R_DBG_TRNG_DIAG_[2468] */
#define IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK     (0xffffffff)

/***********************************************************/
/***********************************************************/
/* Big numbers internal RAM memory map (by index) */
#define IPECC_BNUM_P		0
#define IPECC_BNUM_A		1
#define IPECC_BNUM_B		2
#define IPECC_BNUM_Q		3
/* NOTE: K and R0_X share the same index */
#define IPECC_BNUM_K		4
#define IPECC_BNUM_R0_X		4
#define IPECC_BNUM_R0_Y		5
#define IPECC_BNUM_R1_X		6
#define IPECC_BNUM_R1_Y		7

/** Handling the IP busy state **/
#define IPECC_BUSY_WAIT() do {						\
	while(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_BUSY){};	\
} while(0)
#define IPECC_IS_BUSY_KP() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_KP))
#define IPECC_IS_BUSY_MTY() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_MTY))
#define IPECC_IS_BUSY_POP() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_POP))
#define IPECC_IS_BUSY_R_W() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R_OR_W))
#define IPECC_IS_BUSY_RND() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_ENOUGH_RND))
#define IPECC_IS_BUSY_INIT() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_INIT))
#define IPECC_IS_BUSY_NNDYNACT() (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_NNDYNACT))

/** NN size (static and dynamic) handling **/
#define IPECC_GET_NN_MAX_SIZE() ((IPECC_GET_REG(IPECC_R_CAPABILITIES) >> IPECC_R_CAPABILITIES_NNMAX_POS) \
				& IPECC_R_CAPABILITIES_NNMAX_MSK)

#define IPECC_GET_NN_SIZE() (IPECC_GET_REG(IPECC_R_PRIME_SIZE))

#define IPECC_SET_NN_SIZE(sz) do {								\
	IPECC_SET_REG(IPECC_W_PRIME_SIZE, sz);							\
} while(0)

#define IPECC_IS_NN_DYN_ACTIVE()  (!!IPECC_GET_REG(IPECC_R_STATUS_NNDYNACT))

/** Blinding handling **/
#define IPECC_CLEAR_BLINDING() do {								\
	IPECC_SET_REG(IPECC_W_BLINDING, 0);							\
} while(0)
#define IPECC_SET_BLINDING_SIZE(blinding_size) do { 						\
	uint32_t val = 0;									\
	/* Enable blinding */									\
	val |= IPECC_W_BLINDING_EN;								\
	val |= ((blinding_size & IPECC_W_BLINDING_BITS_MSK) << IPECC_W_BLINDING_BITS_POS);	\
	IPECC_SET_REG(IPECC_W_BLINDING, val);							\
} while(0)


/** Infinity point handling with R0/R1 NULL flags **/
#define IPECC_GET_R0_INF() (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R0_IS_NULL))
#define IPECC_GET_R1_INF() (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R1_IS_NULL))

#define IPECC_CLEAR_R0_INF() do {						\
	IPECC_SET_REG(IPECC_W_R0_NULL, 0);					\
} while(0)
#define IPECC_SET_R0_INF() do {							\
	IPECC_SET_REG(IPECC_W_R0_NULL, 1);					\
} while(0)
#define IPECC_CLEAR_R1_INF() do {						\
	IPECC_SET_REG(IPECC_W_R1_NULL, 0);					\
} while(0)
#define IPECC_SET_R1_INF() do {							\
	IPECC_SET_REG(IPECC_W_R1_NULL, 1);					\
} while(0)

/** On curve/equality/opposition flags handling **/
#define IPECC_GET_ONCURVE() (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))
#define IPECC_GET_EQU()     (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))
#define IPECC_GET_OPP()     (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))

/** Addresses and data handling **/
#define IPECC_SET_READ_ADDR(addr) do {						\
	ip_ecc_word val = 0;							\
	val |= IPECC_W_CTRL_READ_NB;						\
	val |= ((addr & IPECC_W_CTRL_NBADDR_MSK) << IPECC_W_CTRL_NBADDR_POS);	\
	IPECC_SET_REG(IPECC_W_CTRL, val);					\
} while(0)

#define IPECC_READ_DATA() (IPECC_GET_REG(IPECC_R_READ_DATA))

#define IPECC_SET_WRITE_ADDR(addr, scal) do {					\
	ip_ecc_word val = 0;							\
	val |= IPECC_W_CTRL_WRITE_NB;						\
	val |= ((scal) ? IPECC_W_CTRL_WRITE_K : 0);				\
	val |= ((addr & IPECC_W_CTRL_NBADDR_MSK) << IPECC_W_CTRL_NBADDR_POS);	\
	IPECC_SET_REG(IPECC_W_CTRL, val);					\
} while(0)

#define IPECC_WRITE_DATA(val) do {						\
	IPECC_SET_REG(IPECC_W_WRITE_DATA, val);					\
} while(0)

/** Commands execution **/
#define IPECC_EXEC_PT_ADD() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_ADD))
#define IPECC_EXEC_PT_DBL() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_DBL))
#define IPECC_EXEC_PT_CHK() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_CHK))
#define IPECC_EXEC_PT_EQU() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_EQU))
#define IPECC_EXEC_PT_OPP() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_OPP))
#define IPECC_EXEC_PT_NEG() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_NEG))
#define IPECC_EXEC_PT_KP()  (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_KP))

/** Error handling **/
#define IPECC_ERR_COMP			((uint32_t)0x1 << 0) 
#define IPECC_ERR_WREG_FBD 		((uint32_t)0x1 << 1)
#define	IPECC_ERR_KP_FBD   		((uint32_t)0x1 << 2)
#define IPECC_ERR_NNDYN			((uint32_t)0x1 << 3)
#define IPECC_ERR_POP_FBD		((uint32_t)0x1 << 4)
#define IPECC_ERR_RDNB_FBD		((uint32_t)0x1 << 5)
#define IPECC_ERR_BLN			((uint32_t)0x1 << 6)
#define IPECC_ERR_UNKOWN_REG		((uint32_t)0x1 << 7)
#define IPECC_ERR_IN_PT_NOT_ON_CURVE	((uint32_t)0x1 << 8)
#define IPECC_ERR_OUT_PT_NOT_ON_CURVE	((uint32_t)0x1 << 9)


#define IPECC_GET_ERROR() ((IPECC_GET_REG(IPECC_R_STATUS) >> IPECC_R_STATUS_ERRID_POS) & IPECC_R_STATUS_ERRID_MSK)
#define IPECC_ERROR_IS_COMP()			(!!(IPECC_GET_ERROR() & IPECC_ERR_COMP))
#define IPECC_ERROR_IS_WREG_FBD()		(!!(IPECC_GET_ERROR() & IPECC_ERR_WREG_FBD))
#define IPECC_ERROR_IS_KP_FBD()			(!!(IPECC_GET_ERROR() & IPECC_ERR_KP_FBD))
#define IPECC_ERROR_IS_NNDYN()			(!!(IPECC_GET_ERROR() & IPECC_ERR_NNDYN))
#define IPECC_ERROR_IS_POP_FBD()		(!!(IPECC_GET_ERROR() & IPECC_ERR_POP_FBD))
#define IPECC_ERROR_IS_RDNB_FBD()		(!!(IPECC_GET_ERROR() & IPECC_ERR_RDNB_FBD))
#define IPECC_ERROR_IS_BLN()			(!!(IPECC_GET_ERROR() & IPECC_ERR_BLN))
#define IPECC_ERROR_IS_UNKOWN_REG()		(!!(IPECC_GET_ERROR() & IPECC_ERR_UNKOWN_REG))
#define IPECC_ERROR_IS_IN_PT_NOT_ON_CURVE 	(!!(IPECC_GET_ERROR() & IPECC_ERR_IN_PT_NOT_ON_CURVE))
#define IPECC_ERROR_IS_OUT_PT_NOT_ON_CURVE 	(!!(IPECC_GET_ERROR() & IPECC_ERR_OUT_PT_NOT_ON_CURVE))

#define IPECC_ACK_ERROR(err) (IPECC_SET_REG(IPECC_W_ERR_ACK, (((err) & IPECC_R_STATUS_ERRID_MSK) << IPECC_R_STATUS_ERRID_POS)))

/** Capabilities handling **/
#define IPECC_IS_NN_DYN_SUPPORTED() (!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_NNDYN)))
#define IPECC_IS_SHF_SUPPORTED()    (!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_SHF)))
#define IPECC_IS_W64()           (!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_W64)))

#define IPECC_ACTIVATE_SHF() (IPECC_SET_REG(IPECC_W_SHUFFLE, 1))

/** Reset handling **/
#define IPECC_RESET() (IPECC_SET_REG(IPECC_W_RESET, 1))

/** Set small scalar size **/
#define IPECC_SET_SMALL_SCALAR_SIZE(sz) IPECC_SET_REG(IPECC_W_SMALL_SCALAR, sz)


/****** DEBUG ************/
/** TRNG handling **/
/* Reset the raw FIFO */
#define IPECC_TRNG_RESET_FIFO_RAW() IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_RAW)
/* Read the FIFOs at an offset */
#define IPECC_TRNG_READ_FIFO_RAW(addr, a) do {								\
	ip_ecc_word val = 0;										\
	val |= IPECC_W_DBG_TRNG_CTRL_READ_FIFO_RAW;							\
	val |= ((addr & IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_MSK) << IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_POS);  	\
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, val);							\
	(*(a)) = IPECC_GET_REG(IPECC_R_DBG_TRNG_DATA);							\
} while(0)
/* Get the RAW FIFO size in bits */
#define IPECC_TRNG_RAW_FIFO_SZ() 32000 /* XXX */
/* Get the current status (FIFO full), reading or writing offset in the RAW FIFO */
#define IPECC_TRNG_RAW_FIFO_ISFULL() (!!(IPECC_GET_REG(IPECC_R_DBG_TRNG_STAT) & IPECC_R_DBG_TRNG_STAT_RAW_FIFO_FULL))
#define IPECC_TRNG_RAW_FIFO_FULL_BUSY_WAIT() do {                                                       \
        while(!IPECC_TRNG_RAW_FIFO_ISFULL()){};                                                         \
} while(0)
#define IPECC_TRNG_RAW_FIFO_ADDR() ((IPECC_GET_REG(IPECC_R_DBG_TRNG_STAT) >> IPECC_R_DBG_TRNG_STAT_RAW_FIFO_OFFSET_POS) & IPECC_R_DBG_TRNG_STAT_RAW_FIFO_OFFSET_MSK)
/* Configure elements for random generation */
/* Deactivate the Post-Processing */
#define IPECC_TRNG_DEACTIVATE_PP() (IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, IPECC_W_DBG_TRNG_CTRL_DEACTIVATE_PP))
/* Set options for the TRNG */
#define IPECC_TRNG_SET_OPTIONS(debias, ta, cycles, bypass) do {						\
	ip_ecc_word val = IPECC_GET_REG(IPECC_W_DBG_TRNG_CFG);						\
	val |= ((debias) ? IPECC_W_DBG_TRNG_CFG_ACTIVE_DEBIAS : 0);					\
	val |= ((ta) & IPECC_W_DBG_TRNG_CFG_TA_MSK) << IPECC_W_DBG_TRNG_CFG_TA_POS;			\
	val |= ((cycles) & IPECC_W_DBG_TRNG_CFG_TRNG_CYCLES_MSK) << IPECC_W_DBG_TRNG_CFG_TRNG_CYCLES_POS; \
	val |= ((bypass) ? IPECC_W_DBG_TRNG_CFG_TRNG_BYPASS : 0);					\
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CFG, val);							\
} while(0)

typedef enum {
	EC_HW_REG_A      = 0,
	EC_HW_REG_B      = 1,
	EC_HW_REG_P      = 2,
	EC_HW_REG_Q      = 3,
	EC_HW_REG_R0_X   = 4,
	EC_HW_REG_R0_Y   = 5,
	EC_HW_REG_R1_X   = 6,
	EC_HW_REG_R1_Y   = 7,
	EC_HW_REG_SCALAR = 8,
} ip_ecc_register;

typedef enum {
	EC_HW_REG_READ  = 0,
	EC_HW_REG_WRITE = 1,
} ip_ecc_register_mode;

typedef uint32_t ip_ecc_error;

#if defined(WITH_EC_HW_DEBUG)
static const char *ip_ecc_error_strings[] = {
	"EC_HW_STATUS_ERR_COMP",
	"EC_HW_STATUS_ERR_WREG_FBD",
	"EC_HW_STATUS_ERR_KP_FBD",
	"EC_HW_STATUS_ERR_NNDYN",
	"EC_HW_STATUS_ERR_POP_FBD",
	"EC_HW_STATUS_ERR_BLN",
	"EC_HW_STATUS_ERR_RDNB_FBD",
	"EC_HW_STATUS_ERR_BLN",
	"EC_HW_STATUS_ERR_UNKOWN_REG",
	"EC_HW_STATUS_ERR_IN_PT_NOT_ON_CURVE",
	"EC_HW_STATUS_ERR_OUT_PT_NOT_ON_CURVE",
};
static inline void ip_ecc_errors_print(ip_ecc_error err)
{
	unsigned int i;

	if(err){
		for(i = 0; i < 7; i++){
			if(((err >> i) & 1)){
				log_print("%s |", ip_ecc_error_strings[i]);
			}
		}
	}
	else{
		log_print("NONE");
	}
	return;
}
static inline void ip_ecc_log(const char *s)
{
	log_print(s);
	/* Print our current status and error */
	log_print("Status: 0x"IPECC_WORD_FMT", Error: ", IPECC_GET_REG(IPECC_R_STATUS));
	ip_ecc_errors_print(IPECC_GET_ERROR());
	log_print("\n");

	return;
}
#else
/* NO DEBUG mode, empty */
static inline void ip_ecc_log(const char *s)
{
	(void)s;
	return;
}
#endif

/* Helper to compute word size of a big number given in bytes */
static inline unsigned int ip_ecc_nn_words_from_bytes_sz(unsigned int sz)
{
	unsigned int curr_word_sz = (sz / sizeof(ip_ecc_word));
	curr_word_sz = ((sz % sizeof(ip_ecc_word)) == 0) ? (curr_word_sz) : (curr_word_sz + 1);

	return curr_word_sz;
}

/* Helper to compute bytes size of a big number given in bits */
static inline unsigned int ip_ecc_nn_bytes_from_bits_sz(unsigned int sz)
{
	unsigned int curr_bytes_sz = (sz / 8);
	curr_bytes_sz = ((sz % 8) == 0) ? (curr_bytes_sz) : (curr_bytes_sz + 1);

	return curr_bytes_sz;
}

/* Check for an error and return the error code */
static inline int ip_ecc_check_error(ip_ecc_error *out)
{
	int ret = 0;
	ip_ecc_error err;

	err = (ip_ecc_error)IPECC_GET_ERROR();

	if(out != NULL){
		(*out) = err;
	}
	if(err){
#if defined(WITH_EC_HW_DEBUG)
		printf("HW ACCEL: status: 0x"IPECC_WORD_FMT", DBG status: 0x"IPECC_WORD_FMT", got error flag 0x"IPECC_WORD_FMT":", IPECC_GET_REG(IPECC_R_STATUS), IPECC_GET_REG(IPECC_R_DBG_STATUS), err);
		ip_ecc_errors_print(err);
		printf("\n");
#endif
		ret = -1;
		/* Ack the errors */
		IPECC_ACK_ERROR(err);
	}

	return ret;
}


/* Select a register for R/W */
static inline int ip_ecc_select_reg(ip_ecc_register r, ip_ecc_register_mode rw)
{
	uint32_t addr = 0, scal = 0;

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	switch(r){
		case EC_HW_REG_A:{
			addr = IPECC_BNUM_A;
			break;
		}
		case EC_HW_REG_B:{
			addr = IPECC_BNUM_B;
			break;
		}
		case EC_HW_REG_P:{
			addr = IPECC_BNUM_P;
			break;
		}
		case EC_HW_REG_Q:{
			addr = IPECC_BNUM_Q;
			break;
		}
		case EC_HW_REG_R0_X:{
			addr = IPECC_BNUM_R0_X;
			break;
		}
		case EC_HW_REG_R0_Y:{
			addr = IPECC_BNUM_R0_Y;
			break;
		}
		case EC_HW_REG_R1_X:{
			addr = IPECC_BNUM_R1_X;
			break;
		}
		case EC_HW_REG_R1_Y:{
			addr = IPECC_BNUM_R1_Y;
			break;
		}
		case EC_HW_REG_SCALAR:{
			addr = IPECC_BNUM_K;
			scal = 1;
			break;
		}
		default:{
			goto err;
		}
	}

	switch(rw){
		case EC_HW_REG_READ:{
			ip_ecc_log("IPECC_SET_READ_ADDR before\n");
			IPECC_SET_READ_ADDR(addr);
			ip_ecc_log("IPECC_SET_READ_ADDR after\n");
			break;
		}
		case EC_HW_REG_WRITE:{
			ip_ecc_log("IPECC_SET_WRITE_ADDR before\n");
			IPECC_SET_WRITE_ADDR(addr, scal);
			ip_ecc_log("IPECC_SET_WRITE_ADDR after\n");
			break;
		}
		default:{
			goto err;
		}
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Push a word to a given register */
static inline int ip_ecc_push_word(const ip_ecc_word *w)
{
	if(w == NULL){
		goto err;
	}
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	ip_ecc_log("IPECC_WRITE_DATA before\n");
	IPECC_WRITE_DATA((*w));
	ip_ecc_log("IPECC_WRITE_DATA after\n");

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Pop a word from a given register */
static inline int ip_ecc_pop_word(ip_ecc_word *w)
{
	if(w == NULL){
		goto err;
	}
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	ip_ecc_log("IPECC_READ_DATA before\n");
	(*w) = IPECC_READ_DATA();
	ip_ecc_log("IPECC_READ_DATA after\n");

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Activate the shuffling */
static inline int ip_ecc_activate_shuffling(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* We also activate the shuffling if supported */
	if(IPECC_IS_SHF_SUPPORTED()){
		ip_ecc_log("IPECC_ACTIVATE_SHF before\n");
		IPECC_ACTIVATE_SHF();
		ip_ecc_log("IPECC_ACTIVATE_SHF after\n");

		/* Wait until the IP is not busy */
		IPECC_BUSY_WAIT();

		/* Check for error */
		if(ip_ecc_check_error(NULL)){
			goto err;
		}
	}
	else{
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Set the NN size privided in bits */
static inline int ip_ecc_set_nn_bit_size(unsigned int bit_sz)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Get the maximum NN size and check the asked size */
	if(bit_sz > IPECC_GET_NN_MAX_SIZE()){
		/* If we overflow, this is an error */
		goto err;
	}
	/* NOTE: when NN dynamic is not supported we leave
	 * our inherent maximum size.
	 */
	if(IPECC_IS_NN_DYN_SUPPORTED()){
		/* Set the current dynamic value */
		ip_ecc_log("IPECC_SET_NN_SIZE before\n");
		IPECC_SET_NN_SIZE(bit_sz);
		ip_ecc_log("IPECC_SET_NN_SIZE after\n");
		/* Wait until the IP is not busy */
		IPECC_BUSY_WAIT();

		/* Check for error */
		if(ip_ecc_check_error(NULL)){
			goto err;
		}
	}

	/* 
	 * Activate shuffling.
	 * NOTE: we ignore the possible error when
	 * shuffling is not supported
	 */
	ip_ecc_activate_shuffling();

	return 0;
err:
	return -1;
}

/* Get the current dynamic NN size in bits */
static inline unsigned int ip_ecc_get_nn_bit_size(void)
{
	/* Size is in bits, we return number of words */
	if(IPECC_IS_NN_DYN_SUPPORTED()){
		return (unsigned int)IPECC_GET_NN_SIZE();
	}
	else{
		return (unsigned int)IPECC_GET_NN_MAX_SIZE();
	}
}

/* Set the blinding size */
static inline int ip_ecc_set_blinding_size(unsigned int blinding_size)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	if(blinding_size == 0){
		/* Clear the blinding as a size of 0 means that */
		ip_ecc_log("IPECC_CLEAR_BLINDING before\n");
		IPECC_CLEAR_BLINDING();
		ip_ecc_log("IPECC_CLEAR_BLINDING after\n");
	}
	else{
		/* Set the bliding size and enable it */
		ip_ecc_log("IPECC_SET_BLINDING_SIZE before\n");
		IPECC_SET_BLINDING_SIZE(blinding_size);
		ip_ecc_log("IPECC_SET_BLINDING_SIZE after\n");
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Write a big number in the ECC IP:
 *   The input big number is in big endian format, and it is sent to the IP in the
 *   expected endianness.
 *   The numbers are little endian in words (of 32 or 64 bits), and big endian for the
 *   bytes inside words as well as for the bits inside bytes.
 */
static inline int ip_ecc_write_bignum(const unsigned char *a, unsigned int a_sz, ip_ecc_register reg)
{
	unsigned int nn_size, curr_word_sz, words_sent, bytes_idx, j;
	unsigned char end;

	ip_ecc_word w;

	if(a == NULL){
		/* Nothing to write */
		return 0;
	}

	/* Get the current size we will have to send */
	nn_size = ip_ecc_nn_words_from_bytes_sz(ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size()));
	/* Compute our current word size */
	curr_word_sz = ip_ecc_nn_words_from_bytes_sz(a_sz);

	if(curr_word_sz > nn_size){
		/* We overflow, this is an error! */
		goto err;
	}
	/* Select the write mode for the current register */
	if(ip_ecc_select_reg(reg, EC_HW_REG_WRITE)){
		goto err;
	}

	/* Send our words beginning with the last */
	words_sent = 0;
	bytes_idx = ((a_sz >= 1) ? (a_sz - 1) : 0);
	end = ((a_sz >= 1) ? 0 : 1);
	while(words_sent < nn_size){
		/* Format our words */
		w = 0;
		if(!end){
			for(j = 0; j < sizeof(w); j++){
				w |= (ip_ecc_word)(a[bytes_idx] << (8 * j));
				if(bytes_idx == 0){
					/* We have reached the end of the bytes */
					end = 1;
					break;
				}
				bytes_idx--;
			}
		}
		/* Push it to the IP */
		if(ip_ecc_push_word(&w)){
			goto err;
		}
		words_sent++;
	}

	return 0;
err:
	return -1;
}

/* Read a big number from the ECC IP:
 *   The output big number is in big endian format, and it is sent to the IP in the
 *   expected endianness.
 *   The numbers are little endian in words (of 32 or 64 bits), and big endian for the
 *   bytes inside words as well as for the bits inside bytes.
 */
static inline int ip_ecc_read_bignum(unsigned char *a, unsigned int a_sz, ip_ecc_register reg)
{
	unsigned int nn_size, curr_word_sz, words_received, bytes_idx, j;
	unsigned char end;

	ip_ecc_word w;

	if(a == NULL){
		/* Nothing to read */
		return 0;
	}

	/* Get the current size we will have to send */
	nn_size = ip_ecc_nn_words_from_bytes_sz(ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size()));
	/* Compute our current word size */
	curr_word_sz = ip_ecc_nn_words_from_bytes_sz(a_sz);

	if(curr_word_sz > nn_size){
		/* We overflow, this is an error! */
		goto err;
	}

	/* Select the read mode for the current register */
	if(ip_ecc_select_reg(reg, EC_HW_REG_READ)){
		goto err;
	}

	/* Receive our words beginning with the last */
	words_received = 0;
	bytes_idx = ((a_sz >= 1) ? (a_sz - 1) : 0);
	end = ((a_sz >= 1) ? 0 : 1);
	while(words_received < nn_size){
		/* Pop the word from the IP */
		if(ip_ecc_pop_word(&w)){
			goto err;
		}
		if(!end){
			for(j = 0; j < sizeof(w); j++){
				a[bytes_idx] = (w >> (8 * j)) & 0xff;
				if(bytes_idx == 0){
					/* We have reached the end of the bytes */
					end = 1;
					break;
				}
				bytes_idx--;
			}
		}
		words_received++;
	}

	return 0;
err:
	return -1;
}

static inline int ip_ecc_get_r0_inf(int *iszero)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	(*iszero) = (int)IPECC_GET_R0_INF();

	return 0;
}

static inline int ip_ecc_get_r1_inf(int *iszero)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	(*iszero) = (int)IPECC_GET_R1_INF();

	return 0;
}

static inline int ip_ecc_set_r0_inf(int val)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	switch(val){
		case 0:{
			IPECC_CLEAR_R0_INF();
			break;
		}
		case 1:{
			IPECC_SET_R0_INF();
			break;
		}
		default:{
			goto err;
		}
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

static inline int ip_ecc_set_r1_inf(int val)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	switch(val){
		case 0:{
			IPECC_CLEAR_R1_INF();
			break;
		}
		case 1:{
			IPECC_SET_R1_INF();
			break;
		}
		default:{
			goto err;
		}
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/**** Commands execution ******/
static inline int ip_ecc_exec_command(ip_ecc_command cmd, int *flag)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Execute the command */
	switch(cmd){
		case PT_ADD:{
			IPECC_EXEC_PT_ADD();
			break;
		}
		case PT_DBL:{
			IPECC_EXEC_PT_DBL();
			break;
		}
		case PT_KP:{
			IPECC_EXEC_PT_KP();
			break;
		}
		case PT_CHK:{
			IPECC_EXEC_PT_CHK();
			break;
		}
		case PT_EQU:{
			IPECC_EXEC_PT_EQU();
			break;
		}
		case PT_OPP:{
			IPECC_EXEC_PT_OPP();
			break;
		}
		case PT_NEG:{
			IPECC_EXEC_PT_NEG();
			break;
		}
		default:{
			goto err;
		}
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Check for error */
	if(ip_ecc_check_error(NULL)){
		goto err;
	}

	/* Get a flag if necessary */
	if(flag != NULL){
		switch(cmd){
			case PT_CHK:{
				(*flag) = IPECC_GET_ONCURVE();
				break;
			}
			case PT_EQU:{
				(*flag) = IPECC_GET_EQU();
				break;
			}
			case PT_OPP:{
				(*flag) = IPECC_GET_OPP();
				break;
			}
			default:{
				goto err;
			}
		}
	}

	return 0;
err:
	return -1;
}

/**** TRNG debug ******/
/* The following function configures the TRNG */
static inline int ip_ecc_configure_trng(int debias, uint32_t ta, uint32_t cycles, int bypass, int pp)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	if(pp){
		/* Deactivate the Post-Processing if asked to */
		IPECC_TRNG_DEACTIVATE_PP();
		/* Wait until the IP is not busy */
		IPECC_BUSY_WAIT();
	}
	
	/* Set other options */
	IPECC_TRNG_SET_OPTIONS(debias, ta, cycles, bypass);
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

#if 0
/* Function to get the random output of the RAW FIFO */
static inline int ip_ecc_get_random(unsigned char *out, unsigned int out_sz)
{
	unsigned int read = 0, addr;
	unsigned char bit;

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Read in a loop the asked size */
	while(read != (8 * out_sz)){
		unsigned int i;
		/* Wait until our FIFO is full */
		IPECC_TRNG_RAW_FIFO_FULL_BUSY_WAIT();
		/* Read all our data */
		addr = 0;
		for(i = 0; i < IPECC_TRNG_RAW_FIFO_SZ(); i++){
			IPECC_TRNG_READ_FIFO_RAW(addr, &bit);
			if((read % 8) == 0){
				out[(read / 8)] = 0;
			}
			out[(read / 8)] |= (bit << (read % 8));
			addr++;
			read++;
			if(read == (8 * out_sz)){
				break;
			}
		}
	}

	return 0;
err:
	return -1;
}
#endif

/*********** Exported functions *********************************/
/****************************************************************/
static volatile unsigned char hw_driver_setup_state = 0;

static inline int driver_setup(void)
{
	if(!hw_driver_setup_state){
		/* Ask the lower layer for a setup */
		if(hw_driver_setup((volatile unsigned char**)&ipecc_baddr, (volatile unsigned char**)&ipecc_reset_baddr)){
			goto err;
		}
		/* Reset the IP for a clean state */
		IPECC_RESET();
		/* We are in the initialized state */
		hw_driver_setup_state = 1;
	}
	
	return 0;
err:
	return -1;
}

/* Reset the hardware */
int hw_driver_reset(void)
{
	/* Reset the IP for a clean state */
        IPECC_RESET();

	return 0;
}

/* Set the curve parameters a, b, p and q */
int hw_driver_set_curve(const unsigned char *a, unsigned int a_sz, const unsigned char *b, unsigned int b_sz,
       		        const unsigned char *p, unsigned int p_sz, const unsigned char *q, unsigned int q_sz)
{
	if(driver_setup()){
		goto err;
	}
	/* We set the dynamic NN size value to be the max of P and
	 * Q size
	 */
	if(p_sz > q_sz){
		if(ip_ecc_set_nn_bit_size(8 * p_sz)){
			goto err;
		}
	}
	else{
		if(ip_ecc_set_nn_bit_size(8 * q_sz)){
			goto err;
		}
	}

	/* Set a, b, p, q */
	if(ip_ecc_write_bignum(p, p_sz, EC_HW_REG_P)){
		goto err;
	}
	if(ip_ecc_write_bignum(a, a_sz, EC_HW_REG_A)){
		goto err;
	}
	if(ip_ecc_write_bignum(b, b_sz, EC_HW_REG_B)){
		goto err;
	}
	if(ip_ecc_write_bignum(q, q_sz, EC_HW_REG_Q)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Activate the blinding for scalar multiplication */
int hw_driver_set_blinding(unsigned int blinding_size)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_set_blinding_size(blinding_size)){
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
	int inf_r0, inf_r1;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x, x_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y, y_sz, EC_HW_REG_R0_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Check if it is on curve */
	if(ip_ecc_exec_command(PT_CHK, on_curve)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Check if affine points (x1, y1) and (x2, y2) are equal */
int hw_driver_eq(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
       	    	 const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
                 int *is_eq)
{
	int inf_r0, inf_r1;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x1, x1_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y1, y1_sz, EC_HW_REG_R0_Y)){
		goto err;
	}
	/* Write our R1 register */
	if(ip_ecc_write_bignum(x2, x2_sz, EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y2, y2_sz, EC_HW_REG_R1_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Check if it the points are equal */
	if(ip_ecc_exec_command(PT_EQU, is_eq)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Check if affine points (x1, y1) and (x2, y2) are opposite */
int hw_driver_opp(const unsigned char *x1, unsigned int x1_sz, const unsigned char *y1, unsigned int y1_sz,
                  const unsigned char *x2, unsigned int x2_sz, const unsigned char *y2, unsigned int y2_sz,
               	  int *is_opp)
{
	int inf_r0, inf_r1;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x1, x1_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y1, y1_sz, EC_HW_REG_R0_Y)){
		goto err;
	}
	/* Write our R1 register */
	if(ip_ecc_write_bignum(x2, x2_sz, EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y2, y2_sz, EC_HW_REG_R1_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}


	/* Check if the points are opposite */
	if(ip_ecc_exec_command(PT_OPP, is_opp)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Check if the infinity point flag is set in the hardware for
 * point at index idx
 */
int hw_driver_point_iszero(unsigned char idx, int *iszero)
{
	if(driver_setup()){
		goto err;
	}

	switch(idx){
		case 0:{
			/* Get our R0 register infinity flag */
			if(ip_ecc_get_r0_inf(iszero)){
				goto err;
			}
			break;
		}
		case 1:{
			/* Get our R1 register infinity flag */
			if(ip_ecc_get_r1_inf(iszero)){
				goto err;
			}
			break;
		}
		default:{
			/* Index not supported */
			goto err;
		}
	}

	return 0;
err:
	return -1;
}

/* Set the infinity point flag in the hardware for
 * point at index idx
 */
int hw_driver_point_zero(unsigned char idx)
{
	if(driver_setup()){
		goto err;
	}

	switch(idx){
		case 0:{
			/* Write our R0 register infinity flag */
			if(ip_ecc_set_r0_inf(1)){
				goto err;
			}
			break;
		}
		case 1:{
			/* Write our R1 register infinity flag */
			if(ip_ecc_set_r1_inf(1)){
				goto err;
			}
			break;
		}
		default:{
			/* Index not supported */
			goto err;
		}
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
	if(driver_setup()){
		goto err;
	}

	switch(idx){
		case 0:{
			/* Write our R0 register infinity flag */
			if(ip_ecc_set_r0_inf(0)){
				goto err;
			}
			break;
		}
		case 1:{
			/* Write our R1 register infinity flag */
			if(ip_ecc_set_r1_inf(0)){
				goto err;
			}
			break;
		}
		default:{
			/* Index not supported */
			goto err;
		}
	}

	return 0;
err:
	return -1;
}

/* Return (out_x, out_y) = -(x, y) */
int hw_driver_neg(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	int inf_r0, inf_r1;
	unsigned int nn_sz;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x, x_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y, y_sz, EC_HW_REG_R0_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Execute our NEG command */
	if(ip_ecc_exec_command(PT_NEG, NULL)){
		goto err;
	}

	/* Get back the result from R1 */
	nn_sz = ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size());
	if(((*out_x_sz) < nn_sz) || ((*out_y_sz) < nn_sz)){
		goto err;
	}
	(*out_x_sz) = (*out_y_sz) = nn_sz;
	if(ip_ecc_read_bignum(out_x, (*out_x_sz), EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_read_bignum(out_y, (*out_y_sz), EC_HW_REG_R1_Y)){
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
	int inf_r0, inf_r1;
	unsigned int nn_sz;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x, x_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y, y_sz, EC_HW_REG_R0_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Execute our DBL command */
	if(ip_ecc_exec_command(PT_DBL, NULL)){
		goto err;
	}

	/* Get back the result from R1 */
	nn_sz = ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size());
	if(((*out_x_sz) < nn_sz) || ((*out_y_sz) < nn_sz)){
		goto err;
	}
	(*out_x_sz) = (*out_y_sz) = nn_sz;
	if(ip_ecc_read_bignum(out_x, (*out_x_sz), EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_read_bignum(out_y, (*out_y_sz), EC_HW_REG_R1_Y)){
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
	int inf_r0, inf_r1;
	unsigned int nn_sz;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our R0 register */
	if(ip_ecc_write_bignum(x1, x1_sz, EC_HW_REG_R0_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y1, y1_sz, EC_HW_REG_R0_Y)){
		goto err;
	}
	/* Write our R1 register */
	if(ip_ecc_write_bignum(x2, x2_sz, EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y2, y2_sz, EC_HW_REG_R1_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Execute our ADD command */
	if(ip_ecc_exec_command(PT_ADD, NULL)){
		goto err;
	}

	/* Get back the result from R1 */
	nn_sz = ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size());
	if(((*out_x_sz) < nn_sz) || ((*out_y_sz) < nn_sz)){
		goto err;
	}
	(*out_x_sz) = (*out_y_sz) = nn_sz;
	if(ip_ecc_read_bignum(out_x, (*out_x_sz), EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_read_bignum(out_y, (*out_y_sz), EC_HW_REG_R1_Y)){
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
	int inf_r0, inf_r1;
	unsigned int nn_sz;

	if(driver_setup()){
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		goto err;
	}

	/* Write our scalar register with the scalar k */
	if(ip_ecc_write_bignum(scalar, scalar_sz, EC_HW_REG_SCALAR)){
		goto err;
	}
	/* Write our R1 register with the point to be multiplied */
	if(ip_ecc_write_bignum(x, x_sz, EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_write_bignum(y, y_sz, EC_HW_REG_R1_Y)){
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		goto err;
	}

	/* Execute our KP command */
	if(ip_ecc_exec_command(PT_KP, NULL)){
		goto err;
	}

	/* Get back the result from R1 */
	nn_sz = ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size());
	if(((*out_x_sz) < nn_sz) || ((*out_y_sz) < nn_sz)){
		goto err;
	}
	(*out_x_sz) = (*out_y_sz) = nn_sz;
	if(ip_ecc_read_bignum(out_x, (*out_x_sz), EC_HW_REG_R1_X)){
		goto err;
	}
	if(ip_ecc_read_bignum(out_y, (*out_y_sz), EC_HW_REG_R1_Y)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Set the small scalar size in the hardware */
int hw_driver_set_small_scalar_size(unsigned int bit_sz)
{
	/* NOTE: sanity check on this size should be performed by
	 * the hardware (e.g. is this size exceeds the nn size, and
	 * so on). So no need to sanity check anything here. */
	IPECC_SET_SMALL_SCALAR_SIZE(bit_sz);

	return 0;
}

/**********************************************************/

#else
/*
 * Dummy definition to avoid the empty translation unit ISO C warning
 */
typedef int dummy;
#endif /* WITH_EC_HW_ACCELERATOR */
