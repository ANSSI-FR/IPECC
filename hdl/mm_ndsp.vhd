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

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

use work.ecc_customize.all;
use work.ecc_utils.all;
use work.ecc_pkg.all; -- for 'ww' & others
use work.mm_ndsp_pkg.all; -- for 'ndsp'

entity mm_ndsp is
	port(
		clkmm : in std_logic;
		clk : in std_logic;
		rstn : in std_logic;
		-- software reset
		swrst : in std_logic;
		go : in std_logic;
		rdy : out std_logic;
		-- input data
		xyin : in std_logic_vector(ww - 1 downto 0);
		xen : in std_logic;
		yen : in std_logic;
		fpwdata : in std_logic_vector(ww - 1 downto 0);
		fpwe : in std_logic;
		pen : in std_logic;
		ppen : in std_logic;
		-- signals used only when nn_dynamic = TRUE
		nndyn_mask : in std_logic_vector(ww - 1 downto 0);
		nndyn_shrcnt : in unsigned(log2(ww) - 1 downto 0);
		nndyn_shlcnt : in unsigned(log2(ww) - 1 downto 0);
		nndyn_w : in unsigned(log2(w) - 1 downto 0);
		nndyn_wm1 : in unsigned(log2(w - 1) - 1 downto 0);
		nndyn_wm2 : in unsigned(log2(w - 1) - 1 downto 0);
		nndyn_2wm1 : in unsigned(log2((2*w) - 1) - 1 downto 0);
		nndyn_wmin : in unsigned(log2((2*w) - 1) - 1 downto 0);
		nndyn_wmin_excp_val : in unsigned(log2(2*w - 1) - 1 downto 0);
		nndyn_wmin_excp : in std_logic;
		nndyn_mask_wm2 : in std_logic;
		-- output data
		z : out std_logic_vector(ww - 1 downto 0);
		zren : in std_logic;
		irq : out std_logic;
		go_ack : out std_logic;
		irq_ack : in std_logic
	);
end entity mm_ndsp;

architecture rtl of mm_ndsp is

	-- generic component for the DSP block chain
	component maccx is
		port(
			clk  : in std_logic;
			rst  : in std_logic;
			A    : in std_logic_vector(ww - 1 downto 0);
			B    : in std_logic_vector(ww - 1 downto 0);
			dspi : in maccx_array_in_type;
			P    : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0)
		);
	end component maccx;

	signal clk0 : std_logic;

	signal rst0, rst1, rst2 : std_logic;
	signal rst0mm, rst1mm, rst2mm : std_logic;
	signal rst22 : std_logic;

	-- -------------------------------------------------------------------------
	--     Illustration showing overview of operations, with definition of the
	--           terminology used in some comments of code thereinafter
	--                (notably "burst" & "cycle of multiply-&-acc")
	-- -------------------------------------------------------------------------
	-- note: the number of bursts (9 in the illustration example below, 3 per
	--       cycle of multiply-&-acc) is given here as an example, as it
	--       actually depends on the prime size nn (whether it is static or
	--       dynamically changeable by software - see parameter nn_dynamic
	--       in ecc_customize.vhd) and the number of DSP blocks available
	--       in the design (see parameter nbdsp in ecc_customize.vhd)
	-- -------------------------------------------------------------------------
	--
	--                               1 Montgomery
	--                              multiplication
	--                          (aka 1 REDC operation)
	--                                     V
	--  ___________________________________|___________________________________
	-- /                                                                       \
	--
	--                                 value of
	--  ____________________________ r.ctrl.state _____________________________
	-- /                               register                                \
	--
	--  _______________________ ________________________ ______________________
	-- |__________xy___________X___________sp___________X___________ap_________|
	--
	--
	--              9   b u r s t s   o f   o p e r a n d s - p u s h
	--           i n t o   t h e   c h a i n   o f   D S P   b l o c k s
	--
	--                                     ^
	--  ___________________________________|___________________________________
	-- /                                                                       \
	-- +-----+ +-----+ +-----+  +-----+ +-----+ +-----+  +-----+ +-----+ +-----+
	--
	-- `__ __' `__ __' `__ __'  `__ __' `__ __' `__ __'  `__ __' `__ __' `__ __'
	--    |       |       |        |       |       |        |       |       |
	--    V       V       V        V       V       V        V       V       V
	-- 1 burst 1 burst 1 burst  1 burst 1 burst 1 burst  1 burst 1 burst 1 burst
	-- `__________ __________'  `__________ __________'  `__________ __________'
	--            |                        |                        |
	--            V                        V                        V
	--         1 cycle                  1 cycle                 1 cycle
	--    of multiply-&-acc        of multiply-&-acc       of multiply-&-acc
	--      ( x_i x y_j )           ( s_i x p'_j )       ( s_i + alpha_i * p_j )
	--    made of 3 bursts         made of 3 bursts         made of 3 bursts
	--
	--      s_i  produced          alpha_i  produced         s_i  produced
	--
	-- `___________________________________ ___________________________________'
	--                                     |
	--                                     V
	--                               1 Montgomery
	--                              multiplication
	--                          (aka 1 REDC operation)


	-- numerical values in comments below show explicit value in the w = 16 case
	constant OPAGEW : positive := log2(w - 1); -- 4 bit
	
	-- the 3 in definition of OADDR_WIDTH below corresponds to the 7 regions
	-- (pages) inside ORAM memory
	constant OADDR_WIDTH : positive := 3 + OPAGEW; -- 7 bit
	constant X_ORAM_ADDR : std_logic_vector(2 downto 0) := "000"; -- 0x00
	constant Y_ORAM_ADDR : std_logic_vector(2 downto 0) := "001"; -- 0x10
	constant P_ORAM_ADDR : std_logic_vector(2 downto 0) := "010"; -- 0x20
	constant PP_ORAM_ADDR : std_logic_vector(2 downto 0) := "011"; -- 0x30
	constant S_ORAM_ADDR : std_logic_vector(2 downto 0) := "100"; -- 0x40
	constant ALPHA_ORAM_ADDR : std_logic_vector(2 downto 0) := "110"; -- 0x60
	constant PROD_ORAM_ADDR : std_logic_vector(2 downto 0) := "111"; -- 0x70

	-- PRAM is functionally divided in 2 parts of different size
	--  - one for s_k product-terms (k = 0 to 2w - 1)
	--  - one for alpha_i terms (i = 0 to w - 1)
	-- however to ensure power-of-2 alignment, we consider the biggest part
	-- (the s_k one) and double it to define the size of PRAM
	-- Therfore in the end PRAM is divided in 2 pages of size 2**(OPAGEW + 1)
	-- words (with each word of size ww-bit)
	constant PADDR_WIDTH : positive := 2 + OPAGEW; -- 6 bit

	-- constant NBRP designates the number of clock cycles that
	-- it takes from presenting read command to ORAM memory (or IRAM memory
	-- in the async = TRUE case) in order to get the first x_i (or s_i or
	-- alpha_i) operand term, and the time by which the first term accumulated
	-- through the chain of DSP blocks has reached register r.acc.ppacc
	-- see (s44) below
	constant NBRP : positive :=
	    sramlat + 1 -- ORAM read latency, incl. r.prod.rdata latch, see (s1)
	  + ndsp -- because ndsp x_i terms are first read before first y_j term
	  + 1 -- latch into r.prod.bb, see (s38)
	  + 1 -- latch into B register of first DSP block, see (s39)
	  + 2 -- latch into M & P register of first DSP block
	  + (ndsp - 1) -- accumulation through the chain of DSP blocks
	  + 1 -- latch into r.acc.ppend, see (s123) & (s34)
	  + 1; -- latch into r.acc.ppacc, see (s44)
		-- = sramlat + (2 * ndsp) + 6

	-- constant NBRA is the same as NBRP except that it extends to the clock
	-- cycle by which the first term accumulated through the chain of DSP
	-- blocks is written into PRAM memory (or TRAM memory, as these memories
	-- are written in parallel)
	constant NBRA : positive := NBRP + sramlat + 5;
		-- = (2 * sramlat) + (2 * ndsp) + 11

	-- constant NBRT is the same as NBRP & NBRA except that it extends to the
	-- clock cycle by which the first term accumulated through the chain of
	-- DSP blocks {THAT IS REQUIRED BEFORE THE NEXT MULTIPLY-&-ACC CYCLE CAN
	-- START} is written into PRAM memory (or TRAM memory, as these memories
	-- are written in parallel)
	constant NBRT : positive := NBRA + ndsp;
		-- = (2 * sramlat) + (3 * ndsp) + 11

	-- for bit-width of slkcnt counter
	constant NB_SLK_MAX : natural := NBRA + ndsp + w;
	constant NB_SLK_BITS : natural := log2(NB_SLK_MAX - 1);

	-- for "big slack" counter
	constant NB_BIGSLK_BITS : natural := log2(NBRT - 1);

	-- example values w/ sramlat = 2:
	--
	--     ndsp  |       NBRP      NBRA      NBRT
	--    -----------------------------------------
	--      2    |        12        19        21
	--      5    |        18        25        30
	--      6    |        20        27        33
	--     16    |        40        47        63

	-- registered signals to access ORAM memory (operands memory)
	type oram_reg_type is record
		-- registers connected to RAM ports
		wdata : std_logic_vector(ww - 1 downto 0);
		waddr_msb : std_logic_vector(2 downto 0); -- 8 pages
		waddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		we : std_logic;
		raddr_msb : std_logic_vector(2 downto 0); -- 8 pages
		raddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		re : std_logic;
		-- other control signals
		shifted : std_logic_vector(ww - 1 downto 0);
		prodburst : std_logic;
		wcnt : unsigned(log2(w) - 1 downto 0);
		prodburstend : std_logic;
	end record;

	-- registered signals to access IRAM memory (only used if async = TRUE)
	type iram_reg_type is record
		-- registers connected to RAM ports
		wdata : std_logic_vector(ww - 1 downto 0);
		waddr_msb : std_logic_vector(1 downto 0); -- 4 pages
		waddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		we : std_logic;
		raddr_msb : std_logic_vector(1 downto 0); -- 4 pages
		raddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		re : std_logic;
	end record;

	-- registered signals to access TRAM memory (only used if async = TRUE)
	type tram_reg_type is record
		-- registers connected to RAM ports
		wdata : std_logic_vector(ww - 1 downto 0);
		waddr_msb : std_logic_vector(1 downto 0); -- 4 pages
		waddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		we : std_logic;
		raddr_msb : std_logic_vector(1 downto 0); -- 4 pages
		raddr_lsb : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		re : std_logic;
	end record;

	-- registered signals to access ZRAM memory (only used if async = TRUE)
	type zram_reg_type is record
		-- registers connected to RAM ports
		wdata : std_logic_vector(ww - 1 downto 0);
		waddr : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		we : std_logic;
		raddr : std_logic_vector(OPAGEW - 1 downto 0); -- OPAGEW bits
		re : std_logic;
	end record;

	-- 2 x r_oram_[rw]addr signals below use all the dynamic of the address
	-- (i.e OADDR_WIDTH bits) in the async = FALSE case, and 1 bit less than
	-- that (i.e OADDR_WIDTH - 1 bits) in the async = TRUE case
	signal r_oram_waddr : std_logic_vector(OADDR_WIDTH - 1 downto 0);
	signal r_oram_raddr : std_logic_vector(OADDR_WIDTH - 1 downto 0);
	signal r_oram_rdata : std_logic_vector(ww - 1 downto 0);

	-- 3 x r_iram_ signals below are used only in async = TRUE case
	signal r_iram_waddr : std_logic_vector(OADDR_WIDTH - 2 downto 0);
	signal r_iram_raddr : std_logic_vector(OADDR_WIDTH - 2 downto 0);
	signal r_iram_rdata : std_logic_vector(ww - 1 downto 0);

	-- 3 x r_tram_ signals below are used only in async = TRUE case
	signal r_tram_waddr : std_logic_vector(OADDR_WIDTH - 2 downto 0);
	signal r_tram_raddr : std_logic_vector(OADDR_WIDTH - 2 downto 0);
	signal r_tram_rdata : std_logic_vector(ww - 1 downto 0);

	-- 3 x r_zram_ signals below are used only in async = TRUE case
	signal r_zram_waddr : std_logic_vector(OPAGEW - 1 downto 0);
	signal r_zram_raddr : std_logic_vector(OPAGEW - 1 downto 0);
	signal r_zram_rdata : std_logic_vector(ww - 1 downto 0);

	-- registered signals to access PRAM memory (product-terms)
	type pram_reg_type is record
		-- registers connected to RAM ports
		wdata : std_logic_vector(ww - 1 downto 0);
		waddr_msb : std_logic; -- 2 pages
		waddr_lsb : std_logic_vector(OPAGEW downto 0); -- OPAGEW + 1 bits
		we, wedel : std_logic;
		rdata : std_logic_vector(ww - 1 downto 0);
		raddr_msb : std_logic; -- 2 pages
		raddr_lsb : std_logic_vector(OPAGEW downto 0); -- OPAGEW + 1 bits
		re : std_logic;
		-- other control signals
		raddrweight : unsigned(WEIGHT_BITS - 1 downto 0);
		waddr_msb_sh : std_logic_vector(sramlat + 1 downto 0);
		wdataweight : unsigned(WEIGHT_BITS - 1 downto 0);
	end record;

	signal r_pram_waddr : std_logic_vector(PADDR_WIDTH - 1 downto 0);
	signal r_pram_raddr : std_logic_vector(PADDR_WIDTH - 1 downto 0);
	signal r_pram_rdata : std_logic_vector(ww - 1 downto 0);

	type state_type is (idle, xy, sp, ap);
	type prod_state_type is (idle, mult, slack);

	-- interconnect type for wiring of each DSP block of the DSP block chain
	type dsp_type is record
		ace : std_logic;
		bce : std_logic;
		acin : std_logic_vector(ww - 1 downto 0);
		acout : std_logic_vector(ww - 1 downto 0);
		bcin : std_logic_vector(ww - 1 downto 0);
		bcout : std_logic_vector(ww - 1 downto 0);
		p :     std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
		pcin :  std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
		pcout : std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
		rstm : std_logic;
		rstp : std_logic;
		pce : std_logic;
	end record;

	-- registered type for production of input operands to the chain of
	-- DSP blocks
	type prod_reg_type is record
		state : prod_state_type;
		xitoshcnt : std_logic_vector(sramlat downto 0);
		xicnt : unsigned(log2(ndsp - 1) - 1 downto 0);
		xicntzero : std_logic;
		xishen : std_logic;
		xishendel : std_logic;
		xishencnt : unsigned(log2(ndsp - 1) - 1 downto 0);
		xishencntzero : std_logic;
		xishencntzerokeep : std_logic;
		rdata : std_logic_vector(ww - 1 downto 0);
		aa : std_logic_vector(ww - 1 downto 0);
		yicnt : unsigned(log2(w - 1) - 1 downto 0);
		yicntzero : std_logic;
		yishen : std_logic;
		yishencnt : unsigned(log2(w - 1) - 1 downto 0);
		yishencntzero : std_logic;
		bb : std_logic_vector(ww - 1 downto 0);
		xiphase, yiphase : std_logic;
		xiphasesh : std_logic_vector(sramlat - 1 downto 0);
		xlsbpivotraddr : std_logic_vector(OPAGEW - 1 downto 0);
		dosavexlsbraddr : std_logic;
		nextxymsb : std_logic;
		slkcnt : unsigned(NB_SLK_BITS - 1 downto 0);
		slkcntzero : std_logic;
		nbx : unsigned(log2(w) - 1 downto 0);
		bigslkcnt : unsigned(NB_BIGSLK_BITS - 1 downto 0);
		bigslkcntzero : std_logic;
		bigslkcnten : std_logic;
		bigslkcntdone : std_logic;
		slkcntdone : std_logic;
	end record;

	-- registered type for control of the each DSP block in the DSP block chain
	type dsp_reg_type is record
		rstm, rstp, rstpdel : std_logic;
		rstmcnt : unsigned(log2(w - 1) - 1 downto 0); --  trimmed for r.dsp([01])
		rstmcntzero : std_logic; -- trimmed for r.dsp([01])
		ace, acedel : std_logic;
		acecnt : unsigned(log2(ndsp - 1) - 1 downto 0);
		acecntzero : std_logic;
		bce, bcedel : std_logic;
		pce, pcedel : std_logic;
		active : std_logic;
	end record;

	type dsp_reg_array_type is array(0 to ndsp - 1) of dsp_reg_type;

	type term_type is record
		valid : std_logic;
		weight : unsigned(WEIGHT_BITS - 1 downto 0);
		-- the size of .value field (ww + 1) is actually only used for the
		-- last term, that is register r.acc.term(sramlat + 1). For other
		-- terms (that is registers r.acc.term(i) for i = 0 to sramlat)
		-- the useful size is ww. For those synthesizer will trim the extra bit.
		value : unsigned(ww downto 0); -- ww + 1 bits
	end record;

	type term_array_type is array(0 to sramlat + 1) of term_type;

	-- registered signals for accumulation of product-terms after the
	-- chain of DSP blocks
	type acc_reg_type is record
		ppend : unsigned(2*ww + ln2(ndsp) - 1 downto 0);
		ppacc : unsigned(2*ww + ln2(ndsp) - 1 downto 0);
		ppaccrst, ppaccrstdel : std_logic;
		ppaccvalid, ppaccvalidprev : std_logic;
		ppaccvalcnt : unsigned(log2(w + ndsp + 1) - 1 downto 0);
		ppaccvalcntnext : unsigned(log2(w + ndsp + 1) - 1 downto 0);
		ppaccvalcntzero : std_logic;
		ppaccweight : unsigned(WEIGHT_BITS - 1 downto 0);
		ppaccweightnext : unsigned(WEIGHT_BITS - 1 downto 0);
		lastupperweight : unsigned(WEIGHT_BITS - 1 downto 0);
		ppaccbaseweight : unsigned(WEIGHT_BITS downto 0); -- size WEIGHT_BITS + 1
		nbx : unsigned(log2(w) - 1 downto 0);
		nextnbx : unsigned(log2(w) - 1 downto 0);
		term : term_array_type;
		mustread : std_logic;
		mustadd : std_logic_vector(sramlat downto 0);
		psum0 : unsigned(ww + 1 downto 0); -- ww + 2 bit
		psum0valid : std_logic;
		psum0weight : unsigned(WEIGHT_BITS - 1 downto 0);
		dorstpsum0 : std_logic;
		carry0 : unsigned(2 downto 0); -- 3 bit
		dorstcarry0 : std_logic;
		carry1 : unsigned(2 downto 0); -- 3 bit
		carry1valid : std_logic;
		carry1weight : unsigned(WEIGHT_BITS - 1 downto 0);
		carry1match : std_logic;
		dosavecarry1 : std_logic;
		rdlock : std_logic;
		state : state_type;
	end record;

	-- registered signals for everything related to input/output out/from mm_ndsp
	type io_reg_type is record
		xyin0, xyin1, xyin2, xyin : std_logic_vector(ww - 1 downto 0);
		xien, xien_prev : std_logic;
		yien, yien_prev : std_logic;
		pin : std_logic_vector(ww - 1 downto 0);
		pprimein : std_logic_vector(ww - 1 downto 0);
		pien : std_logic;
		piencnt : unsigned(log2(w - 1) - 1 downto 0);
		ppiencnt : unsigned(log2(w - 1) - 1 downto 0);
		ppien : std_logic;
		-- forbid_ signals below are only used in the async = TRUE case
		forbid_resync0, forbid_resync1, forbid_resync2, forbid : std_logic;
		zrendel : std_logic;
	end record;

	-- registered signals for everything related to input resynchronization
	-- (used only when async=TRUE, otherwise trimmed by synthesizer)
	type resync_reg_type is record
		go0, go1, go2, go2_del : std_logic;
		go_ack : std_logic;
		irq_ack0, irq_ack1, irq_ack2 : std_logic;
	end record;

	-- registered signals for global main control
	type ctrl_reg_type is record
		go : std_logic;
		-- handshake with external world
		rdy : std_logic;
		irq : std_logic;
		active : std_logic;
		state : state_type;
		ioforbid : std_logic;
	end record;

	-- registered signals for final output (result) barrel-shifter
	type barrel_shift_type is array(0 to log2(ww)-1) of unsigned(ww-1 downto 0);
	type brl_shaddr_type is array(0 to log2(ww)-1) of
	  std_logic_vector(OPAGEW - 1 downto 0);
	type barrel_reg_type is record
		shr : barrel_shift_type;
		shl : barrel_shift_type;
		right : unsigned(ww - 1 downto 0);
		sh_addr : brl_shaddr_type;
		sh_valid : std_logic_vector(log2(ww) - 1 downto 0);
		actcnt : unsigned(log2(w - 1) - 1 downto 0);
		active, activedel : std_logic;
		start : std_logic;
		startcnt : unsigned(log2(log2(ww) + 1) - 1 downto 0);
		armcnt : unsigned(log2(sramlat + 2) - 1 downto 0);
		armcnten : std_logic;
		armed : std_logic;
		shexcp : std_logic_vector(log2(ww) - 1 downto 0);
		enright : std_logic;
		armsh : std_logic_vector(log2(ww) - 2 downto 0);
	end record;

	-- -------------------------------
	-- registers for clk0 clock domain
	-- -------------------------------
	type reg_type is record
		-- inputs/outputs
		io : io_reg_type; -- only used in the async = FALSE (synchronous) case
		-- control signals
		ctrl : ctrl_reg_type;
		-- operands-RAM interface
		oram : oram_reg_type;
		-- production of input to the chain of DSP blocks
		prod : prod_reg_type;
		-- iram, tram & zram are only used when async = TRUE
		iram : iram_reg_type;
		tram : tram_reg_type;
		zram : zram_reg_type;
		-- control operation of the chain of DSP blocks
		dsp : dsp_reg_array_type;
		dsp0_bcedel2 : std_logic;
		-- accumulation of product-terms out of the chain of DSP blocks
		acc : acc_reg_type;
		-- product-terms-RAM interface
		pram : pram_reg_type;
		-- barrel-shifter for final result
		brl : barrel_reg_type;
		-- used only in async = TRUE
		resync : resync_reg_type;
		-- pragma translate_off
		-- there must be better an upper bound than w^2 for the total
		-- number of cycles (this is just for simulation anyway)
		simcnt : unsigned(log2(w*w - 1) - 1 downto 0);
		-- pragma translate_on	
	end record;

	signal r, rin : reg_type;
	signal rio : io_reg_type;
	signal riram : iram_reg_type;
	signal rzram : zram_reg_type;

	signal vcc, gnd : std_logic;

	signal dspi : maccx_array_in_type;
	signal dsp_p : std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);

	-- pragma translate_off
	subtype std_logic_ww is std_logic_vector(ww - 1 downto 0);
	signal r_ppacc_cry : unsigned(ww - 1 downto 0);
	signal r_ppacc_msb : unsigned(ww - 1 downto 0);
	signal r_ppacc_lsb : unsigned(ww - 1 downto 0);
	signal r_ppend_cry : unsigned(ww - 1 downto 0);
	signal r_ppend_msb : unsigned(ww - 1 downto 0);
	signal r_ppend_lsb : unsigned(ww - 1 downto 0);
	signal c_prod_nextnbx : unsigned(log2(w) - 1 downto 0);
	signal c_prod_nextxlsbraddr : std_logic_vector(OPAGEW - 1 downto 0);
	signal c_prod_nextxicnt : unsigned(log2(ndsp - 1) - 1 downto 0);
	signal c_prod_nextxicntzero : std_logic;
	signal c_prod_nextslkcnt : unsigned(NB_SLK_BITS - 1 downto 0);
	signal c_prod_tobenext : std_logic;
	signal c_prod_nextxmsbraddr : std_logic_vector(2 downto 0);
	signal c_prod_nextymsbraddr : std_logic_vector(2 downto 0);
	signal c_acc_tobenext : std_logic;
	signal c_acc_ndspactive : unsigned(log2(ndsp) - 1 downto 0);
	-- pragma translate_on

begin

	-- (s101) see (s0) in maccx_series7.vhd
	assert((techno /= series7) or (2*ww + ln2(ndsp) <= get_dsp_maxacc))
		report "mm_ndsp.vhd: too many chained multiply-&-acc blocks (aka "
		     & "'DSP blocks), available accumulation dynamic will overflow "
		     & "(w = " & integer'image(ww) & ", ndsp = " & integer'image(ww)
		     & ", get_dsp_maxacc() = " & integer'image(get_dsp_maxacc) & ")"
			severity FAILURE;

	-- (s108) see (s104) & (s105)
	assert(ln2(ndsp) <= ww)
		report "mm_ndsp.vhd: too many multiply-&-acc blocks (aka 'DSP blocks)"
			severity FAILURE;

	-- (s125), see (s124)
	assert(ndsp >= 2)
		report "mm_ndsp.vhd: ndsp = 1 is not supported"
			severity FAILURE;

	-- (s98) see (s99) & (s100)
	assert (log2(ww) > 1)
		report "mm_ndsp.vhd: requires that ww > 1"
			severity FAILURE;

	assert(w >= 2)
		report "mm_ndsp.vhd: w < 2 is not supported (nn value being equal, "
		     & "you may decrease value of ww to increase value of w)"
			severity FAILURE;

	tt0: if async generate
		-- ----------------------
		-- IRAM R-&-W address bus (only in the async = TRUE case)
		-- ----------------------
		-- r_iram_waddr is in the clk clock domain (for WR access by ecc_fp)
		r_iram_waddr <= riram.waddr_msb & riram.waddr_lsb; -- 2 + OPAGEW
		-- r_iram_raddr is in the clk0 clock domain
		r_iram_raddr <= r.iram.raddr_msb & r.iram.raddr_lsb; -- 2 + OPAGEW

		-- ----------------------
		-- TRAM R-&-W address bus (only in the async = TRUE case)
		-- ----------------------
		r_tram_waddr <= r.tram.waddr_msb & r.tram.waddr_lsb; -- 2 + OPAGEW
		r_tram_raddr <= r.tram.raddr_msb & r.tram.raddr_lsb; -- 2 + OPAGEW

		-- ----------------------
		-- ZRAM R-&-W address bus (only in the async = TRUE case)
		-- ----------------------
		-- r_zram_waddr is in the clk0 clock domain
		r_zram_waddr <= r.zram.waddr; -- OPAGEW
		-- r_zram_raddr is in the clk clock domain (for RD access from ecc_fp)
		r_zram_raddr <= rzram.raddr; -- OPAGEW
	end generate;

	tt1: if not async generate
		-- ----------------------
		-- ORAM R-&-W address bus
		-- ----------------------
		--   (in the async = FALSE case, all 3 + OPAGEW bits of r_oram_[rw]addr
		--    signals are used, and only 2 + OPAGEW in the async = TRUE case)
		r_oram_waddr <= r.oram.waddr_msb & r.oram.waddr_lsb; -- 3 + OPAGEW
		r_oram_raddr <= r.oram.raddr_msb & r.oram.raddr_lsb; -- 3 + OPAGEW
	end generate;

	-- ----------------------
	-- PRAM R-&-W address bus
	-- ----------------------
	r_pram_waddr <= r.pram.waddr_msb & r.pram.waddr_lsb; -- 1 + (PRAM_WIDTH - 1)
	r_pram_raddr <= r.pram.raddr_msb & r.pram.raddr_lsb; -- 1 + (PRAM_WIDTH - 1)

	-- --------------
	-- clocks & reset
	-- --------------

	c00: if async generate
		clk0 <= clkmm;
	end generate;

	c01: if not async generate
		clk0 <= clk;
	end generate;

	vcc <= '1';
	gnd <= '0';

	-- One instance of the DSP block chain
	d0: maccx
		port map(
			clk => clk0,
			rst => rst22,
			A => r.prod.aa,
			B => r.prod.bb, -- (s39)
			dspi => dspi,
			P => dsp_p); -- (s123)

	-- DSP block #0 connections
	dspi(0).rstm <= gnd; --r.dsp(0).rstm;
	dspi(0).rstp <= r.dsp(0).rstp;
	dspi(0).ace <= r.dsp(0).ace;
	dspi(0).bce <= r.dsp(0).bce;
	dspi(0).pce <= r.dsp(0).pce;

	-- connections for other DSP blocks (1 to ndsp - 1)
	d2: for i in 1 to ndsp - 1 generate
		dspi(i).rstm <= r.dsp(i).rstm;
		dspi(i).rstp <= r.dsp(i).rstp;
		dspi(i).ace <= r.dsp(i).ace;
		dspi(i).bce <= r.dsp(i).bce;
		dspi(i).pce <= r.dsp(i).pce;
	end generate;

	-- rstn is assumed to be asynchronous to clk0, so we must
	-- resynchronize it before feeding it to clk0-driven logic
	process(clk0)
	begin
		if clk0'event and clk0 = '1' then
			rst0mm <= (not rstn) or swrst;
			rst1mm <= rst0mm;
			rst2mm  <= rst1mm;
		end if;
	end process;

	-- rstn is assumed to be asynchronous to clk, so we must
	-- resynchronize it before feeding it to clk-driven logic
	process(clk)
	begin
		if clk'event and clk = '1' then
			rst0 <= (not rstn) or swrst;
			rst1 <= rst0;
			rst2  <= rst1;
		end if;
	end process;

	r0: if async generate
		rst22 <= rst2mm;
	end generate;

	r1: if not async generate
		rst22 <= rst2;
	end generate;

	-- in the ASYNChronous case, input terms, intermediate terms and result
	-- (output) terms are separated:
	--   - input terms are buffered into IRAM memory, with:
	--       - the WR port synchronous to clk (for write by ecc_fp)
	--       - the RD port synchronous to clkmm (= clk0)
	--     see (s111)
	--   - intermediate terms are buffered into TRAM memory, with:
	--       - both WR & RD ports synchronous to clkmm (= clk0)
	--     see (s112)
	--   - output terms are buffered into ZRAM memory, with:
	--       - the WR port synchronous to clkmm (= clk0)
	--       - the RD port synchronous to clk (for read by ecc_fp)
	--     see (s113)
	rm0: if async generate
		-- -------------
		-- "IRAM" memory ("input-terms" memory)
		-- -------------
		im00: sync2ram_sdp -- (s111)
			generic map(
				rdlat => sramlat, datawidth => ww, datadepth => 2**(OADDR_WIDTH-1))
			port map(
				-- port A (W only)
				clka => clk,
				addra => r_iram_waddr,
				wea => riram.we,
				ena => vcc,
				dia => riram.wdata,
				-- port B (R only)
				clkb => clk0,
				addrb => r_iram_raddr,
				enb => r.iram.re,
				dob => r_iram_rdata -- directly latched into r.prod.rdata, see (s1)
			);
		-- -------------
		-- "TRAM" memory ("intermediate-terms" memory)
		-- -------------
		tm00: syncram_sdp -- (s112)
			generic map(
				rdlat => sramlat, datawidth => ww, datadepth => 2**(OADDR_WIDTH-1))
			port map(
				clk => clk0,
				-- port A (W only)
				addra => r_tram_waddr,
				wea => r.tram.we,
				ena => vcc,
				dia => r.tram.wdata,
				-- port B (R only)
				addrb => r_tram_raddr,
				enb => r.tram.re,
				dob => r_tram_rdata -- directly latched into r.prod.rdata, see (s1)
			);
		-- -------------
		-- "ZRAM" memory ("final result" memory)
		-- -------------
		zm00: sync2ram_sdp -- (s113)
			generic map(
				rdlat => sramlat, datawidth => ww, datadepth => 2**OPAGEW)
			port map(
				-- port A (W only)
				clka => clk0,
				addra => r_zram_waddr,
				wea => r.zram.we,
				ena => vcc,
				dia => r.zram.wdata,
				-- port B (R only)
				clkb => clk,
				addrb => r_zram_raddr,
				enb => rzram.re,
				dob => r_zram_rdata
			);
	end generate;

	-- in the synchronous case, input terms, intermediate terms & result
	-- (output) terms are gathered in the same memory array (ORAM)
	rm1: if not async generate
		-- -------------
		-- "ORAM" memory ("operand-terms" memory)
		-- -------------
		om0: syncram_sdp
			generic map(
				rdlat => sramlat, datawidth => ww, datadepth => 2**OADDR_WIDTH)
			port map(
				clk => clk0,
				-- port A (W only)
				addra => r_oram_waddr,
				wea => r.oram.we,
				ena => vcc,
				dia => r.oram.wdata,
				-- port B (R only)
				addrb => r_oram_raddr,
				enb => r.oram.re,
				dob => r_oram_rdata -- directly latched into r.prod.rdata, see (s1)
			);
	end generate;

	-- -------------
	-- "PRAM" memory ("product-terms" memory)
	-- -------------
	-- present both in the synchronous & ASYNChronous cases
	pm0: syncram_sdp
		generic map(
			rdlat => sramlat, datawidth => ww, datadepth => 2*2*n)
		port map(
			clk => clk0,
			-- port A (W only)
			addra => r_pram_waddr,
			wea => r.pram.we,
			ena => vcc, -- r.pram.we, TODO: replace with true enable STABLE signal!
			dia => r.pram.wdata,
			-- port B (R only)
			addrb => r_pram_raddr,
			enb => r.pram.re, --TODO: replace with true enable STABLE signal!
			dob => r_pram_rdata
		);

	-- -----------------------------------------------------------------
	--            'clk' clock-domain RTL logic (I/O interface)
	--        (only in the async = TRUE case, because in this case
	--        I/O access is made by ecc_fp in its own clock-domain,
	--      which is the 'clk' domain, hence our logic interfacing w/
	--          it and accessing IRAM (for inputs) or ZRAM (for
	--      outputs) can't be but in the same clock-domain as clkmm)
	-- -----------------------------------------------------------------
	io0: if async generate
		iortl: process(clk)
		begin
			if clk'event and clk = '1' then
				if rstn = '0' or swrst = '1' then
					rio.xien <= '0';
					rio.yien <= '0';
					rio.pien <= '0';
					rio.ppien <= '0';
					rio.xien_prev <= '0';
					rio.yien_prev <= '0';
					rio.piencnt <= (others => '0');
					rio.ppiencnt <= (others => '0');
					rzram.re <= '0';
				else
					-- ----------------
					-- X & Y data input
					-- ----------------
					rio.xyin <= xyin;
					-- input of x_i terms
					rio.xien <= xen;
					-- input of y_i terms
					rio.yien <= yen;
					-- ----------------------
					-- P (prime number) input
					-- ----------------------
					-- input of p_i terms
					if pen = '1' then
						rio.pin <= fpwdata;
						if fpwe = '1' then
							rio.pien <= '1';
						else
							rio.pien <= '0';
						end if;
					else
						rio.pien <= '0';
					end if;
					-- ------------------------------
					-- P' (Montgomery constant) input
					-- ------------------------------
					-- input of p'_i terms
					if ppen = '1' then
						rio.pprimein <= fpwdata;
						if fpwe = '1' then
							rio.ppien <= '1';
						else
							rio.ppien <= '0';
						end if;
					else
						rio.ppien <= '0';
					end if;
					rio.forbid_resync0 <= r.ctrl.ioforbid;
					rio.forbid_resync1 <= rio.forbid_resync0;
					rio.forbid_resync2 <= rio.forbid_resync1;
					rio.forbid <= rio.forbid_resync2;
					rio.xien_prev <= rio.xien;
					rio.yien_prev <= rio.yien;
					-- --------------------------------------------------------
					-- transfer of X, Y, P & P' input operands into IRAM memory
					-- --------------------------------------------------------
					if rio.forbid = '0' then
						-- generation of write enable into IRAM memory
						riram.we <= rio.xien or rio.yien or rio.pien or rio.ppien;
						-- generation of write address into IRAM memory & its increment
						if rio.xien = '1' then
							if rio.xien_prev = '0' then
								riram.waddr_msb <= X_ORAM_ADDR(1 downto 0);
								riram.waddr_lsb <= (others => '0');
							else
								riram.waddr_lsb <=
									std_logic_vector(unsigned(riram.waddr_lsb) + 1);
							end if;
						elsif rio.yien = '1' then
							if rio.yien_prev = '0' then
								riram.waddr_msb <= Y_ORAM_ADDR(1 downto 0);
								riram.waddr_lsb <= (others => '0');
							else
								riram.waddr_lsb <=
									std_logic_vector(unsigned(riram.waddr_lsb) + 1);
							end if;
						elsif rio.pien = '1' then
							riram.waddr_lsb <=
								std_logic_vector(unsigned(riram.waddr_lsb) + 1);
							rio.piencnt <= rio.piencnt + 1;
							if rio.piencnt = (rio.piencnt'range => '0') then
								riram.waddr_msb <= P_ORAM_ADDR(1 downto 0);
								riram.waddr_lsb <= (others => '0');
							elsif rio.piencnt = nndyn_wm1 then
								rio.piencnt <= (others => '0');
							end if;
						elsif rio.ppien = '1' then
							riram.waddr_lsb <=
								std_logic_vector(unsigned(riram.waddr_lsb) + 1);
							rio.ppiencnt <= rio.ppiencnt + 1;
							if rio.ppiencnt = (rio.ppiencnt'range => '0') then
								riram.waddr_msb <= PP_ORAM_ADDR(1 downto 0);
								riram.waddr_lsb <= (others => '0');
							elsif rio.ppiencnt = nndyn_wm1 then
								rio.ppiencnt <= (others => '0');
							end if;
						end if;
						-- generation of write data into IRAM memory
						if rio.xien = '1' or rio.yien = '1' then
							riram.wdata <= rio.xyin;
						elsif rio.pien = '1' then
							riram.wdata <= rio.pin;
						elsif rio.ppien = '1' then
							riram.wdata <= rio.pprimein;
						end if;
					else -- rio.forbid
						riram.we <= '0';
					end if;
					-- --------------------------------------------------------
					-- transfer of Z output operands (result of multiplication)
					-- from ZRAM memory
					-- --------------------------------------------------------
					rzram.re <= zren;
					if zren = '1' then
						if rzram.re = '0' then
							rzram.raddr <= (others => '0');
						elsif rzram.re = '1' then
							rzram.raddr <= std_logic_vector(unsigned(rzram.raddr) + 1);
						end if;
					end if;
				end if; -- rstn
			end if; -- clk
		end process iortl;
	end generate;

	-- -----------------------------------------------------------------
	--          combinational process (clk0 clock-domain)
	-- -----------------------------------------------------------------
	comb : process(r, rst22, go,
	               xyin, xen, yen, ppen, fpwdata, fpwe, pen, zren,
	               irq_ack, r_oram_rdata, r_tram_rdata, r_iram_rdata,
	               r_pram_rdata, dsp_p,
	               nndyn_mask, nndyn_shrcnt, nndyn_shlcnt, nndyn_w, nndyn_wm1,
	               nndyn_wm2, nndyn_2wm1, nndyn_wmin, nndyn_mask_wm2,
	               nndyn_wmin_excp_val, nndyn_wmin_excp)
		variable v : reg_type;
		variable vtmp_0, vtmp_1, vtmp_2 : signed(log2(w) downto 0);
		variable vtmp_3 : unsigned(log2(w) - 1 downto 0);
		variable vtmp_7, vtmp_8, vtmp_9 : signed(log2(w) downto 0);
		variable vtmp_10 : unsigned(WEIGHT_BITS downto 0);
		variable vtmp_11 : unsigned(ww + 2 downto 0); -- ww + 3 bit
		variable v_acc_ndspactive : unsigned(log2(ndsp) - 1 downto 0);
		variable vap : std_logic;
		variable v_prod_nextnbx : unsigned(log2(w) - 1 downto 0);
		variable v_prod_nextxlsbraddr : std_logic_vector(OPAGEW - 1 downto 0);
		variable v_prod_nextxicnt : unsigned(log2(ndsp - 1) - 1 downto 0);
		variable v_prod_nextxicntzero : std_logic;
		variable v_prod_nextslkcnt : unsigned(NB_SLK_BITS - 1 downto 0);
		variable v_prod_tobenext : std_logic;
		variable v_acc_tobenext : std_logic;
		variable v_prod_nextxmsbraddr : std_logic_vector(2 downto 0);
		variable v_prod_nextymsbraddr : std_logic_vector(2 downto 0);
	begin
		-- to ensure that 'comb' process is purely combinational
		v := r;

		-- (s1)
		-- generation of r.prod.rdata
		if async then -- statically resolved by synthesizer
			if sramlat > 2 then -- statically resolved by synthesizer
				v.prod.xiphasesh :=
					r.prod.xiphase & r.prod.xiphasesh(sramlat - 1 downto 1);
			elsif sramlat = 2 then
				v.prod.xiphasesh :=
					r.prod.xiphase & r.prod.xiphasesh(sramlat - 1);
			elsif sramlat = 1 then
				v.prod.xiphasesh(0) := r.prod.xiphase;
			end if;
			-- selective latch of r_iram_rdata/r_tram_rdata into r.prod.rdata
			if r.ctrl.state = xy then
				v.prod.rdata := r_iram_rdata;
			elsif (r.ctrl.state = sp) or (r.ctrl.state = ap) then
				if r.prod.xiphasesh(0) = '1' then
					-- so that s_ij terms (when .state = sp) or alpha_i terms
					-- (when .state = ap) are selected
					v.prod.rdata := r_tram_rdata;
				elsif r.prod.xiphasesh(0) = '0' then
					-- so that p'_i terms (when .state = sp) or p_i terms
					-- (when .state = ap) are selected
					v.prod.rdata := r_iram_rdata;
				end if;
			end if;
		else -- not async
			-- in the synchronous case, all terms fed to the DSP blocks chain
			-- are latched from ORAM common memory
			v.prod.rdata := r_oram_rdata;
		end if;

		-- resynchronization registers
		-- surrounding these statements with 'if async' condition is just for
		-- sake of readability (in case async = FALSE, they would be trimmed
		-- by synthesizer anyway)
		if async then
			v.resync.go0 := go;
			v.resync.go1 := r.resync.go0;
			v.resync.go2 := r.resync.go1;
			v.resync.irq_ack0 := irq_ack;
			v.resync.irq_ack1 := r.resync.irq_ack0;
			v.resync.irq_ack2 := r.resync.irq_ack1;
		end if;

		-- --------------------------------------------------------------------
		--                          I / O operations
		-- --------------------------------------------------------------------

		if not async then -- statically resolved by synthesizer

			-- synchronous case

			-- ----------------
			-- X & Y data input
			-- ----------------
			v.io.xyin := xyin;
			v.io.xien_prev := r.io.xien;
			v.io.yien_prev := r.io.yien;
			if r.ctrl.state = idle then
				v.io.xien := xen;
				v.io.yien := yen;
			end if;
			-- ----------------------
			-- P (prime number) input
			-- ----------------------
			v.io.pien := '0';
			if pen = '1' then
				v.io.pin := fpwdata;
				if fpwe = '1' then
					v.io.pien := '1';
				end if;
			end if;
			-- ------------------------------
			-- P' (Montgomery constant) input
			-- ------------------------------
			v.io.ppien := '0';
			if ppen = '1' then
				v.io.pprimein := fpwdata;
				if fpwe = '1' then
					v.io.ppien := '1';
				end if;
			end if;

		end if; -- async

		-- --------------------------------------------------------
		-- transfer of X, Y, P & P' input operands into ORAM memory
		-- --------------------------------------------------------

		if async then -- statically resolved by synthesizer

			if r.ctrl.state = idle and r.oram.prodburst = '0' then
				v.ctrl.ioforbid := '0'; -- I/O access allowed
			else
				v.ctrl.ioforbid := '1'; -- I/O access forbidden
			end if;

		else -- synchronous case

			if r.ctrl.state = idle and r.oram.prodburst = '0' then
				-- generation of write enable (s119), see also (s120)
				v.oram.we := r.io.xien or r.io.yien or r.io.pien or r.io.ppien;
				-- generation of write address & its increment
				if r.io.xien = '1' then
					if r.io.xien_prev = '0' then
						v.oram.waddr_msb := X_ORAM_ADDR;
						v.oram.waddr_lsb := (others => '0');
					else
						v.oram.waddr_lsb :=
							std_logic_vector(unsigned(r.oram.waddr_lsb) + 1);
					end if;
				elsif r.io.yien = '1' then
					if r.io.yien_prev = '0' then
						v.oram.waddr_msb := Y_ORAM_ADDR;
						v.oram.waddr_lsb := (others => '0');
					else
						v.oram.waddr_lsb :=
							std_logic_vector(unsigned(r.oram.waddr_lsb) + 1);
					end if;
				elsif r.io.pien = '1' then
					v.oram.waddr_lsb :=
						std_logic_vector(unsigned(r.oram.waddr_lsb) + 1);
					v.io.piencnt := r.io.piencnt + 1;
					if r.io.piencnt = (r.io.piencnt'range => '0') then
						v.oram.waddr_msb := P_ORAM_ADDR;
						v.oram.waddr_lsb := (others => '0');
					elsif r.io.piencnt = nndyn_wm1 then
						v.io.piencnt := (others => '0');
					end if;
				elsif r.io.ppien = '1' then
					v.oram.waddr_lsb :=
						std_logic_vector(unsigned(r.oram.waddr_lsb) + 1);
					v.io.ppiencnt := r.io.ppiencnt + 1;
					if r.io.ppiencnt = (r.io.ppiencnt'range => '0') then
						v.oram.waddr_msb := PP_ORAM_ADDR;
						v.oram.waddr_lsb := (others => '0');
					elsif r.io.ppiencnt = nndyn_wm1 then
						v.io.ppiencnt := (others => '0');
					end if;
				end if;
				-- generation of write data
				if r.io.xien = '1' or r.io.yien = '1' then
					v.oram.wdata := r.io.xyin;
				elsif r.io.pien = '1' then
					v.oram.wdata := r.io.pin;
				elsif r.io.ppien = '1' then
					v.oram.wdata := r.io.pprimein;
				end if;
			end if;

		end if; -- async

		-- ----------------------------
		-- multiplication result output
		-- ----------------------------

		if not async then -- statically resolved by synthesizer
			v.ctrl.irq := '0';
		end if;

		-- used only in asynchronous case
		if async and r.ctrl.irq = '1' and r.resync.irq_ack2 = '1' then
			v.ctrl.irq := '0';
		end if;
		-- (end of: used only in asynchronous case)
	
		-- --------------------------------------------------------------------
		--                  s t a r t   o f   o p e r a t i o n s
		-- --------------------------------------------------------------------

		-- pragma translate_off
		if r.ctrl.active = '1' then
			v.simcnt := r.simcnt + 1;
		else
			v.simcnt := (others => 'X');
		end if;
		-- pragma translate_on	

		if async then -- statically resolved by synthesizer
			v.ctrl.go := r.resync.go2;
			v.resync.go2_del := r.resync.go2;
		else
			v.ctrl.go := go;
		end if;

		v.prod.xitoshcnt := '0' & r.prod.xitoshcnt(sramlat downto 1); -- (s2)
		v.prod.dosavexlsbraddr := '0'; -- (s6)
		v.prod.yishencntzero := '0'; -- (s10)

		if r.prod.dosavexlsbraddr = '1' then
			-- TODO: set a multicycle on path:
			-- r.ctrl.state -> r.prod.xlsbpivotraddr + see also (s84)
			if async then -- statically resolved by synthesizer
				if r.ctrl.state = xy then
					v.prod.xlsbpivotraddr := r.iram.raddr_lsb; -- x_i terms
				else
					v.prod.xlsbpivotraddr := r.tram.raddr_lsb; -- s_i or alpha_i terms
				end if;
			else -- synchronous case
				-- (s82) is bypassed by (s84)
				v.prod.xlsbpivotraddr := r.oram.raddr_lsb; -- (s82), see (s83)
			end if;
		end if;

		-- deassertion of r.resync.go_ack
		if r.resync.go_ack = '1' and r.ctrl.go = '0' then
			v.resync.go_ack := '0';
		end if;

		-- xi & yi operand counters
		v.prod.xicntzero := '0';
		if r.prod.xicnt = to_unsigned(1, log2(ndsp - 1)) and r.prod.xiphase = '1'
		then
			v.prod.xicntzero := '1';
		end if;
		v.prod.yicntzero := '0';
		if r.prod.yicnt = to_unsigned(1, log2(w - 1)) and r.prod.yiphase = '1'
		then
			v.prod.yicntzero := '1';
		end if;

		if async then -- statically resolved by synthesizer
			if r.prod.xiphase = '1' then
				v.prod.xicnt := r.prod.xicnt - 1;
				if r.ctrl.state = xy then
					v.iram.raddr_lsb := std_logic_vector(
						unsigned(r.iram.raddr_lsb) - 1 );
				else
					v.tram.raddr_lsb := std_logic_vector(
						unsigned(r.tram.raddr_lsb) - 1 );
				end if;
			end if;
			if r.prod.yiphase = '1' then
				v.prod.yicnt := r.prod.yicnt - 1;
				v.iram.raddr_lsb := std_logic_vector (
					unsigned(r.iram.raddr_lsb) + 1 );
			end if;
		else -- synchronous case
			if r.prod.xiphase = '1' then
				v.prod.xicnt := r.prod.xicnt - 1;
				v.oram.raddr_lsb := std_logic_vector(
					unsigned(r.oram.raddr_lsb) - 1 );
			end if;
			if r.prod.yiphase = '1' then
				v.prod.yicnt := r.prod.yicnt - 1;
				v.oram.raddr_lsb := std_logic_vector (
					unsigned(r.oram.raddr_lsb) + 1 );
			end if;
		end if;

		-- --------------------------------------------------------------------
		-- production of operands to serve as inputs to the chain of DSP blocks
		-- --------------------------------------------------------------------

		v.prod.slkcntzero := '0';
		if r.prod.slkcnt = to_unsigned(1, r.prod.slkcnt'length) then
			v.prod.slkcntzero := '1'; -- stays asserted only 1 cycle
		end if;

		if r.prod.state = slack then
			v.prod.slkcnt := r.prod.slkcnt - 1;
		end if;

		-- 1st phase: shift of A input to DSP blocks (xishen = 1)
		if r.prod.xitoshcnt(0) = '1' then
			v.prod.xishen := '1';
			v.prod.xishencntzero := r.prod.xishencntzerokeep;
		end if;

		if r.prod.xishen = '1' then
			v.prod.xishencnt := r.prod.xishencnt - 1;
			-- shift of operand A throughout the chain of DSP blocks
			v.prod.aa := r.prod.rdata;
		end if;

		if r.prod.xishencnt = to_unsigned(1, log2(ndsp - 1))
		  and r.prod.xishen = '1'
		then
			v.prod.xishencntzero := '1';
		end if;

		if r.prod.xishencntzero = '1' and r.prod.xishen = '1' then
			v.prod.xishencntzero := '0';
			v.prod.xishen := '0';
			v.prod.yishen := '1';
			v.prod.yishencnt := nndyn_wm1;
			if nndyn_wm1 = (nndyn_wm1'range => '0') then -- means nndyn_w = 1
				v.prod.yishencntzero := '1'; -- 'll have effect on (s11) next cycle
			end if;
		end if;

		-- 2nd phase: shift of B input to DSP blocks (yishen = 1)
		if r.prod.yishen = '1' then
			v.prod.yishencnt := r.prod.yishencnt - 1;
			-- shift of operand B throughout the chain of DSP blocks
			v.prod.bb := r.prod.rdata; -- (s38)
		end if;

		if r.prod.yishencnt = to_unsigned(1, log2(w - 1))
			and r.prod.yishen = '1'
		then
			v.prod.yishencntzero := '1'; -- stays asserted only 1 cycle thx to (s10)
		end if;

		if r.prod.yishencntzero = '1' and r.prod.yishen = '1' then -- (s11)
			v.prod.yishen := '0';
		end if;

		-- -----------------------------------------------------------------------
		-- computation of r.prod.nextnbx, r.prod.nextxicnt, r.prod.nextxicntzero,
		-- r.prod.nextxlsbraddr & r.prod.nextslkcnt, all as a multi-cycle function
		-- of r.prod.nbx & input nndyn_w
		-- -----------------------------------------------------------------------
		-- TODO: set a multicycle of [TODO: how many cycles?] on paths:
		--       r.prod.nbx -> r.prod.nextxicnt
		--       r.prod.nbx -> r.prod.nextxicntzero
		--       r.prod.nbx -> r.prod.nextnbx
		--       r.prod.nbx -> r.prod.nextxlsbraddr
		--       r.prod.nbx -> r.prod.nextslkcnt
		--       r.prod.rw -> r.prod.nextxicnt
		--       r.prod.rw -> r.prod.nextxicntzero
		--       r.prod.rw -> r.prod.nextnbx
		--       r.prod.rw -> r.prod.nextxlsbraddr
		--       r.prod.rw -> r.prod.nextslkcnt
		-- CHECKED OK: v_prod_tobenext always set: no LATCH should be inferred
		if r.prod.nbx = (r.prod.nbx'range => '0') then -- (s85)
			v_prod_tobenext := '0';
		else
			v_prod_tobenext := '1';
		end if;

		-- CHECKED OK: v_prod_nextnbx always set: no LATCH should be inferred
		-- CHECKED OK: v_prod_nextxlsbraddr always set: no LATCH should be inferred
		-- CHECKED OK: v_prod_nextxicnt always set: no LATCH should be inferred
		-- CHECKED OK: v_prod_nextxicntzero always set: no LATCH should be inferred
		-- CHECKED OK: v_prod_nextslkcnt always set: no LATCH should be inferred
		if v_prod_tobenext = '0' then
			-- we're in the LAST burst of a cycle of mult-&-acc
			-- (mind that this is not incompatible with it also being the first one)
			vtmp_0 := signed('0' & nndyn_w);
			vtmp_1 := signed('0' & to_unsigned(ndsp, log2(w)));
			vtmp_2 := vtmp_0 - vtmp_1;
			if vtmp_2(log2(w)) = '1' or vtmp_2 = (vtmp_2'range => '0') then
				-- w < ndsp (or =)
				v_prod_nextxicnt := nndyn_w(log2(ndsp - 1) - 1 downto 0) - 1;
				-- v.prod.nextxicnt can turn out to be 0 (meaning that there is
				-- only one x_i term to multiply to the serie of y_j terms)
				if v_prod_nextxicnt = (v_prod_nextxicnt'range => '0') then
					v_prod_nextxicntzero := '1';
				else
					v_prod_nextxicntzero := '0';
				end if;
				v_prod_nextnbx := (others => '0');
				-- for (s70) below, size of nndyn_w is log2(w) and OPAGEW = log2(w-1)
				-- the former is always greater (of a unit) than the latter when w is
				-- a power of 2, and equal when it is not.
				-- However as we are first decrementing .rw by 1 before assigning it
				-- to v.oram.nextxlsbraddr, in the case where nndyn_w is not a
				-- power of 2, then (.rw - 1) will have the same size as .rw, and
				-- if it is (likely) a power of 2, then (.rw - 1) will lose one bit
				-- as compared to .rw. In either case, no information is lost by
				-- keeping solely the bits in the range OPAGEW - 1 downto 0
				vtmp_3 := nndyn_w - 1;
				v_prod_nextxlsbraddr :=
					std_logic_vector(vtmp_3(OPAGEW - 1 downto 0)); -- (s70)
				v_prod_nextslkcnt :=
					to_unsigned(NBRA - 1, NB_SLK_BITS);
			else
				-- w > ndsp
				v_prod_nextxicnt := to_unsigned(ndsp - 1, log2(ndsp - 1));
				if ndsp = 1 then -- statically resolved by synthesizer
					-- TODO: didn't we agree that ndsp > 1 strictly?
					v_prod_nextxicntzero := '1';
				else
					v_prod_nextxicntzero := '0';
				end if;
				v_prod_nextnbx := unsigned(vtmp_2(log2(w) - 1 downto 0));
				-- as regards to (s76) below, ndsp < w (or =)  =>  ndsp - 1 < w-1 (or =)
				-- => log2(ndsp - 1) < log2(w - 1) (or =), therefore it makes sense
				-- to encode ndsp - 1 on OPAGEW bits, as OPAGEW = log2(w - 1)
				v_prod_nextxlsbraddr := std_logic_vector (
					to_unsigned(ndsp - 1, OPAGEW) ); -- (s76)
				if ndsp > 2 then -- statically resolved by synthesizer
					v_prod_nextslkcnt := to_unsigned(ndsp - 1, NB_SLK_BITS);
				else
					v_prod_nextslkcnt := to_unsigned(2, NB_SLK_BITS);
				end if;
			end if;
		elsif v_prod_tobenext = '1' then
			-- we're NOT in the last burst of the cycle of mult-&-acc
			-- (but in one of the bursts that precede the last one, possibly
			-- the first)
			vtmp_0 := signed('0' & r.prod.nbx);
			vtmp_1 := signed('0' & to_unsigned(ndsp, log2(w)));
			vtmp_2 := vtmp_0 - vtmp_1;
			if vtmp_2(log2(w)) = '1' or vtmp_2 = (vtmp_2'range => '0') then
				-- .nbx < ndsp (or =)
				v_prod_nextxicnt := r.prod.nbx(log2(ndsp - 1) - 1 downto 0) - 1;
				-- v.prod.nextxicnt can turn out to be 0 (meaning that there is
				-- only one x_i term to multiply to the serie of y_j terms)
				if v_prod_nextxicnt = (v_prod_nextxicnt'range => '0') then
					v_prod_nextxicntzero := '1';
				else
					v_prod_nextxicntzero := '0';
				end if;
				v_prod_nextnbx := (others => '0');
				-- as regards to (s78) below, same remark applies as for (s70)
				vtmp_3 := unsigned(r.prod.nbx) - 1;
				v_prod_nextxlsbraddr := std_logic_vector(
					unsigned(r.prod.xlsbpivotraddr) +
					r.prod.nbx(OPAGEW - 1 downto 0) ); -- (s78)
				-- r.prod.nbx is on log2(w) bits & NB_SLK_BITS=log2(NBRA + ndsp + w - 1)
				-- so resize function won't truncate nothing
				v_prod_nextslkcnt := resize(r.prod.nbx, NB_SLK_BITS) +
				                     to_unsigned(ndsp - 1, NB_SLK_BITS);
			else
				-- .nbx > ndsp
				v_prod_nextxicnt := to_unsigned(ndsp - 1, log2(ndsp - 1));
				if ndsp = 1 then -- statically resolved by synthesizer
					-- TODO: didn't we agree that ndsp > 1 strictly?
					v_prod_nextxicntzero := '1';
				else
					v_prod_nextxicntzero := '0';
				end if;
				v_prod_nextnbx := unsigned(vtmp_2(log2(w) - 1 downto 0));
				-- as regards to (s80) below, same remark applies as for (s76)
				v_prod_nextxlsbraddr := std_logic_vector (
					-- .xlsbpivotraddr was previously latched by (s82), or initialized
					-- by (s84)
					unsigned(r.prod.xlsbpivotraddr) + -- (s83)
					to_unsigned(ndsp, OPAGEW) ); -- (s80)
				if ndsp > 2 then -- statically resolved by synthesizer
					v_prod_nextslkcnt := to_unsigned(ndsp - 1, NB_SLK_BITS);
				else
					v_prod_nextslkcnt := to_unsigned(2, NB_SLK_BITS);
				end if;
			end if;
		end if;

		-- TODO: set a multicycle on path:
		-- r.ctrl.state -> r.prod.xlsbpivotraddr
		if r.ctrl.state = idle then
			v.prod.nbx := nndyn_w;
			v.prod.xlsbpivotraddr := std_logic_vector(
				to_signed(-1, OPAGEW) ); -- (s84) bypass of (s82)
		end if;

		-- ------------------------------------------------------------------
		-- computation of r.prod.nextxmsbraddr & r.prod.nextymsbraddr as a
		-- multi-cycle function of r.prod.nbx & input nndyn_w
		-- ------------------------------------------------------------------

		-- TODO: set a multicycle constraint on path:
		--       r.ctrl.state -> r.prod.nextxmsbraddr
		--       r.ctrl.state -> r.prod.nextymsbraddr
		--       r.prod.nbx -> r.prod.nextxmsbraddr (mind (s85))
		--       r.prod.nbx -> r.prod.nextymsbraddr (mind (s85))
		-- CHECKED OK: v_prod_nextxmsbraddr always set: no LATCH should be inferred
		-- CHECKED OK: v_prod_nextymsbraddr always set: no LATCH should be inferred
		v_prod_nextxmsbraddr := (others => '0'); -- TO AVOID INFERENCE
		v_prod_nextymsbraddr := (others => '0'); -- OF ERRONOUS LATCH
		case r.ctrl.state is

			when idle =>

				v_prod_nextxmsbraddr := X_ORAM_ADDR;
				v_prod_nextymsbraddr := Y_ORAM_ADDR;

			when xy =>

				if v_prod_tobenext = '1' then
					v_prod_nextxmsbraddr := X_ORAM_ADDR;
					v_prod_nextymsbraddr := Y_ORAM_ADDR;
				elsif v_prod_tobenext = '0' then
					if r.prod.nextxymsb = '0' then
						v_prod_nextxmsbraddr := X_ORAM_ADDR;
						v_prod_nextymsbraddr := Y_ORAM_ADDR;
					elsif r.prod.nextxymsb = '1' then
						v_prod_nextxmsbraddr := S_ORAM_ADDR;
							v_prod_nextymsbraddr := PP_ORAM_ADDR;
					end if;
				end if;

			when sp =>

				if v_prod_tobenext = '1' then
					v_prod_nextxmsbraddr := S_ORAM_ADDR;
					v_prod_nextymsbraddr := PP_ORAM_ADDR;
				elsif v_prod_tobenext = '0' then
					if r.prod.nextxymsb = '0' then
					v_prod_nextxmsbraddr := S_ORAM_ADDR;
					v_prod_nextymsbraddr := PP_ORAM_ADDR;
					elsif r.prod.nextxymsb = '1' then
						v_prod_nextxmsbraddr := ALPHA_ORAM_ADDR;
							v_prod_nextymsbraddr := P_ORAM_ADDR;
					end if;
				end if;

			when others => -- ap

				if v_prod_tobenext = '1' then
					v_prod_nextxmsbraddr := ALPHA_ORAM_ADDR;
					v_prod_nextymsbraddr := P_ORAM_ADDR;
				elsif v_prod_tobenext = '0' then
					if r.prod.nextxymsb = '0' then
						v_prod_nextxmsbraddr := ALPHA_ORAM_ADDR;
						v_prod_nextymsbraddr := P_ORAM_ADDR;
					elsif r.prod.nextxymsb = '1' then
						v_prod_nextxmsbraddr := X_ORAM_ADDR;
							v_prod_nextymsbraddr := Y_ORAM_ADDR;
					end if;
				end if;

		end case;

		-- ----------------------------
		-- start of overall computation (i.e one complete REDC operation)
		-- ----------------------------
		-- TODO: dispatch a part of init logic on registers other than
		-- "r.ctrl.rdy and etc" to lighten its fan-out (perhaps use a delayed
		-- version of it)
		if r.ctrl.rdy = '1' and
		  (( (not async) and r.ctrl.go = '0' and go = '1' )
		  or (    async  and r.resync.go2_del = '0' and r.resync.go2 = '1')) then
			v.ctrl.active := '1';
			v.ctrl.state := xy;
			v.prod.state := mult;
			v.prod.bigslkcnt := to_unsigned(NBRT - 1, NB_BIGSLK_BITS);
			v.prod.bigslkcnten := '1';
			v.prod.bigslkcntdone := '0';
			v.ctrl.rdy := '0';
			-- pragma translate_off
			v.simcnt := (others => '0');
			-- pragma translate_on
			v.resync.go_ack := '1';
			if async then -- statically resolved by synthesizer
				v.iram.re := '1'; -- first terms are the x_i ones taken from IRAM
			else
				v.oram.re := '1'; -- (s114)
			end if;
			-- TODO: set a large multicycle on paths:
			-- r.oram.nextraddr -> r.oram.raddr
			-- r.oram.nextxicnt -> r.prod.xicnt
			-- r.oram.nextraddr -> r.oram.xishencnt
			-- r.oram.raddr, r.prod.xicnt & r.prod.xishencnt
			if async then -- statically resolved by synthesizer
				v.iram.raddr_msb := v_prod_nextxmsbraddr(1 downto 0);
				v.iram.raddr_lsb := v_prod_nextxlsbraddr;
			else -- synchronous case
				v.oram.raddr_msb := v_prod_nextxmsbraddr;
				v.oram.raddr_lsb := v_prod_nextxlsbraddr;
			end if;
			v.prod.dosavexlsbraddr := '1'; -- asserted only 1 cycle thx to (s6)
			v.prod.xicnt := v_prod_nextxicnt;
			v.prod.xishencnt := v_prod_nextxicnt;
			if v_prod_nextxicntzero = '1' then
				v.prod.xicntzero := '1'; -- 'll have effect on (s9) upon next cycle
				v.prod.xishencntzerokeep := '1';
			else
				v.prod.xishencntzerokeep := '0';
			end if;
			v.prod.xiphase := '1';
			v.prod.yiphase := '0';
			v.prod.xitoshcnt(sramlat) := '1'; -- asserted only 1 cycle, see (s2)
			-- TODO: set large multicycle on path r.prod.rw -> r.prod.nbx
			-- the 1st nbx count used in the 1st cycle of multiply-&-accumulate
			-- is always the flip one (that is 0)
			v.prod.nbx := v_prod_nextnbx;
		end if;

		if r.ctrl.go = '1' then
			v.oram.we := '0'; -- (s120), otherwise .we may stay asserted from (s119)
		end if;

		-- -----------------------------------------------------------------------
		-- last cycle of state 'slack' (for r.prod.state):
		--   - we switch r.ctrl.state to 'sp', 'ap', or 'idle' if it's currently
		--     the last burst of a cycle of multiply-&-accumulate
		--   - we switch r.prod.state to 'mult' if there is another burst to
		--     perform in the current cycle of multiply-&-accumulate
		-- -----------------------------------------------------------------------
		if r.prod.slkcntzero = '1' or
			(r.prod.slkcntdone = '1' and r.prod.bigslkcntdone = '1')
		then
			v.prod.slkcntdone := '0';
			-- TODO: set a large multicycle on paths:
			-- r.oram.nextraddr -> r.oram.raddr
			-- r.prod.nextxicnt -> r.prod.xicnt
			-- r.prod.nextxicnt -> r.prod.xishencnt
			if not async then -- statically resolved by synthesizer
				v.oram.raddr_msb := v_prod_nextxmsbraddr;
				v.oram.raddr_lsb := v_prod_nextxlsbraddr;
			end if;
			--v.prod.yiphase := '0'; -- useless, already the case
			if v_prod_tobenext = '1' then
				v.prod.nextxymsb := '0';
				if async then -- statically resolved by synthesizer
					if r.ctrl.state = xy then
						v.iram.raddr_msb := v_prod_nextxmsbraddr(1 downto 0);
						v.iram.raddr_lsb := v_prod_nextxlsbraddr;
					else
						v.tram.raddr_msb := v_prod_nextxmsbraddr(1 downto 0);
						v.tram.raddr_lsb := v_prod_nextxlsbraddr;
					end if;
				end if;
				-- we're beginning a new burst of multiplications in the SAME CYCLE
				-- of multiply-&-accumulate
				if async then -- statically resolved by synthesizer
					if r.ctrl.state = xy then
						-- next multiplicand terms are still x_i ones, taken from IRAM
						v.iram.re := '1';
					else
						-- next multiplicand terms are s_i or alpha_i ones, taken from TRAM
						v.tram.re := '1';
					end if;
				else -- synchronous case
					v.oram.re := '1'; -- (s115)
				end if;
				v.prod.xicnt := v_prod_nextxicnt;
				v.prod.xishencnt := v_prod_nextxicnt;
				-- TODO: set a large multicycle on path:
				-- r.prod.nextxicntzero -> r.prod.xishencntzero
				if v_prod_nextxicntzero = '1' then
					v.prod.xicntzero := '1'; -- 'll have effect on (s9) next cycle
					v.prod.xishencntzerokeep := '1';
				else
					v.prod.xishencntzerokeep := '0';
				end if;
				v.prod.xiphase := '1';
				v.prod.xitoshcnt(sramlat) := '1'; -- asserted 1 cycle, see (s2)
				v.prod.state := mult;
				-- TODO: set large multicycle on path r.prod.nextnbx -> r.prod.nbx
				v.prod.nbx := v_prod_nextnbx;
				v.prod.dosavexlsbraddr := '1'; -- asserted only 1 cycle thx to (s6)
			elsif v_prod_tobenext = '0' then
				if r.prod.bigslkcntdone = '1' then
					v.prod.nextxymsb := '0';
					v.prod.bigslkcntdone := '0';
					if async then -- statically resolved by synthesizer
						v.tram.raddr_msb := v_prod_nextxmsbraddr(1 downto 0);
						v.tram.raddr_lsb := v_prod_nextxlsbraddr;
					end if;
					if r.ctrl.state = ap then
						-- v.oram.re := '0'; -- useless, already deasserted
						v.ctrl.state := idle;
						v.prod.state := idle;
						-- TODO: post a counter so that the switch back to idle state is
						-- propagated down along the pipeline (till PRAM write state machine)
					else
						-- we're begining a new burst of multiplications IN A NEW cycle of
						-- multiply-&-accumulate, entering either state sp (coming from
						-- state xy) or state ap (coming from state sp)
						if async then -- statically resolved by synthesizer
							-- since we're begining a new cycle of multiply-&-acc, multiplicand
							-- terms can't be but s_i or alpha_i terms, taken from TRAM
							v.tram.re := '1';
						else -- synchronous case
							-- all terms are taken from common ORAM memory
							v.oram.re := '1'; -- (s116)
						end if;
						-- TODO: set a large multicycle on paths:
						-- r.oram.nextraddr -> r.oram.raddr
						-- r.prod.nextxicnt -> r.prod.xicnt
						-- r.prod.nextxicnt -> r.prod.xishencnt
						if r.ctrl.state = xy then
							v.ctrl.state := sp;
						else -- if r.ctrl.state = sp
							v.ctrl.state := ap;
						end if;
						v.prod.xicnt := v_prod_nextxicnt;
						v.prod.xishencnt := v_prod_nextxicnt;
						-- TODO: set a large multicycle on path:
						-- r.prod.nextxicntzero -> r.prod.xishencntzero
						if v_prod_nextxicntzero = '1' then
							v.prod.xicntzero := '1'; -- 'll have effect on (s9) next cycle
							v.prod.xishencntzerokeep := '1';
						else
							v.prod.xishencntzerokeep := '0';
						end if;
						v.prod.xiphase := '1';
						v.prod.xitoshcnt(sramlat) := '1'; -- asserted 1 cycle, see (s2)
						v.prod.state := mult;
						v.prod.bigslkcnt := to_unsigned(NBRT - 1, NB_BIGSLK_BITS);
						v.prod.bigslkcnten := '1';
						-- TODO: set large multicycle on path r.prod.nextnbx -> r.prod.nbx
						v.prod.nbx := v_prod_nextnbx;
						v.prod.dosavexlsbraddr := '1'; -- asserted only 1 cycle thx to (s6)
					end if;
				elsif r.prod.bigslkcntdone = '0' then
					v.prod.slkcntdone := '1';
				end if; -- r.prod.bigslkcntdone
			end if; -- v_prod_tobenext
		end if; -- r.prod.slkcntzero = 1

		v.prod.bigslkcntzero := '0';
		if r.prod.bigslkcnten = '1' then	
			v.prod.bigslkcnt := r.prod.bigslkcnt - 1;
			if r.prod.bigslkcnt = to_unsigned(1, NB_BIGSLK_BITS) then
				v.prod.bigslkcntzero := '1';
				v.prod.bigslkcnten := '0';
			end if;
		end if;
		if r.prod.bigslkcntzero = '1' then
			v.prod.bigslkcntdone := '1';
		end if;

		-- TODO: set a multicycle on path:
		-- input nndyn_wm1 -> r.prod.yicnt
		if r.prod.xicntzero = '1' then -- (s9)
			v.prod.xiphase := '0';
			v.prod.yiphase := '1';
			v.prod.yicnt := nndyn_wm1;
			if async then -- statically resolved by synthesizer
				v.iram.raddr_msb := v_prod_nextymsbraddr(1 downto 0);
				v.iram.raddr_lsb := (others => '0');
				v.iram.re := '1';
				v.tram.re := '0';
			else
				-- all terms are taken from common ORAM memory
				v.oram.raddr_msb := v_prod_nextymsbraddr;
				v.oram.raddr_lsb := (others => '0');
				-- v.oram.re := '1'; -- useless thx to (s114), (s115) & (s116)
			end if;
			v.prod.nextxymsb := '1';
		end if;
		if r.prod.yicntzero = '1' then
			v.prod.yiphase := '0';
			v.prod.state := slack;
			if async then
				v.iram.re := '0';
			else
				v.oram.re := '0';
			end if;
			v.prod.slkcnt := v_prod_nextslkcnt;
			-- TODO: REMOVE THAT, BUT ONLY AFTER VERIF THAT v_prod_nextslkcnt can't =0
			if v_prod_nextslkcnt = (v_prod_nextslkcnt'range => '0') then
				v.prod.slkcntzero := '1';
			end if;
		end if;

		for i in 0 to ndsp - 1 loop
			v.dsp(i).acecntzero := '0';
		end loop;

		v.prod.xishendel := r.prod.xishen;
		if r.prod.xishen = '1' and r.prod.xishendel = '0' then -- (s12)
			v.dsp(0).ace := '1';
			v.dsp(0).acecnt := r.prod.xishencnt;
			v.dsp(0).acecntzero := r.prod.xishencntzero;
			-- DSP block 0 is always active (otherwise there would be no new
			-- burst (as opposed to other DSP blocks, which may or may not be
			-- active during each burst)
			v.dsp(0).active := '1'; -- deasserted by (s96) below, same as for i>0
		end if;

		-- ----------------------------------------------------------------
		-- transfer of the clock-enable signal of the A input port
		-- of each DSP block from one block (i) to the next (i + 1)
		-- ----------------------------------------------------------------
		for i in 0 to ndsp - 1 loop
			v.dsp(i).acedel := r.dsp(i).ace;
		end loop;
		-- 1/2 - assertion of the clock-enable signal
		for i in 0 to ndsp - 2 loop -- (s124), ndsp assumed >= 2, see (s125)
			if r.dsp(i).ace = '1' and r.dsp(i).acedel = '0' then -- (s13)
				v.dsp(i + 1).acecnt := r.dsp(i).acecnt - 1;
				if r.dsp(i).acecnt = (r.dsp(i).acecnt'range => '0') then
					v.dsp(i + 1).ace := '0';
				else
					v.dsp(i + 1).ace := '1';
				end if;
				if r.dsp(i).acecnt = to_unsigned(1, log2(ndsp - 1)) then
					v.dsp(i + 1).acecntzero := '1';
				end if;
			end if;
		end loop;

		for i in 0 to ndsp - 1 loop
			if r.dsp(i).ace = '1' then
				v.dsp(i).acecnt := r.dsp(i).acecnt - 1;
				if r.dsp(i).acecnt = to_unsigned(1, log2(ndsp - 1)) then
					v.dsp(i).acecntzero := '1';
				end if;
			end if;
		end loop;

		-- 2/2 - deassertion of the clock-enable signal
		for i in 0 to ndsp - 1 loop
			if r.dsp(i).acecntzero = '1' then
				v.dsp(i).ace := '0';
			end if;
		end loop;

		-- assertion & deassertion of r.dsp(i).active
		--   r.dsp(i).active is used below (see "RSTM") to decide if rstm, once
		--   asserted, should stay so for the current burst production of
		--   product-terms (this is when .active = 0) or if it should be
		--   deasserted earlier, namely when decounter r.dsp(i).rstmcnt
		--   reaches 0, see (s30) & (s90)

		-- assertion of .active: on falling edge of .ace
		for i in 1 to ndsp - 1 loop
			if r.dsp(i).ace = '0' and r.dsp(i).acedel = '1' then -- (s16)
				v.dsp(i).active := '1';
			end if;
		end loop;

		-- deassertion of .active: on falling edge of .bce
		for i in 0 to ndsp - 1 loop
			if r.dsp(i).bce = '0' and r.dsp(i).bcedel = '1' then
				v.dsp(i).active := '0'; -- (s96)
			end if;
		end loop;

		-- ----------------------------------------------------------------
		-- transfer of the clock-enable signal of the B input port
		-- of each DSP block, from one block to the other
		-- ----------------------------------------------------------------
		-- CE for first DSP block (#0) is simply the 1-cycle delayed version
		-- of r.prod.yishen signal
		v.dsp(0).bce := r.prod.yishen;

		for i in 0 to ndsp - 1 loop
			v.dsp(i).bcedel := r.dsp(i).bce;
		end loop;

		-- for DSP block #1, BCE is asserted 1 cycle later than BCE of DSP
		-- block #0, and deasserted 2 cycles after it
		-- assertion of BCE for DSP block #1
		if r.dsp(0).bce = '1' and r.dsp(0).bcedel = '0' then
			v.dsp(1).bce := '1';
		end if;
		-- deassertion of BCE for DSP block #1
		if r.dsp(1).bce = '1' and r.dsp(0).bcedel = '0' then
			v.dsp(1).bce := '0';
		end if;

		-- for all other DSP blocks (other than 0 and 1) BCE is merely the
		-- delayed version of BCE of the previous block, by 2 cycles
		if ndsp > 2 then
			for i in 2 to ndsp - 1 loop
				v.dsp(i).bce := r.dsp(i - 1).bcedel;
			end loop;
		end if;

		-- ----------------------------------------------------------------
		-- generation of reset signals to M & P register for all DSP blocks
		-- ----------------------------------------------------------------

		-- --------------------         RSTM         --------------------

		-- DSP block #0 does not need to have its M reg reset
		v.dsp(0).rstm := '0'; -- useless (will be trimmed by synthesizer, but
		-- kept here for sake of readability)

		-- for DSP block #1 .rstm is asserted 1 cycle after BCE and stays so
		-- for 1 cycle only, unless it is inactive for the current burst,
		-- in which case its deassertion is triggered by the falling pulse of
		-- .bce, as for other DSP blocks (i > 1, as described by (s93)-(s94)
		-- below)
		if r.dsp(1).active = '1' then
			v.dsp(1).rstm := '0'; -- (s14)
		end if;
		if r.dsp(1).bce = '1' and r.dsp(1).bcedel = '0' then -- (s21)
			v.dsp(1).rstm := '1'; -- stays so 1 cycle thx to (s14) (if .active = 1)
		end if;
		if r.dsp(1).active = '0' and r.dsp(1).bce = '0' and r.dsp(1).bcedel = '1'
		then -- like (s94)
			v.dsp(1).rstm := '0';
		end if;

		-- for all other DSP blocks (other than 0 and 1) .rstm is asserted
		-- 1 cycle after the one of previous block, and lasts 1 cycle more
		-- than it lasts for the previous block, unless it is inactive for
		-- the current burst, in which case its assertion must last the
		-- duration of the whole burst
		if ndsp >= 2 then -- statically resolved by synthesizer
			for i in 2 to ndsp - 1 loop
				-- assertion of .rstm
				if r.dsp(i).rstm = '0' and r.dsp(i - 1).rstm = '1' then -- (s22)
					v.dsp(i).rstm := '1';
					if r.dsp(i).active =  '1' then
						v.dsp(i).rstmcnt := to_unsigned(i - 1, log2(w - 1)); -- can't be 0
					end if;
				end if;
				-- deassertion of .rstm
				if r.dsp(i).rstm = '1' and r.dsp(i).active = '1' then
					v.dsp(i).rstmcnt := r.dsp(i).rstmcnt - 1;
				end if;
				v.dsp(i).rstmcntzero := '0'; -- (s15)
				if r.dsp(i).rstmcnt = to_unsigned(1, log2(w - 1)) then
					v.dsp(i).rstmcntzero := '1'; -- (s30) asserted 1 cycle thx to (s15)
				end if;
				if r.dsp(i).active = '0' then
					-- if .active was low for the current burst of multiplications
					-- (due to condition (s16) not met) then rstm must stay asserted
					-- for the whole duration of the burst: we use the falling edge
					-- of .bce to deassert .rstm
					if r.dsp(i).bce = '0' and r.dsp(i).bcedel = '1' then -- (s94)
						v.dsp(i).rstm := '0'; -- (s93)
					end if;
				elsif r.dsp(i).active = '1' then
					-- if .active was high during the current burst of multiplications
					-- then the deassertion of .rstm is triggered using dedicated
					-- counter .rstmcnt, see (s15) & (s30) above
					if r.dsp(i).rstmcntzero = '1' then
						v.dsp(i).rstm := '0'; -- (s90)
					end if;
				end if;
			end loop;
		end if;

		-- --------------------         RSTP         --------------------

		for i in 0 to ndsp - 1 loop
			v.dsp(i).rstpdel := r.dsp(i).rstp;
		end loop;

		for i in 0 to ndsp - 1 loop
			-- for all DSP blocks except the last one, the assignment here-after
			-- will take effect at all cycles except for only 1 transient cycle
			-- enforced by (s17) below
			-- for i = ndsp - 1 (last DSP block) the assignment here-after will
			-- take effect for all cycles except for a transient state of 2 clock
			-- cycles enforced by (s18) below
			v.dsp(i).rstp := '0'; -- (s19)
		end loop;

		-- for DSP block #0, RSTP is generated from BCE signal, with an assertion
		-- happening 2 clock cycles after the falling edge of BCE
		v.dsp0_bcedel2 := r.dsp(0).bcedel;
		if r.dsp(0).bcedel = '0' and r.dsp0_bcedel2 = '1' then
			v.dsp(0).rstp := '1'; -- lasts only 1 cycle thx to (s19)
		end if;

		-- for other DSP blocks, except the last one (#{ndsp - 1}) RSTP is
		-- merely a delayed version of RSTP of the previous block, by 2 cycles
		if ndsp > 2 then
			for i in 1 to ndsp - 2 loop
				v.dsp(i).rstp := r.dsp(i - 1).rstpdel; -- (s17)
			end loop;
			-- DSP block #{ndsp - 1} is the last one and assertion of RSTP must
			-- lasts 2 cycles for it
			if (r.dsp(ndsp - 2).rstp = '0' and r.dsp(ndsp - 2).rstpdel = '1')
			  or (r.dsp(ndsp - 1).rstp = '1' and r.dsp(ndsp - 1).rstpdel = '0')
			then
				v.dsp(ndsp - 1).rstp := '1'; -- (s18) lasts 2 cycles thx to (s19)
			end if;
		elsif ndsp = 2 then
			-- DSP block #1 is the last one and assertion of RSTP must lasts
			-- 2 cycles
			if (r.dsp(0).rstp = '0' and r.dsp(0).rstpdel = '1')
			  or (r.dsp(1).rstp = '1' and r.dsp(1).rstpdel = '0')
			then
				v.dsp(1).rstp := '1'; -- (s18) lasts 2 cycles thx to (s19)
			end if;
		end if;

		-- ----------------------------------------------------------------
		-- generation of PCE clock-enable signal for all DSP blocks
		-- ----------------------------------------------------------------

		-- first DSP block (#0)
		v.dsp(0).pce := r.dsp(0).bcedel;

		for i in 0 to ndsp - 1 loop
			v.dsp(i).pcedel := r.dsp(i).pce;
		end loop;

		-- other DSP blocks (from 1 to ndsp - 1)
		-- assertion (1 cycle after assertion of .pce from "upper" level)
		for i in 1 to ndsp - 1 loop
			if r.dsp(i - 1).pce = '1' and r.dsp(i).pce = '0' then -- (s20)
				v.dsp(i).pce := '1';
			end if;
		end loop;

		-- deassertion (2 cycles after deassertion of .pce from "upper" level)
		for i in 1 to ndsp - 1 loop
			if r.dsp(i - 1).pcedel = '0' and r.dsp(i).pce = '1' then
				v.dsp(i).pce := '0';
			end if;
		end loop;

		-- -----------------------------------------------------------------
		--                 accumulation of product-terms
		--            at the output of the chain of DSP blocks
		--          (through r.acc.ppend & r.acc.ppacc registers)
		-- -----------------------------------------------------------------
		v.acc.ppend := unsigned(dsp_p); -- (s34)
		-- The following line means: take the {ww + ln2(ndsp)} upper bits
		-- of r.acc.ppacc, right-shift them by ww positions, make a completion of
		-- the left-most part with zeros, and then add the result to r.acc.ppend
		-- Note: r.acc.ppacc is of type unsigned, so resize function will add
		-- MSB 0's to it. Furthermore, the length of returned vector
		-- (= 2*ww + ln2(ndsp)) is guaranteed to be strictly greater than the
		-- one of the input vector (= ww + ln2(ndsp)) except for the case ww = 0
		-- (which is not admissible)
		v.acc.ppacc := r.acc.ppend + -- (s44)
			resize(r.acc.ppacc(2*ww + ln2(ndsp) - 1 downto ww), 2*ww + ln2(ndsp));

		-- upper part of r.acc.ppacc needs to be (re-)initialized to 0 just
		-- before every new burst of product-terms starts outgoing from the
		-- chain of DSP blocks
		v.acc.ppaccrst := '0';
		if r.dsp(ndsp - 1).pce = '1' and r.dsp(ndsp - 1).pcedel = '0' then
			v.acc.ppaccrst := '1'; -- stays asserted only 1 cycle
		end if;
		if r.acc.ppaccrst = '1' then
			v.acc.ppacc(2*ww + ln2(ndsp) - 1 downto ww) := (others => '0');
		end if;
		v.acc.ppaccrstdel := r.acc.ppaccrst;

		-- CHECKED OK: v_acc_tobenext always set: no LATCH should be inferred
		if r.acc.nbx = to_unsigned(0, r.acc.nbx'length) then
			v_acc_tobenext := '0';
		else
			v_acc_tobenext := '1';
		end if;

		-- TODO: set a multicycle on paths:
		-- r.acc.state -> r.acc.nbx
		-- r.acc.state -> r.acc.mustread
		-- (a new Montgomery multiplication is not suppposed to start again
		-- before at least the external interface pulls out the result of the
		-- current one from mm_ndsp, which represents at least 'valw' cycles)
		-- so unless valw is very low, there's slack here that should be
		-- given to the router
		if r.acc.state = idle then
			v.acc.nbx := nndyn_w; -- (s24) bypassed by (s26) don't switch order
			v.acc.mustread := '0';
			v.acc.ppaccbaseweight :=
				unsigned(to_signed(-ndsp, WEIGHT_BITS + 1));
			v.acc.rdlock := '0';
		end if;

		-- generation of r.acc.ppaccvalid: asserted 3 cycles after assertion
		-- of PCE signal of the last DSP block of the chain, and stays so
		-- for a duration of ww + rn + 2 clock-cycles, if rn denotes the
		-- number of DSP blocks which are active in the current burst of
		-- product-terms computation (this is either ndsp, or w mod ndsp
		-- if this is the last burst)
		-- 1/2 - assertion of r.acc.ppaccvalid (along w/ change of r.acc.state)
		if r.acc.ppaccrstdel = '1' then
			v.acc.ppaccvalid := '1';
			v.acc.ppaccvalcnt := r.acc.ppaccvalcntnext; -- (s25) see note (s27) below
			-- note that r.acc.ppaccvalcntnext cannot be null, as stated in (s31)
			-- and (s32) below, which is why we do not assert v.acc.ppaccvalcntzero
			-- here, but only in (s33) below
			v.acc.nbx := r.acc.nextnbx; -- (s26) see note (s27) below + (s24) above
			v.acc.ppaccweight := r.acc.ppaccweightnext;
			v.acc.ppaccbaseweight := '0' & r.acc.ppaccweightnext;
			-- transition of r.acc.state state machine
			if r.acc.state = idle then
				v.acc.state := xy;
			elsif r.acc.state = xy and v_acc_tobenext = '0' then
				v.acc.state := sp;
				v.acc.mustread := '0';
			elsif r.acc.state = sp and v_acc_tobenext = '0' then
				v.acc.state := ap;
				v.acc.mustread := '0';
			--elsif r.acc.state = ap and v_acc_tobenext = '0' then
			--	v.acc.state := idle;
			end if;
		end if;
		-- 2/2 - deassertion r.acc.ppaccvalid (when valid counter reaches 0)
		v.acc.ppaccvalcntzero := '0';
		if r.acc.ppaccvalcnt = to_unsigned(1, r.acc.ppaccvalcnt'length) then
			v.acc.ppaccvalcntzero := '1'; -- (s33) stays asserted only 1 cycle
		end if;
		if r.acc.ppaccvalcntzero = '1' then
			v.acc.ppaccvalid := '0';
		end if;

		-- deassertion also must be forced when the weight of the product-terms
		-- reaches value (2*w) - 1 (which is the highest valid height)
		-- (s46) note: nndyn_2wm1 being an unsigned, resize can but extend it
		-- with 0's. Furthermore, as size of nndyn_2wm1 is log2(w) + 1 and
		-- the size of r.acc.ppaccweight is WEIGHT_BITS (defined as log2(2w - 1))
		-- resize function can only extend it, not truncate it (WEIGHT_BITS is
		-- either equal to size of nndyn_2wm1, or equal to it when w is a
		-- power of 2)
		if r.acc.ppaccweight = resize(nndyn_2wm1, WEIGHT_BITS)
			and r.acc.ppaccvalid = '1'
		then
			v.acc.ppaccvalid := '0';
		end if;

		-- decrement of valid counter, increment of weight
		if r.acc.ppaccvalid = '1' then
			v.acc.ppaccvalcnt := r.acc.ppaccvalcnt - 1;
			v.acc.ppaccweight := r.acc.ppaccweight + 1;
		end if;

		-- -------------------------------------------------------------------
		-- computation of r.acc.ppaccvalcntnext & r.prod.nextnbx as a function
		-- of r.acc.nbx - (s28) see also note (s27) below
		-- -------------------------------------------------------------------
		-- TODO: set a large multicycle (4 ?) on paths:
		-- r.acc.nbx -> r.acc.ppaccvalcntnext
		-- r.acc.nbx -> r.acc.nextnbx
		-- (the value of 4 corresponds to the minimal duration of 'mult' state)
		-- CHECKED OK: v_acc_ndspactive always set: no LATCH should be inferred
		if v_acc_tobenext = '0' then
			-- we're in the LAST burst of a cycle of mult-&-acc
			-- (mind that this is not incompatible with it also being the first one)
			vtmp_7 := signed('0' & nndyn_w);
			vtmp_8 := signed('0' & to_unsigned(ndsp, log2(w)));
			vtmp_9 := vtmp_7 - vtmp_8;
			if vtmp_9(log2(w)) = '1' or vtmp_9 = (vtmp_9'range => '0') then
				-- w < ndsp (or =)
				-- the number of x_i terms that remain to process is smaller than
				-- (or equal to) the number of DSP blocks in the chain
				-- Therefore only a subset of the DSP blocks will be active during
				-- the next round of multiplication-accumulations, in number r.acc.nbx
				v_acc_ndspactive := resize(nndyn_w, log2(ndsp));
				-- in the line below:
				--   - v_acc_ndspactive'width = log2(ndsp) which cannot be strictly
				--     greater than log2(w + ndsp + 1), therefore resize function
				--     cannot truncate it. Furthermore it is of type unsigned, so
				--     resize function will left-pad it with 0's (NOT with 1's)
				--   - nndyn_w'width = log2(w), which cannot be strictly greater
				--     than log2(w + ndsp + 1), so the same applies
				-- Also note that v.acc.ppaccvalcntnext resulting from (s31) can't be 0
				v.acc.ppaccvalcntnext := -- (s31)
						resize(v_acc_ndspactive, log2(w + ndsp + 1))
					+ resize(nndyn_w, log2(w + ndsp + 1));
				v.acc.nextnbx := (others => '0');
			else
				-- w > ndsp (strictly)
				-- the number of x_i terms that remain to process is bigger than
				-- the number of DSP blocks in the chain
				-- Therefore all the DSP blocks will be active during the next
				-- round of multiplication-accumulations
				v_acc_ndspactive := to_unsigned(ndsp, log2(ndsp));
				-- note that computation of v.acc.ppaccvalcntnext by (s32) below
				-- cannot yield value 0
				v.acc.ppaccvalcntnext := -- (s32)
						resize(v_acc_ndspactive, log2(w + ndsp + 1))
					+ resize(nndyn_w, log2(w + ndsp + 1));
				v.acc.nextnbx := unsigned(vtmp_9(log2(w) - 1 downto 0));
			end if;
			v.acc.ppaccweightnext := (others => '0');
		elsif v_acc_tobenext = '1' then
			-- we're NOT in the last burst of the cycle of mult-&-acc
			-- (but in one of the bursts that precede the last one, possibly
			-- the first)
			vtmp_7 := signed('0' & r.acc.nbx);
			vtmp_8 := signed('0' & to_unsigned(ndsp, log2(w)));
			vtmp_9 := vtmp_7 - vtmp_8;
			if vtmp_9(log2(w)) = '1' or vtmp_9 = (vtmp_9'range => '0') then -- < or =0
				-- the number of x_i terms that remain to process is smaller than
				-- (or equal to) the number of DSP blocks in the chain
				-- Therefore only a subset of the DSP blocks will be active during
				-- the next round of multiplication-accumulations, un number r.acc.nbx
				v_acc_ndspactive := r.acc.nbx(log2(ndsp) - 1 downto 0);
				-- in the line below:
				--   - v_acc_ndspactive'width = log2(ndsp) which cannot be strictly
				--     greater than log2(w + ndsp + 1), therefore resize function
				--     cannot truncate it. Furthermore it is of type unsigned, so
				--     resize function will left-pad it with 0's (and NOT with 1's)
				--   - nndyn_w'width = log2(w), which cannot be strictly greater
				--     than log2(w + ndsp + 1), so the same applies here
				-- Also note that v.acc.ppaccvalcntnext cannot be null from (s31)
				v.acc.ppaccvalcntnext := -- (s31)
						resize(v_acc_ndspactive, log2(w + ndsp + 1))
					+ resize(nndyn_w, log2(w + ndsp + 1));
				v.acc.nextnbx := (others => '0');
			else -- r.acc.nbx > ndsp (strictly)
				-- the number of x_i terms that remain to process is bigger than
				-- the number of DSP blocks in the chain
				-- Therefore all the DSP blocks will be active during the next
				-- round of multiplication-accumulations
				v_acc_ndspactive := to_unsigned(ndsp, log2(ndsp));
				-- note that computation of v.acc.ppaccvalcntnext by (s32) below
				-- cannot yield value 0
				v.acc.ppaccvalcntnext := -- (s32)
						resize(v_acc_ndspactive, log2(w + ndsp + 1))
					+ resize(nndyn_w, log2(w + ndsp + 1));
				v.acc.nextnbx := unsigned(vtmp_9(log2(w) - 1 downto 0));
			end if;
			vtmp_10 := r.acc.ppaccbaseweight + to_unsigned(ndsp, WEIGHT_BITS + 1);
			v.acc.ppaccweightnext := resize(vtmp_10, WEIGHT_BITS);
		end if;

		-- (s27)
		-- note: we use the cycle where r.ppaccrst is asserted as the cycle to:
		--   - latch value of r.acc.nextnbx into r.acc.nbx and latch value of
		--     r.acc.ppaccvalcntnext into r.acc.ppaccvalcnt, see (s25) & (s26) above
		--   - starting to compute r.acc.nextnbx for the burst to come (the one
		--     that'll follow the current starting one), see (s28) above

		-- next transitions (xy -> sp, sp -> ap and ap -> idle) are based on
		-- falling edge of r.acc.ppaccvalid with condition v.acc.nextnbx = 0
		if r.acc.ppaccvalid = '0' and r.acc.ppaccvalidprev = '1'
			and v_acc_tobenext = '0' and r.acc.state = ap
		then
			v.acc.state := idle;
		end if;

		-- the start of the last accumulation burst is used to allow the barrel-
		-- shifter to be started
		if r.acc.ppaccvalid = '1' and r.acc.ppaccvalidprev ='0'
			and v_acc_tobenext = '0' and r.acc.state = ap
		then
			-- Initiate r.brl.armcnt decounting.
			-- When r.brl.armcnt reaches 0, this means r.brl.start can be asserted
			-- by (s118)
			v.brl.armcnten := '1';
			v.brl.armcnt := to_unsigned(sramlat + 2, log2(sramlat + 2));
		end if;

		if r.brl.armcnten = '1' then
			v.brl.armcnt := r.brl.armcnt - 1;
			if r.brl.armcnt = (r.brl.armcnt'range => '0') then
				v.brl.armcnten := '0';
				v.brl.armed := '1';
			end if;
		end if;

		-- ---------------------------------------------------------------------
		--     accumulation of product-terms by accesses from/to PRAM memory
		-- ---------------------------------------------------------------------

		--         -------------------------------------------------
		--         1/4 - READ partial product-terms from PRAM memory
		--         -------------------------------------------------

		-- (s65) generation of read-enable signal into PRAM memory
		-- it is generated on the fly by determining if the value in the least
		-- significant ww-bit part of ppacc (r.acc.ppacc(ww-1..0)) corresponds
		-- to a weight (currently latched in r.acc.pppaccweight) for which
		-- at least one term has already been written into PRAM for the current
		-- cycle of multiplication.
		-- If it is, then we must assert RE (so that the term will be read
		-- from PRAM and later be added to r.acc.term, see (s49) & (s66))
		-- otherwise we must deassert RE.
		-- Furthermore, it also depends on the state of the multiplication
		-- we're currently in:
		--   - in state 'xy'
		--   - in state 'sp'
		--   - in state 'ap'
		if r.acc.state = ap then vap := '1'; else vap := '0'; end if;
		v.pram.re := r.acc.ppaccvalid
			and ( (r.acc.mustread and not r.acc.rdlock) or vap );
		if r.pram.re = '1' and r.pram.raddrweight = r.acc.lastupperweight
			and vap = '0'
		then
			v.pram.re := '0';
			v.acc.rdlock := '1';
		end if;
		if r.acc.ppaccvalid = '0' and r.acc.rdlock = '1' then
			v.acc.rdlock := '0';
		end if;

		-- latch of r.acc.lastupperweight (from r.acc.ppaccweight when
		-- r.acc.ppaccvalid is deasserted)
		if r.acc.ppaccvalid = '0' and r.acc.ppaccvalidprev = '1' then
			v.acc.lastupperweight := r.pram.raddrweight;
		end if;

		v.acc.ppaccvalidprev := r.acc.ppaccvalid;
		if r.acc.ppaccvalid = '0' and r.acc.ppaccvalidprev = '1' then
			v.acc.mustread := '1';
		end if;

		-- (s66) see also (s65) above & (s49) below
		-- r.pram.re is shifted by the number of clock cycles equal to the
		-- read latency of PRAM memory in order the detect if we must add value
		-- read from PRAM memory to the one accumulated in the tail register
		-- of r.acc.term chain, i.e r.acc.term(sramlat + 1)
		-- (we have read into PRAM memory <=> we must add value read from PRAM)
		v.acc.mustadd := r.pram.re & r.acc.mustadd(sramlat downto 1);

		v.pram.rdata := r_pram_rdata;

		-- generation of read-address into PRAM memory
		-- note: r.pram.raddr may toggle needlessly (i.e when no actual read is
		-- to be performed) but power-saving is based on precise assertion/
		-- deassertion of r.pram.re instead
		v.pram.raddr_lsb := std_logic_vector(r.acc.ppaccweight);
		v.pram.raddrweight := r.acc.ppaccweight;

		-- generation of r.pram.raddr_msb (upper part of read-address in PRAM
		-- memory) - this is just one bit: 0 means reading from s_i terms page,
		-- 1 means reading from alpha_i terms page
		if r.acc.state = xy or r.acc.state = ap then
			v.pram.raddr_msb := '0'; -- corresponds to s_i terms page
		elsif r.acc.state = sp then
			v.pram.raddr_msb := '1'; -- corresponds to alpha_i terms page
		end if;

		--       ------------------------------------------------------
		--       2/4 - shift registers r.acc.term(0 .. sramlat + 1)
		--       ------------------------------------------------------

		v.acc.term(0).valid := r.acc.ppaccvalid;
		v.acc.term(0).weight := r.acc.ppaccweight;

		-- r.acc.ppacc content is shifted through a layer of shift-registers
		-- in quantity sramlat + 1
		v.acc.term(0).value(ww - 1 downto 0) := r.acc.ppacc(ww - 1 downto 0);
		v.acc.term(0).value(ww) := '0'; -- (s122)
		for i in 1 to sramlat loop
			v.acc.term(i).valid := r.acc.term(i - 1).valid;
			v.acc.term(i).weight := r.acc.term(i - 1).weight;
			v.acc.term(i).value -- (ww - 1 downto 0) :=
				:= r.acc.term(i - 1).value; -- (ww - 1 downto 0);
		end loop;

		-- the last term (i = sramlat + 1) is a special case, it consumes the
		-- possible 3-bit carry r.acc.carry1 (coming from the last addition of
		-- r.acc.psum0 with r.acc.carry0)
		v.acc.term(sramlat + 1).valid := r.acc.term(sramlat).valid;
		v.acc.term(sramlat + 1).weight := r.acc.term(sramlat).weight;
		v.acc.carry1match := '0';
		if r.acc.term(sramlat - 1).weight = r.acc.carry1weight then
			v.acc.carry1match := '1';
		end if;
		if r.acc.term(sramlat).valid = '1' and r.acc.carry1valid = '1'
			and r.acc.carry1match = '1'
		then
			v.acc.term(sramlat + 1).value := -- ww + 1
        -- we add two words of size ww + 1 but we know there can be
				-- no carry (of weight ww + 1) as the first operand has an
				-- actual dynamic of ww bits (the MSB is set to 0, see
				-- (s122)) and the second operand has a 3-bit size
				(r.acc.term(sramlat).value) -- ww + 1
			  + resize(r.acc.carry1, ww + 1); -- ww + 1
			-- TODO: could (s91) be possibly bypassed by simultaneous end of burst?
			-- in the general case, we have to assume that it could
			v.acc.carry1valid := '0'; -- (s91) bypassed by (s92)
		else
			v.acc.term(sramlat + 1).value :=
				'0' & r.acc.term(sramlat).value(ww - 1 downto 0);
		end if;

		--            ------------------------------------------
		--            3/4 - accumulation through .psum0 register
		--            ------------------------------------------

		--                          . p s u m 0

		-- (s49)
		-- conditional addition of r.acc.term tail register w/ value read from
		-- PRAM memory - mind bypass (s50)
		if r.acc.mustadd(0) = '1' then
			v.acc.psum0 := resize(unsigned(r.pram.rdata), ww + 2)
				+ resize(r.acc.term(sramlat + 1).value, ww + 2);
		else
			v.acc.psum0 := resize(r.acc.term(sramlat + 1).value, ww + 2);
		end if;

		-- nominally content of r.acc.psum0 is "strobed" by r.acc.psum0valid
		-- which is just the 1 cycle delayed version of the valid signal for
		-- the tailing register of r.acc.term array. However we must also account
		-- for possible overrun of weight, beyond 2w - 1
		v.acc.psum0valid := r.acc.term(sramlat + 1).valid;
		-- for comparison between r.acc.psum0weight & input nndyn_2wm1, same remark
		-- applies as for (s46)
		if r.acc.psum0weight = resize(nndyn_2wm1, WEIGHT_BITS)
		  and r.acc.psum0valid = '1'
		then
			v.acc.psum0valid := '0';
		end if;

		v.acc.psum0weight := r.acc.term(sramlat + 1).weight;

		--             --------------------------------------
		--             4/4 - WRITE-back of (partial or final)
		--                 product-terms into PRAM memory
		--             --------------------------------------

		-- the MSBit of address at which words are written into PRAM is the same
		-- as the MSBit of address at which they are read, delayed by a number of
		-- cycles corresponding to the read latency of BlockRAM
		v.pram.waddr_msb_sh(sramlat + 1) := r.pram.raddr_msb;
		for i in sramlat downto 0 loop
			v.pram.waddr_msb_sh(i) := r.pram.waddr_msb_sh(i + 1);
		end loop;
		v.pram.waddr_msb := r.pram.waddr_msb_sh(0);

		-- (s48) addition of r.acc.psum0 with r.acc.carry0 into r.pram.wdata
		vtmp_11 := ('0' & r.acc.psum0) + resize(r.acc.carry0, ww + 3); -- ww+3 bit
		v.pram.wdata := std_logic_vector(vtmp_11(ww - 1 downto 0)); -- ww bit
		v.acc.carry0 := vtmp_11(ww + 2 downto ww); -- 3 bit
		if r.acc.dosavecarry1 = '1' then
			v.acc.carry1valid := '1'; -- (s92) bypass of (s91)
			v.acc.carry1weight := r.acc.psum0weight;
			v.acc.carry1 := r.acc.carry0; -- 3 bit
		end if;
		if r.acc.dorstcarry0 = '1' then -- (s53) asserted only 1 cycle thx to (s54)
			v.acc.carry0 := "000";
		end if;
		-- TODO: it is probably possible to avoid creating the path below
		--       (r.acc.dorstpsum0 -> r.acc.psum0)
		-- by initializing .psum0 before (at the end of previous burst)
		if r.acc.dorstpsum0 = '1' then -- (s51) asserted only 1 cycle thx to (s52)
			v.acc.psum0 := (others => '0'); -- (s50) bypass of (s49)
		end if;

		-- r.acc.pcarry0 need to be reset when r.acc.psum0 is latched with the
		-- first term of one burst (otherwise (s48) will produce undesired value)
		v.acc.dorstcarry0 := '0';
		if r.acc.term(sramlat + 1).valid = '0'
			and r.acc.term(sramlat).valid = '1'
		then
			v.acc.dorstcarry0 := '1'; -- (s54), see (s53)
		end if;

		-- r.acc.psum0 also need to be reset at the end of the burst, because
		-- of the extra-weight term inherent to the 2-bit carry when adding
		-- r.acc.psum0 with r.acc.carry0, see (s48)
		v.acc.dorstpsum0 := '0';
		if r.acc.term(sramlat).valid = '0'
			and r.acc.term(sramlat + 1).valid = '1'
		then
			v.acc.dorstpsum0 := '1'; -- (s52), see (s51)
		end if;

		v.pram.waddr_lsb := std_logic_vector(r.acc.psum0weight);

		v.pram.we := r.acc.psum0valid;

		v.acc.dosavecarry1 := '0';
		if r.acc.dorstpsum0 = '1' then
			-- for comparison between r.acc.psum0weight & input nndyn_2wm1,
			-- same remark applies as for (s46)
			if r.acc.psum0weight /= resize(nndyn_2wm1, WEIGHT_BITS) then
				v.acc.dosavecarry1 := '1';
			end if;
		end if;

		v.pram.wdataweight := r.acc.psum0weight;

		-- ----------------------------------------------------------------
		--                 transfer of product-terms
		--            into TRAM memory (if async = TRUE)
		--              or ORAM memory (if async = FALSE)
		--             (when they must be served back as
		--             inputs to the chain of DSP blocks)
		-- ----------------------------------------------------------------

		-- TODO: set a multicycle on following paths:
		-- r.acc.state -> r.oram.we / r.tram.we
		-- r.acc.state -> r.oram.waddr / r.tram.waddr
		-- r.acc.state -> r.oram.wdata / r.tram.wdata
		v.brl.armsh := '0' & r.brl.armsh(log2(ww) - 2 downto 1);
		if r.acc.state = xy or r.acc.state = sp then
			if async then -- statically resolved by synthesizer
				v.tram.we := r.pram.we;
				v.tram.waddr_lsb := r.pram.waddr_lsb(OPAGEW - 1 downto 0);
				v.tram.waddr_msb(0) := r.pram.waddr_lsb(OPAGEW);
				v.tram.wdata := r.pram.wdata;
			else
				v.oram.we := r.pram.we;
				v.oram.waddr_lsb := r.pram.waddr_lsb(OPAGEW - 1 downto 0);
				v.oram.waddr_msb(0) := r.pram.waddr_lsb(OPAGEW);
				v.oram.wdata := r.pram.wdata;
			end if;
				-- TODO: set a multicycle on paths:
				-- nndyn_wm1 -> r.oram.wdata
				-- nndyn_mask -> r.oram.wdata
				if nndyn_mask_wm2 = '1' then
					if r.pram.wdataweight = resize(nndyn_wm2, WEIGHT_BITS) then
						if async then -- statically resolved by synthesizer
							v.tram.wdata := r.pram.wdata and nndyn_mask;
						else
							v.oram.wdata := r.pram.wdata and nndyn_mask;
						end if;
					elsif r.pram.wdataweight = resize(nndyn_wm1, WEIGHT_BITS) then
						if async then -- statically resolved by synthesizer
							v.tram.wdata := (others => '0'); -- TODO: probably useless
						else
							v.oram.wdata := (others => '0'); -- TODO: probably useless
						end if;
					end if;
				elsif nndyn_mask_wm2 = '0' then
					if r.pram.wdataweight = resize(nndyn_wm1, WEIGHT_BITS) then
						if async then -- statically resolved by synthesizer
							v.tram.wdata := r.pram.wdata and nndyn_mask;
						else
							v.oram.wdata := r.pram.wdata and nndyn_mask;
						end if;
					end if;
				end if;
		-- TODO: set a multicycle on following paths:
		-- r.acc.nbx -> r.oram.we / r.zram.we
		-- r.acc.nbx -> r.oram.prodburst
		-- r.acc.nbx -> r.oram.wdata / r.zram.wdata
		-- r.acc.nbx -> r.oram.waddr_msb
		-- r.acc.nbx -> r.oram.waddr_lsb / r.zram.waddr
		-- r.acc.nbx -> r.oram.wcnt
		-- (due to pipeline depth from r.acc.xxx signals and write cycles
		-- into ORAM, r.acc.nbx is stabilized at least 'sramlat + 1' cycles
		-- before we "use" it, same as r.acc.state)
		elsif r.brl.armed = '1' then
			if (nndyn_wmin_excp = '0' and r.pram.wdataweight = nndyn_wmin) or
				 (nndyn_wmin_excp = '1' and r.pram.wdataweight = nndyn_wmin_excp_val)
			then
				v.brl.start := '1'; -- (s118)
				if nndyn_wmin_excp = '0' then
					v.brl.startcnt := to_unsigned(log2(ww) + 1, log2(log2(ww) + 1) );
				elsif nndyn_wmin_excp = '1' then
					v.brl.startcnt := to_unsigned(log2(ww)    , log2(log2(ww) + 1) );
					v.brl.armsh(log2(ww) - 2) := '1';
				end if;
			end if;
		end if;

		if r.brl.armsh(0) = '1' then
			v.brl.enright := '1';
		end if;

		if r.brl.start = '1' then
			v.brl.startcnt := r.brl.startcnt - 1;
			if r.brl.startcnt = (r.brl.startcnt'range => '0') then
				v.brl.start := '0';
				v.oram.prodburst := '1';
				if async then -- statically resolved by synthesizer
					v.zram.we := '1';
					v.zram.wdata := r.oram.shifted;
					v.zram.waddr := (others => '0');
				else
					v.oram.we := '1';
					v.oram.wdata := r.oram.shifted;
					v.oram.waddr_msb := PROD_ORAM_ADDR;
					v.oram.waddr_lsb := (others => '0');
				end if;
				v.oram.wcnt := resize(nndyn_wm1, log2(w));
			end if;
		end if;

		if r.oram.prodburst = '1' then
			if async then -- statically resolved by synthesizer
				v.zram.wdata := r.oram.shifted;
			else
				v.oram.wdata := r.oram.shifted;
			end if;
			if async then -- statically resolved by synthesizer
				v.zram.waddr := std_logic_vector(unsigned(r.zram.waddr) + 1);
			else
				v.oram.waddr_lsb := std_logic_vector(unsigned(r.oram.waddr_lsb) + 1);
			end if;
			v.oram.wcnt := r.oram.wcnt - 1;
			if r.oram.wcnt(log2(w)-1) = '0' and v.oram.wcnt(log2(w)-1) = '1' then
				v.oram.prodburst := '0';
				if async then -- statically resolved by synthesizer
					v.zram.we := '0';
				else
					v.oram.we := '0';
				end if;
				v.ctrl.irq := '1';
				v.ctrl.rdy := '1';
				v.ctrl.active := '0';
				v.brl.armed := '0';
				v.brl.shexcp := (others => '0');
				v.brl.enright := '0';
			end if;
		end if;

		-- generation of MSB part of write address into ORAM memory (or TRAM
		-- when async = TRUE)
		if async then -- statically resolved by synthesizer
			if r.acc.state = xy then
				v.tram.waddr_msb(1) := '0'; -- s_i terms page
			elsif r.acc.state = sp then
				v.tram.waddr_msb(1) := '1'; -- alpha_i terms page
			end if;
		else
			if r.acc.state = xy then
				v.oram.waddr_msb(2 downto 1) := "10"; -- s_i terms page
			elsif r.acc.state = sp then
				v.oram.waddr_msb(2 downto 1) := "11"; -- alpha_i terms page
			end if;
		end if;

		-- ---------------------------------------------------------------
		-- barrel shifter used to format properly the result of Montgomery
		-- multiplication (end of 'ap' state)
		-- ---------------------------------------------------------------

		-- --------------------
		-- right barrel-shifter
		-- --------------------
		-- TODO: set a multicycle on paths:
		-- ... -> r.brl.shrcnt
		-- ... -> r.brl.shlcnt
		-- TODO: set a multicycle on paths:
		-- input 'nndyn_shrcnt' -> ...
		if nndyn_shrcnt(log2(ww) - 1) = '1' then
			v.brl.shr(log2(ww) - 1) :=
				shift_right(unsigned(r.pram.wdata), 2 ** (log2(ww) - 1));
		elsif nndyn_shrcnt(log2(ww) - 1) = '0' then
			v.brl.shr(log2(ww) - 1) := unsigned(r.pram.wdata);
		end if;
		-- for (s99), note that (s98) above enforces that log2(ww) - 2 >= 0
		for i in log2(ww) - 2 downto 0 loop -- (s99)
			if nndyn_shrcnt(i) = '1' then
				v.brl.shr(i) :=
					shift_right(r.brl.shr(i + 1), 2**i);
			elsif nndyn_shrcnt(i) = '0' then
				v.brl.shr(i) := r.brl.shr(i + 1);
			end if;
		end loop;

		v.brl.shexcp := '0' & r.brl.shexcp(log2(ww) - 1 downto 1);
		if nndyn_wmin_excp = '1' then
			if r.brl.armed = '0' then
				if r.pram.wdataweight = nndyn_wmin -- and r.pram.we = '1' -- useless
				then
					v.brl.shexcp(log2(ww) - 1) := '1';
				end if;
			end if;
		end if;
		if nndyn_wmin_excp = '1' then
			if r.brl.shexcp(0) = '1' and r.brl.armed = '0' then
				v.brl.right := r.brl.shr(0);
			end if;
			if r.brl.enright = '1' then
				v.brl.right := r.brl.shr(0);
			end if;
		elsif nndyn_wmin_excp = '0' then
			v.brl.right := r.brl.shr(0);
		end if;

		-- -------------------
		-- left barrel-shifter
		-- -------------------
		-- TODO: set a multicycle on paths:
		-- input 'nndyn_shlcnt' -> ...
		if nndyn_shlcnt(log2(ww) - 1) = '1' then
			v.brl.shl(log2(ww) - 1) :=
				shift_left(unsigned(r.pram.wdata), 2 ** (log2(ww) - 1));
		elsif nndyn_shlcnt(log2(ww) - 1) = '0' then
			v.brl.shl(log2(ww) - 1) := unsigned(r.pram.wdata);
		end if;
		-- for (s100), note that (s98) above enforces that log2(ww) - 2 >= 0
		for i in log2(ww) - 2 downto 0 loop -- (s100)
			if nndyn_shlcnt(i) = '1' then
				v.brl.shl(i) :=
					shift_left(r.brl.shl(i + 1), 2**i);
			elsif nndyn_shlcnt(i) = '0' then
				v.brl.shl(i) := r.brl.shl(i + 1);
			end if;
		end loop;

		v.oram.shifted := std_logic_vector(r.brl.right or r.brl.shl(0));

		-- --------------------------------------------
		-- read-back of multiplication result by ecc_fp (synchronous case only)
		-- --------------------------------------------
		if not async then -- statically resolved by synthesizer
			v.io.zrendel := zren;
			if zren = '1' and r.io.zrendel = '0' then
				v.oram.re := '1';
				v.oram.raddr_msb := PROD_ORAM_ADDR;
				v.oram.raddr_lsb := (others => '0');
			end if;
			if zren = '1' and r.io.zrendel = '1' then
				v.oram.raddr_lsb := std_logic_vector(unsigned(r.oram.raddr_lsb) + 1);
			end if;
			if zren = '0' and r.io.zrendel = '1' then
				v.oram.re := '0';
			end if;
		end if;

		-- ---------------------------------------------------------------------
		-- synchronous (active high) reset
		-- ---------------------------------------------------------------------
		if rst22 = '1' then
			v.ctrl.state := idle;
			v.prod.state := idle;
			v.io.piencnt := (others => '0');
			v.io.ppiencnt := (others => '0');
			v.ctrl.rdy := '1';
			v.ctrl.active := '0';
			v.ctrl.irq := '0';
			if async then
				v.ctrl.ioforbid := '0'; -- I/O access is allowed after reset
			end if;
			v.prod.xishen := '0'; -- so that (s12) detects 1st edge of r.prod.xishen
			for i in 0 to ndsp - 1 loop
				v.dsp(i).ace := '0'; -- so that (s13) detects 1st edge of r.dsp(i).ace
				v.prod.yishen := '0';
				v.dsp(i).pce := '0'; -- so that (s20) detects 1st edge of r.dsp(i).pce
				v.dsp(i).rstm := '0'; -- so that (s22) logic operates properly
				--v.dsp(i).active := '0';
			end loop;
			v.dsp(0).rstmcnt := (others => '0');
			v.dsp(1).rstmcnt := (others => '0');
			if ndsp > 2 then
				v.dsp(2).rstmcnt :=
					(others => '0'); -- ABSOLUTELY MANDATORY IN SYNTHESIS (was a BUG FIX)
			end if;
			v.dsp(1).bce := '0'; -- so that (s21) detects 1st edge of r.dsp(1).bce
			v.acc.ppaccvalid := '0';
			v.prod.nextxymsb := '0';
			v.acc.state := idle;
			v.acc.carry1valid := '0';
			v.oram.prodburst := '0';
			v.brl.start := '0';
			v.brl.armed := '0';
			v.brl.armcnten := '0';
			v.brl.shexcp := (others => '0');
			v.brl.enright := '0';
			v.brl.armsh := (others => '0');
			v.prod.bigslkcntzero := '0';
			v.prod.bigslkcnten := '0';
			v.prod.bigslkcntdone := '0';
			v.prod.slkcntdone := '0';
		end if;

		-- generate combinational input of registered signals
		rin <= v;

		-- pragma translate_off
		c_prod_nextnbx <= v_prod_nextnbx;
		c_prod_nextxlsbraddr <= v_prod_nextxlsbraddr;
		c_prod_nextxicnt <= v_prod_nextxicnt;
		c_prod_nextxicntzero <= v_prod_nextxicntzero;
		c_prod_nextslkcnt <= v_prod_nextslkcnt;
		c_prod_tobenext <= v_prod_tobenext;
		c_prod_nextxmsbraddr <= v_prod_nextxmsbraddr;
		c_prod_nextymsbraddr <= v_prod_nextymsbraddr;
		c_acc_tobenext <= v_acc_tobenext;
		c_acc_ndspactive <= v_acc_ndspactive;
		-- pragma translate_on
	end process comb;

	-- synchronous process (clk0 clock-domain)
	regs: process(clk0)
	begin
		if (clk0'event and clk0 = '1') then
			r <= rin;
		end if;
	end process regs;

	-- drive outputs
	rdy <= r.ctrl.rdy;
	z <= r_zram_rdata when async -- statically resolved by synthesizer
	     else r_oram_rdata;
	irq <= r.ctrl.irq;
	-- </used only in asynchronous case
	go_ack <= r.resync.go_ack;
	-- end of: used only in asynchronous case/>

	-- pragma translate_off
	-- for sake of waveform readability while simulating, both r.acc.ppacc
	-- & r.acc.ppend are chopped into three sub-parts, each of ww-bit width:
	--  - a least significant part (ww-bit always)
	--  - a middle significant part (ww-bit always)
	--  - a most significant part (or carry, of width ww - ln2(ndsp) bits)

	-- r.acc.ppacc
	r_ppacc_lsb <= r.acc.ppacc(ww - 1 downto 0); -- least
	r_ppacc_msb <= r.acc.ppacc(2*ww - 1 downto ww); -- middle
	r_ppacc_cry <=
		to_unsigned(0, ww - ln2(ndsp)) -- (s104) see (s108)
		& r.acc.ppacc(2*ww + ln2(ndsp) - 1 downto 2*ww); -- carry

	-- r.acc.ppend
	r_ppend_lsb <= r.acc.ppend(ww - 1 downto 0); -- least
	r_ppend_msb <= r.acc.ppend(2*ww - 1 downto ww); -- middle
	r_ppend_cry <=
		to_unsigned(0, ww - ln2(ndsp)) -- (s105) see (s108)
		& r.acc.ppend(2*ww + ln2(ndsp) - 1 downto 2*ww); -- carry
	-- pragma translate_on

end architecture rtl;
