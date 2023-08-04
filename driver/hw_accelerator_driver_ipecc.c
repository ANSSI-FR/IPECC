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
#define IPECC_GET_REG(reg)	((*((ip_ecc_word*)((reg)))) & 0xffffffff)
#define IPECC_SET_REG(reg, val)	\
	((*((ip_ecc_word*)((reg)))) = (((((ip_ecc_word)(val)) & 0xffffffff) << 32) \
		| (((ip_ecc_word)(val)) >> 32)))
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
static volatile uint64_t *ipecc_pseudotrng_baddr = NULL;

/* NOTE: addresses in the IP are 64-bit aligned */
#define IPECC_ALIGNED(a) ((a) / sizeof(uint64_t))

/* Write-only registers */
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
/*	-- Reserved                                                           0x068...0x0f8  */
#define IPECC_W_DBG_HALT    (ipecc_baddr + IPECC_ALIGNED(0x100))
#define IPECC_W_DBG_BKPT 		(ipecc_baddr + IPECC_ALIGNED(0x108))
#define IPECC_W_DBG_STEPS 		(ipecc_baddr + IPECC_ALIGNED(0x110))
#define IPECC_W_DBG_TRIG_ACT 		(ipecc_baddr + IPECC_ALIGNED(0x118))
#define IPECC_W_DBG_TRIG_UP		(ipecc_baddr + IPECC_ALIGNED(0x120))
#define IPECC_W_DBG_TRIG_DOWN 		(ipecc_baddr + IPECC_ALIGNED(0x128))
#define IPECC_W_DBG_OP_WADDR   		(ipecc_baddr + IPECC_ALIGNED(0x130))
#define IPECC_W_DBG_OPCODE 		(ipecc_baddr + IPECC_ALIGNED(0x138))
#define IPECC_W_DBG_TRNG_CTRL 		(ipecc_baddr + IPECC_ALIGNED(0x140))
#define IPECC_W_DBG_TRNG_CFG 		(ipecc_baddr + IPECC_ALIGNED(0x148))
#define IPECC_W_DBG_FP_WADDR  		(ipecc_baddr + IPECC_ALIGNED(0x150))
#define IPECC_W_DBG_FP_WDATA 		(ipecc_baddr + IPECC_ALIGNED(0x158))
#define IPECC_W_DBG_FP_RADDR  		(ipecc_baddr + IPECC_ALIGNED(0x160))
#define IPECC_W_DBG_CFG_XYSHUF  		(ipecc_baddr + IPECC_ALIGNED(0x168))
#define IPECC_W_DBG_CFG_AXIMSK  		(ipecc_baddr + IPECC_ALIGNED(0x170))
#define IPECC_W_DBG_CFG_TOKEN  		(ipecc_baddr + IPECC_ALIGNED(0x178))
#define IPECC_W_DBG_RESET_TRNG_CNT    (ipecc_baddr + IPECC_ALIGNED(0x180))
/*	-- Reserved                                                           0x188...0x1f8  */

/* Read-only registers */
#define IPECC_R_STATUS  		(ipecc_baddr + IPECC_ALIGNED(0x000))
#define IPECC_R_READ_DATA  		(ipecc_baddr + IPECC_ALIGNED(0x008))
#define IPECC_R_CAPABILITIES  		(ipecc_baddr + IPECC_ALIGNED(0x010))
#define IPECC_R_PRIME_SIZE  		(ipecc_baddr + IPECC_ALIGNED(0x018))
#define IPECC_R_HW_VERSION      (ipecc_baddr + IPECC_ALIGNED(0x020))
/*	-- Reserved                               0x028...0x0f8 */
#define IPECC_R_DBG_CAPABILITIES_0	(ipecc_baddr + IPECC_ALIGNED(0x100))
#define IPECC_R_DBG_CAPABILITIES_1	(ipecc_baddr + IPECC_ALIGNED(0x108))
#define IPECC_R_DBG_CAPABILITIES_2	(ipecc_baddr + IPECC_ALIGNED(0x110))
#define IPECC_R_DBG_STATUS  		(ipecc_baddr + IPECC_ALIGNED(0x118))
#define IPECC_R_DBG_TIME       (ipecc_baddr + IPECC_ALIGNED(0x120))
/* Time to fill the RNG raw FIFO in cycles */
#define IPECC_R_DBG_RAWDUR      (ipecc_baddr + IPECC_ALIGNED(0x128))
#define IPECC_R_DBG_FLAGS      (ipecc_baddr + IPECC_ALIGNED(0x130))  /* Obsolete, will be removed */
#define IPECC_R_DBG_TRNG_STATUS     (ipecc_baddr + IPECC_ALIGNED(0x138))
/* Read TRNG data */
#define IPECC_R_DBG_TRNG_RAW_DATA   (ipecc_baddr + IPECC_ALIGNED(0x140))
#define IPECC_R_DBG_FP_RDATA  		 (ipecc_baddr + IPECC_ALIGNED(0x148))
#define IPECC_R_DBG_IRN_CNT_AXI  		(ipecc_baddr + IPECC_ALIGNED(0x150))
#define IPECC_R_DBG_IRN_CNT_EFP  		(ipecc_baddr + IPECC_ALIGNED(0x158))
#define IPECC_R_DBG_IRN_CNT_CRV  		(ipecc_baddr + IPECC_ALIGNED(0x160))
#define IPECC_R_DBG_IRN_CNT_SHF  		(ipecc_baddr + IPECC_ALIGNED(0x168))
#define IPECC_R_DBG_FP_RDATA_RDY    (ipecc_baddr + IPECC_ALIGNED(0x170))
#define IPECC_R_DBG_TRNG_DIAG_0  		(ipecc_baddr + IPECC_ALIGNED(0x178))
#define IPECC_R_DBG_TRNG_DIAG_1  		(ipecc_baddr + IPECC_ALIGNED(0x180))
#define IPECC_R_DBG_TRNG_DIAG_2  		(ipecc_baddr + IPECC_ALIGNED(0x188))
#define IPECC_R_DBG_TRNG_DIAG_3  		(ipecc_baddr + IPECC_ALIGNED(0x190))
#define IPECC_R_DBG_TRNG_DIAG_4  		(ipecc_baddr + IPECC_ALIGNED(0x198))
#define IPECC_R_DBG_TRNG_DIAG_5  		(ipecc_baddr + IPECC_ALIGNED(0x1a0))
#define IPECC_R_DBG_TRNG_DIAG_6  		(ipecc_baddr + IPECC_ALIGNED(0x1a8))
#define IPECC_R_DBG_TRNG_DIAG_7  		(ipecc_baddr + IPECC_ALIGNED(0x1b0))
#define IPECC_R_DBG_TRNG_DIAG_8  		(ipecc_baddr + IPECC_ALIGNED(0x1b8))
/*	-- Reserved                               0x1c0...0x1f8 */

/* Optional device acting as "pseudo TRNG" device, which software can push
 * some byte stream/file to.
 *
 * Using the same byte stream/file in the VHDL testbench of the IP hence
 * makes it possible to get full bit-by-bit and instruction-per-instruction 
 * comparison between VHDL simulation & real hardware.
 *
 * This is not "CABA" (cycle-accurate, bit-accurate) simulation yet,
 * rather "IACA" (instruction-accurate, bit-accurate) simulation - which,
 * using the breakpoint & the step-by-step features provided with the IP
 * and its driver, can be a powerful debugging tool.
 * */
/* Write-only registers */
#define IPECC_PSEUDOTRNG_W_SOFT_RESET   (ipecc_pseudotrng_baddr + IPECC_ALIGNED(0x00))
#define IPECC_PSEUDOTRNG_W_WRITE_DATA   (ipecc_pseudotrng_baddr + IPECC_ALIGNED(0x08))

/* Read-only registers */
#define IPECC_PSEUDOTRNG_R_FIFO_COUNT   (ipecc_pseudotrng_baddr + IPECC_ALIGNED(0x00))

/*************************************
 * Bit & fields positions in registers
 *************************************/

/* Fields for W_CTRL */
#define IPECC_W_CTRL_PT_KP		((uint32_t)0x1 << 0)
#define IPECC_W_CTRL_PT_ADD		((uint32_t)0x1 << 1)
#define IPECC_W_CTRL_PT_DBL		((uint32_t)0x1 << 2)
#define IPECC_W_CTRL_PT_CHK		((uint32_t)0x1 << 3)
#define IPECC_W_CTRL_PT_NEG		((uint32_t)0x1 << 4)
#define IPECC_W_CTRL_PT_EQU		((uint32_t)0x1 << 5)
#define IPECC_W_CTRL_PT_OPP		((uint32_t)0x1 << 6)
/* bits 7-11 reserved */
#define IPECC_W_CTRL_RD_TOKEN   ((uint32_t)0x1 << 12)
#define IPECC_W_CTRL_WRITE_NB		((uint32_t)0x1 << 16)
#define IPECC_W_CTRL_READ_NB		((uint32_t)0x1 << 17)
#define IPECC_W_CTRL_WRITE_K		((uint32_t)0x1 << 18)
#define IPECC_W_CTRL_NBADDR_MSK		(0xfff)
#define IPECC_W_CTRL_NBADDR_POS		(20)

/* Fields for W_R0_NULL & W_R1_NULL */
#define IPECC_W_POINT_IS_NULL      ((uint32_t)0x1 << 0)
#define IPECC_W_POINT_IS_NOT_NULL      ((uint32_t)0x0 << 0)

/* Fields for W_PRIME_SIZE & R_PRIME_SIZE */
#define IPECC_W_PRIME_SIZE_POS   (0)
#define IPECC_W_PRIME_SIZE_MSK   (0xffff)

/* Fields for W_BLINDING */
#define IPECC_W_BLINDING_EN		((uint32_t)0x1 << 0)
#define IPECC_W_BLINDING_BITS_MSK	(0xfffffff)
#define IPECC_W_BLINDING_BITS_POS	(4)
#define IPECC_W_BLINDING_DIS		((uint32_t)0x0 << 0)

/* Fields for W_SHUFFLE */
#define IPECC_W_SHUFFLE_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_SHUFFLE_DIS    ((uint32_t)0x0 << 0)

/* Fields for W_ZREMASK */
#define IPECC_W_ZREMASK_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_ZREMASK_BITS_MSK	(0xffff)
#define IPECC_W_ZREMASK_BITS_POS	(16)
#define IPECC_W_ZREMASK_DIS    ((uint32_t)0x0 << 0)

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

/* Fields for W_DBG_TRIG_UP & W_DBG_TRIG_DOWN */
#define IPECC_W_DBG_TRIG_POS    (0)
#define IPECC_W_DBG_TRIG_MSK    (0xffffffff)

/* Fields for W_DBG_OP_WADDR */
#define IPECC_W_DBG_OP_WADDR_POS   (0)
#define IPECC_W_DBG_OP_WADDR_MSK   (0xffff)

/* Fields for W_DBG_OPCODE */
#define IPECC_W_DBG_OPCODE_POS   (0)
#define IPECC_W_DBG_OPCODE_MSK   (0xffffffff)

/* Fields for W_DBG_TRNG_CTRL */
/* Disable the TRNG post processing logic that pulls bytes
 * from the raw random source */
#define IPECC_W_DBG_TRNG_CTRL_POSTPROC_DISABLE  (0)
/* Reset the raw FIFO */
#define IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_RAW		((uint32_t)0x1 << 1)
/* Reset the internal random numbers FIFOs */
#define IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_IRN		((uint32_t)0x1 << 2)
/* Read one bit from raw FIFO */
#define IPECC_W_DBG_TRNG_CTRL_READ_FIFO_RAW		((uint32_t)0x1 << 4)
/* Reading offset in bits inside the FIFO on 20 bits */
#define IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_MSK		(0xfffff)
#define IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_POS		(8)
/* Disable the read function of the raw random FIFO
 * (to allow debug software to read & statistically analyze
 * the raw random bits). */
#define IPECC_W_DBG_TRNG_CTRL_RAW_DISABLE_FIFO_READ_PORT_POS   (28)
/* Complete bypass of the TRNG (1) or not (0) */
#define IPECC_W_DBG_TRNG_CTRL_TRNG_BYPASS			((uint32_t)0x1 << 29)
/* Deterministic bit value produced when complete bypass is on */
#define IPECC_W_DBG_TRNG_CTRL_TRNG_BYPASS_VAL_POS		(30)
#define IPECC_W_DBG_TRNG_CTRL_NNRND_DETERMINISTIC   (31)

/* Fields for W_DBG_TRNG_CFG */
/* Von Neumann debiaser activate */
#define IPECC_W_DBG_TRNG_CFG_ACTIVE_DEBIAS		((uint32_t)0x1 << 0)
/* TA value (in nb of system clock cycles) */
#define IPECC_W_DBG_TRNG_CFG_TA_POS			(4)
#define IPECC_W_DBG_TRNG_CFG_TA_MSK			(0xffff)
/* latency (in nb of system clock cycles) between each phase of
   one-bit generation in the TRNG */
#define IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_POS		(20)
#define IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_MSK		(0xf)
#define IPECC_W_DBG_TRNG_CFG_USE_PSEUDO   ((uint32_t)0x1 << 31)

/* Fields for IPECC_W_DBG_FP_WADDR */
#define IPECC_W_DBG_FP_WADDR_POS     (0)
#define IPECC_W_DBG_FP_WADDR_MSK     (0xffffffff)

/* Fields for IPECC_W_DBG_FP_WDATA & IPECC_R_DBG_FP_RDATA */
#define IPECC_W_DBG_FP_DATA_POS     (0)
#define IPECC_W_DBG_FP_DATA_MSK     (0xffffffff)

/* Fields for IPECC_W_DBG_FP_RADDR */
#define IPECC_W_DBG_FP_RADDR_POS     (0)
#define IPECC_W_DBG_FP_RADDR_MSK     (0xffffffff)

/* Fields for IPECC_W_DBG_CFG_NOXYSHUF */
#define IPECC_W_DBG_CFG_XYSHUF_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_DBG_CFG_XYSHUF_DIS    ((uint32_t)0x0 << 0)

/* Fields for IPECC_W_DBG_CFG_AXIMSK */
#define IPECC_W_DBG_CFG_AXIMSK_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_DBG_CFG_AXIMSK_DIS    ((uint32_t)0x0 << 0)

/* Fields for IPECC_W_DBG_CFG_TOKEN */
#define IPECC_W_DBG_CFG_TOKEN_EN    ((uint32_t)0x1 << 0)
#define IPECC_W_DBG_CFG_TOKEN_DIS    ((uint32_t)0x0 << 0)

/* Fields for IPECC_W_DBG_RESET_TRNG_CNT */
/* no field here: action is performed simply by writing to the
   register address, whatever the value written */

/* Fields for R_STATUS */
#define IPECC_R_STATUS_BUSY		((uint32_t)0x1 << 0)
#define IPECC_R_STATUS_KP		((uint32_t)0x1 << 4)
#define IPECC_R_STATUS_MTY		((uint32_t)0x1 << 5)
#define IPECC_R_STATUS_POP		((uint32_t)0x1 << 6)
#define IPECC_R_STATUS_R_OR_W		((uint32_t)0x1 << 7)
#define IPECC_R_STATUS_INIT   ((uint32_t)0x1 << 8)
#define IPECC_R_STATUS_NNDYNACT		((uint32_t)0x1 << 9)
#define IPECC_R_STATUS_ENOUGH_RND_WK	((uint32_t)0x1 << 10)
#define IPECC_R_STATUS_YES		((uint32_t)0x1 << 11)
#define IPECC_R_STATUS_R0_IS_NULL	((uint32_t)0x1 << 12)
#define IPECC_R_STATUS_R1_IS_NULL	((uint32_t)0x1 << 13)
#define IPECC_R_STATUS_TOKEN_GEN    ((uint32_t)0x1 << 14)
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
#define IPECC_R_HW_VERSION_MAJOR_MSK    (0xffff)
#define IPECC_R_HW_VERSION_MINOR_POS    (0)
#define IPECC_R_HW_VERSION_MINOR_MSK    (0xffff)

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
#define IPECC_R_DBG_CAPABILITIES_2_RAW_RAMSZ_MSK    (0xffff)
#define IPECC_R_DBG_CAPABILITIES_2_IRN_SHF_WIDTH_POS    (16)
#define IPECC_R_DBG_CAPABILITIES_2_IRN_SHF_WIDTH_MSK    (0xffff)

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

/* Fields for R_DBG_FLAGS */  /* Obsolete, will be removed */
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

/* Fields for R_DBG_TRNG_RAW_DATA */
#define  IPECC_R_DBG_TRNG_RAW_DATA_POS    (0)
#define  IPECC_R_DBG_TRNG_RAW_DATA_MSK    (0x1)

/* Fields for R_DBG_IRN_CNT_AXI, R_DBG_IRN_CNT_EFP,
 * R_DBG_IRN_CNTV_CRV & R_DBG_IRN_CNT_SHF */
#define  IPECC_R_DBG_IRN_CNT_COUNT_POS    (0)
#define  IPECC_R_DBG_IRN_CNT_COUNT_MSK    (0xffffffff)

/* Fields for R_DBG_FP_RDATA_RDY */
#define IPECC_R_DBG_FP_RDATA_RDY_IS_READY     ((uint32_t)0x1 << 0)

/* Fields for R_DBG_TRNG_DIAG_0 */
#define IPECC_R_DBG_TRNG_DIAG_0_STARV_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_0_STARV_MSK     (0xffffffff)

/* Fields for R_DBG_TRNG_DIAG_[1|3|5|7] */
#define IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK     (0xffffffff)

/* Fields for R_DBG_TRNG_DIAG_[2|4|6|8] */
#define IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS     (0)
#define IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK     (0xffffffff)



/*************************************************************
 * Low-level macros: actions involving a direct write or read
 * to/from an IP register, along with related helper macros.
 *
 * Hereafter sorted by their target register.
 *************************************************************/
/*
 * Actions involving registers R_STATUS & W_CTRL
 * *********************************************
 */
/* Handling the IP busy state.
 */
#define IPECC_BUSY_WAIT() do { \
	while(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_BUSY){}; \
} while(0)
/* The following macros IPECC_IS_BUSY_* are to obtain more info, when the IP is busy,
 * on why it is busy.
 * However one should keep in mind that polling code should restrict to IPECC_BUSY_WAIT
 * to determine if previous action/job submitted to the IP is done and if the IP is
 * ready to receive next command. The following macros (all in the form IPECC_IS_BUSY_*)
 * are only provided as a way for software to get extra information on the reason why
 * the IP being busy */

/* Is the IP busy computing a [k]P?
 */
#define IPECC_IS_BUSY_KP() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_KP))

/* Is the IP busy computing the Montgomery constants?
 */
#define IPECC_IS_BUSY_MTY() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_MTY))

/* Is the IP busy computing a point operation other than [k]P?
 * (e.g addition, doubling, etc)
 */
#define IPECC_IS_BUSY_POP() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_POP))

/* Is the IP busy transferring a big number from/to the AXI interface
 * to/from its internal memory of big numbers?
 */
#define IPECC_IS_BUSY_R_W() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R_OR_W))

/* Is the IP is in its reset/initialization process?
 */
#define IPECC_IS_BUSY_INIT() 	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_INIT))

/* Is the IP busy computing internal signals due to the refresh
 * of 'nn' main security parameter? (only with a hardware synthesized
 * with 'nn modifiable at runtime' option)
 */
#define IPECC_IS_BUSY_NNDYNACT() \
	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_NNDYNACT))

/* To know if the IP is ready to accept a new scalar (writing the scalar is a
 * particular case of writing a big number: the IP must first gather enough random
 * to mask it on-the-fly during its transfer into the IP's memory of large numbers).
 *
 * This bit is not part of the "busy" state, meaning the IP won't show a high
 * 'STATUS_BUSY' bit just because there is not enough random to mask the scalar (yet).
 *
 * Software must first check that this bit is active (1) before writing a new scalar
 * (otherwise data written by software when transmitting the scalar will be ignored,
 * and error flag 'NOT_ENOUGH_RANDOM_WK' will be set in register 'R_STATUS').
 */
#define IPECC_IS_ENOUGH_RND_WRITE_SCALAR() \
	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_ENOUGH_RND_WK))

#define IPECC_ENOUGH_WK_RANDOM_WAIT() do { \
	while(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_ENOUGH_RND_WK){}; \
} while(0)

/* Is the IP busy generating the random token?
 */
#define IPECC_IS_BUSY_GEN_TOKEN() \
	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_TOKEN_GEN))

/* Commands */
#define IPECC_EXEC_PT_KP()  (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_KP))
#define IPECC_EXEC_PT_ADD() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_ADD))
#define IPECC_EXEC_PT_DBL() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_DBL))
#define IPECC_EXEC_PT_CHK() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_CHK))
#define IPECC_EXEC_PT_EQU() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_EQU))
#define IPECC_EXEC_PT_OPP() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_OPP))
#define IPECC_EXEC_PT_NEG() (IPECC_SET_REG(IPECC_W_CTRL, IPECC_W_CTRL_PT_NEG))

/* On curve/equality/opposition flags handling
 */
#define IPECC_GET_ONCURVE() (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))
#define IPECC_GET_EQU()     (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))
#define IPECC_GET_OPP()     (!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_YES))

/*
 * Actions involving register W_WRITE_DATA & R_READ_DATA
 * *****************************************************
 */
/* Addresses and data handling.
 */
/* Write in register W_CTRL the address of the big number to read
 * and assert the read-command bit.
 *
 * Also assert the specific bit if the number to read is the token.
 */
#define IPECC_SET_READ_ADDR(addr, token) do { \
	ip_ecc_word val = 0; \
	val |= IPECC_W_CTRL_READ_NB; \
	val |= ((token) ? IPECC_W_CTRL_RD_TOKEN : 0); \
	val |= (((addr) & IPECC_W_CTRL_NBADDR_MSK) << IPECC_W_CTRL_NBADDR_POS); \
	IPECC_SET_REG(IPECC_W_CTRL, val); \
} while(0)

/* Big numbers internal RAM memory map (by index).
 */
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

#define IPECC_READ_DATA() (IPECC_GET_REG(IPECC_R_READ_DATA))

/* Write in register W_CTRL the address of the big number to write
 * and assert the write-command bit.
 *
 * Also assert the specific bit if the number to write is the scalar.
 */
#define IPECC_SET_WRITE_ADDR(addr, scal) do { \
	ip_ecc_word val = 0; \
	val |= IPECC_W_CTRL_WRITE_NB; \
	val |= ((scal) ? IPECC_W_CTRL_WRITE_K : 0); \
	val |= ((addr & IPECC_W_CTRL_NBADDR_MSK) << IPECC_W_CTRL_NBADDR_POS); \
	IPECC_SET_REG(IPECC_W_CTRL, val); \
} while(0)

#define IPECC_WRITE_DATA(val) do { \
	IPECC_SET_REG(IPECC_W_WRITE_DATA, val); \
} while(0)

/*
 * Actions involving registers W_R[01]_NULL & R_STATUS
 * ***************************************************
 */
/* Infinity point handling with R0/R1 NULL flags.
 */
#define IPECC_GET_R0_INF() \
	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R0_IS_NULL))
#define IPECC_GET_R1_INF() \
	(!!(IPECC_GET_REG(IPECC_R_STATUS) & IPECC_R_STATUS_R1_IS_NULL))

#define IPECC_CLEAR_R0_INF() do { \
	IPECC_SET_REG(IPECC_W_R0_NULL, IPECC_W_POINT_IS_NOT_NULL); \
} while(0)
#define IPECC_SET_R0_INF() do { \
	IPECC_SET_REG(IPECC_W_R0_NULL, IPECC_W_POINT_IS_NULL); \
} while(0)
#define IPECC_CLEAR_R1_INF() do { \
	IPECC_SET_REG(IPECC_W_R1_NULL, IPECC_W_POINT_IS_NOT_NULL); \
} while(0)
#define IPECC_SET_R1_INF() do { \
	IPECC_SET_REG(IPECC_W_R1_NULL, IPECC_W_POINT_IS_NULL); \
} while(0)

/*
 * Actions involving registers W_PRIME_SIZE & R_PRIME_SIZE
 * *******************************************************
 *
 * NN size (static and dynamic) handling.
 */
/* To get the value of 'nn' the IP is currently set with
 * (or the static value if hardware was not synthesized
 * with the 'nn modifiable at runtime' option).
 */
#define IPECC_GET_NN_SIZE() \
	(((IPECC_GET_REG(IPECC_R_PRIME_SIZE)) >> IPECC_W_PRIME_SIZE_POS) \
	 & IPECC_W_PRIME_SIZE_MSK)

/* To set the value of nn (only with hardware synthesized
 * with the 'nn modifiable at runtime' option).
 */
#define IPECC_SET_NN_SIZE(sz) do { \
	IPECC_SET_REG(IPECC_W_PRIME_SIZE, \
			((sz) & IPECC_W_PRIME_SIZE_MSK) << IPECC_W_PRIME_SIZE_POS); \
} while(0)

/*
 * Actions involving register W_BLINDING
 * (blinding handling)/
 * *************************************
 */

/* To disable blinding.
 * */
#define IPECC_DISABLE_BLINDING() do { \
	IPECC_SET_REG(IPECC_W_BLINDING, 0); \
} while(0)

/* To enable & configure blinding countermeaure.
 * */
#define IPECC_SET_BLINDING_SIZE(blinding_size) do { \
	uint32_t val = 0; \
	/* Enable blinding */ \
	val |= IPECC_W_BLINDING_EN; \
	/* Configure blinding */ \
	val |= ((blinding_size & IPECC_W_BLINDING_BITS_MSK) << \
			IPECC_W_BLINDING_BITS_POS); \
	IPECC_SET_REG(IPECC_W_BLINDING, val); \
} while(0)

/*
 * Actions involving register W_SHUFFLE
 * ************************************
 */

/* Enable shuffling countermeasure.
 *
 *   - Shuffling method/algo is set statically (at synthesis time)
 *     and cannot be modified dynamically.
 *
 *   - Shuffling can always be activated if a shuffling method/algo
 *     was selected at synthesis time (even without the synthesis
 *     constraining the systematic use of shuffle).
 *     The important thing is that actions can only increase the
 *     security.
 */
#define IPECC_ENABLE_SHUFFLE() do { \
	IPECC_SET_REG(IPECC_W_SHUFFLE, IPECC_W_SHUFFLE_EN); \
} while (0)

/* Disable the shuffling countermeasure.
 *
 *   - Shuffling cannot be deactivated if it was hardware-locked
 *     at synthesis time & the IP was synthesized in production
 *     (secure) mode.
 *
 *   - If IP was synthesized in debug (unsecure) mode, shuffling
 *     can be arbitrarily enabled/disabled.
 */
#define IPECC_DISABLE_SHUFFLE() do { \
	IPECC_SET_REG(IPECC_W_SHUFFLE, IPECC_W_SHUFFLE_DIS); \
} while (0)

/*
 * Actions involving register W_ZREMASK
 * ********************************************
 */
/* To enable & configure Z-remask countermeasure.
 */
#define IPECC_ENABLE_ZREMASK(zremask_period) do { \
	uint32_t val = 0; \
	/* Enable Z-remasking */ \
	val |= IPECC_W_ZREMASK_EN; \
	/* Configure Z-remasking */ \
	val |= ((zremask_period & IPECC_W_ZREMASK_BITS_MSK) \
			<< IPECC_W_ZREMASK_BITS_POS); \
	IPECC_SET_REG(IPECC_W_ZREMASK, val); \
} while (0)

#define IPECC_DISABLE_ZREMASK() do { \
	(IPECC_SET_REG(IPECC_W_ZREMASK, IPECC_W_ZREMASK_DIS)); \
} while (0)

/*
 * Actions involving register W_TOKEN
 * (token handling)
 * **********************************
 */
/* Have the IP generate a fresh random token. */
#define IPECC_ASK_FOR_TOKEN_GENERATION() do { \
	IPECC_SET_REG(IPECC_W_TOKEN, 1); /* written value actually is indifferent */ \
} while (0)

/*
 * Actions involving register W_IRQ
 * (interrupt request handling)
 * ********************************
 */
/* Enable interrupt requests */
#define IPECC_ENABLE_IRQ() do { \
	IPECC_SET_REG(IPECC_W_IRQ, IPECC_W_IRQ_EN); \
} while (0)

/*
 * Actions using register R_STATUS & W_ERR_ACK
 * (error detection & acknowlegment)
 * *******************************************
 */
/* Definition of error bits.
 *
 * Exact same bit positions exist both in R_STATUS register
 * and in W_ERR_ACK register.
 *
 * Hence an error set (=1) by hardware in R_STATUS register
 * can always be acknowledged by the software driver by writing
 * a 1 at the exact same bit position in W_ERR_ACK register,
 * thus having hardware reset back the error (=0) in the exact
 * same bit position in R_STATUS register.
 *
 * Note however that following bit positions start at 0 and
 * hence are relative: corresponding real bit positions are
 * actually shifted by a qty IPECC_R_STATUS_ERRID_POS (both in
 * R_STATUS and W_ERR_ACK register), however higher-level of
 * the software does not need to bother with these details
 * as they are masked by macros IPECC_GET_ERROR() &
 * IPECC_ACK_ERROR() below, which perform the actual bit-
 * shift of IPECC_R_STATUS_ERRID_POS positions.
 */
#define IPECC_ERR_IN_PT_NOT_ON_CURVE	((uint32_t)0x1 << 0)
#define IPECC_ERR_OUT_PT_NOT_ON_CURVE	((uint32_t)0x1 << 1)
#define IPECC_ERR_COMP			((uint32_t)0x1 << 2)
#define IPECC_ERR_WREG_FBD 		((uint32_t)0x1 << 3)
#define IPECC_ERR_KP_FBD   		((uint32_t)0x1 << 4)
#define IPECC_ERR_NNDYN			((uint32_t)0x1 << 5)
#define IPECC_ERR_POP_FBD		((uint32_t)0x1 << 6)
#define IPECC_ERR_RDNB_FBD		((uint32_t)0x1 << 7)
#define IPECC_ERR_BLN			((uint32_t)0x1 << 8)
#define IPECC_ERR_UNKOWN_REG		((uint32_t)0x1 << 9)
#define IPECC_ERR_TOKEN		((uint32_t)0x1 << 10)
#define IPECC_ERR_SHUFFLE   ((uint32_t)0x1 << 11)
#define IPECC_ERR_ZREMASK		((uint32_t)0x1 << 12)
#define IPECC_ERR_NOT_ENOUGH_RANDOM_WK  ((uint32_t)0x1 << 13)
#define IPECC_ERR_RREG_FBD 		((uint32_t)0x1 << 14)

/* Get the complete error field of R_STATUS
 */
#define IPECC_GET_ERROR() \
	((IPECC_GET_REG(IPECC_R_STATUS) >> IPECC_R_STATUS_ERRID_POS) \
	 & IPECC_R_STATUS_ERRID_MSK)

/* To identify 'Computation' error */
#define IPECC_ERROR_IS_COMP() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_COMP))

/* To identify 'Forbidden register-write' error */
#define IPECC_ERROR_IS_WREG_FBD() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_WREG_FBD))

/* To identify 'Forbidden register-read' error */
#define IPECC_ERROR_IS_RREG_FBD() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_RREG_FBD))

/* To identify '[k]P computation not possible' error */
#define IPECC_ERROR_IS_KP_FBD() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_KP_FBD))

/* To identify 'nn value not in authorized range' error */
#define IPECC_ERROR_IS_NNDYN() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_NNDYN))

/* To identify 'Point operation (other than [k]P) not possible' error */
#define IPECC_ERROR_IS_POP_FBD() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_POP_FBD))

/* To identify 'Read large number command cannot be satisfied' error */
#define IPECC_ERROR_IS_RDNB_FBD() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_RDNB_FBD))

/* To identify 'Blinding configuration' error */
#define IPECC_ERROR_IS_BLN() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_BLN))

/* To identify 'Unknown register' error */
#define IPECC_ERROR_IS_UNKOWN_REG() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_UNKOWN_REG))

/* To identify 'Input point is not on curve' error */
#define IPECC_ERROR_IS_IN_PT_NOT_ON_CURVE \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_IN_PT_NOT_ON_CURVE))

/* To identify 'Output point is not on curve' error */
#define IPECC_ERROR_IS_OUT_PT_NOT_ON_CURVE() \
	(!!(IPECC_GET_ERROR() & IPECC_ERR_OUT_PT_NOT_ON_CURVE))

/* To acknowledge error(s) to the IP.
 */
#define IPECC_ACK_ERROR(err) \
	(IPECC_SET_REG(IPECC_W_ERR_ACK, \
	  (((err) & IPECC_R_STATUS_ERRID_MSK) << IPECC_R_STATUS_ERRID_POS)))

/*
 * Actions using register W_SMALL_SCALAR
 * *************************************
 */
/* Set small scalar size.
 */
#define IPECC_SET_SMALL_SCALAR_SIZE(sz) do { \
	IPECC_SET_REG(IPECC_W_SMALL_SCALAR, \
			(sz & IPECC_W_SMALL_SCALAR_K_MSK) << IPECC_W_SMALL_SCALAR_K_POS); \
} while (0)

/*
 * Actions using register W_SOFT_RESET
 * (soft reset handling)
 * ***********************************
 */
/* Perform a software reset */
#define IPECC_SOFT_RESET() do { \
	(IPECC_SET_REG(IPECC_W_SOFT_RESET, 1)); /* written value actually is indifferent */ \
} while (0)

/*
 * Actions using register R_CAPABILITIES
 * (Capabilities handling)
 * *************************************
 */
/* To know if the IP hardware was synthesized with
 * the option 'nn modifiable at runtime' */
#define IPECC_IS_DYNAMIC_NN_SUPPORTED() \
	(!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_NNDYN)))

/* To know if the IP hardware was synthesized with
 * the 'shuffling memory of large numbers' countermeasure.
 */
#define IPECC_IS_SHUFFLING_SUPPORTED() \
	(!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_SHF)))
#define IPECC_IS_W64() \
	(!!((IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_W64)))

/* Returns the maximum (and default) value allowed for 'nn' parameter (if the IP was
 * synthesized with the 'nn modifiable at runtime' option) or simply the static,
 * unique value of 'nn' the IP supports (otherwise).
 */
#define IPECC_GET_NN_MAX_SIZE() \
	((IPECC_GET_REG(IPECC_R_CAPABILITIES) >> IPECC_R_CAPABILITIES_NNMAX_POS) \
	 & IPECC_R_CAPABILITIES_NNMAX_MSK)

/* To know if the IP was synthesized in debug (unsecure) mode
 * or in production (secure) mode.
 */
#define IPECC_IS_DEBUG_OR_PROD() \
	(!!(IPECC_GET_REG(IPECC_R_CAPABILITIES) & IPECC_R_CAPABILITIES_DBG_N_PROD))

/* Actions using register R_HW_VERSION
 * ***********************************
 */

/* This register exists in hardware only if the IP was synthesized in DEBUG (unsecure) mode
 * (as opposed to prodution (secure) mode. */
#define IPECC_GET_MAJOR_VERSION() \
	((IPECC_GET_REG(IPECC_R_HW_VERSION) >> IPECC_R_HW_VERSION_MAJOR_POS) \
	 & IPECC_R_HW_VERSION_MAJOR_MSK)
#define IPECC_GET_MINOR_VERSION() \
	((IPECC_GET_REG(IPECC_R_HW_VERSION) >> IPECC_R_HW_VERSION_MINOR_POS) \
	 & IPECC_R_HW_VERSION_MINOR_MSK)

/* Actions involving register W_DBG_HALT
 * *************************************
 */

/* To halt the IP */
#define IPECC_HALT_NOW()  do { \
	IPECC_SET_REG(IPECC_W_DBG_HALT, IPECC_W_DBG_HALT_DO_HALT); \
} while (0)

/* Actions involving register W_DBG_BKPT
 * *************************************
 */
/* IP main FSM state is accessible in debug mode,
 * below are defined the corresponding state codes
 *
 * (see also macro IPECC_GET_FSM_STATE()). */
#define IPECC_DEBUG_STATE_ANY_OR_IDLE  0
#define IPECC_DEBUG_STATE_CSTMTY  1
#define IPECC_DEBUG_STATE_CHECKONCURVE  2
#define IPECC_DEBUG_STATE_BLINDINIT  3
#define IPECC_DEBUG_STATE_BLINDBIT  4
#define IPECC_DEBUG_STATE_BLINDEXIT  5
#define IPECC_DEBUG_STATE_ADPA  6
#define IPECC_DEBUG_STATE_SETUP  7
#define IPECC_DEBUG_STATE_DOUBLE  8
/* Value 9 was tied to an obsolete state
 * which has been removed. */
#define IPECC_DEBUG_STATE_ITOH  10
#define IPECC_DEBUG_STATE_ZADDU  11
#define IPECC_DEBUG_STATE_ZADDC  12
#define IPECC_DEBUG_STATE_SUBTRACTP  13
#define IPECC_DEBUG_STATE_EXIT  14

/*
 * Set a breakpoint, valid in a specific state & for a specific bit-
 * position of the scalar.
 */
#define IPECC_SET_BKPT(id, addr, nbbit, state) do { \
	IPECC_SET_REG(IPECC_W_DBG_BKPT_EN \
			| (((id) & IPECC_W_DBG_BKPT_ID_MSK) << IPECC_W_DBG_BKPT_ID_POS ) \
	    | (((addr) & IPECC_W_DBG_BKPT_ADDR_MSK) << IPECC_W_DBG_BKPT_ADDR_POS ) \
	    | (((nbbit) & IPECC_W_DBG_BKPT_NBIT_MSK ) << IPECC_W_DBG_BKPT_NBBIT_POS ) \
	    | (((state) & IPECC_W_DBG_BKPT_STATE_MSK) << IPECC_W_DBG_BKPT_STATE_POS )); \
} while (0)

/*
 * Set a breakpoint, valid for any state & for any bit of the scalar.
 */
#define IPECC_SET_BREAKPOINT(id, addr, nbbit, state) do { \
	IPECC_SET_BKT((id), (addr), 0, IPECC_DEBUG_STATE_ANY_OR_IDLE); \
} while (0)

/* Remove a breakpoint */
#define IPECC_REMOVE_BREAKPOINT(id) do { \
	IPECC_SET_REG(IPECC_W_DBG_BKPT_DIS \
			| (((id) & IPECC_W_DBG_BKPT_ID_MSK) << IPECC_W_DBG_BKPT_ID_POS )); \
} while (0)

/* Actions involving register W_DBG_STEPS
 * **************************************
 */
/*
 * Running part of the microcode when IP is debug-halted
 * or resuming execution.
 */
#define IPECC_RUN_OPCODES(nb) do { \
	IPECC_SET_REG(IPECC_W_DBG_STEPS_RUN_NB_OP \
			| (((nb) & IPECC_W_DBG_STEPS_NB_OP_MSK) << IPECC_W_DBG_STEPS_NB_OP_POS )); \
} while (0)

#define IPECC_RESUME() do { \
	IPECC_SET_REG(IPECC_W_DBG_STEPS_RESUME); \
} while (0)

/* Actions involving register W_DBG_TRIG_ACT
 * *****************************************
 */
/*
 * Arming both signal rising-edge & falling-edge triggers.
 */
#define IPECC_ARM_TRIGGER() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRIG_ACT, IPECC_W_DBG_TRIG_ACT_EN); \
} while (0)

/* Actions involving register W_DBG_TRIG_UP & W_DBG_TRIG_DOWN
 * **********************************************************
 */
/*
 * To set the time at which the trigger output signal must be raised.
 *
 * Argument 'time' is expressed in multiple of the clock cycles starting from
 * the begining of [k]P computation.
 */
#define IPECC_SET_TRIGGER_UP(time) do { \
	IPECC_SET_REG(IPECC_W_DBG_TRIG_UP, ((time) & IPECC_W_DBG_TRIG_MSK) \
			<< IPECC_W_DBG_TRIG_POS); \
} while (0)

/*
 * To set the time at which the trigger output signal must be lowered back.
 * (same remark as for IPECC_SET_TRIGGER_UP).
 */
#define IPECC_SET_TRIGGER_DOWN() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRIG_DOWN, ((time) & IPECC_W_DBG_TRIG_MSK) \
			<< IPECC_W_DBG_TRIG_POS); \
} while (0)

/* Actions involving register W_DBG_OP_WADDR
 * *****************************************
 */
#define IPECC_SET_OPCODE_WRITE_ADDRES(addr) do { \
	IPECC_SET_REG(IPECC_W_DBG_OP_WADDR, ((addr) & IPECC_W_DBG_OP_WADDR_MSK) \
			<< IPECC_W_DBG_OP_WADDR_POS); \
} while (0)

/* Actions involving register W_DBG_OPCODE
 * ***************************************
 */
#define IPECC_SET_OPCODE_TO_WRITE(opcode) do { \
	IPECC_SET_REG(IPECC_W_DBG_OPCODE, ((addr) & IPECC_W_DBG_OPCODE_MSK) \
			<< IPECC_W_DBG_OPCODE_POS); \
} while (0)

/* Actions involving register W_DBG_TRNG_CTRL
 * (controlling TRNG behaviour)
 * ******************************************
 */
/* Disable the TRNG post-processing logic that pulls bytes from the
 * raw random source.
 *
 * Note: this macro does not take action on the physical raw random source
 * which produces raw random bits into the raw random FIFO, it takes action
 * on the post-processing function that consumes these bits, thus leading,
 * after a while, to starving all downstream production of internal random
 * numbers.
 *
 * See also macros IPECC_TRNG_RAW_FIFO_READ_PORT_[EN|DIS]ABLE().
 *
 * Watchout: implicitly remove a possibly pending complete bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
#define IPECC_TRNG_DISABLE_POSTPROC() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, \
			((uint32_t)0x1 << IPECC_W_DBG_TRNG_CTRL_POSTPROC_DISABLE)); \
} while (0)

/* (Re)enable the TRNG post-processing logic that pulls bytes from the
 * raw random source - in the IP debug mode, that logic is disabled upon reset
 * and needs to be explicitly enabled by sofware by calling this macro.
 *
 * Watchout: implicitly remove a possibly pending complete bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
#define IPECC_TRNG_ENABLE_POSTPROC() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, \
			((uint32_t)0x0 << IPECC_W_DBG_TRNG_CTRL_POSTPROC_DISABLE)); \
} while (0)

/* Disable the read port of the TRNG raw random FIFO.
 *
 * Note: this macro does not take action on the post-processing function 
 * that consumes bits out of the raw random FIFO, but on the raw random
 * FIFO itself. The purpose is to inhibit the read port of the FIFO 
 * used by the post-processing function, in order to guarantee that
 * software becomes the only consumer of the FIFO, and that no portion
 * of the raw data slips out of software analysis, possibly creating
 * some bias or erronous analysis.
 *
 * See also macros IPECC_TRNG_[EN|DIS]ABLE_POSTPROC().
 *
 * Watchout: implicitly remove a possibly pending complet bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
#define IPECC_TRNG_RAW_FIFO_READ_PORT_DISABLE() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, \
			((uint32_t)0x1 << IPECC_W_DBG_TRNG_CTRL_RAW_DISABLE_FIFO_READ_PORT_POS)); \
} while (0)

/* (Re)enable the read port of the TRNG raw random FIFO.
 * Watchout: implicitly remove a possibly pending complet bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
#define IPECC_TRNG_RAW_FIFO_READ_PORT_ENABLE() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, \
			((uint32_t)0x0 << IPECC_W_DBG_TRNG_CTRL_RAW_DISABLE_FIFO_READ_PORT_POS)); \
} while (0)

/* Empty the FIFO buffering raw random bits of the TRNG
 * and reset associated logic.
 */
#define IPECC_TRNG_RESET_EMPTY_RAW_FIFO() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_RAW); \
} while (0)

/* Empty the FIFOs buffering internal random bits of the TRNG
 * (all channels) and reset associated logic.
 */
#define IPECC_TRNG_RESET_EMPTY_IRN_FIFOS() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, IPECC_W_DBG_TRNG_CTRL_RESET_FIFO_IRN); \
} while (0)

/* Set address in the TRNG raw FIFO memory array where to read
 * a raw random bit from, and fetch the corresponding bit.
 * (see also IPECC_TRNG_GET_RAW_BIT).
 */
#define IPECC_TRNG_SET_RAW_BIT_ADDR(addr) do { \
	ip_ecc_word val = 0; \
	val |= IPECC_W_DBG_TRNG_CTRL_READ_FIFO_RAW; \
	val |= (((addr) & IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_MSK) \
			<< IPECC_W_DBG_TRNG_CTRL_FIFO_ADDR_POS); \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, val); \
} while (0)

/* Get the raw random bit fetched by IPECC_TRNG_SET_RAW_BIT_READ_ADDR
 * (c.f that macro just above).
 * Note that for each read, first setting the address w/ IPECC_TRNG_SET_RAW_BIT_ADDR()
 * is mandatory, even if the read targets the same address, otherwise error 'ERR_RREG_FBD'
 * is raised in R_STATUS register.
 */
#define IPECC_TRNG_GET_RAW_BIT() do { \
	(((IPECC_GET_REG(IPECC_W_DBG_TRNG_CTRL)) >> IPECC_R_DBG_TRNG_RAW_DATA_POS) \
	 & IPECC_R_DBG_TRNG_RAW_DATA_MSK) \
} while (0)

/* Completely bypass the TRNG physical source.
 *
 * It does not mean that the physical TRNG stops working and producing random
 * bits, it means that its output is ignored as well as the post-processing
 * function's one, and that internal random numbers become deterministic
 * constants, made of constantly the same bit value.
 *
 * Because a null value is not always desired for the large numbers served
 * to some of the random clients, software can choose the value, 0 or 1, that
 * internal random numbers will be made of when the physical true entropy
 * source is bypassed (this is the purpose of argument 'bit' of the macro,
 * that should bet set to 0 or 1).
 */
#define IPECC_TRNG_COMPLETE_BYPASS(bit) do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, IPECC_W_DBG_TRNG_CTRL_TRNG_BYPASS \
			| (((bit) & 0x1) << IPECC_W_DBG_TRNG_CTRL_TRNG_BYPASS_VAL_POS)); \
} while (0)

/* Undo the action of IPECC_TRNG_COMPLETE_BYPASS(), restoring the
 * unpredictable behaviour of internal random numbers.
 *
 * Implicitly (re)enable the TRNG read port of the FIFO by deasserting
 * its 'RAW_FIFO_READ_DISABLE_POS' bit, and also implicitly (re)enable the
 * consumption of data from the raw random FIFO by the TRNG post-processing
 * logic, by deasserting its 'RAW_PULL_PP_DISABLE_POS' bit.
 */
#define IPECC_TRNG_UNDO_COMPLETE_BYPASS() do { \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CTRL, 0); \
} while (0)

/* Actions involving register W_DBG_TRNG_CFG
 * (configuration of TRNG).
 * *****************************************
 */
#define IPECC_TRNG_CONFIG(debias, ta, idlenb) do { \
	uint32_t val = 0; \
	/* Configure Von Neumann debias logic */ \
	if (debias) { \
		val |= IPECC_W_DBG_TRNG_CFG_ACTIVE_DEBIAS ; \
	} \
	val |= ((ta) & IPECC_W_DBG_TRNG_CFG_TA_MSK) \
	  << IPECC_W_DBG_TRNG_CFG_TA_POS; \
	val |= ((idlenb) & IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_MSK) \
	  << IPECC_W_DBG_TRNG_CFG_TRNG_IDLE_POS; \
	IPECC_SET_REG(IPECC_W_DBG_TRNG_CFG, val); \
} while (0)

/* Actions involving registers W_DBG_FP_WADDR & W_DBG_FP_WDATA
 * ***********************************************************
 */

/* Set the address in the memory of large numbers at which to write a data word.
 * The data itself can be subsequently transmitted using IPECC_DBG_SET_FP_WRITE_DATA().
 */
#define IPECC_DBG_SET_FP_WRITE_ADDR(addr) do { \
	IPECC_SET_REG(IPECC_W_DBG_FP_WADDR, ((addr) & IPECC_W_DBG_FP_WADDR_MSK) \
			<< IPECC_W_DBG_FP_WADDR_POS); \
} while (0)

/* Set the data to be written in memory of large numbers, at the address previously
 * set using IPECC_DBG_SET_FP_WRITE_ADDR(), and performs the write.
 * This is a ww-bit word which is a limb of a larger large-number.
 */
#define IPECC_DBG_SET_FP_WRITE_DATA(limb) do { \
	IPECC_SET_REG(IPECC_W_DBG_FP_WDATA, ((limb) & IPECC_W_DBG_FP_DATA_MSK) \
			<< IPECC_W_DBG_FP_DATA_POS); \
} while (0)

/* Actions involving register W_DBG_FP_RADDR, IPECC_R_DBG_FP_RDATA &
 * IPECC_R_DBG_FP_RDATA_RDY
 * *****************************************************************
 */

/* Set the address in the memory of large numbers at which a data word is to be read.
 * The data itself can be subsequently obtained using IPECC_DBG_GET_FP_READ_DATA().
 */
#define IPECC_DBG_SET_FP_READ_ADDR(addr) do { \
	IPECC_SET_REG(IPECC_W_DBG_FP_RADDR, ((addr) & IPECC_W_DBG_FP_RADDR_MSK) \
			<< IPECC_W_DBG_FP_RADDR_POS); \
} while (0)

/* Polling macro to know when the data word to fecth from the memory of large numbers
 * (using previous macro IPECC_DBG_SET_FP_READ_ADDR) was actually read and hence if
 * the data can now be read, using the following macro IPECC_DBG_GET_FP_READ_DATA,
 * see below. */
#define IPECC_DBG_IS_FP_READ_DATA_AVAIL()  (!!(IPECC_GET_REG(IPECC_R_DBG_FP_RDATA_RDY) \
			& IPECC_R_DBG_FP_RDATA_RDY_IS_READY))

/* Obtain the data word from memory of large numbers whose address
 * was previously set using IPECC_DBG_SET_FP_READ_ADDR().
 */
#define IPECC_DBG_GET_FP_READ_DATA() \
	(((IPECC_GET_REG(IPECC_R_DBG_FP_RDATA)) >> IPECC_W_DBG_FP_DATA_MSK) \
	 & IPECC_W_DBG_FP_DATA_POS)

/* Actions involving register W_DBG_CFG_XYSHUF
 * *******************************************
 */

/* Enable the XY-coords shuffling of R0 & R1 sensitivie points
 */
#define IPECC_DBG_ENABLE_XYSHUF() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_XYSHUF, IPECC_W_DBG_CFG_XYSHUF_EN); \
} while (0)

/* Disable the XY-coords shuffling or R0 & R1 sensitive points
 * (can only by done in debug (unsecure) mode).
 */
#define IPECC_DBG_DISABLE_XYSHUF() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_XYSHUF, IPECC_W_DBG_CFG_XYSHUF_DIS); \
} while (0)

/* Actions involving register W_DBG_CFG_AXIMSK
 * *******************************************/

/* Enable on-the-fly masking of the scalar by the AXI interface along its
 * writting in memory of large numbers.
 */
#define IPECC_DBG_ENABLE_AXIMSK() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_AXIMSK, IPECC_W_DBG_CFG_AXIMSK_EN); \
} while (0)

/* Disable on-the-fly masking of the scalar by the AXI interface along its
 * writting in memory of large numbers.
 * (can only by done in debug (unsecure) mode).
 */
#define IPECC_DBG_DISABLE_AXIMSK() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_AXIMSK, IPECC_W_DBG_CFG_AXIMSK_DIS); \
} while (0)

/* Actions involving register W_DBG_CFG_TOKEN
 * ******************************************
 */

/* Enable token feature - a random value used to mask the coordinates
 * of result [k]P that software driver gets before launching the [k]P
 * computation.
 */
#define IPECC_DBG_ENABLE_TOKEN() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_TOKEN, IPECC_W_DBG_CFG_TOKEN_EN); \
} while (0)

/* Disale token feature.
 * (can only by done in debug (unsecure) mode).
 */
#define IPECC_DBG_DISABLE_TOKEN() do { \
	IPECC_SET_REG(IPECC_W_DBG_CFG_TOKEN, IPECC_W_DBG_CFG_TOKEN_DIS); \
} while (0)

/* Actions involving register W_DBG_RESET_TRNG_CNT
 * ***********************************************
 */

/* Reset the diagnostic counters that software driver can access through
 * registers R_DBG_TRNG_DIAG_1 to R_DBG_TRNG_DIAG_8.
 *
 * It is advised to reset the counters before any new [k]P computation
 * to avoid their overflow.
 *
 * Note: register R_DBG_TRNG_DIAG_0 is not impacted.
 */
#define IPECC_RESET_TRNG_DIAGNOSTIC_COUNTERS() do { \
	IPECC_SET_REG(IPECC_W_DBG_RESET_TRNG_CNT, 1); /* written value actually is indifferent */ \
} while (0)

/* Actions involving register R_DBG_CAPABILITIES_0
 * ***********************************************
 */

/* Get the value of parameter 'ww'.
 *
 * Parameter 'ww' designates the bit size of the limbs that large numbers
 * are made of in large number memory.
 *
 * The software driver normally does not need to bother about this parameter,
 * otherwise in debug mode when using the macros IPECC_DBG_SET_FP_WRITE_DATA
 * & IPECC_DBG_GET_FP_READ_DATA.
 * (see these macros).
 */
#define IPECC_GET_WW()  (IPECC_GET_REG(IPECC_R_DBG_CAPABILITIES_0))

/* Actions involving register R_DBG_CAPABILITIES_1
 * ***********************************************
 */

/* To get the number of opcode words forming the complete footprint of
 * the microcode.
 */
#define IPECC_GET_NBOPCODES() \
	(((IPECC_GET_REG(IPECC_R_DBG_CAPABILITIES_1)) \
		>> IPECC_R_DBG_CAPABILITIES_1_NBOPCODES_POS) \
		& IPECC_R_DBG_CAPABILITIES_1_NBOPCODES_MSK)

/* To get the bitwidth of opcode words. */
#define IPECC_GET_OPCODE_SIZE() \
	(((IPECC_GET_REG(IPECC_R_DBG_CAPABILITIES_1)) \
		>> IPECC_R_DBG_CAPABILITIES_1_OPCODE_SZ_POS) \
		& IPECC_R_DBG_CAPABILITIES_1_OPCODE_SZ_MSK)

/* Actions involving register R_DBG_CAPABILITIES_2
 * ***********************************************
 */
/* To get the size (in bits) of the TRNG FIFO buffering raw random numbers. */
#define IPECC_GET_TRNG_RAW_SZ() \
	(((IPECC_GET_REG(IPECC_R_DBG_CAPABILITIES_2)) \
		>> IPECC_R_DBG_CAPABILITIES_2_RAW_RAMSZ_POS) \
		& IPECC_R_DBG_CAPABILITIES_2_RAW_RAMSZ_MSK)

/* To get the bitwidth of TRNG internal random numbers
 * served to the logic implementing the shuffling counter-
 * measure (shuffling of the memory of large numbers).
 *
 * The bitwidth is static and depends on the algorithm/
 * method used to shuffle the memory.
 */
#define IPECC_GET_TRNG_IRN_SHF_BITWIDTH() \
	(((IPECC_GET_REG(IPECC_R_DBG_CAPABILITIES_2)) \
		>> IPECC_R_DBG_CAPABILITIES_2_IRN_SHF_WIDTH_POS) \
		& IPECC_R_DBG_CAPABILITIES_2_IRN_SHF_WIDTH_MSK)

/* Actions involving register R_DBG_STATUS
 * ***************************************
 */

/* Is IP currently halted? (on a breakpoint hit, or after having
 * been asked to run a certain nb of microcode opcodes).
 */
#define IPECC_IS_IP_HALTED() \
	(!!(IPECC_GET_REG(IPECC_R_DBG_STATUS) & IPECC_R_DBG_STATUS_HALTED))

/* Did IP was halted on a breakpoint hit? */
#define IPECC_IS_IP_HALTED_ON_BKPT_HIT() \
	(!!(IPECC_GET_REG(IPECC_R_DBG_STATUS) & IPECC_R_DBG_STATUS_BK_HIT))

/* Get the 'breakpoint ID' field in R_DBG_STATUS register.
 * If IPECC_IS_IP_HALTED_ON_BKPT_HIT() confirms that the IP
 * is halted due to a breakpoint hit, then this field gives
 * the ID of that breakpoint.
 */
#define IPECC_GET_BKPT_ID_IP_IS_HALTED_ON() \
	(((IPECC_GET_REG(IPECC_R_DBG_STATUS)) \
		>> IPECC_R_DBG_STATUS_BKID_POS) & IPECC_R_DBG_STATUS_BKID_MSK)

/* Get the current value of PC (program counter).
 * This is the value of the decode stage of the pipeline;
 * hence the opcode that address is pointing to has not
 * been executed yet.
 */
#define IPECC_GET_PC() \
	(((IPECC_GET_REG(IPECC_R_DBG_STATUS)) \
		>> IPECC_R_DBG_STATUS_PC_POS) & IPECC_R_DBG_STATUS_PC_MSK)

/* Get the ID of the state the main FSM is currently in.
 * (see also macros related to register W_DBG_BKPT, namely
 * IPECC_SET_BKPT & IPECC_SET_BREAKPOINT).
 */
#define IPECC_GET_FSM_STATE() \
	(((IPECC_GET_REG(IPECC_R_DBG_STATUS)) >> \
		IPECC_R_DBG_STATUS_STATE_POS) & IPECC_R_DBG_STATUS_STATE_MSK)

/* Actions involving register R_DBG_TIME
 * *************************************
 */

/* To get value of point-operation time counter.
 *
 * Each time a point-based operation is started (including [k]P
 * computation) an internal counter is started and incremented at
 * each cycle of the main clock. Reading this counter allows to
 * measure computation duration of point operations.
 */
#define IPECC_GET_PT_OP_TIME() \
	(((IPECC_GET_REG(IPECC_R_DBG_TIME)) >> IPECC_R_DBG_TIME_POS) & IPECC_R_DBG_TIME_MSK)

/* Actions involving register R_DBG_RAWDUR
 * ***************************************
 */

/* To get the duration it took to fill-up the TRNG raw random FIFO.
 *
 * In debug mode, after each hard/soft/debug reset, an internal
 * counter is started and incrememted at each cycle of the main
 * clock. It is then stopped as soon as the TRNG raw random FIFO
 * becomes FULL.
 *
 * This allows any debug software driver to know the time it took
 * to completely fill up the FIFO, and hence to estimate the random
 * production throughput of the TRNG main entropy source.
 *
 * Warning: this requires to first disable the post-processing
 * logic in the TRNG (which otherwise constantly empties the raw
 * random FIFO) using macro IPECC_TRNG_DISABLE_POSTPROC() (c.f
 * that macro).
 */
#define IPECC_GET_TRNG_RAW_FIFO_FILLUP_TIME() \
	(((IPECC_GET_REG(IPECC_R_DBG_RAWDUR)) >> IPECC_R_DBG_RAWDUR_POS) & IPECC_R_DBG_RAWDUR_MSK)

/* Actions involving register R_DBG_FLAGS
 * ***************************************/
/* Obsolete, will be removed */


/* Actions involving register R_DBG_TRNG_STATUS
 * ********************************************
 */

/* Returns the current value of the write-pointer into the TRNG raw random FIFO
 *
 * If post-processing is disabled (see macro IPECC_TRNG_DISABLE_POSTPROC)
 * and no TRNG raw random bits were read (using macros IPECC_TRNG_SET_RAW_BIT_ADDR
 * and IPECC_TRNG_GET_RAW_BIT) then this yields the current quantity of TRNG raw
 * random bits that have been produced since last reset. */
#define IPECC_GET_TRNG_RAW_FIFO_WRITE_POINTER() \
	(((IPECC_GET_REG(IPECC_R_DBG_TRNG_STATUS)) >> IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_OFFSET_POS) \
	 & IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_OFFSET_MSK)

/* Gives the FULL/not-FULL state of TRNG raw random FIFO */
#define IPECC_IS_TRNG_RAW_FIFO_FULL() \
	(!!(IPECC_GET_REG(IPECC_R_DBG_TRNG_STATUS) & IPECC_R_DBG_TRNG_STATUS_RAW_FIFO_FULL))

/* Actions involving register R_DBG_IRN_CNT_AXI
 * ********************************************
 */

/* Returns the quantity of internal random numbers currently buffered
 * in the TRNG FIFO that serves randomness to the AXI interface.
 *
 * Internal random numbers served to the AXI interface are 'ww'-bit long.
 *
 * Value of 'ww' can be obtained using macro IPECC_GET_WW (c.f). */
#define IPECC_GET_TRNG_NB_IRN_AXI() \
	((IPECC_GET_REG(IPECC_R_DBG_IRN_CNT_AXI) >> IPECC_R_DBG_IRN_CNT_COUNT_POS) \
	 & IPECC_R_DBG_IRN_CNT_COUNT_MSK)

/* Actions involving register R_DBG_IRN_CNT_EFP
 * ********************************************
 */

/* Returns the quantity of internal random numbers currently buffered
 * in the TRNG FIFO that serves randomness to the ALU for field large
 * numbers (these random are used to implement instruction NNRND (c.f
 * IP documentation).
 *
 * Internal random numbers served to the F_p ALU are 'ww'-bit long.
 *
 * Value of 'ww' can be obtained using macro IPECC_GET_WW (c.f).
 */
#define IPECC_GET_TRNG_NB_IRN_EFP()  ((IPECC_GET_REG(IPECC_R_DBG_IRN_CNT_EFP) \
			>> IPECC_R_DBG_IRN_CNT_COUNT_POS) & IPECC_R_DBG_IRN_CNT_COUNT_MSK)

/* Actions involving register R_DBG_IRN_CNT_CRV
 * ********************************************
 */

/* Returns the quantity of internal random numbers currently buffered
 * in the TRNG FIFO that serves randomness used to implement the XY-shuffling
 * of the coordinates of R0 & R1 sensitive points.
 *
 * Internal random numbers used for the XY-shuffling countermeasure are made
 * of 2-bits.
 */
#define IPECC_GET_TRNG_NB_IRN_CRV()  ((IPECC_GET_REG(IPECC_R_DBG_IRN_CNT_CRV) \
			>> IPECC_R_DBG_IRN_CNT_COUNT_POS) & IPECC_R_DBG_IRN_CNT_COUNT_MSK)

/* Actions involving register R_DBG_IRN_CNT_SHF
 * ********************************************
 */

/* Returns the quantity of internal random numbers currently buffered
 * in the TRNG FIFO that serves randomness to logic implementing the
 * shuffling of the memory of large numbers.
 *
 * Internal random numbers used for the memory shuffling countermeasure
 * have a bitwidth which depends on the type of algorithm used to randomly
 * permutate the memory. Three methods are available in the IP HDL source
 * code but one at most (and possible none) has been synthesized in the IP.
 *
 * The bitwidth of the internal random numbers here can be obtained using
 * macro IPECC_GET_TRNG_IRN_SHF_BITWIDTH (c.f).
 */
#define IPECC_GET_TRNG_NB_IRN_SHF()  ((IPECC_GET_REG(IPECC_R_DBG_IRN_CNT_SHF) \
			>> IPECC_R_DBG_IRN_CNT_COUNT_POS) & IPECC_R_DBG_IRN_CNT_COUNT_MSK)

/* Actions involving register R_DBG_TRNG_DIAG_0
 * ********************************************
 */

/* Actions involving registers R_DBG_TRNG_DIAG_1 - R_DBG_TRNG_DIAG_8
 * *****************************************************************
 */
/* In debug mode, for each of the 4 entropy clients in the IP, the TRNG maintains
 * a counter that is incremented at each clock cycle where the client is requiring
 * a fresh internal random number and the TRNG actually satisfies it, providing a
 * fresh random.
 *
 * Similarly, a second counter is incremented in each clock cycle where the client
 * is requiring a fresh IRN without the TRNG being able to provide it.
 *
 * Macro R_DBG_TRNG_DIAG_1 (resp. 3, 5 and 7) yields the value of the first counter
 * (satisfied requests) for the TRNG channel "AXI interface" (resp. for "NNRND instruction",
 * "XY-shuffling countermeasure" & "memory of large nb shuffling" countermeasure).
 *
 * Macro R_DBG_TRNG_DIAG_2 (resp. 4, 6 and 8) yeilds the value of the second counter
 * (starvation cycles) for the TRNG channel "AXI interface" (resp. for "NNRND instruction",
 * "XY-shuffling countermeasure" & "memory of large nb shuffling" countermeasure).
 *
 * Thus by computing for instance of ratio (R_DBG_TRNG_DIAG_2 / R_DBG_TRNG_DIAG_1 + R_DBG_TRNG_DIAG_2)
 * the software driver can evaluate the percentage of clock cycles where the AXI interface client
 * was requesting a fresh random without the TRNG actually having one at disposal to serve to it.
 */

/* TRNG channel "AXI interface"
 */
#define IPECC_GET_TRNG_AXI_OK() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_1) >> IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS) \
	& IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK)
#define IPECC_GET_TRNG_AXI_STARV() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_2) >> IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK)

/* TRNG channel "NNRND instruction"
 */
#define IPECC_GET_TRNG_EFP_OK() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_3) >> IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK)
#define IPECC_GET_TRNG_EFP_STARV() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_4) >> IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK)

/* TRNG channel "XY-shuffle countermeasure"
 */
#define IPECC_GET_TRNG_CRV_OK() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_5) >> IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK)
#define IPECC_GET_TRNG_CRV_STARV() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_6) >> IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK)

/* TRNG channel "Shuffling of memory of large numbers countermeasure"
 */
#define IPECC_GET_TRNG_SHF_OK() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_7) >> IPECC_R_DBG_TRNG_DIAG_CNT_OK_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_OK_MSK)
#define IPECC_GET_TRNG_SHF_STARV() \
	((IPECC_GET_REG(IPECC_R_DBG_TRNG_DIAG_8) >> IPECC_R_DBG_TRNG_DIAG_CNT_STARV_POS) \
	 & IPECC_R_DBG_TRNG_DIAG_CNT_STARV_MSK)

/*
 * The pseudo TRNG device (debug mode only)
 */

/* Actions using register IPECC_PSEUDOTRNG_W_SOFT_RESET
 * **************************************************
 */
/* Perform a software reset */
#define IPECC_PSEUDOTRNG_SOFT_RESET() do { \
	(IPECC_SET_REG(IPECC_PSEUDOTRNG_W_SOFT_RESET, 1)); /* written value actually is indifferent */ \
} while (0)

/* Push a data word into the FIFO of the pseudo TRNG device */
#define IPECC_PSEUDOTRNG_PUSH_DATA(data) do { \
	(IPECC_SET_REG(IPECC_PSEUDOTRNG_W_WRITE_DATA, (data))); \
} while (0)



/************************************************
 * One layer up - Middle-level macros & functions
 *
 * Hereafter sorted by category/function.
 ************************************************/

/* TRNG handling */
/* Read the FIFOs at an offset */
#define IPECC_TRNG_READ_FIFO_RAW(addr, a) do { \
	IPECC_TRNG_SET_RAW_BIT_ADDR(addr); \
	(*(a)) = IPECC_TRNG_GET_RAW_BIT(); \
} while(0)

/* Poll until the TRNG ran random FIFO is full */
#define IPECC_TRNG_RAW_FIFO_FULL_BUSY_WAIT() do { \
        while(!IPECC_IS_TRNG_RAW_FIFO_FULL()){}; \
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
	EC_HW_REG_TOKEN  = 9,
} ip_ecc_register;

typedef enum {
	EC_HW_REG_READ  = 0,
	EC_HW_REG_WRITE = 1,
} ip_ecc_register_mode;

typedef uint32_t ip_ecc_error;

#if defined(WITH_EC_HW_DEBUG)
static const char *ip_ecc_error_strings[] = {
	"EC_HW_STATUS_ERR_IN_PT_NOT_ON_CURVE",
	"EC_HW_STATUS_ERR_OUT_PT_NOT_ON_CURVE",
	"EC_HW_STATUS_ERR_COMP",
	"EC_HW_STATUS_ERR_WREG_FBD",
	"EC_HW_STATUS_ERR_KP_FBD",
	"EC_HW_STATUS_ERR_NNDYN",
	"EC_HW_STATUS_ERR_POP_FBD",
	"EC_HW_STATUS_ERR_RDNB_FBD",
	"EC_HW_STATUS_ERR_BLN",
	"EC_HW_STATUS_ERR_UNKOWN_REG",
	"EC_HW_STATUS_ERR_TOKEN",
	"EC_HW_STATUS_ERR_SHUFFLE",
	"EC_HW_STATUS_ERR_ZREMASK",
	"EC_HW_STATUS_ERR_NOT_ENOUGH_RANDOM_WK",
	"EC_HW_STATUS_ERR_RREG_FBD",
};

static inline void ip_ecc_errors_print(ip_ecc_error err)
{
	unsigned int i;

	if(err){
		for(i = 0; i < 15; i++){
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
	log_print("%s", s);
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
#endif /* WITH_EC_HW_DEBUG */

/* Helper function to compute the size, in nb of words, of a big number, given its size in bytes.
 */
static inline unsigned int ip_ecc_nn_words_from_bytes_sz(unsigned int sz)
{
	unsigned int curr_word_sz = (sz / sizeof(ip_ecc_word));
	curr_word_sz = ((sz % sizeof(ip_ecc_word)) == 0) ? (curr_word_sz) : (curr_word_sz + 1);

	return curr_word_sz;
}

/* Helper function to compute the size in bytes of a big number, given its size in bits.
 */
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
	uint32_t addr = 0, scal = 0, token = 0;

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
		case EC_HW_REG_TOKEN:{
			addr = 0; /* value actually does not matter */
			token = 1;
			break;
		}
		default:{
			goto err;
		}
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	switch(rw){
		case EC_HW_REG_READ:{
			IPECC_SET_READ_ADDR(addr, token);
			break;
		}
		case EC_HW_REG_WRITE:{
			IPECC_SET_WRITE_ADDR(addr, scal);
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

	IPECC_WRITE_DATA((*w));

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

	(*w) = IPECC_READ_DATA();

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

	/* We activate the shuffling only if it is supported */
	if(IPECC_IS_SHUFFLING_SUPPORTED()){
		IPECC_ENABLE_SHUFFLE();

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

/* Set the NN size provided in bits */
static inline int ip_ecc_set_nn_bit_size(unsigned int bit_sz)
{
	/* Get the maximum NN size and check the asked size */
	if(bit_sz > IPECC_GET_NN_MAX_SIZE()){
		/* If we overflow, this is an error */
		goto err;
	}

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* NOTE: when NN dynamic is not supported we leave
	 * our inherent maximum size.
	 */
	if(IPECC_IS_DYNAMIC_NN_SUPPORTED()){
		/* Set the current dynamic value */
		IPECC_SET_NN_SIZE(bit_sz);
		/* Wait until the IP is not busy */
		IPECC_BUSY_WAIT();

		/* Check for error */
		if(ip_ecc_check_error(NULL)){
			goto err;
		}
	}

	return 0;
err:
	return -1;
}

/* Get the current dynamic NN size in bits */
static inline unsigned int ip_ecc_get_nn_bit_size(void)
{
	/* Size is in bits */
	if(IPECC_IS_DYNAMIC_NN_SUPPORTED()){
		return (unsigned int)IPECC_GET_NN_SIZE();
	}
	else{
		return (unsigned int)IPECC_GET_NN_MAX_SIZE();
	}
	/*
	 * Note: a sole use of IPECC_GET_NN_SIZE() could also work as this
	 * macro also returns the NN_MAX size when the 'dynamic nn' feature is
	 * not supported.
	 */
}

/* Set the blinding size for scalar multiplication.
 *
 * A value of 0 for input argument 'blinding_size' means disabling
 * the blinding countermeasure.
 */
static inline int ip_ecc_set_blinding_size(unsigned int blinding_size)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	if(blinding_size == 0){
		/* Clear the blinding */
		IPECC_DISABLE_BLINDING();
	}
	else{
		/* Set the blinding size and enable the countermeasure. */
		IPECC_SET_BLINDING_SIZE(blinding_size);
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

/* Disable the blinding for scalar multiplication.
 */
static inline int ip_ecc_disable_blinding(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Disable the blinding */
	IPECC_DISABLE_BLINDING();

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

/* Activate the shuffling for scalar multiplication.
 */
static inline int ip_ecc_set_shuffling(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Enable shuffling */
	IPECC_ENABLE_SHUFFLE();

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

/* Disable the shuffling for scalar multiplication.
 */
static inline int ip_ecc_disable_shuffling(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Disable shuffling */
	IPECC_DISABLE_SHUFFLE();

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

/* Set the period of the Z-remask countermeasure for scalar multiplication.
 *
 * A value of 0 for input argument 'period' means disabling the countermeasure.
 */
static inline int ip_ecc_set_zremask(unsigned int period)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	if(period == 0){
		/* Clear the Z-remask countermeasure */
		IPECC_DISABLE_ZREMASK();
	}
	else{
		/* Set the blinding size and enable the countermeasure. */
		IPECC_ENABLE_ZREMASK(period);
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

/* Disable the Z-remask countermeasure for scalar multiplication.
 */
static inline int ip_ecc_disable_zremask(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Disable the countermeasure */
	IPECC_DISABLE_ZREMASK();

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

/* Write a big number to the IP
 *
 *   The input big number is in big-endian format, and it is sent to the IP in the
 *   endianness it expects, meaning: the numbers are little-endian in words (of 32
 *   or 64 bits) and big-endian for the bytes inside words as well as for the bits
 *   inside bytes.
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

	/* Get the current nb of words we need to send to the IP */
	nn_size = ip_ecc_nn_words_from_bytes_sz(ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size()));
	/* Compute our current word size */
	curr_word_sz = ip_ecc_nn_words_from_bytes_sz(a_sz);

	if(curr_word_sz > nn_size){
		/* We overflow, this is an error! */
		goto err;
	}

	/* If the number to write to the IP is the scalar, we must first check
	 * that bit 'R_STATUS_ENOUGH_RND_WK' is actually asserted in 'R_STATUS'
	 * register, as this means the IP has gathered enough random to mask
	 * the scalar with during its transfer into its internal memory of
	 * large numbers.
	 */
	if (reg == EC_HW_REG_SCALAR)
	{
		/* Hence we poll this bit until it says we can actually write the
		 * scalar.
		 */
		IPECC_ENOUGH_WK_RANDOM_WAIT();
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

/* Read a big number from the IP.
 *
 *   The output big number is in big-endian format, and it is read from the IP in the
 *   endianness it expects, meaning: the numbers are little-endian in words (of 32
 *   or 64 bits) and big-endian for the bytes inside words as well as for the bits
 *   inside bytes.
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

	/* Get the current size we need to read from the IP */
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

/* Ask the IP for the generation of the random one-shot token.
 *
 * (More info in ip_ecc_get_token() header below).
 */
int ip_ecc_generate_token(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Write to proper register for token generation. */
	IPECC_ASK_FOR_TOKEN_GENERATION();
	
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

/* Get from the IP a unique one-shot random token that the software
 * should later use to unmask the [k]P result of the next scalar
 * multiplication with. At the end of the next scalar multiplication,
 * the IP will whiten the coordinates of the [k]P result with this
 * token (with a simple bit-by-bit XOR) and erase the token. Thus
 * the unmasking by the software on its part will unveil the plain
 * values of the [k]P coordinates.
 *
 * This emulates some kind of secret sharing between the IP and the
 * software that only lasts the time of the scalar multiplication.
 * Obviously the "secret" is transferred as a plaintext value on the
 * bus/interconnect between the IP and the CPU, so the token just
 * constitutes an extra subsidiary countermeasure in the case where
 * the [k]P result may serve as a secret or a half-secret) e.g in
 * an ECDH exchange. (If malevolent software/agent is trying to spy
 * on the [k]P coordinates, she will have to intercept the transfers
 * between the IP and the software at both the begining and the end
 * of the scalar multiplication, given that several dozens of milli-
 * seconds may pass by in the meantime).
 *
 * The token is a large number whose bit-width is given by the current
 * value of parameter 'nn' in the IP (whether it is static or dynamic).
 *
 * Hence argument 'out_tok' should point to a buffer of size at least
 * '(ceil(nn / 8)' in bytes. The call to ip_ecc_read_bignum() will
 * enforce that the value of argument 't_sz' follows this rule.
 */
int ip_ecc_get_token(unsigned char* out_tok, unsigned int t_sz)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Ask the IP for the token generation */
	if(ip_ecc_generate_token()){
		goto err;
	}

	/* Read the "token" large number */
	if(ip_ecc_read_bignum(out_tok, t_sz, EC_HW_REG_TOKEN)){
		goto err;
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

/*
 * Unmask (XOR) the provided 'in_a' large number with the provided
 * 'in_tok' large number. 
 */
int ip_ecc_unmask_with_token(const unsigned char* in_a, unsigned int a_sz, const unsigned char* in_tok,
		                         unsigned int t_sz, unsigned char* out_b, unsigned int* out_b_sz)
{
	unsigned int i;

	/* It doesn't make sense that input sizes not match. */
	if (a_sz != t_sz) {
		goto err;
	}

	for(i = 0; i < a_sz; i++){
		/* Do a simple byte-by-byte XOR */
		out_b[i] = in_a[i] ^ in_tok[i];
	}

	*out_b_sz = a_sz;

	return 0;
err:
	return -1;
}

/*
 * Clear the local copy of the token
 */
int ip_ecc_clear_token(unsigned char* tok, unsigned int t_sz)
{
	unsigned int i;

	for (i = 0; i < t_sz; i++){
		tok[i] = 0;
	}

	return 1;
}

/*
 * To know if R0 is currently the null point (aka point at infinity)
 */
static inline int ip_ecc_get_r0_inf(int *iszero)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	(*iszero) = (int)IPECC_GET_R0_INF();

	return 0;
}

/*
 * To know if R1 is currently the null point (aka point at infinity)
 */
static inline int ip_ecc_get_r1_inf(int *iszero)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	(*iszero) = (int)IPECC_GET_R1_INF();

	return 0;
}

/*
 * To set R0 as being or not being the null point (aka point at infinity).
 *
 * When R0 is set as the null point, the coordinates the IP was previously
 * holding for R0 (as e.g resulting from a previous computation) become invalid
 * and are ignored by the IP henceforth.
 *
 * The null point does not have affine coordinates, so either R0 is null and
 * the coordinates buffered in the IP for it are meaningless, or it isn't null
 * and these coordinates actually define R0.
 *
 * Note that pushing coordinates to the IP for point R0 automatically makes
 * R0 a not-null point for the IP. Hence function ip_ecc_set_r0_inf()'s
 * purpose is mainly to set R0 as the null point.
 */
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

/*
 * To set R1 as being or not being the null point (aka point at infinity).
 *
 * Every remark made about point R0 in function ip_ecc_set_r0_inf() (see above)
 * is also valid and apply here identically to point R1.
 */
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

/*
 * Commands execution (point operation)
 */
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

/* Is the IP in 'debug' or 'production' mode? */
static inline int ip_ecc_is_debug(unsigned int* answer)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Ask the IP register. */
	*answer = IPECC_IS_DEBUG_OR_PROD();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* Get the major version number of the IP */
static inline int ip_ecc_get_version_major(unsigned int* nb)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Get both version numbers from IP register. */
	*nb = IPECC_GET_MAJOR_VERSION();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* Get the minor version number of the IP */
static inline int ip_ecc_get_version_minor(unsigned int* nb)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Get both version numbers from IP register. */
	*nb = IPECC_GET_MINOR_VERSION();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/*
 * *** TRNG debug ***
 */
/* The following function configures the TRNG */
static inline int ip_ecc_configure_trng(int debias, uint32_t ta, uint32_t cycles)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Write the TRNG configuration register */
	IPECC_TRNG_CONFIG(debias, ta, cycles);

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* TRNG complete bypass */
static inline int ip_ecc_bypass_full_trng(uint32_t instead_bit)
{
	if ((instead_bit != 0) && (instead_bit != 1))
		goto err;

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Activate the TRNG complete bypass, specifying deterministic
	 * value to use instead of random bits. */
	IPECC_TRNG_COMPLETE_BYPASS(instead_bit);

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;

err:
	return -1;
}

/* TRNG leave bypass state and return to normal generation
 * (also implicitly re-enable the post-processing function) */
static inline int ip_ecc_dont_bypass_trng(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Transmit action to low-level routine */
	IPECC_TRNG_UNDO_COMPLETE_BYPASS();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* Disable the TRNG post-processing logic that pulls bytes from the
 * raw random source.
 *
 * Watchout: implicitly remove a possibly pending complete bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
static inline int ip_ecc_trng_postproc_disable(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Deactivate the Post-Processing */
	IPECC_TRNG_DISABLE_POSTPROC();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* (Re)enable the TRNG post-processing logic that pulls bytes from the
 * raw random source - in the debug mode of the IP, that logic is disabled
 * upon reset and needs to be explicitly enabled by sofware by calling
 * this macro.
 *
 * Watchout: implicitly remove a possibly pending complete bypass of the TRNG
 * by deasserting the 'complete bypass' bit in the same register.
 */
static inline int ip_ecc_trng_postproc_enable()
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Deactivate the Post-Processing */
	IPECC_TRNG_ENABLE_POSTPROC();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* Disable the read port of the TRNG raw random FIFO,
 * allowing complete and exclusive access by software to the raw
 * random bits.
 */
static inline int ip_ecc_disable_read_port_of_raw_fifo(void)
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Disable the read port of the FIFO used by the post-processing. */
	IPECC_TRNG_RAW_FIFO_READ_PORT_DISABLE();

	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	return 0;
}

/* (Re)nable the read port of the TRNG raw random FIFO.
 */
static inline int ip_ecc_enable_read_port_of_raw_fifo()
{
	/* Wait until the IP is not busy */
	IPECC_BUSY_WAIT();

	/* Enable the read port of the FIFO used by the post-processing. */
	IPECC_TRNG_RAW_FIFO_READ_PORT_ENABLE();

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
		for(i = 0; i < IPECC_GET_TRNG_RAW_SZ(); i++){
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

static volatile unsigned char hw_driver_setup_state = 0;

static inline int driver_setup(void)
{
	if(!hw_driver_setup_state){
		/* Ask the lower layer for a setup */
		if(hw_driver_setup((volatile unsigned char**)&ipecc_baddr, (volatile unsigned char**)&ipecc_pseudotrng_baddr)){
			goto err;
		}
#if 0
		log_print("Waiting for 2s back from hw_driver_setup() & B4 soft reset...\n");
		sleep(2);
#endif
		/* Reset the IP for a clean state */
		IPECC_SOFT_RESET();

#if 0
		log_print("Waiting for 2s after soft reset...\n");
		sleep(2);
#endif

#if 0
		/* Reset the pseudo TRNG device to empty its FIFO of pseudo raw random bytes */
		IPECC_PSEUDOTRNG_SOFT_RESET();

		log_print("Waiting for 2s after soft pseudo TRNG reset...\n");
		sleep(2);
#endif

		/* We are in the initialized state */
		hw_driver_setup_state = 1;
	}
	
	return 0;
err:
	return -1;
}

/*********************************************
 **  Driver API (top-layer exported functions)
 *********************************************/

/* Reset the hardware */
int hw_driver_reset(void)
{
	/* Reset the IP for a clean state */
        IPECC_SOFT_RESET();

	return 0;
}

/* To know if the IP is in 'debug' or 'production' mode */
int hw_driver_is_debug(unsigned int* answer)
{
	if(driver_setup()){
		goto err;
	}
	if (ip_ecc_is_debug(answer)){
		goto err;
	}
	return 0;
err: 
	return -1;
}

/* Get major version of the IP */
int hw_driver_get_version_major(unsigned int* nb)
{
	if(driver_setup()){
		goto err;
	}
	if (ip_ecc_get_version_major(nb)){
		goto err;
	}
	return 0;
err: 
	return -1;
}

/* Get minor version of the IP */
int hw_driver_get_version_minor(unsigned int* nb)
{
	if(driver_setup()){
		goto err;
	}
	if (ip_ecc_get_version_minor(nb)){
		goto err;
	}
	return 0;
err: 
	return -1;
}

/* Enable TRNG post-processing logic */
int hw_driver_trng_post_proc_enable()
{
	if(driver_setup()){
		goto err;
	}
	if (ip_ecc_trng_postproc_enable()){
		goto err;
	}
	return 0;
err: 
	return -1;
}

/* Disable TRNG post-processing logic */
int hw_driver_trng_post_proc_disable()
{
	if(driver_setup()){
		goto err;
	}
	if (ip_ecc_trng_postproc_disable()){
		goto err;
	}
	return 0;
err: 
	return -1;
}

/* Set the curve parameters a, b, p and q.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 *
 * Note: if software does not intend to later use the blinding
 * countermeasure, then the order 'q' of the curve is not mandatory
 * (using e.g an arbitrary number for argument 'q' and setting 'q_sz'
 * the same as 'p_sz').
 *
 * Note however that the IP could have been synthesized with an
 * active hardware-locked blinding countermeasure, which, if the IP
 * was further synthesized in production (secure) mode, won't be
 * disengageable by software. In this situation, since every scalar
 * multiplication will be run by the IP with active blinding, 'q'
 * and 'q_sz' arguments should be rigorously set.
 */
int hw_driver_set_curve(const unsigned char *a, unsigned int a_sz, const unsigned char *b, unsigned int b_sz,
       		        const unsigned char *p, unsigned int p_sz, const unsigned char *q, unsigned int q_sz)
{
	if(driver_setup()){
		goto err;
	}
	/* We set the dynamic NN size value to be the max
	 * of P and Q size
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

/* Activate the blinding for scalar multiplication.
 *
 * Argument 'blinding_size' must be given in bits, and must be
 * strictly less than the value of 'nn' currently set in the
 * hardware (hance 'nn' - 1 is the largest authorized value).
 *
 * Otherwise error 'ERR_BLN' is raised in R_STATUS register.
 *
 * A value of 0 for input argument 'blinding_size' is counter-
 * intuitive and will be held as meaning to disable the blinding
 * countermeasure (consider using instead  explicit function
 * hw_driver_disable_blinding()).
 */
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

/* Disable the blinding for scalar multiplication.
 */
int hw_driver_disable_blinding(void)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_disable_blinding()){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Activate the shuffling for scalar multiplication */
int hw_driver_set_shuffling(void)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_set_shuffling()){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Disable the shuffling for scalar multiplication */
int hw_driver_disable_shuffling(void)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_disable_shuffling()){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Activate and configure the periodic Z-remasking countermeasure
 * (the 'period' arguement is expressed in number of bits of the scalar */
int hw_driver_set_zremask(unsigned int period)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_set_zremask(period)){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Disable the periodic Z-remasking countermeasure for scalar multiplication */
int hw_driver_disable_zremask(void)
{
	if(driver_setup()){
		goto err;
	}

	if(ip_ecc_disable_zremask()){
		goto err;
	}

	return 0;
err:
	return -1;
}

/* Check if an affine point (x, y) is on the curve currently defined
 * in the IP (this curve was previously set in the hardware using
 * function hw_driver_set_curve() - c.f above).
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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

/* Check if affine points (x1, y1) and (x2, y2) are equal.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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

/* Check if affine points (x1, y1) and (x2, y2) are opposite.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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
 * point at index idx.
 *
 * Argument 'index' must be either 0, identifying point R0, or 1,
 * identifying point R1.
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

/* Set the infinity point flag in the hardware for point
 * at index idx. This tells hardware to hold the corresponding
 * point (R0 or R1) as being the null point (aka point at infinity).
 *
 * Any values of the affine coordinates the hardware was currently
 * holding for that point will become irrelevant, either they were
 * resulting from a previous computation or transmitted by software.
 *
 * Argument 'index' must be either 0, identifying point R0, or 1,
 * identifying point R1.
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
 * point at index idx. This tells hardware to hold the corresponding
 * point (R0 or R1) as NOT being the null point (aka point at infinity).
 *
 * The affine coordinates the hardware was currently holding for that
 * point will then become relevant, either they were resulting from a
 * previous computation or transmitted by software.
 *
 * Further note that transmitting coordinates to the hardware for one
 * of particular points R0 or R1 (using ip_ecc_write_bignum()) automatically
 * set that point as being not null, just as hw_driver_point_unzero()
 * would do.
 *
 * Argument 'index' must be either 0, identifying point R0, or 1,
 * identifying point R1.
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

/* Return (out_x, out_y) = -(x, y) i.e the opposite of the
 * intput point.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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

/* Return (out_x, out_y) = 2 * (x, y), i.e the double of the
 * input point.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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


/* Return (out_x, out_y) = (x1, y1) + (x2, y2), i.e perform addition
 * of the two input points.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
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

/* Return (out_x, out_y) = scalar * (x, y), i.e perform the scalar 
 * multiplication of the input point by the input scalar.
 *
 * All size arguments (*_sz) must be given in bytes.
 *
 * Please read and take into consideration the 'NOTE:' mentionned
 * at the top of the prototype file <hw_accelerator_driver.h>
 * about the formatting and size of large numbers.
 */
int hw_driver_mul(const unsigned char *x, unsigned int x_sz, const unsigned char *y, unsigned int y_sz,
                  const unsigned char *scalar, unsigned int scalar_sz,
                  unsigned char *out_x, unsigned int *out_x_sz, unsigned char *out_y, unsigned int *out_y_sz)
{
	int inf_r0, inf_r1;
	unsigned int nn_sz;

	/* 32768 bits are more than enough for any practical
	 * use of elliptic curve cryptography.
	 */
	unsigned char token[4096] = {0, }; /* Heck, a whole page? Yes indeed. */

	if(driver_setup()){
		log_print("In hw_driver_mul(): Error in driver_setup()\n");
		goto err;
	}

	/* Nb of bytes corresponding to current value of 'nn' in the IP.
	 */
	nn_sz = ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size());

	/* Check that the current value of 'nn' does not exceed the size
	 * allocated to the token on the stack.
	 */
	if(ip_ecc_nn_bytes_from_bits_sz(ip_ecc_get_nn_bit_size()) > 4096){
		log_print("In hw_driver_mul(): Error in ip_ecc_nn_bytes_from_bits_sz()\n");
		goto err;
	}

	/* Preserve our inf flags in a constant time fashion */
	if(ip_ecc_get_r0_inf(&inf_r0)){
		log_print("In hw_driver_mul(): Error in ip_ecc_get_r0_inf()\n");
		goto err;
	}
	if(ip_ecc_get_r1_inf(&inf_r1)){
		log_print("In hw_driver_mul(): Error in ip_ecc_get_r1_inf()\n");
		goto err;
	}

	/* Get the random one-shot token */
	if (ip_ecc_get_token(token, nn_sz)){
		log_print("In hw_driver_mul(): Error in ip_ecc_get_token()\n");
		goto err;
	}

	/* Write our scalar register with the scalar k */
	if(ip_ecc_write_bignum(scalar, scalar_sz, EC_HW_REG_SCALAR)){
		log_print("In hw_driver_mul(): Error in ip_ecc_write_bignum()\n");
		goto err;
	}
	/* Write our R1 register with the point to be multiplied */
	if(ip_ecc_write_bignum(x, x_sz, EC_HW_REG_R1_X)){
		log_print("In hw_driver_mul(): Error in ip_ecc_write_bignum()\n");
		goto err;
	}
	if(ip_ecc_write_bignum(y, y_sz, EC_HW_REG_R1_Y)){
		log_print("In hw_driver_mul(): Error in ip_ecc_write_bignum()\n");
		goto err;
	}

	/* Restore our inf flags in a constant time fashion */
	if(ip_ecc_set_r0_inf(inf_r0)){
		log_print("In hw_driver_mul(): Error in ip_ecc_set_r0_inf()\n");
		goto err;
	}
	if(ip_ecc_set_r1_inf(inf_r1)){
		log_print("In hw_driver_mul(): Error in ip_ecc_set_r1_inf()\n");
		goto err;
	}

	/* Execute our [k]P command */
	if(ip_ecc_exec_command(PT_KP, NULL)){
		log_print("In hw_driver_mul(): Error in ip_ecc_exec_command()\n");
		goto err;
	}

	/* Get back the result from R1 */
	if(((*out_x_sz) < nn_sz) || ((*out_y_sz) < nn_sz)){
		log_print("In hw_driver_mul(): *out_x_sz = %d\n", *out_x_sz);
		log_print("In hw_driver_mul(): *out_y_sz = %d\n", *out_y_sz);
		log_print("In hw_driver_mul(): nn_sz = %d\n", nn_sz);
		log_print("In hw_driver_mul(): Error in sizes' comparison\n");
		goto err;
	}
	(*out_x_sz) = (*out_y_sz) = nn_sz;
	if(ip_ecc_read_bignum(out_x, (*out_x_sz), EC_HW_REG_R1_X)){
		log_print("In hw_driver_mul(): Error in ip_ecc_read_bignum()\n");
		goto err;
	}
	if(ip_ecc_read_bignum(out_y, (*out_y_sz), EC_HW_REG_R1_Y)){
		log_print("In hw_driver_mul(): Error in ip_ecc_read_bignum()\n");
		goto err;
	}

	/* Unmask the [k]P result coordinates with the one-shot token */
	if (ip_ecc_unmask_with_token(out_x, (*out_x_sz), token, nn_sz, out_x, out_x_sz)) {
		log_print("In hw_driver_mul(): Error in ip_ecc_unmask_with_token()\n");
		goto err;
	}
	if (ip_ecc_unmask_with_token(out_y, (*out_y_sz), token, nn_sz, out_y, out_y_sz)) {
		log_print("In hw_driver_mul(): Error in ip_ecc_unmask_with_token()\n");
		goto err;
	};

	/* Clear the token */
	ip_ecc_clear_token(token, nn_sz);

	return 0;
err:
	return -1;
}

/* Set the small scalar size in the hardware.
 *
 * The 'small scalar size' feature is provided by the IP in order
 * to provide a computation speed-up for really small scalar.
 *
 * This is a "one shot" feature, meaning the 'nn' parameter is
 * still recorded by the IP and will become applicable again
 * as soon as the scalar multiplication following the call to
 * function hw_driver_set_small_scalar_size() is done.
 *
 * Hence hw_driver_set_small_scalar_size() must be called
 * each time the feature is needed.
 *
 * Obviously this feature only concerns the scalar multiplication.
 * */
int hw_driver_set_small_scalar_size(unsigned int bit_sz)
{
	if(driver_setup()){
		goto err;
	}

	/* NOTE: sanity check on this size should be performed by
	 * the hardware (e.g. is this size exceeds the nn size, and
	 * so on). So no need to sanity check anything here. */
	IPECC_SET_SMALL_SCALAR_SIZE(bit_sz);

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
