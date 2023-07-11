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
	-- large numbers in ecc_fp_dram (which are in qty nblargenb). Parameter
	-- FP_ADDR_MSB obviously has an effect on the size of opcode words in
	-- ecc_curve_iram, that's why modifying parameter nblargenb in
	-- ecc_customize.vhd should be made with caution (increasing nblargenb
	-- would increase FP_ADDR_MSB which in turn may have the opcode size
	-- exceed the current nominal size of 32 bit)
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
	constant IRAM_ADDR_SZ : positive := log2(nbopcodes - 1); -- 9

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
	constant CST_ADDR_TOKEN : stdop := std_nat(LARGE_NB_TOKEN_ADDR, FP_ADDR_MSB);

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
			wea : in std_logic;
			dia : in std_logic_vector(datawidth - 1 downto 0);
			-- port B (R only)
			addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			reb : in std_logic;
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
			wea : in std_logic;
			dia : in std_logic_vector(datawidth - 1 downto 0);
			-- port B (R only)
			clkb : in std_logic;
			addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			reb : in std_logic;
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

	function set_irn_width_sh return positive;

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

	-- ---------------------------------------------------------------------------
	-- AXI interface
	-- ---------------------------------------------------------------------------

	-- AXIAW
	-- width of AXI address bus (nb of significant bits in address,
	-- including the 3 bits 0..2 which are not actually decoded by the
	-- IP, as all of its registers are aligned on 8-byte boundaries)
	constant AXIAW : integer := 9;

	-- ADB
	-- same thing as AWIAW but without the 3 bits 0..2 not used in
	-- decoding.
	-- Defining ADB by AXIAW - 3 hence means that the bits of the AXI
	-- address bus actually used by the IP to decode access to its
	-- registers are the bits "AXIAW - 2 downto 3".
	constant ADB : natural := AXIAW - 3;

	-- Note: the alignment of registers on 8-byte boundaries is effective
	--       whatever the IP being being configured as a 32-bit AXI interface
	--       (this is the case when axi32or64 = 32 in ecc_customize.vhd)
	--       or as a 64-bit AXI interface (this is the case when axi32or64 = 64
	--       in ecc_customize.vhd)

	-- Below is a little ASCII art to illustrate how the IP decodes the AXI
	-- address bus (either read or write) to determine which register is
	-- accessed during an AXI transaction made by any AXI initiator (typical-
	-- ly the CPU if the transaction was initiated as the result of an ins-
	-- truction of the software driver):
	--
	--                                         AXIAW = 9 bits
	--                                               ^
	--                                        _______|_______
	--                                       /               \
	--  bit index on AXI address bus ->    9 8 7 6 5 4 3 2 1 0
	-- ... ---------------------------------------------------+
	--                                       1|0 1 0 1 1 . . .|  =  0x158
	-- ... ---------------------------------------------------+
	--                                       \____ ____/ \_ _/
	--                                            |        |
	--                                            V        V
	--                              ADB = AXIAW - 3        the 3 LSbits
	--                          (only 6 bits of the        of AXI address bus
	--                          AXI address bus are        are not decoded by
	--                         sampled by the IP to        IPECC as registers
	--                             decode which reg        are aligned on
	--                                 is accessed)        8-byte addresses
	--                                         \______ ______/
	--                                                |
	--                                                V
	--                                    numerical example above
	--                               (offset +0x158 from base address
	--                               of the IP in the system) matches
	--                               register W_DBG_FP_WDATA (search
	--                                this character string in file
	--                               ecc_software.vhd) in write-mode
	--                               and register R_DBG_IRN_CNT_AXI
	--                                        in read mode.
	--
	-- Note that address decoding is not the same depending on the value of
	-- parameter 'debug' in ecc_customize.vhd:
	--
	--   if debug = TRUE:  the complete ADB (= 6) bits are decoded, allowing
	--                     software driver to access the complete bank of 64
	--                     registers - both the nominal lower half, the one
	--                     with address offsets 0x000-0x0f8) and the debug
	--                     upper half, the one with address offsets 0x100-0x1f8 
	--
	--   if debug = FALSE: only the lower halt of the bank made of the first
	--                     32 registers can be accessed by the software driver
	--
	-- Hence both in write & read spaces, the nominal (i.e not debug)
	-- 32 registers, some of which are reserved, are mapped in address
	-- offset range +0x000 to +0x0f8, while the remaining 32 debug registers,
	-- some of which also are reserved, are mapped in address offset range
	-- +0x100 to +0x1f8

	subtype rat is std_logic_vector(ADB - 1 downto 0);

	function set_phys_addr_width return positive;

end package ecc_pkg;

package body ecc_pkg is

	-- It doesn't make sense that the nb of DSP primitives in design is
	-- greater than 'w'.
	function set_ndsp return positive is
		variable tmp : positive;
	begin
		assert (nbdsp > 1)
			report "minimal allowed value of nbdsp user parameter is 2"
				severity failure;
		if nbdsp > w then -- 'nbdsp' is defined by user
			tmp := w;
		else
			tmp := nbdsp;
		end if;
		return tmp;
	end function set_ndsp;

	function set_irn_width_sh return positive is
		variable tmp : positive;
	begin
		-- 'shuffle_type' is defined in package ecc_customize
		if shuffle_type = linear or shuffle_type = permute_limbs then
			tmp := FP_ADDR; -- defined in current package, see above
		elsif shuffle_type = permute_lgnb then
			tmp := log2(nblargenb - 1);
		end if;
		return tmp;
	end function set_irn_width_sh;

	function set_phys_addr_width return positive is
		variable tmp : positive;
	begin
		if shuffle_type /= none then
			if shuffle_type = permute_limbs then
				tmp := FP_ADDR;
			elsif shuffle_type = permute_lgnb then
				tmp := FP_ADDR_MSB;
			else -- means 'shuffle_type' = 'linear'
				tmp := FP_ADDR;
			end if;
		else -- 'shuffle_type' = 'none'
			-- not important in this case (we set an arbitrary value)
			tmp := FP_ADDR;
		end if;
		return tmp;
	end function set_phys_addr_width;

end package body ecc_pkg;
