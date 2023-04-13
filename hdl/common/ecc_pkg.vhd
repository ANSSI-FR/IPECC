--
--  Copyright (C) 2023 - This file is part of IPECC project
--
--  Authors:
--      Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
--      Ryad BENADJILA <ryadbenadjila@gmail.com>
--
--  Contributors:
--      Adrian THILLARD
--      Emmanuel PROUFF
--
--  This software is licensed under GPL v2 license.
--  See LICENSE file at the root folder of the project.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_customize.all;
use work.ecc_utils.all;
use work.ecc_vars.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

package ecc_pkg is

	-- 'ww'
	--
	-- this is the "word width": the width, in bits, of the words in which
	-- big numbers are split to fit into memory 'ecc_fp_dram', in which all
	-- big numbers are stored (and on which instructions in ecc_curve_iram
	-- program memory operate).
	-- 'ecc_fp_dram' memory is atomically and independently addressable
	-- in words of ww bits, both in read and write mode.
	-- Consequently, ww is also the width of input and output buses of
	-- component 'mm' (Montgomery multipler) as well as the multipler-
	-- accumulator primitive instanciated in it.
	--
	-- For FPGA, 'ww' is automatically set according to the vendor/family/
	-- device (that's the reason for parameter 'techno')
	-- For ASIC, 'ww' is set to 'multwidth'
	constant ww : positive := set_ww;

	-- 'w'
	--
	-- this is the number of 'ww'-bit words required to form a big-number
	-- of size nn + 4 (1 extra bit for signedness, 1 extra bit because big-
	-- numbers may fall in the range [p, 2p[ before reduction & 2 extra-bits
	-- for the trick that if R>4p then conditional subtraction is avoided at
	-- the end of Mongtomery reduction).
	-- Parameter 'w' depends only on the choice of 'nn' and, through the 'ww'
	-- parameter value, to the parameter 'techno' which is also set by user.
	--
	-- e.g with ww = 16:       nn  |   w
	-- (techno = 7-series)    -----+----
	--                        256  |  17    (as 256 + 4 = (17 x 16) -  12)
	--                        320  |  21    (as 320 + 4 = (21 x 16) -  12)
	-- this parameter is set automatically according to value of nn and ww
	-- and MUST be greater than or equal to 2
	constant w : natural := div(nn + 4, ww);

	-- 'W_BITS'
	--
	-- denotes the number of bits required to encode a counter from 0 to w - 1
	constant W_BITS : natural := log2(w - 1); -- 4 for (nn = 256, ww = 17)

	-- 'n'
	--
	-- this is the power-of-2 which is either equal to or directly greater
	-- than 'w'.
	-- Parameter 'n' depends only on the choice of 'nn' and 'ww' made by user
	--
	-- e.g with ww = 17:    nn  |   n
	--                     -----+----
	--                     256  |  16  (as w = 16)
	--                     320  |  32  (as w = 19)
	constant n : natural := ge_pow_of_2(w);

	-- FP_ADDR_MSB
	--
	-- this is the number of bits required to encode the address of one of the
	-- large numbers in ecc_fp_dram (in qty nblargenb). This parameter obviously
	-- has an effect on the size of opcode words in ecc_curve_iram, that's why
	-- modifying parameter nblargenb in ecc_customize.vhd should be made with
	-- caution
	constant FP_ADDR_MSB : positive := log2(nblargenb - 1);

	-- FP_ADDR_LSB
	--
	-- this is the number of bits required to encode the address of one of the
	-- ww-bit limbs that form one large number. This parameter has no effect
	-- on the size of opcode words, but modification should not be made has
	-- parameter n is computed automatically based on nn and ww
	constant FP_ADDR_LSB : positive := log2(n - 1);

	-- FP_ADDR
	--
	-- this is the number of bits of both R/W address-bus to/from ecc_fp_dram
	constant FP_ADDR : positive := FP_ADDR_MSB + FP_ADDR_LSB;

	-- bitwidth of address bus to ecc_curve_iram
	-- the default value is 9, matching value 512 for parameter nbopcodes
	-- in ecc_customize.vhd
	constant IRAM_ADDR_SZ : positive := log2(nbopcodes - 1); -- 10

	subtype std_logic_ww is std_logic_vector(ww - 1 downto 0);

	-- types for interface between ecc_curve & ecc_fp
	type opi_type is record
		-- the 5 bits in the definition of fields a, b & c below accounts for
		-- the nb of addressable words in ecc_fp_dram memory, namely 32 big-numbers
		a : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		b : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		c : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		add : std_logic;
		sub : std_logic;
		ssrl : std_logic;
		ssll : std_logic;
		rnd : std_logic;
		xxor : std_logic;
		redc : std_logic;
		extended : std_logic;
		par : std_logic;
		div2 : std_logic;
		valid : std_logic;
		-- extra flags for NNRND instruction (NNRNDm, NNRNDs, NNRNDf variants)
		m : std_logic;
		sh : std_logic;
		shf : std_logic;
		-- extra flag for NNSRL instruction (NNSRLs variant)
		ssrl_sh : std_logic;
		-- pragma translate_off
		parsh : std_logic;
		oposhr : std_logic;
		-- pragma translate_on
	end record;

	constant NB_MSK_SH_REG : positive := 4;

	type opo_type is record
		rdy : std_logic;
		resultz : std_logic;
		resultsn : std_logic;
		resultpar : std_logic;
		resulterr : std_logic;
		done : std_logic;
		shr : std_logic_vector(NB_MSK_SH_REG - 1 downto 0);
	end record;

	subtype stdop is std_logic_vector(FP_ADDR_MSB - 1 downto 0);

	constant CST_ADDR_P : stdop := std_nat(LARGE_NB_P_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_A : stdop := std_nat(LARGE_NB_A_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_B : stdop := std_nat(LARGE_NB_B_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_Q : stdop := std_nat(LARGE_NB_Q_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_K : stdop := std_nat(LARGE_NB_K_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_XR0 : stdop := std_nat(LARGE_NB_XR0_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_YR0 : stdop := std_nat(LARGE_NB_YR0_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_XR1 : stdop := std_nat(LARGE_NB_XR1_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_YR1 : stdop := std_nat(LARGE_NB_YR1_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_ZR01 : stdop := std_nat(LARGE_NB_ZR01_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_R : stdop := std_nat(LARGE_NB_R_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_ONE : stdop := std_nat(LARGE_NB_ONE_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_ZERO : stdop := std_nat(LARGE_NB_ZERO_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_XR0BK : stdop := std_nat(LARGE_NB_XR0BK_ADDR, FP_ADDR_MSB);
	constant CST_ADDR_YR0BK : stdop := std_nat(LARGE_NB_YR0BK_ADDR, FP_ADDR_MSB);

	constant CST_ARITH_MASK_0 : integer := 10;
	constant CST_ARITH_MASK_1 : integer := 11;
	constant CST_LOGIC_MASK_0 : integer := 26;
	constant CST_LOGIC_MASK_1 : integer := 27;

	-- structure of opcode words in ecc_curve_iram
	-- (in the right column are typical values, that is values corresponding
	-- to the default value of 32 for parameter nblargenb in ecc_customize.vhd,
	-- operands address are then 5-bit long)
	constant OPC_LSB : integer := 0;                                   --  0
	constant OPC_MSB : integer := FP_ADDR_MSB - 1;                     --  4
	constant OPB_LSB : integer := FP_ADDR_MSB;                         --  5
	constant OPB_MSB : integer := (2 * FP_ADDR_MSB) - 1;               --  9
	constant OPA_LSB : integer := (2 * FP_ADDR_MSB);                   -- 10
	constant OPA_MSB : integer := (3 * FP_ADDR_MSB) - 1;               -- 14
	constant OP_AFILL : integer := set_op_arith_fill(FP_ADDR_MSB, IRAM_ADDR_SZ);
	constant OP_M_POS : integer := OPA_MSB + 1 + OP_AFILL;             -- 15
	constant OP_PATCH_LSB : integer := OP_M_POS + 1;                   -- 16
	constant OP_PATCH_SZ : integer := 6;
	constant OP_PATCH_MSB : integer := OP_PATCH_LSB + OP_PATCH_SZ - 1; -- 21
	constant OP_P_POS : integer := OP_PATCH_LSB + OP_PATCH_SZ;         -- 22
	constant OP_X_POS : integer := OP_P_POS + 1;                       -- 23
	-- there are currently 16 different opcodes per type of opcodes (hence
	-- NB_OF_OP is set to 16 right below). This allows to encode 16 arith and/or
	-- logical instructions, and 16 conditional branchs
	constant NB_OF_OP : integer := 16;
	constant OP_OP_SZ : integer := log2(NB_OF_OP - 1);
	constant OP_OP_LSB : integer := OP_X_POS + 1;                      -- 24
	constant OP_OP_MSB : integer := OP_OP_LSB + OP_OP_SZ - 1;          -- 27
	-- there are currently 4 types of opcodes (hence NB_OF_TYPE is set to 4 right
	-- below) which are: ARITH, BRANCH, UPDATE (now obsolete) and NOP
	constant NB_OF_TYPE : integer := 4;
	constant OP_TYPE_SZ : integer := log2(NB_OF_TYPE - 1);
	constant OP_TYPE_LSB : integer := OP_OP_MSB + 1;                   -- 28
	constant OP_TYPE_MSB : integer := OP_TYPE_LSB + OP_TYPE_SZ - 1;    -- 29
	constant OP_B_POS : integer := OP_TYPE_MSB + 1;                    -- 30
	constant OP_S_POS : integer := OP_B_POS + 1;                       -- 31
	constant OPCODE_SZ : positive := OP_S_POS + 1;                     -- 32 bits

	-- for branch instructions, target address is given as an immediate value the
	-- bit width of which depends on parameter nbopcodes (in ecc_customize.vhd)
	-- which defines the size of microcode memory ecc_curve_iram. Nominaly
	-- nbopcodes = 512, hence the address immediate value is 9-bit long
	constant OP_BR_IMM_SZ : positive := IRAM_ADDR_SZ;
	--constant OP_BR_IMM_MSB : integer := OPA_MSB; --TODO
	--constant OP_BR_IMM_LSB : integer := OP_BR_IMM_MSB - OP_BR_IMM_SZ + 1;
	constant OP_SHREG_IMM_SZ : positive := 2;

	-- constants for opcode type (field TYPE of the opcode word)
	constant OPCODE_ARITH : std_logic_vector(OP_TYPE_SZ - 1 downto 0) := "01";
	constant OPCODE_BRANCH : std_logic_vector(OP_TYPE_SZ - 1 downto 0) := "10";
	constant OPCODE_UPDATE : std_logic_vector(OP_TYPE_SZ - 1 downto 0) := "11";
	constant OPCODE_NOP : std_logic_vector(OP_TYPE_SZ - 1 downto 0) := "00";

	-- constants for arithmetic and/or logical instructions (field OPCODE of the
	-- opcode word)
	constant OPCODE_ARITH_ADD : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0001";
	constant OPCODE_ARITH_SUB : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0010";
	constant OPCODE_ARITH_SRL : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0011";
	constant OPCODE_ARITH_SLL : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0100";
	constant OPCODE_ARITH_RND : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0101";
	constant OPCODE_ARITH_TSH : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0110";
	constant OPCODE_ARITH_XOR : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0111";
	constant OPCODE_ARITH_RED : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1000";
	constant OPCODE_ARITH_TST : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1001";
	constant OPCODE_ARITH_RNM : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1010";
	constant OPCODE_ARITH_DIV : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1011";
	constant OPCODE_ARITH_RNH : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1100";
	constant OPCODE_ARITH_RNF : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1101";
	constant OPCODE_ARITH_SRH : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1110";

	-- constant for the conditional test branchs (field OPCODE of the opcode word)
	constant OPCODE_BRA_B : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0001";
	constant OPCODE_BRA_BZ : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0010";
	constant OPCODE_BRA_BSN : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0011";
	constant OPCODE_BRA_BODD : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0100";
	constant OPCODE_BRA_BKAP : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0101";
	constant OPCODE_BRA_CALL : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0110";
	constant OPCODE_BRA_CALLSN : std_logic_vector(OP_OP_SZ - 1 downto 0) := "0111";
	constant OPCODE_BRA_RET : std_logic_vector(OP_OP_SZ - 1 downto 0) := "1000";

	-- states of ecc_scalar
	constant DEBUG_STATE_IDLE : std_logic4 := std_logic_vector(to_unsigned(0, 4));
	constant DEBUG_STATE_CSTMTY : std_logic4 := std_logic_vector(to_unsigned(1, 4));
	constant DEBUG_STATE_CHECKONCURVE : std_logic4 := std_logic_vector(to_unsigned(2, 4));
	constant DEBUG_STATE_BLINDINIT : std_logic4 := std_logic_vector(to_unsigned(3, 4));
	constant DEBUG_STATE_BLINDBIT : std_logic4 := std_logic_vector(to_unsigned(4, 4));
	constant DEBUG_STATE_BLINDEXIT : std_logic4 := std_logic_vector(to_unsigned(5, 4));
	constant DEBUG_STATE_ADPA : std_logic4 := std_logic_vector(to_unsigned(6, 4));
	constant DEBUG_STATE_SETUP : std_logic4 := std_logic_vector(to_unsigned(7, 4));
	constant DEBUG_STATE_DOUBLE : std_logic4 := std_logic_vector(to_unsigned(8, 4));
	constant DEBUG_STATE_SWITCH3P : std_logic4 := std_logic_vector(to_unsigned(9, 4));
	constant DEBUG_STATE_ITOH : std_logic4 := std_logic_vector(to_unsigned(10, 4));
	constant DEBUG_STATE_ZADDU : std_logic4 := std_logic_vector(to_unsigned(11, 4));
	constant DEBUG_STATE_ZADDC : std_logic4 := std_logic_vector(to_unsigned(12, 4));
	constant DEBUG_STATE_SUBTRACTP : std_logic4 := std_logic_vector(to_unsigned(13, 4));
	constant DEBUG_STATE_EXIT : std_logic4 := std_logic_vector(to_unsigned(14, 4));

	type breakpoint_type is record
		addr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		act : std_logic;
		nbbits : std_logic_vector(15 downto 0);
		state : std_logic_vector(3 downto 0);
	end record;

	type breakpoints_type is array(natural range 0 to 3) of breakpoint_type;

	-- Single Dual Port memory (one W only port, one R only port)
	component syncram_sdp is
		generic(
			rdlat : positive range 1 to 2;
			datawidth : natural range 1 to integer'high;
			datadepth : natural range 1 to integer'high);
		port(
			clk : in std_logic;
			-- port A (W only)
			addra : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			ena : in std_logic;
			wea : in std_logic;
			dia : in std_logic_vector(datawidth - 1 downto 0);
			-- port B (R only)
			addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			enb : in std_logic;
			dob : out std_logic_vector(datawidth - 1 downto 0)
		);
	end component;

	-- Single Dual Port memory (one W only port, one R only port)
	-- with completely asynchronous W & R ports
	component sync2ram_sdp is
		generic(
			rdlat : positive range 1 to 2;
			datawidth : natural range 1 to integer'high;
			datadepth : natural range 1 to integer'high);
		port(
			-- port A (W only)
			clka : in std_logic;
			addra : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			ena : in std_logic;
			wea : in std_logic;
			dia : in std_logic_vector(datawidth - 1 downto 0);
			-- port B (R only)
			clkb : in std_logic;
			addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			enb : in std_logic;
			dob : out std_logic_vector(datawidth - 1 downto 0)
		);
	end component;

	component fifo is
		generic(
			datawidth : natural range 1 to integer'high;
			datadepth : natural range 1 to integer'high);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			datain : in std_logic_vector(datawidth - 1 downto 0);
			we : in std_logic;
			werr : out std_logic;
			full : out std_logic;
			dataout : out std_logic_vector(datawidth - 1 downto 0);
			re : in std_logic;
			empty : out std_logic;
			rerr : out std_logic;
			count : out std_logic_vector(log2(datadepth) - 1 downto 0);
			-- debug feature
			dbgdeact : in std_logic;
			dbgwaddr : out std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			dbgraddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			dbgrst : in std_logic
		);
	end component fifo;

	--subtype phys_addr is std_logic_vector(5 + log2(w - 1) - 1 downto 0);

	--type virt_to_phys_table_type is
	--	array(integer range 0 to (2**(5 + log2(w - 1))) - 1)
	--		of phys_addr;

	type fp_dram_type is
		array(integer range 0 to ge_pow_of_2(nblargenb * n) - 1) of std_logic_ww;

	-- types for interface with Montgomery multipliers
	type mmi_rtype is record
		xy : std_logic_vector(ww - 1 downto 0);
		xen : std_logic;
		yen : std_logic;
		go : std_logic;
		zren : std_logic;
		irq_ack : std_logic;
	end record;

	type mmo_rtype is record
		rdy : std_logic;
		z : std_logic_vector(ww - 1 downto 0);
		irq : std_logic;
		go_ack : std_logic;
		xen_ack : std_logic;
		yen_ack : std_logic;
		zren_ack : std_logic;
	end record;

	type mmi_type is array(0 to nbmult - 1) of mmi_rtype;
	type mmo_type is array(0 to nbmult - 1) of mmo_rtype;

	function set_ndsp return positive;

	-- the following is used between ecc_axi & ecc_scalar to encode operations
	-- and does not need to be known by software
	--   point based operations encoding (used between ecc_axi & ecc_scalar)
	constant ECC_AXI_POINT_ADD : std_logic_vector(2 downto 0) := "000";
	constant ECC_AXI_POINT_DBL : std_logic_vector(2 downto 0) := "001";
	constant ECC_AXI_POINT_CHK : std_logic_vector(2 downto 0) := "010";
	constant ECC_AXI_POINT_NEG : std_logic_vector(2 downto 0) := "011";
	constant ECC_AXI_POINT_EQU : std_logic_vector(2 downto 0) := "100";
	constant ECC_AXI_POINT_OPP : std_logic_vector(2 downto 0) := "101";

	--   Fp arithmetic operations encoding (used between ecc_axi & ecc_scalar)
	constant ECC_AXI_FP_ADD : std_logic_vector(2 downto 0) := "000";
	constant ECC_AXI_FP_SUB : std_logic_vector(2 downto 0) := "001";
	constant ECC_AXI_FP_MUL : std_logic_vector(2 downto 0) := "010";
	constant ECC_AXI_FP_INV : std_logic_vector(2 downto 0) := "011";
	constant ECC_AXI_FP_INVEXP : std_logic_vector(2 downto 0) := "100";

	-- ---------------------------------------------------------------------------
	-- ECC_CURVE specifics
	-- ---------------------------------------------------------------------------
	constant PENDING_OPS_NBBITS : integer := 5;

	-- ---------------------------------------------------------------------------
	-- TRNG specifics
	-- ---------------------------------------------------------------------------

	-- raw_ram_size
	--
	-- this is the size of TRNG memory in which all raw random bits are buffered
	-- (this memory is only instanciated, and accessible for read, in debug mode,
	-- to allow for statistical analysis of the physical TRNG).
	constant raw_ram_size : natural := 32768; -- TODO: set something smarter

	-- pp_irn_width
	-- 
	-- this is the bus size of data driven out by the TRNG post-processing
	-- component, if any
	constant pp_irn_width : positive := 32;

	-- irn_fifo_size_axi
	--
	-- this is the size of TRNG internal random numbers served to AXI interface
	-- (for on-the-fly masking of the scalar)
	constant irn_fifo_size_axi : positive := 4 * 2 * n; -- ~256 bytes (nn=256)

	-- irn_fifo_size_fp
	--
	-- this is the size of TRNG internal random numbers served to ecc_fp (Fp ALU)
	-- (for implementation of the NNRND instruction)
	constant irn_fifo_size_fp : positive := ge_pow_of_2(4 * 6 * n); -- ~768 bytes (nn=256)

	-- irn_fifo_size_curve
	--
	-- this is the size of TRNG internal random numbers served to ecc_curve
	-- (for implementation of the shuffling of [XY]R[01] coordinates)
	constant irn_fifo_size_curve : positive := ge_pow_of_2(2 * nn * 32); -- 4 Kbytes (nn=256)

	-- irn_fifo_size_sh
	--
	-- this is the size of TRNG internal random numbers served to ecc_fp_dram_sh
	-- (for implementation of the large numbers memory shuffling)
	constant irn_fifo_size_sh : positive := ge_pow_of_2(32768 / (2 * (5 + log2(n) - 1)));

	-- ---------------------------------------------------------------------------
	-- AXI interface
	-- ---------------------------------------------------------------------------

	-- width of AXI address bus (nb of significant bits in address)
	constant AXIAW : integer := 8;

	-- software can rely on the following definitions for proper interaction
	-- ADB = number of most significant bits in the address bus that are used
	--       for decoding the access to the IP registers
	-- ADB = AXIAW - 3 on line just below means bits AXIAW - 2 downto 3
	constant ADB : natural := AXIAW - 3;

	-- a little ASCII art to illustrate how the IP decodes the AXI address
	-- bus (either read or write) to determine which register is accessed
	-- during an AXI transaction made by any AXI initiator (typically the
	-- CPU if the transaction was initiated by a software driver):
	--
	--                                          AXIAW = 8 bits
	--                                                ^
	--                                          ______|______
	--                                         /             \
	--  bit index on AXI address bus ->      8 7 6 5 4 3 2 1 0
	-- ... ---------------------------------------------------+
	--                                        |1 1 0 1 1 . . .|
	-- ... ---------------------------------------------------+
	--                                         \___ ___/ \_ _/
	--                                             |       |
	--                                             V       V
	--                               ADB = AXIAW - 3       the 3 LSbits
	--                           (only 5 bits of the       of AXI address bus
	--                           AXI address bus are       are not decoded by
	--                          sampled by the IP to       IPECC as registers
	--                              decode which reg       are aligned on
	--                                  is accessed)       8-byte addresses
	--                                         \______ ______/
	--                                                |
	--                                                V
	--                                     that numerical example
	--                                    (offset +0xd8 from base
	--                                    address of the IP in the
	--                                    system) matches register
	--                                   W_DBG_FP_RADDR (see below)
	--
	-- Note that address decoding is not the same depending on value of
	-- parameter 'debug' in ecc_customize.vhd:
	--
	--   if debug = TRUE:  the complete ADB (= 5) bits are decoded, allowing
	--                     software driver to access the complete bank of 32
	--                     registers
	--
	--   if debug = FALSE: only the lower subset of the bank made of the first
	--                     16 registers can be accessed by the software driver
	--
	-- Hence both in write & read spaces, the nominal (not debug) 16 registers
	-- (some of which are reserved) are mapped in address offset range +0x00 to
	-- +0x78, while the remaining 16 debug registers (some of which also are
	-- reserved) are mapped in address offset range +0x80 to +0xf8

	subtype rat is std_logic_vector(ADB - 1 downto 0);
	-- -----------------------------------------------
	-- addresses of all AXI-accessible write registers
	-- -----------------------------------------------
	constant W_CTRL : rat := std_nat(0, ADB);              -- 0x00
	constant W_WRITE_DATA : rat := std_nat(1, ADB);        -- 0x08
	constant W_R0_NULL : rat := std_nat(2, ADB);           -- 0x10
	constant W_R1_NULL : rat := std_nat(3, ADB);           -- 0x18
	constant W_PRIME_SIZE : rat := std_nat(4, ADB);        -- 0x20
	constant W_BLINDING : rat := std_nat(5, ADB);          -- 0x28
	constant W_SHUFFLE : rat := std_nat(6, ADB);           -- 0x30
	constant W_IRQ : rat := std_nat(7, ADB);               -- 0x38
	constant W_ERR_ACK : rat := std_nat(8, ADB);           -- 0x40
	constant W_SMALL_SCALAR : rat := std_nat(9, ADB);      -- 0x48
	constant W_SOFT_RESET : rat := std_nat(10, ADB);       -- 0x50
	-- reserved                                            -- 0x58...0x78
	-- (start of write DEBUG registers)
	constant W_DBG_HALT : rat := std_nat(16, ADB);         -- 0x80
	constant W_DBG_BKPT : rat := std_nat(17, ADB);         -- 0x88
	constant W_DBG_STEPS : rat := std_nat(18, ADB);        -- 0x90
	constant W_DBG_TRIG_ACT : rat := std_nat(19, ADB);     -- 0x98
	constant W_DBG_TRIG_UP : rat := std_nat(20, ADB);      -- 0xa0
	constant W_DBG_TRIG_DOWN : rat := std_nat(21, ADB);    -- 0xa8
	constant W_DBG_OP_ADDR : rat := std_nat(22, ADB);      -- 0xb0
	constant W_DBG_WR_OPCODE : rat := std_nat(23, ADB);    -- 0xb8
	constant W_DBG_TRNGCTR : rat := std_nat(24, ADB);      -- 0xc0
	constant W_DBG_TRNGCFG : rat := std_nat(25, ADB);      -- 0xc8
	constant W_DBG_FP_WADDR : rat := std_nat(26, ADB);     -- 0xd0
	constant W_DBG_FP_WDATA : rat := std_nat(27, ADB);     -- 0xd8
	constant W_DBG_FP_RADDR : rat := std_nat(28, ADB);     -- 0xe0
	constant W_DBG_CFG_NOXYSHUF : rat := std_nat(29, ADB); -- 0xe8
	-- ----------------------------------------------
	-- addresses of all AXI-accessible read registers
	-- ----------------------------------------------
	constant R_STATUS : rat := std_nat(0, ADB);              -- 0x00
	constant R_READ_DATA : rat := std_nat(1, ADB);           -- 0x08
	constant R_CAPABILITIES : rat := std_nat(2, ADB);        -- 0x10
	constant R_PRIME_SIZE : rat := std_nat(3, ADB);          -- 0x18
	constant R_HW_VERSION : rat := std_nat(4, ADB);          -- 0x20
	-- reserved                                              -- 0x28...0x78
	-- (start of read DEBUG registers)
	constant R_DBG_CAPABILITIES_0 : rat := std_nat(16, ADB); -- 0x80
	constant R_DBG_CAPABILITIES_1 : rat := std_nat(17, ADB); -- 0x88
	constant R_DBG_CAPABILITIES_2 : rat := std_nat(18, ADB); -- 0x90
	constant R_DBG_STATUS : rat := std_nat(19, ADB);         -- 0x98
	constant R_DBG_TIME : rat := std_nat(20, ADB);           -- 0xa0
	constant R_DBG_RAWDUR : rat := std_nat(21, ADB);         -- 0xa8
	constant R_DBG_FLAGS : rat := std_nat(22, ADB);          -- 0xb0
	constant R_DBG_RD_OPCODE : rat := std_nat(23, ADB);      -- 0xb8
	constant R_DBG_TRNG_STATUS : rat := std_nat(24, ADB);    -- 0xc0
	constant R_DBG_TRNG_DATA : rat := std_nat(25, ADB);      -- 0xc8
	constant R_DBG_FP_RDATA : rat := std_nat(26, ADB);       -- 0xd0
	constant R_DBG_IRN_CNT_AXI : rat := std_nat(27, ADB);    -- 0xd8
	constant R_DBG_IRN_CNT_EFP : rat := std_nat(28, ADB);    -- 0xe0
	constant R_DBG_IRN_CNT_CUR : rat := std_nat(29, ADB);    -- 0xe8
	constant R_DBG_IRN_CNT_SHF : rat := std_nat(30, ADB);    -- 0xf0
	constant R_DBG_FP_RDATA_RDY : rat := std_nat(31, ADB);   -- 0xf8

	-- bit positions in W_CTRL register
	constant CTRL_KP : natural := 0;
	constant CTRL_PT_ADD : natural := 1;
	constant CTRL_PT_DBL : natural := 2;
	constant CTRL_PT_CHK : natural := 3;
	constant CTRL_PT_NEG : natural := 4;
	constant CTRL_PT_EQU : natural := 5;
	constant CTRL_PT_OPP : natural := 6;
	constant CTRL_FP_ADD : natural := 7;
	constant CTRL_FP_SUB : natural := 8;
	constant CTRL_FP_MUL : natural := 9;
	constant CTRL_FP_INV : natural := 10;
	constant CTRL_FP_INVEXP : natural := 11;
	constant CTRL_WRITE_NB : natural := 16;
	constant CTRL_READ_NB : natural := 17;
	constant CTRL_WRITE_K : natural := 18;
	constant CTRL_NBADDR_LSB : natural := 20;
	constant CTRL_NBADDR_SZ : natural := 12;
	constant CTRL_NBADDR_MSB : natural := CTRL_NBADDR_LSB + CTRL_NBADDR_SZ - 1;

	-- bit positions in W_R0_NULL / W_R1_NULL registers
	constant WR0_IS_NULL : natural := 0;
	constant WR1_IS_NULL : natural := 0;

	-- bit positions in W_SHF register
	constant SHF_EN : natural := 0;

	-- bit positions in W_BLINDING register
	constant BLD_EN : natural := 0;
	constant BLD_BITS_LSB : natural := 4;
	constant BLD_BITS_MSB : natural := BLD_BITS_LSB + log2(nn) - 1;

	-- bit positions in W_IRQ register
	constant IRQ_EN : natural := 0;

	-- bit positions in W_PRIME_SIZE register
	constant PMSZ_VALNN_LSB : natural := 0;
	constant PMSZ_VALNN_SZ : natural := log2(nn);
	constant PMSZ_VALNN_MSB : natural := PMSZ_VALNN_LSB + PMSZ_VALNN_SZ - 1;

	-- bit positions in R_STATUS register (AXI interface w/ software)
	constant STATUS_BUSY : natural := 0;
	constant STATUS_KP : natural := 4;
	constant STATUS_MTY : natural := 5;
	constant STATUS_POP : natural := 6;
	constant STATUS_AOP : natural := 7;
	constant STATUS_R_OR_W : natural := 8;
	constant STATUS_INIT : natural := 9;
	constant STATUS_ENOUGH_RND : natural := 10;
	constant STATUS_NNDYNACT : natural := 11;
	constant STATUS_YES : natural := 13;
	constant STATUS_R0_IS_NULL : natural := 14;
	constant STATUS_R1_IS_NULL : natural := 15;
	constant STATUS_ERR_LSB : natural := 16;
	constant STATUS_ERR_COMP : natural := 16;
	constant STATUS_ERR_WREG_FBD : natural := 17;
	constant STATUS_ERR_KP_FBD : natural := 18;
	constant STATUS_ERR_NNDYN : natural := 19;
	constant STATUS_ERR_POP_FBD : natural := 20;
	constant STATUS_ERR_RDNB_FBD : natural := 21;
	constant STATUS_ERR_BLN : natural := 22;
	constant STATUS_ERR_UNKNOWN_REG : natural := 23;
	constant STATUS_ERR_IN_PT_NOT_ON_CURVE : natural := 24;
	constant STATUS_ERR_OUT_PT_NOT_ON_CURVE : natural := 25;
	constant STATUS_ERR_MSB : natural := 31;

	-- bit positions in R_CAPABILITIES register
	constant CAP_DBG_N_PROD : natural := 0;
	constant CAP_SHF : natural := 4;
	constant CAP_NNDYN : natural := 8;
	constant CAP_W64 : natural := 9;
	constant CAP_NNMAX_LSB : natural := 12;
	constant CAP_NNMAX_MSB : natural := CAP_NNMAX_LSB + log2(nn) - 1;

	-- bit flags in R_DBG_FLAGS register
	constant FLAGS_P_NOT_SET : natural := 0;
	constant FLAGS_P_NOT_SET_MTY : natural := 1;
	constant FLAGS_A_NOT_SET : natural := 2;
	constant FLAGS_A_NOT_SET_MTY : natural := 3;
	constant FLAGS_B_NOT_SET : natural := 4;
	constant FLAGS_K_NOT_SET : natural := 5;
	constant FLAGS_NNDYN_NOERR : natural := 6;
	constant FLAGS_NOT_BLN_OR_Q_NOT_SET : natural := 7;

	-- bit positions in W_DBG_TRNGCFG register
	constant DBG_TRNG_VONM : natural := 0;
	constant DBG_TRNG_TA_LSB : natural := 4;
	constant DBG_TRNG_TA_MSB : natural := 23;
	constant DBG_TRNG_IDLE_LSB : natural := 24;
	constant DBG_TRNG_IDLE_MSB : natural := 27;
	constant DBG_TRNG_COMPLETE_BYPASS : natural := 31;

	-- bit positions in W_DBG_TRNGCTR register
	constant DBG_TRNG_RAW_RESET : natural := 0;
	constant DBG_TRNG_IRN_RESET : natural := 1;
	constant DBG_TRNG_RAW_READ : natural := 4;
	constant DBG_TRNG_PP_DEACT : natural := 8;
	constant DBG_TRNG_RAW_ADDR_LSB : natural := 12;
	constant DBG_TRNG_RAW_ADDR_MSB : natural :=
		DBG_TRNG_RAW_ADDR_LSB + log2(raw_ram_size - 1) - 1;

	-- bit positions in W_DBG_HALT register
	constant DBG_HALT : natural := 0;

	-- bit positions in R_PRIME_SIZE
	--   (same definitions as for W_PRIME_SIZE register, see above)

end package ecc_pkg;

package body ecc_pkg is

	-- it doesn't make sense that the nb of DSP primitives in design is
	-- greater than 'w'
	function set_ndsp return positive is
		variable tmp : positive;
	begin
		assert (nbdsp > 1)
			report "minimal allowed value of nbdsp user parameter is 2"
				severity failure;
		if nbdsp > w then -- nbdsp is defined by user
			tmp := w;
		else
			tmp := nbdsp;
		end if;
		return tmp;
	end function set_ndsp;

end package body ecc_pkg;
