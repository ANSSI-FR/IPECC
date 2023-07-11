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
use work.ecc_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

use work.ecc_addr.all;

entity ecc_scalar is
	port (
		clk : in  std_logic;
		rstn : in  std_logic; -- synchronous reset
		-- software reset
		swrst : in std_logic;
		-- interface with ecc_axi
		--   general
		initdone : out std_logic;
		ardy : out std_logic;
		aerr_inpt_not_on_curve : out std_logic;
		aerr_outpt_not_on_curve : out std_logic;
		aerr_inpt_ack : in std_logic;
		aerr_outpt_ack : in std_logic;
		ar01zien : out std_logic;
		ar0zi : out std_logic;
		ar1zi : out std_logic;
		ar0zo : in std_logic;
		ar1zo : in std_logic;
		nndyn_nnp1 : in unsigned(log2(nn + 1) - 1 downto 0);
		nndyn_nnm3 : in unsigned(log2(nn) - 1 downto 0);
		--   [k]P computation
		agokp : in std_logic;
		kpdone : out std_logic;
		doblinding : in std_logic;
		blindbits : in std_logic_vector(log2(nn) - 1 downto 0);
		doshuffle : in std_logic;
		k_is_null : in std_logic;
		small_k_sz_en : in std_logic;
		small_k_sz_en_en : in std_logic;
		small_k_sz : in unsigned(log2(nn) - 1 downto 0);
		small_k_sz_en_ack : out std_logic;
		small_k_sz_kpdone : out std_logic;
		tokenact : in std_logic;
		zremaskact : in std_logic;
		zremaskbits : in unsigned(log2(nn - 1) - 1 downto 0);
		--   Montgomery constants computation
		agocstmty : in std_logic;
		mtydone : out std_logic;
		--   constant 'a' Montgomery transform
		agomtya : in std_logic;
		amtydone : out std_logic;
		--   other point-based computations
		dopop : in std_logic;
		popid : in std_logic_vector(2 downto 0); -- id defined in ecc_pkg
		popdone : out std_logic;
		yes : out std_logic;
		yesen : out std_logic;
		--   token
		gentoken : in std_logic;
		tokendone : out std_logic;
		-- interface with ecc_curve
		initkp : out std_logic; -- also driven to ecc_fp
		frdy : in std_logic;
		fgo : out std_logic;
		faddr : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		ferr : in std_logic;
		zero : in std_logic;
		laststep : out std_logic;
		firstzdbl : out std_logic;
		firstzaddu : out std_logic;
		iterate_shuffle_valid : out std_logic;
		iterate_shuffle_rdy : in std_logic;
		iterate_shuffle_force : out std_logic;
		first2pz : in std_logic;
		first3pz : out std_logic;
		torsion2 : in std_logic;
		xmxz : in std_logic;
		ymyz : in std_logic;
		kap : in std_logic;
		kapp : in std_logic;
		zu : out std_logic;
		zc : out std_logic;
		r0z : out std_logic;
		r1z : out std_logic;
		pts_are_equal : out std_logic;
		pts_are_oppos : out std_logic;
		phimsb : in std_logic;
		kb0end : in std_logic;
		ptadd : out std_logic;
		-- interface with ecc_fp
		compkp : out std_logic;
		compcstmty : out std_logic;
		comppop : out std_logic;
		token_generating : out std_logic;
		-- interface with ecc_fp_dram_sh (used only if shuffle_type /= none)
		permute : out std_logic;
		permuterdy : in std_logic;
		permuteundo : out std_logic;
		-- debug features
		dbgpgmstate : out std_logic_vector(3 downto 0);
		dbgnbbits : out std_logic_vector(15 downto 0);
		dbgnbstarvrndxyshuf : out std_logic_vector(15 downto 0)
		-- pragma translate_off
		-- interface with ecc_fp (simu only)
		; logr0r1 : out std_logic;
		logr0r1step : out natural;
		logfinalresult : out std_logic;
		simbit : out natural
		-- pragma translate_on
	);
end entity ecc_scalar;

architecture rtl of ecc_scalar is

	type state_type is (idle, cst, set, kp, pop, tok);

	type program_type is (idle, checkoncurve, blindinit, blindbit, blindexit,
	                      adpa, ssetup, joyecoz, subtractp, exits,
	                      wait_xyr01_permute, token);

	-- main control signals
	type ctrl_reg_type is record
		out_of_reset : std_logic;
		active : std_logic;
		initdone : std_logic;
		uponreset : std_logic;
		state : state_type;
		r1z_init : std_logic;
		r0z : std_logic;
		r1z : std_logic;
		small_k_sz_en : std_logic;
	end record;

	type joye_state_type is (idle, itoh, prezaddu, zaddu, prezaddc, zaddc,
		permutation, zdblu, zdblc, znegc, zrmsk);

	-- registers used to encode Joye state machine
	type joye_reg_type is record
		nbbits : unsigned(log2(nn) downto 0);
		state : joye_state_type;
	end record;

	type subptype_type is (last_zaddc, last_zdblc, last_znegc);

	-- registers involved in [k]P computation
	type kp_reg_type is record
		initkp : std_logic;
		computing : std_logic;
		joye : joye_reg_type;
		substate : program_type;
		nextsubstate : program_type;
		done : std_logic;
		blind_nbbits : unsigned(log2(nn) - 1 downto 0);
		laststep : std_logic;
		firstzdbl : std_logic;
		firstzaddu : std_logic;
		iterate_shuffle_valid : std_logic;
		iterate_shuffle_force : std_logic;
		k_is_null : std_logic;
		subpstep : std_logic;
		subptype : subptype_type; --std_logic_vector(1 downto 0);
		zu, zc : std_logic;
		pts_are_equal : std_logic;
		pts_are_oppos : std_logic;
		ssetup_step : std_logic_vector(1 downto 0);
		first3pz : std_logic;
		--firstitoh : std_logic;
		zrmcnt : unsigned(log2(nn - 1) - 1 downto 0);
		zrmstep : std_logic;
	end record;

	-- registers involved in computation of Montgomery constants
	type mty_reg_type is record
		computing, computing_del : std_logic;
		computing_a : std_logic;
		done : std_logic;
		donea : std_logic;
		step : std_logic_vector(1 downto 0);
		cntrshift : unsigned(log2(nn + 1) - 1 downto 0);
	end record;

	-- registers involved in curve point operations
	type pop_reg_type is record
		computing : std_logic;
		add : std_logic;
		dbl : std_logic;
		neg : std_logic;
		check : std_logic;
		equal : std_logic;
		opp : std_logic;
		step : std_logic_vector(1 downto 0);
		equalx : std_logic;
		done : std_logic;
		yes : std_logic;
		yesen : std_logic;
	end record;

	-- pragma translate_off
	-- simulation only
	type sim_reg_type is record
		logr0r1 : std_logic;
		logr0r1step : natural;
		logfinalresult : std_logic;
		simbit : natural;
		perfcnt : integer;
		perfcnten : std_logic;
		simblbit : natural;
	end record;
	-- pragma translate_on

	-- registers used as interface to other components
	type int_reg_type is record
		-- interface with ecc_axi
		ardy : std_logic;
		ar01zien : std_logic;
		ar0zi : std_logic;
		ar1zi : std_logic;
		aerr_inpt_not_on_curve : std_logic;
		aerr_outpt_not_on_curve : std_logic;
		-- interface with ecc_curve
		faddr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		fgo : std_logic;
		-- interface with ecc_fp_dram (only used in the 'shuffle' case)
		permute : std_logic;
		permuteundo : std_logic;
		small_k_sz_en_ack : std_logic;
		small_k_sz_kpdone : std_logic;
		ptadd : std_logic;
		tokendone : std_logic;
		token_generating : std_logic;
	end record;

	-- debug features
	type debug_reg_type is record
		joyebit : std_logic_vector(log2(2*nn - 1) - 1 downto 0);
		nbstarvrndxyshuf : std_logic_vector(15 downto 0);
	end record;

	type reg_type is record
		ctrl : ctrl_reg_type;
		kp : kp_reg_type;
		mty : mty_reg_type;
		pop : pop_reg_type;
		int : int_reg_type;
		dbg : debug_reg_type;
		-- pragma translate_off
		sim : sim_reg_type;
		-- pragma translate_on
	end record; -- reg_type

	signal r, rin : reg_type;
	-- pragma translate_off
	signal rbak_state : state_type;
	signal rbak_substate : program_type;
	signal rbak_joye_state : joye_state_type;
	signal rlog_blind_nbbits : natural;
	-- pragma translate_on

	constant CONSTMTY0_ROUTINE : natural := 0;
	constant CONSTMTY1_ROUTINE : natural := 1;
	constant CONSTMTY2_ROUTINE : natural := 2;
	constant CHKCURVE_ROUTINE : natural := 3;
	constant BLINDSTART_ROUTINE : natural := 4;
	constant BLNBIT_ROUTINE : natural := 5;
	constant BLINDSTOP_ROUTINE : natural := 6;
	constant ADPA_ROUTINE : natural := 7;
	constant DRAWZ_ROUTINE : natural := 8;
	constant ITOH_ROUTINE : natural := 9;
	constant ZADDU_ROUTINE : natural := 10;
	constant ZADDC_ROUTINE : natural := 11;
	constant SUBTRACTP_ROUTINE : natural := 12;
	constant EXIT_ROUTINE : natural := 13;
	constant ADDITION_BEGIN_ROUTINE : natural := 14;
	constant DOUBLE_ROUTINE : natural := 15;
	constant NEGATIVE_ROUTINE : natural := 16;
	constant EQUALX_ROUTINE : natural := 17;
	constant EQUALY_ROUTINE : natural := 18;
	constant OPPOSITEY_ROUTINE : natural := 19;
	constant IS_ON_CURVE_ROUTINE : natural := 20;
	constant ZREMASK_ROUTINE : natural := 21;
	constant AMONTY_ROUTINE : natural := 22;
	constant PRE_ZADDU_ROUTINE : natural := 23;
	constant PRE_ZADDC_ROUTINE : natural := 24;
	constant ZDBL_ROUTINE : natural := 25;
	constant ZNEGC_ROUTINE : natural := 26;
	constant ADDITION_END_ROUTINE : natural := 27;
	constant ZDBLSW_ROUTINE : natural := 28;
	constant SETUP_ROUTINE : natural := 29;
	constant GET_TOKEN_ROUTINE : natural := 30;
	constant MASK_TOKEN_ROUTINE : natural := 31;
	--constant NOP_ROUTINE : natural := 32;

	-- Address of the routines below (all constants whose name starts with
	-- "ECC_IRAM_" (see below definition of array constant EXEC_ADDR) are
	-- defined in package ecc_addr (see file <ecc_addr.vhd>) which is
	-- automatically generated when running 'make' in folder hdl/ecc_curve_iram/.
	-- Numerical values in <ecc_addr.vhd> are obtained when assembling all
	-- *.s source files present in folder hdl/ecc_curve_iram/asm_src and
	-- extracting addresses from the final binary image. (This is done
	-- through Makefile and scripting in folder hdl/ecc_curve_iram - see
	-- in particular script <ipecc_assembler.py>). The addresses to be
	-- extracted are all the addresses whose label is suffixed with the
	-- string "_export":
	--
	--   1. this suffixe is removed, as long as the uppercase letter 'L'
	--      preceeding it, as long as the initial dot prefixing the label name
	--   2. the remaining identification string is switched to uppercase
	--   3. it is prefixed with the string "ECC_IRAM_"
	--
	-- Example: constant ECC_IRAM_CONSTMTY0_ADDR is the address of routine
	--  ".constMTY0L_export".
	--  (.constMTY0L_export -> constMTY0L -> CONSTMTY0 -> ECC_IRAM_CONSTMTY0_ADDR)
	--
	-- Hence label names should not be considered case sensitive (.foobarL and
	-- .FoObARL will lead to the same routine address entry)
	--
	-- A note on synthesis of constant EXEC_ADDR: it will almost certainly
	-- lead to inference of LUT-based logic only, because of the way EXEC_ADDR
	-- is combinationaly (hence asynchronously) accessed in the remaining
	-- of ecc_scalar code below (see e.g (s0)). This indeed will prevent
	-- synthesizer from infering a blockRAM, as these blocks are always
	-- purely synchronous in off-the-shelf FPGAs. However allowing EXEC_ADDR
	-- to be synthesized as an SRAM memory (either for FPGA or ASIC target)
	-- should not take a big effort in modifying the RTL below
	subtype std_logic_pc is std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	type exec_addr_type is array(0 to 31) of std_logic_pc;
	constant EXEC_ADDR : exec_addr_type := ( -- (s115)  --  matching routine:
		CONSTMTY0_ROUTINE => ECC_IRAM_CONSTMTY0_ADDR,     -- .constMTY0L[_export]
		CONSTMTY1_ROUTINE => ECC_IRAM_CONSTMTY1_ADDR,     -- .constMTY1L[_export]
		CONSTMTY2_ROUTINE => ECC_IRAM_CONSTMTY2_ADDR,     -- .constMTY2L[_export]
		-- all routines used by [k]P computation
		CHKCURVE_ROUTINE => ECC_IRAM_CHKCURVE_ADDR,       -- .chkcurveL[_export]
		BLINDSTART_ROUTINE => ECC_IRAM_BLINDSTART_ADDR,   -- .blindstartL_[export]
		BLNBIT_ROUTINE => ECC_IRAM_BLNBIT_ADDR,           -- .blnbitL[_export]
		BLINDSTOP_ROUTINE => ECC_IRAM_BLINDSTOP_ADDR,     -- .blindstopL[_export]
		ADPA_ROUTINE => ECC_IRAM_ADPA_ADDR,               -- .adpaL[_export]
		DRAWZ_ROUTINE => ECC_IRAM_DRAWZ_ADDR,             -- .drawZL[_export]
		SETUP_ROUTINE => ECC_IRAM_SETUP_ADDR,             -- .setupL[_export]
		ITOH_ROUTINE => ECC_IRAM_ITOH_ADDR,               -- .itohL[_export]
		ZADDU_ROUTINE => ECC_IRAM_ZADDU_ADDR,             -- .zadduL[_export]
		ZADDC_ROUTINE => ECC_IRAM_ZADDC_ADDR,             -- .zaddcL[_export]
		SUBTRACTP_ROUTINE => ECC_IRAM_SUBTRACTP_ADDR,     -- .subtractPL[_export]
		EXIT_ROUTINE => ECC_IRAM_EXIT_ADDR,               -- .exitL[_export]
		-- extra point-level routines
		ADDITION_BEGIN_ROUTINE => ECC_IRAM_ADDITION_BEGIN_ADDR,
		                                                -- .addition_beginL[_export]
		DOUBLE_ROUTINE => ECC_IRAM_DOUBLE_ADDR,           -- .doubleL[_export]
		NEGATIVE_ROUTINE => ECC_IRAM_NEGATIVE_ADDR,       -- .negativeL[_export]
		EQUALX_ROUTINE => ECC_IRAM_EQUALX_ADDR,           -- .equalXL[_export]
		EQUALY_ROUTINE => ECC_IRAM_EQUALY_ADDR,           -- .equalYL[_export]
		OPPOSITEY_ROUTINE => ECC_IRAM_OPPOSITEY_ADDR,     -- .oppositeYL[_export]
		IS_ON_CURVE_ROUTINE => ECC_IRAM_IS_ON_CURVE_ADDR, -- .is_on_curveL[_export]
		-- extra arithmetic-level routines
		ZREMASK_ROUTINE => ECC_IRAM_ZREMASK_ADDR,         -- .zremaskL[_export]
		AMONTY_ROUTINE => ECC_IRAM_AMONTY_ADDR,           -- .aMontyL[_export]
		PRE_ZADDU_ROUTINE => ECC_IRAM_PRE_ZADDU_ADDR,     -- .pre_zadduL[_export]
		PRE_ZADDC_ROUTINE => ECC_IRAM_PRE_ZADDC_ADDR,     -- .pre_zaddcL[_export]
		ZDBL_ROUTINE => ECC_IRAM_ZDBL_ADDR,               -- .zdblL[_export]
		ZNEGC_ROUTINE => ECC_IRAM_ZNEGC_ADDR,             -- .znegcL[_export]
		ADDITION_END_ROUTINE => ECC_IRAM_ADDITION_END_ADDR,
		                                                  -- .addition_endL[_export]
		ZDBLSW_ROUTINE => ECC_IRAM_ZDBL_SW_ADDR,          -- .zdbl_swL[_export]
		GET_TOKEN_ROUTINE => ECC_IRAM_GET_TOKEN_ADDR,     -- .get_tokenL[_export]
		MASK_TOKEN_ROUTINE => ECC_IRAM_TOKEN_KP_MASK_ADDR --.token_kP_maskL[_export]
		-- NOP_ROUTINE =>         (not used here, clumsy exceeds 31, and for nothing)
	);

	-- pragma translate_off
	signal nnmax_joye_loop_s : integer;
	signal r_sim_prevbit : natural;
	signal blbits_max_s : integer;
	signal r_sim_prevblbit : natural;
	signal z_rmsk_on : std_logic;
	-- pragma translate_on

	constant NB_BITS_LINE : natural := 16;

begin

	-- pragma translate_off
	z_rmsk_on <= '1' when r.kp.joye.state = zrmsk else '0';
	-- pragma translate_on

	-- (s29), see (s30)
	-- pragma translate_off
	assert (log2(nn) <= 16)
		report "blinding size is too large for debug mode"
			severity FAILURE;
	-- pragma translate_on

	-- combinational process
	comb : process(r, rstn, agokp, agocstmty, doblinding, blindbits, agomtya,
	               frdy, ferr, zero, iterate_shuffle_rdy, permuterdy, doshuffle,
	               k_is_null, aerr_inpt_ack, aerr_outpt_ack, nndyn_nnm3,
	               nndyn_nnp1, dopop, popid, ar0zo, ar1zo,
	               swrst, first2pz, xmxz, ymyz, torsion2, kap, kapp,
	               phimsb, kb0end, small_k_sz_en, small_k_sz_en_en, small_k_sz,
	               gentoken, tokenact, zremaskact, zremaskbits)
		variable v : reg_type;
		variable v_simkb : integer;
		variable v01z : std_logic_vector(1 downto 0);
	begin
		v := r;

		-- pragma translate_off
		v.sim.logr0r1 := '0';
		v.sim.logfinalresult := '0';
		-- pragma translate_on

		v.mty.computing_del := r.mty.computing;

		v.kp.iterate_shuffle_force := '0';

		v.pop.yesen := '0'; -- (s27)

		-- (s28)
		v.int.ar01zien := '0';

		-- ACKnowledge by software (transmitted through ecc_axi) of the on-curve
		-- tests possible error
		if aerr_inpt_ack = '1' then
			v.int.aerr_inpt_not_on_curve := '0';
		end if;
		if aerr_outpt_ack = '1' then
			v.int.aerr_outpt_not_on_curve := '0';
		end if;

		v.int.small_k_sz_en_ack := '0';
		-- acknowledge that ecc_axi has sent a new value of small_k_sz
		if small_k_sz_en_en = '1' then
			v.int.small_k_sz_en_ack := '1';
			v.ctrl.small_k_sz_en := small_k_sz_en;
		end if;

		v.int.small_k_sz_kpdone := '0'; -- (s54)

		-- ----------------------
		-- interface with ecc_axi
		-- ----------------------
		if r.ctrl.state = idle then
			if (r.int.ardy = '1' and agocstmty = '1') then
				-- trigger computation of the 1st Montgomery constant (-p^{-1} mod R)
				v.ctrl.state := cst;
				v.ctrl.active := '1';
				v.int.ardy := '0';
				v.int.faddr := EXEC_ADDR(CONSTMTY0_ROUTINE);
				v.mty.step := "00";
				v.int.fgo := '1'; -- (s69), see (s67)
				v.mty.computing := '1';
				v.mty.computing_a := '0';
				v.mty.done := '0';
				v.kp.laststep := '0';
				v.kp.firstzdbl := '0';
				v.kp.firstzaddu := '0';
			elsif (r.int.ardy = '1' and agomtya = '1') then
				-- trigger computation of 'a' parameter into Montgomery domain
				v.ctrl.state := cst;
				v.ctrl.active := '1';
				v.int.ardy := '0';
				v.int.faddr := EXEC_ADDR(AMONTY_ROUTINE); -- to start .aMontyL routine
				v.int.fgo := '1'; -- (s70), see (s67)
				v.mty.computing := '1';
				v.mty.computing_a := '1';
				v.mty.donea := '0';
			elsif (r.int.ardy = '1' and agokp = '1') then
				-- TODO: may be reduce the fan-out of ardy & agokp signals by
				-- creating a delayed version of their logic-and and have those
				-- of the registers below which do not have priority be set 1 cycle
				-- later with that register copy
				-- --------------------------------------------
				-- trigger start of an overall [k]P computation
				-- --------------------------------------------
				-- check that software configuration matches hardware static config.
				-- pragma translate_off
				v.sim.perfcnt := 0;
				v.sim.perfcnten := '1';
				-- pragma translate_on
				v.ctrl.state := set;
				-- (s19) asserts initkp for a short period (nominaly only 1 cycle)
				-- for ecc_curve to initialize a few internal signals - see (s20)
				v.kp.initkp := '1'; -- (s19)
				v.ctrl.active := '1';
				v.kp.computing := '1';
				v.int.ardy := '0';
				v.int.aerr_inpt_not_on_curve := '0';
				v.int.aerr_outpt_not_on_curve := '0';
				v.kp.done := '0';
				v.kp.laststep := '0';
				v.kp.firstzdbl := '0';
				v.kp.firstzaddu := '0';
				v.kp.zu := '0';
				v.kp.zc := '0';
				v.kp.pts_are_equal := '0';
				v.kp.pts_are_oppos := '0';
				v.kp.first3pz := '0';
				if r.ctrl.small_k_sz_en = '1' then
					v.kp.joye.nbbits :=
						resize(small_k_sz, log2(nn) + 1) - to_unsigned(3, log2(nn) + 1);
					-- deassert r.ctrl.small_k_sz_en to enforce the one-shot validity
					-- of "smaller size scalar" feature
					v.ctrl.small_k_sz_en := '0';
				elsif doblinding = '1' then
					v.kp.blind_nbbits := unsigned(blindbits);
					v.kp.joye.nbbits :=
						  resize(unsigned(blindbits), log2(nn) + 1)
						+ resize(nndyn_nnm3, log2(nn) + 1);
				else
					v.kp.joye.nbbits := resize(nndyn_nnm3, log2(nn) + 1);
				end if;
				-- pragma translate_off
				nnmax_joye_loop_s <= to_integer(v.kp.joye.nbbits);
				blbits_max_s <= to_integer(unsigned(blindbits));
				-- pragma translate_on
				if debug then -- statically resolved by synthesizer
					v.int.permuteundo := '0';
				end if;
				v.int.ar0zi := ar0zo;
				v.int.ar1zi := ar1zo;
				-- pragma translate_off
				if simkb /= 0 then
					assert simkb >= 3
						report "simkb parameter (ecc_pkg.vhd) must be >= 3"
							severity FAILURE;
					if simkb >= 3 then
						v_simkb := simkb - 3;
						v.kp.joye.nbbits := to_unsigned(v_simkb, log2(nn) + 1);
					end if;
				end if;
				v.sim.simbit := 1;
				-- pragma translate_on
				v.dbg.joyebit := std_nat(1, log2(2*nn - 1));
				v.dbg.nbstarvrndxyshuf := (others => '0');
				v.ctrl.r1z_init := ar1zo; -- state of R1 before starting [k]P saved here
				v.ctrl.r1z := ar1zo; -- as opposed to .r1z_init, this one now may evolve
				v.ctrl.r0z := '0';
				-- sample the state of scalar k as regards to its possible nullity
				-- (using k_is_null input signal driven by ecc_axi)
				v.kp.k_is_null := k_is_null;
			elsif (r.int.ardy = '1' and dopop = '1') then
				-- ----------------------------------
				-- trigger start of a point operation (other than [k]P)
				-- ----------------------------------
				v.int.ardy := '0';
				v.pop.done := '0';
				v.int.aerr_inpt_not_on_curve := '0';
				v.int.aerr_outpt_not_on_curve := '0';
				v.ctrl.active := '1';
				v.ctrl.state := pop;
				v.pop.check := '0';
				v.pop.equal := '0';
				v.pop.opp := '0';
				v.pop.add := '0';
				v.pop.dbl := '0';
				v.pop.neg := '0';
				case popid is
					when ECC_AXI_POINT_ADD =>
						v.int.faddr := EXEC_ADDR(ADDITION_BEGIN_ROUTINE); -- point addition
						v.pop.add := '1';
						v.pop.step := "00"; -- (s61)
						v.int.ptadd := '1';
					when ECC_AXI_POINT_DBL =>
						v.int.faddr := EXEC_ADDR(DOUBLE_ROUTINE); -- point doubling
						v.pop.dbl := '1';
					when ECC_AXI_POINT_CHK =>
						v.int.faddr := EXEC_ADDR(IS_ON_CURVE_ROUTINE); -- is point on curve?
						v.pop.check := '1';
					when ECC_AXI_POINT_NEG =>
						v.int.faddr := EXEC_ADDR(NEGATIVE_ROUTINE); -- compute -P
						v.pop.neg := '1';
					when ECC_AXI_POINT_EQU =>
						v.int.faddr := EXEC_ADDR(EQUALX_ROUTINE); -- are X-coords equal?
						v.pop.equal := '1';       -- (equality of Y-coords tested later)
						v.pop.step := "00"; -- (s62)
					when ECC_AXI_POINT_OPP =>
						v.int.faddr := EXEC_ADDR(EQUALX_ROUTINE); -- are X-coords equal?
						v.pop.opp := '1';       -- (opposition of Y-coords tested later)
						v.pop.step := "00"; -- (s63)
					when others =>
						null; -- no error, ids should be filtered by ecc_axi
				end case;
				-- sample now the possible null-state of R0 & R1 points (from signals
				-- ar[01]zo, which are driven by ecc_axi) so that even if SW changes
				-- these in the current of operation (it is possible in debug mode)
				-- the information will stay internally the same for both ecc_scalar
				-- and ecc_curve and we'll have consistant computation
				v.ctrl.r0z := ar0zo;
				v.ctrl.r1z := ar1zo;
				v.int.fgo := '1'; -- (s71), see (s67)
				v.pop.computing := '1';
				v.int.ar0zi := ar0zo;
				v.int.ar1zi := ar1zo;
			elsif (r.int.ardy = '1' and gentoken = '1') then
				-- ----------------------------------
				-- trigger generation of random token
				-- ----------------------------------
				v.int.ardy := '0';
				v.int.tokendone := '0';
				v.ctrl.active := '1';
				v.ctrl.state := tok;
				v.int.faddr := EXEC_ADDR(GET_TOKEN_ROUTINE);
				v.int.fgo := '1'; -- (s73), see (s67)
				-- Aim of (s110) below is to allow ecc_fp to access ecc_fp_dram
				-- memory when generating the random token
				v.int.token_generating := '1'; -- (s110)
			end if;
		end if;

		-- pragma translate_off
		if r.sim.perfcnten = '1' then
			v.sim.perfcnt := r.sim.perfcnt + 1;
		end if;
		-- pragma translate_on

		-- deassert fgo when ecc_curve (here acting as an agent) has
		-- acknowledged the request for execution of a program (that is
		-- when frdy = '1' at the same time we have fgo asserted high)
		if r.int.fgo = '1' and frdy = '1' then -- (s66)
			v.int.fgo := '0'; -- (s102)
		end if;

		-- ------------------------
		-- interface with ecc_curve
		-- ------------------------
		-- (s113) main state machine (based on r.ctrl.state).
		--        For the 'kp' state, sub state-machine (s1) also applies.
		v.int.permute := '0'; -- (s4)
		if r.int.fgo = '0' and frdy = '1' then -- (s67)
			-- means ecc_curve was triggered for a software routine execution
			-- by one of the r.int.fgo assertions (s69)-(s101) + (s111), then
			-- ecc_curve acknowledged that by asserting frdy while fgo was still
			-- high (see (s66)) and now the job by ecc_curve is completed, which
			-- is indicated by frdy asserted again with fgo having been deasserted
			-- in the meantime by (s102) 
			case r.ctrl.state is
				when cst =>
					if r.mty.computing_a = '0' then
						if r.mty.step = "00" then
							v.int.faddr := EXEC_ADDR(CONSTMTY1_ROUTINE);
							v.mty.step := "01";
							v.int.fgo := '1'; -- (s74), see (s67)
							v.mty.cntrshift := nndyn_nnp1;
						elsif r.mty.step = "01" then
							v.mty.cntrshift := r.mty.cntrshift - 1;
							if r.mty.cntrshift(log2(nn + 1) - 1) = '0' and
								v.mty.cntrshift(log2(nn + 1) - 1) = '1'
							then
								v.int.faddr := EXEC_ADDR(CONSTMTY2_ROUTINE);
								v.mty.step := "10";
							else
								-- r.int.faddr keeps its current value EXEC_ADDR(CONSTMTY1_ROUTINE)
								-- (no need to set it again), same for r.mty.step, it stays "01"
								null;
							end if;
							v.int.fgo := '1'; -- (s75), see (s67)
						elsif r.mty.step = "10" then
							v.ctrl.state := idle;
							v.mty.computing := '0';
							v.int.ardy := '1';
							v.mty.done := '1';
							v.ctrl.active := '0';
						end if;
					elsif r.mty.computing_a = '1' then
						v.ctrl.state := idle;
						v.mty.computing := '0';
						--v.mty.computing_a := '0'; --useless
						v.int.ardy := '1';
						v.mty.donea := '1';
						v.ctrl.active := '0';
					end if;
				when kp =>
					if r.kp.substate = exits then
						if tokenact = '0' then -- (s2)
							-- end of overall computation, return to idle state and notify
							-- ecc_axi that the result (computed [k]P point) is available
							-- for user/software to read
							v.ctrl.active := '0';
							v.ctrl.state := idle;
							v.kp.substate := idle;
							v.int.ardy := '1';
							v.kp.computing := '0';
						end if;
						-- pragma translate_off
						v.sim.logfinalresult := '1';
						v.sim.perfcnten := '0';
						-- pragma translate_on
						if r.kp.k_is_null = '1' -- the scalar was null to begin with
							-- TODO: remove next condition on .r1z_init (should not play role)
							or r.ctrl.r1z_init = '1' -- the point was null to being with
							or r.ctrl.r1z = '1' -- [k]P is null by computation
							-- TODO: the possible nullity of [k]P result should in the end
							-- only based on signal r.ctrl.r1z
						then
							-- [k]P is therefore also null
							v.int.ar1zi := '1';
						else
							v.int.ar1zi := '0';
						end if;
						v.int.ar01zien := '1';
						if r.ctrl.small_k_sz_en = '1' then
							v.int.small_k_sz_kpdone := '1'; -- asserted 1 cycle thx to (s54)
						end if;
					elsif r.kp.substate = token -- (s112)
						-- and tokenact = '1' -- useless (obviously true if .substate=token)
					then
						-- end of overall computation, return to idle state and notify
						-- ecc_axi that the result (computed [k]P point) is available
						v.ctrl.active := '0';
						v.ctrl.state := idle;
						v.kp.substate := idle;
						v.int.ardy := '1';
						v.kp.computing := '0';
					else
						-- nothing to do, ecc_curve acknowledgement is handled in the
						-- programs sub-state machine, see (s1) below
						null;
					end if;
				when tok =>
					v.ctrl.active := '0';
					v.ctrl.state := idle;
					v.int.ardy := '1';
					v.int.tokendone := '1';
					v.int.token_generating := '0';
				when pop =>
					-- (s24) - following assignments on .active./.state/.ardy/.pop.done/
					-- .computing have possible bypasses in (s25), (s26) & (s60) below
					v.ctrl.active := '0';
					v.ctrl.state := idle;
					v.int.ardy := '1';
					v.pop.done := '1';
					v.pop.computing := '0';
					-- handle specific cases of point tests (is point on curve?
					-- are points equal? are points opposite?)
					if r.pop.check = '1' then
						-- ----------------------------------------
						-- operation was to CHECK if point ON CURVE
						-- ----------------------------------------
						if r.ctrl.r0z = '1' then -- point R0 was null to begin with
							v.pop.yes := '1'; -- therefore it belongs to the curve
							v.pop.yesen := '1'; -- stays asserted only 1 cycle thx to (s27)
						elsif r.ctrl.r0z = '0' then -- point R0 was not null
							v.pop.yes := zero; -- result depends on arithmetic computations
							v.pop.yesen := '1'; -- stays asserted only 1 cycle thx to (s27)
						end if;
					elsif r.pop.add = '1' then
						-- ------------------------
						-- operation is a point ADD
						-- ------------------------
						if r.pop.step = "00" then
							v.pop.step(0) := '1';
							-- ---------------------------------------------------------
							-- ecc_curve has just finished executing .pre_zadduL routine
							-- ---------------------------------------------------------
							v.kp.pts_are_equal := xmxz and ymyz;
							v.kp.pts_are_oppos := xmxz and not ymyz;
							if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' -- both points non null
								and xmxz = '1' and ymyz = '1' -- R0 = R1 (pts are equal)
							then
								-- R0 = R1 are equal, we need to call ZDBL to handle this case
								v.int.faddr := EXEC_ADDR(ZDBLSW_ROUTINE);
							else
								-- all other cases, including:
								--   R0 and R1 are neither equal nor different nor null
								--   R0 and R1 are opposite (and both non null)
								--   R0 = 0 (and R1 is not)
								--   R1 = 0 (and R0 is not)
								--   R0 = R1 = 0
								-- are covered by calling ZADDU.
								-- The differences will be handled in state 'r.pop.step = 10',
								-- see (s65) below
								v.int.faddr := EXEC_ADDR(ZADDU_ROUTINE);
							end if;
							v.int.fgo := '1'; -- (s77), see (s67)
							-- (s26), following statements are bypasses of the ones
							-- in (s24) above
							v.ctrl.active := '1';
							v.ctrl.state := pop;
							v.int.ardy := '0';
							v.pop.done := '0';
							v.pop.computing := '1';
						elsif r.pop.step = "01" then
							v.int.faddr := EXEC_ADDR(ADDITION_END_ROUTINE);
							v.int.fgo := '1'; -- (s78), see (s67)
							-- (s60), following statements are bypasses of the ones
							-- in (s24) above
							v.ctrl.active := '1';
							v.ctrl.state := pop;
							v.int.ardy := '0';
							v.pop.done := '0';
							v.pop.computing := '1';
							v.pop.step := "10";
						elsif r.pop.step = "10" then -- (s65)
							v.int.ptadd := '0';
							-- no bypasses here, (s24) statements are legitimate
							v01z := r.ctrl.r1z & r.ctrl.r0z;
							case v01z is
								when "00" =>
									-- neither R0 nor R1 input points were null to begin with
									-- we need to catch if the resulting P + Q point happens to be
									-- the null point, which can happen in two and only two cases:
									-- if the input points were equal and this common point happe-
									-- ned to be a 2-torsion point; and if the input points were
									-- opposite.
									-- Input signals xmxz and ymyz (driven by ecc_curve) are valid
									-- because routine .pre_zadduL was executed prior (while in
									-- "state" r.pop.step = 0)
									if xmxz = '1' and ymyz = '1' then
										-- input points were equal, the result is null iff input
										-- torsion2 is asserted by ecc_curve
										v.int.ar1zi := torsion2;
										v.int.ar01zien := '1'; -- asserted only 1 cycle thx to (s28)
									elsif xmxz = '1' and ymyz = '0' then
										-- input points were opposite, the result is null
										v.int.ar1zi := '1';
										v.int.ar01zien := '1'; -- asserted only 1 cycle thx to (s28)
									end if;
								when "01" =>
									-- R0 was null, R1 was not
									-- patch mechanism in ecc_curve has ensured that coordinates
									-- XR1 & YR1 of output point R1 have in fact been overwritten,
									-- at the end of routine .additionL, with what they were when
									-- point addition operation was started
									-- both points R0 & R1 stays in the same state, we don't even
									-- assert ar01zien
									null;
								when "10" =>
									-- R1 was null, R0 was not
									-- patch mechanism in ecc_curve has ensured that coordinates
									-- XR1 & YR1 of output point R1 have in fact been overwritten,
									-- at the end of routine .additionL, with values of XR0 & YR0
									-- at the time point addition operation was started
									-- R1 is no longer null (nor R0 but no need to set it)
									v.int.ar1zi := '0';
									v.int.ar01zien := '1'; -- stays asserted 1 cycle thx to (s28)
								when "11" =>
									-- both R0 & R1 were null, they stay so
									null;
								when others => null;
							end case;
							-- v.pop.step := '0'; -- no need to reset r.pop.step, this will
							-- be done by either (s61), (s62) or (s63)
						end if; -- r.pop.step
					elsif r.pop.dbl = '1' then
						-- -------------------------
						-- operation was a point DBL
						-- -------------------------
						-- since R1 <- [2]R0, R1 gets the state (regarding nullity) that
						-- R0 was showing at the time computation was set OR it is set
						-- to nullity if R0 was detected to be a 2-torsion point
						v.int.ar1zi := r.ctrl.r0z or torsion2;
						v.int.ar01zien := '1'; -- stays asserted 1 cycle thx to (s28)
					elsif r.pop.neg = '1' then
						-- -------------------------
						-- operation was a point NEG
						-- -------------------------
						-- since R1 <- -R0, R1 gets the state (regarding nullity) that
						-- R0 was showing at the time computation was set
						v.int.ar1zi := r.ctrl.r0z;
						v.int.ar01zien := '1'; -- stays asserted 1 cycle thx to (s28)
					elsif r.pop.equal = '1' or r.pop.opp = '1' then
						-- -----------------------------------------------------
						-- operation was to TEST is points are EQUAL or OPPOSITE
						-- -----------------------------------------------------
						if r.pop.step(0) = '0' then
							v.pop.step(0) := '1';
							if zero = '1' then -- X coordinates of the 2 points are equal
								v.pop.equalx := '1';
							elsif zero = '0' then
								v.pop.equalx := '0';
							end if;
							-- now execute second routine .equalYL (if r.pop.equal = 1)
							-- or .oppYL (if r.pop.opp = 1)
							v.ctrl.state := pop;
							if r.pop.equal = '1' then
								-- now test if YR0 == YR1
								v.int.faddr := EXEC_ADDR(EQUALY_ROUTINE); -- .equalYL routine
							elsif r.pop.opp = '1' then
								-- now test if YR0 == -YR1
								v.int.faddr := EXEC_ADDR(OPPOSITEY_ROUTINE); -- .oppYL routine
							end if;
							v.int.fgo := '1'; -- (s79), see (s67)
							-- (s25), following statements are bypasses of the ones
							-- in (s24) above
							v.int.ardy := '0';
							v.pop.done := '0';
							v.ctrl.active := '1';
							v.ctrl.state := pop;
							v.pop.computing := '1';
						elsif r.pop.step(0) = '1' then
							-- the R0 & R1 nullity tests take precedence over computations
							v01z := r.ctrl.r1z & r.ctrl.r0z;
							case v01z is
								when "00" =>
									-- neither R0 nor R1 input points were null, so the result
									-- of arithmetic computations is pertinent
									if zero = '1' and r.pop.equalx = '1' then
										v.pop.yes := '1';
										v.pop.yesen := '1'; -- stays high only 1 cycle thx to (s27)
									elsif zero = '0' or r.pop.equalx = '0' then
										v.pop.yes := '0';
										v.pop.yesen := '1'; -- stays high only 1 cycle thx to (s27)
									end if;
								when "01" =>
									-- R0 was null, R1 was not: points can't be equal
									v.pop.yes := '0';
									v.pop.yesen := '1'; -- stays high only 1 cycle thx to (s27)
								when "10" =>
									-- R1 was null, R0 was not: points can't be equal
									v.pop.yes := '0';
									v.pop.yesen := '1'; -- stays high only 1 cycle thx to (s27)
								when "11" =>
									-- both R0 & R1 were null, they are equal
									v.pop.yes := '1';
									v.pop.yesen := '1'; -- stays high only 1 cycle thx to (s27)
								when others => null;
							end case;
							-- v.pop.step(0) := '0'; -- no need to reset r.pop.step, this will
							-- be done by either (s61), (s62) or (s63)
						end if;
					end if;
				when others => null; -- TODO: treat this as an error
			end case; -- r.ctrl.state
		end if; -- fgo = 0 + frdy = 1

		-- the 'set' state is special, as it always only lasts 1 clock cycle,
		-- which is why it is handled outside of the fgo/frdy handshake with
		-- ecc_curve (handled 
		if r.ctrl.state = set then
			v.kp.initkp := '0'; -- (s20), see (s19)
			v.ctrl.state := kp;
			v.kp.substate := checkoncurve;
			v.int.faddr := EXEC_ADDR(CHKCURVE_ROUTINE); -- (s0)
			v.int.fgo := '1'; -- (s76), see (s67)
		end if;

		-- (s1) program sequence state machine (based on r.kp.substate)
		--      This can be seen as a substate machine of the main one (see (s113))
		--      which applies to the (r.ctrl.)state value 'kp'.
		-- Handle sequential execution of the different programs involved in
		-- one complete [k]P computation.
		-- A program is assumed to have been executed completely by ecc_curve
		-- when ecc_curve asserts 'frdy' high again after we have deasserted
		-- 'fgo' (which implies that ecc_curve should deassert 'frdy' as soon as
		-- it has monitored its input 'fgo' to a logic high, since ecc_scalar might
		-- deassert 'fgo' just the cycle after it has asserted it in the case
		-- where 'frdy' was positionned high by default by ecc_curve)
		if r.ctrl.state = kp and r.int.fgo = '0' and frdy = '1' then -- (s7)
			-- (s1) program sequence state machine (based on r.kp.substate)
			case r.kp.substate is
				-- -----------------------------------------------------
				-- checkoncurve: check given initial point P is on curve
				-- -----------------------------------------------------
				when checkoncurve =>
					if doblinding = '1' then
						-- switch from 'checkoncurve' state to 'blindinit' state
						v.int.faddr := EXEC_ADDR(BLINDSTART_ROUTINE);
						v.kp.substate := blindinit;
					elsif doblinding = '0' then
						-- switch from 'checkoncurve' state to 'adpa' state
						v.int.faddr := EXEC_ADDR(ADPA_ROUTINE);
						v.kp.substate := adpa;
					end if;
					v.int.fgo := '1'; -- (s80), see (s67)
					if r.ctrl.r1z = '1' then
						-- R1 being null from start of computation, the check-on-curve
						-- test is assumed to be TRUE with no regards as to the result of
						-- computations on coordinates
						v.int.aerr_inpt_not_on_curve := '0'; -- no error (0-pt is on curve)
					elsif r.ctrl.r1z = '0' then
						if zero = '0' then -- input point is not null and is NOT on curve
							-- error (= input point NOT on curve)
							v.int.aerr_inpt_not_on_curve := '1';
						elsif zero = '1' then
							-- no error
							v.int.aerr_inpt_not_on_curve := '0';
						end if;
					end if;
				-- ----------------------------------------------------
				-- blindinit: initialization of blinding countermeasure
				-- ----------------------------------------------------
				when blindinit =>
					-- switch from 'blindinit' state to 'blindbit' state, to loop
					-- on the bits of the random blinding value in order to mask,
					-- or blind, the private scalar
					v.int.faddr := EXEC_ADDR(BLNBIT_ROUTINE);
					v.kp.substate := blindbit;
					v.int.fgo := '1'; -- (s81), see (s67)
					-- pragma translate_off
					v.sim.simblbit := 0;
					-- pragma translate_on
				-- ---------------------------------------------------
				-- blindbit: one call per bit of random blinding coeff
				-- ---------------------------------------------------
				when blindbit => 
					-- this state is looped a number of times equal to the number
					-- of bits which the random blinding number ("alpha") is made of
					v.kp.blind_nbbits := r.kp.blind_nbbits - 1;
					if r.kp.blind_nbbits = to_unsigned(1, log2(nn)) then
						-- blinding of the private scalar is now complete, switch to
						-- next program .blindstopL ('blindexit' substate)
						v.int.faddr := EXEC_ADDR(BLINDSTOP_ROUTINE);
						v.kp.substate := blindexit;
						v.int.fgo := '1'; -- (s82), see (s67)
					else
						-- run the program again
						-- (r.int.faddr is still set to ECC_IRAM_BLNBIT_ADDR)
						-- (r.kp.substate is still set to 'blindbit')
						v.int.fgo := '1'; -- (s83), see (s67)
						-- pragma translate_off
						v.sim.simblbit := r.sim.simblbit + 1;
						-- pragma translate_on
					end if;
				when blindexit =>
					-- post-processing of blinding is done, switch to
					-- next program: "ADPA init" ('adpa' substate)
					v.int.faddr := EXEC_ADDR(ADPA_ROUTINE);
					v.kp.substate := adpa;
					v.int.fgo := '1'; -- (s84), see (s67)
				-- -------------------------------------------------
				-- adpa: prepare Anti Address-Bit DPA countermeasure
				-- -------------------------------------------------
				when adpa =>
					-- switch from 'adpa' state to 'ssetup' state
					v.int.faddr := EXEC_ADDR(DRAWZ_ROUTINE);
					v.kp.substate := ssetup;
					-- r.kp.ssetup_step is used to differentiate between 1st, 2nd
					-- & 3rd pass of 'ssetup' state: here we set it low to "00" as
					-- we're starting the 1st pass
					v.kp.ssetup_step := "00";
					v.kp.firstzdbl := '1';
					v.int.fgo := '1'; -- (s85), see (s67)
				-- -----------------------------------------------------
				-- ssetup: enter  Montgomery domain,  switch to Jacobian
				--         coordinates, compute [2]P & [3]P, set R0 & R1
				--         to be Co-Z
				-- -----------------------------------------------------
				when ssetup =>
					if r.kp.ssetup_step = "00" then
						if zero = '1' then
							-- this means that lambda random is null - this is not acceptable
							-- (despite the fact that it probably indicates a tampering of the
							-- hardware, it will cause arithmetical error when passing point
							-- coords into Jacobian form)
							-- retry drawing lots
							--v.int.faddr := EXEC_ADDR(DRAWZ_ROUTINE); useless (still set)
							--v.kp.ssetup_step := "00"; useless (still set)
							v.int.fgo := '1'; -- (s86), see (s67)
						elsif zero = '0' then
							-- lambda random is not null
							v.int.faddr := EXEC_ADDR(SETUP_ROUTINE);
							v.int.fgo := '1'; -- (s87), see (s67)
							-- we stay in the same 'ssetup' state, but the 2nd pass (switch to
							-- Mont. & Jacobian domains, including a call to .pre_zaddU routine
							-- in order to prepare the 3rd & last step) is enforced by asserting
							-- .kp.ssetup_step to "01"
							v.kp.ssetup_step := "01";
						end if;
					elsif r.kp.ssetup_step = "01" then
						-- ----------------------------------
						-- 1st pass of state 'ssetup' is done
						-- ----------------------------------
						-- we just have finished executing the .pre_zadduL routine that the
						-- code of .setupL has branched to at its end
						if r.ctrl.r1z = '1' then
							-- P was the null point to begin with
							v.ctrl.r0z := '1';
							-- we execute .zadduL but as a dummy operation
						elsif r.ctrl.r1z = '0' then
							-- P is not the null point
							-- There is no need to detect if [2]P == P (this would mean that
							-- software gave us the null point without telling us so: this
							-- is not possible because the only way to give us the null point
							-- it to tell it through metadata: software gives us point P
							-- using affine coordinates, and there is no representation of
							-- the null point in affine coordinates)
							-- Hence: [2]P and P are not equal
							v.kp.pts_are_equal := '0';
							-- but [2]P might be null if P is a 2-torsion point, which is
							-- the case if ecc_curve asserts signal 'first2pz' (as a result
							-- of patch ,p56 in .zdblL)
							v.ctrl.r0z := first2pz;
							-- points [2]P and P might also be opposite (meaning [3]P = 0,
							-- that is P is a 3-torsion point). In this situation there is
							-- no need to specifically call routine .zdblL, we simply call
							-- .zadduL as a dummy operation
							-- if this case we must also drive output 'first3pz' high to
							-- ecc_curve so that patches in .zadduL ensure proper processing
							v.kp.first3pz := xmxz and not ymyz; -- (s55) R0 = -R1
						end if;
						-- R1 still holds point P after .zdblL (& .pre_zadduL) execution
						v.int.faddr := EXEC_ADDR(ZADDU_ROUTINE);
						v.int.fgo := '1'; -- (s88), see (s67)
						v.kp.firstzdbl := '0';
						v.kp.firstzaddu := '1';
						-- we stay in the same 'ssetup' state, but the 3rd pass (executing
						-- zaddU routine in order to perform [3]P <- [2]P + P) is enforced
						-- by asserting .kp.ssetup_step to "10"
						v.kp.ssetup_step := "10";
						v.kp.zu := '1'; --TODO: is it necessary?
						-- pragma translate_off
						v.sim.logr0r1 := '1';
						v.sim.logr0r1step := 0;
						-- pragma translate_on
					elsif r.kp.ssetup_step = "10" then
						-- ----------------------------------
						-- 2nd pass of state 'ssetup' is done
						-- ----------------------------------
						-- we just have finished executing the .zadduL routine called
						-- as the 2nd part of the state 'ssetup', in order to compute
						-- ([2]P, P) -> ([3]P, P)
						v.kp.ssetup_step := "00";
						v.int.faddr := EXEC_ADDR(ITOH_ROUTINE); -- (s9)
						v.kp.firstzaddu := '0';
						--v.kp.firstitoh := '1';
						v.kp.substate := joyecoz;
						v.kp.joye.state := itoh;
						v.int.fgo := '1'; -- (s89), see (s67)
						-- pragma translate_off
						v.sim.logr0r1 := '1';
						v.sim.logr0r1step := 1;
						-- pragma translate_on
						--if iterate_shuffle_rdy = '1' then
						--	-- switch from 'ssetup' state to 'switch3p' state
						--	v.kp.substate := switch3p;
						--	v.int.fgo := '1'; -- (s90), see (s67)
						--	-- pragma translate_off
						--	v.sim.logr0r1 := '1';
						--	v.sim.logr0r1step := 1;
						--	-- pragma translate_on
						--elsif iterate_shuffle_rdy = '0' then
						--	v.kp.substate := wait_xyr01_permute;
						--	v.kp.nextsubstate := switch3p;
						--end if;
						if kap = '0' then
							-- R0 contains initial point P, so it is non null if P isn't
							v.ctrl.r0z := r.ctrl.r1z_init;
							-- R1 contains [3]P, which is null iif P is a 3-torsion point
							-- Remark: obviously [3]P would also be the null point if initial
							-- point P was null to begin with. However we can't rely on signal
							-- r.kp.first3pz to be asserted when P is null, because signal
							-- r.kp.first3pz is based on input xmxz and ymyz (see (s55) above)
							-- that ecc_curve drives on the basis of arithmetic computations
							-- made on actual points coordinates. Now when P is null to begin
							-- with, point coordinates in ecc_fp_dram contain random noise,
							-- because the information that P is null is not encoded in its
							-- coordinates but only by the fact that software driver has
							-- written the W_R1_NULL register (see ecc_axi.vhd).
							-- We don't need r.ctrl.r1z to be asserted here when P is ini-
							-- tially 0. The final result [k]P will simply tagged as null
							-- when whole computation is over at the end of 'exits state',
							-- see (s64) below
							v.ctrl.r1z := r.kp.first3pz; -- set by (s55)
						elsif kap = '1' then
							-- R0 contains [3]P, which is null iif P is a 3-torsion point
							-- or if initial point P was null to begin with (same remarks
							-- apply as discussed just above for the kap = 0 case)
							v.ctrl.r0z := r.kp.first3pz;
							-- R1 contains initial point P, so it is non null if P isn't
							v.ctrl.r1z := r.ctrl.r1z_init;
						end if;
						-- If needed, initialize the Z-remasking counter.
						if zremaskact = '1' then
							v.kp.zrmcnt := zremaskbits;
						end if;
					end if;
				-- ------------------------
				-- Joye Double-&-Add always (s5), see also (s6)
				-- ------------------------
				when joyecoz => 
					-- this state is looped a number of times equal to the number of
					-- bits which the blinded scalar number is made of (that is, the
					-- number of bits of the private scalar + the number of bits of
					-- the random blinding number if blinding is active, or simply
					-- the number of bits of the private scalar if it is not)
					if r.kp.joye.state = itoh then
						-- -------------------------------------------
						--                 end of ITOH
						-- -------------------------------------------
						v.int.faddr := EXEC_ADDR(PRE_ZADDU_ROUTINE); -- (s10)
						if iterate_shuffle_rdy = '1' then
							-- enter Joye FSM state 'prezaddu'
							v.kp.joye.state := prezaddu; -- (s12)
							v.int.fgo := '1'; -- (s91), see (s67)
							--if r.kp.firstitoh = '1' then
							--	v.kp.firstitoh := '0';
							--elsif r.kp.firstitoh = '0' then
							v.kp.iterate_shuffle_valid := '1';
							--end if;
							-- pragma translate_off
							v.sim.simbit := r.sim.simbit + 1;
							-- pragma translate_on
							v.dbg.joyebit := std_logic_vector(unsigned(r.dbg.joyebit) + 1);
						elsif iterate_shuffle_rdy = '0' then
							-- random is not available yet to ensure shuffle of [XR]R[01]
							-- coords, switch from substate joyecoz to wait_xyr01_permute.
							-- Having not set r.kp.joye.state to prezaddu (see (s12) just
							-- above) and instead having kept it to 'itoh' will ensure that
							-- logic described by (s13) below recognizes we entered substate
							-- 'wait_xyr01_permute' to prepare an itoh-to-prezaddu transition
							-- rather than a zaddu-to-prezaddc one.
							v.kp.substate := wait_xyr01_permute;
							v.kp.nextsubstate := joyecoz; -- (s14)
							v.dbg.nbstarvrndxyshuf := std_logic_vector(
								unsigned(r.dbg.nbstarvrndxyshuf) + 1);
						end if;
					elsif r.kp.joye.state = prezaddu then
						-- -------------------------------------------
						--             end of pre-ZADDU
						-- -------------------------------------------
						if (r.ctrl.r0z xor r.ctrl.r1z) = '1' then
							v.kp.pts_are_equal := '0';
							v.kp.pts_are_oppos := '0';
						else
							v.kp.pts_are_equal := xmxz and ymyz; -- (s45)
							v.kp.pts_are_oppos := xmxz and not ymyz; -- (s46)
						end if;
						v.int.faddr := EXEC_ADDR(ZADDU_ROUTINE); -- (s31), bypassed by (s33)
						v.kp.joye.state := zaddu; -- (s32), bypassed by (s34)
						v.kp.zu := '1';
						v.int.fgo := '1'; -- (s92), see (s67)
						-- if the two points R0 & R1 are equal (and non null), we must
						-- call .zdblL instead of .zadduL (and switch to zdblu state
						-- instead of zaddu)
						-- Note that otherwise, all other cases, including:
						--   - pts R0 & R1 are opposite and both non null
						--   - R0 = 0 but not R1
						--   - R1 = 0 but not R0
						--   - R0 = R1 = 0
						-- are supported by calling the zaddU routine as in the nominal case
						-- (see (s31) just above)
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' -- neither XR0 nor XR1 is 0
							and xmxz = '1' and ymyz = '1' -- R0 = R1 (pts are equal)
						then
							-- we need to call ZDBL to handle this case
							v.int.faddr := EXEC_ADDR(ZDBL_ROUTINE); -- (s33), bypass of (s31)
							v.kp.joye.state := zdblu; -- (s34), bypass of (s32)
						end if;
					elsif r.kp.joye.state = zaddu then
						-- -------------------------------------------
						--                end of ZADDU
						-- -------------------------------------------
						v.int.faddr := EXEC_ADDR(PRE_ZADDC_ROUTINE); -- (s11)
						if iterate_shuffle_rdy = '1' then
							v.kp.joye.state := prezaddc; -- (s17)
							v.int.fgo := '1'; -- (s93), see (s67)
							v.kp.iterate_shuffle_valid := '1';
							-- pragma translate_off
							v.sim.logr0r1 := '1';
							v.sim.logr0r1step := 2;
							-- pragma translate_on
						elsif iterate_shuffle_rdy = '0' then
							-- switch from substate joyecoz to wait_xyr01_permute.
							-- Having not set r.kp.joye.state to prezaddc (see (s17) just
							-- above) and instead having kept it to 'zaddu' will ensure that
							-- logic described by (s18) below will recognize that we entered
							-- substate 'wait_xyr01_permute' for preparing a zaddu-to-prezaddc
							-- Joye-state transition
							v.kp.substate := wait_xyr01_permute;
							v.kp.nextsubstate := joyecoz; -- (s16)
							v.dbg.nbstarvrndxyshuf := std_logic_vector(
								unsigned(r.dbg.nbstarvrndxyshuf) + 1);
						end if;
						-- compute new nullity flags for R0 & R1.
						-- Independently of whether we're entering immediately prezaddc
						-- joye-state or temporarily switching to state wait_xyr01_permute,
						-- we set the zero flags according to:
						--    - r.kp.pts_are_[equal/oppos] signals which were set at the
						--      end of prezaddu state
						--    - r.ctrl.r[01]z
						--    - kap & kapp inputs (driven by ecc_curve), also used in patchs
						--    - (torsion2 plays no role here, only in ZDBL - see below)
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' then
							-- neither R0 nor R1 were null when starting ZADDU
							if r.kp.pts_are_equal = '1' then -- was set by (s45)
								assert (FALSE)
									report "ERROR - points were equal in pre-ZADDU: "
									& "we shouldn't be at the end of ZADDU but at the "
									& "end of ZDBLU!"
										severity FAILURE;
							elsif r.kp.pts_are_oppos = '1' then -- was set by (s46)
								if kapp = '0' then
									-- v.ctrl.r0z := '0' -- useless (R0 wasn't null, it stays so)
									v.ctrl.r1z := '1'; -- R1 is now null
								elsif kapp = '1' then
									v.ctrl.r0z := '1'; -- R0 is now null
									-- v.ctrl.r1z := '0' -- useless (R1 wasn't null, it stays so)
								end if;
							else
								-- points were neither equal nor opposite (and non null)
								-- so they stay non-null
								--v.ctrl.r0z := '0'; -- useless (R0 wasn't null, it stays so)
								--v.ctrl.r1z := '0'; -- useless (R0 wasn't null, it stays so)
								null;
							end if;
						elsif r.ctrl.r0z = '0' and r.ctrl.r1z = '1' then
							-- R0 was non null, but R1 was, when starting ZADDU
							if kapp = '0' then
								v.ctrl.r0z := '1'; -- R0 is now null
								v.ctrl.r1z := '0'; -- R1 is not null anymore
							elsif kapp = '1' then
								-- v.ctrl.r0z := '0' -- useless (R0 wasn't null, it stays so)
								v.ctrl.r1z := '0'; -- R1 is not null anymore
							end if;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '0' then
							-- R0 was null, and R1 wasn't, when starting ZADDU
							if kapp = '0' then
								v.ctrl.r0z := '0'; -- R0 is not null anymore
								-- v.ctrl.r1z := '0' -- useless (R1 wasn't null, it stays so)
							elsif kapp = '1' then
								v.ctrl.r0z := '0'; -- R0 is not null anymore
								v.ctrl.r1z := '1'; -- R1 is now null
							end if;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '1' then
							-- R0 & R1 were both null when starting ZADDU
							--v.ctrl.r0z := '1'; -- useless (R0 was null, it stays so)
							--v.ctrl.r1z := '1'; -- useless (R1 was null, it stays so)
							null;
						end if;
					elsif r.kp.joye.state = zdblu then
						-- -------------------------------------------
						--                end of ZDBLU
						-- -------------------------------------------
						v.int.faddr := EXEC_ADDR(PRE_ZADDC_ROUTINE); -- (s37)
						if iterate_shuffle_rdy = '1' then
							v.kp.joye.state := prezaddc; -- (s35)
							v.int.fgo := '1'; -- (s94), see (s67)
							v.kp.iterate_shuffle_valid := '1';
							-- pragma translate_off
							v.sim.logr0r1 := '1';
							v.sim.logr0r1step := 2;
							-- pragma translate_on
						elsif iterate_shuffle_rdy = '0' then
							-- switch from substate itoh to wait_xyr01_permute.
							-- Having not set r.kp.joye.state to prezaddc (see (s35) just
							-- above) and instead having kept it to 'zdblu' will ensure that
							-- logic described by (s36) below will recognize that we entered
							-- substate 'wait_xyr01_permute' for preparing a zdblu-to-prezaddc
							-- Joye-state transition
							v.kp.substate := wait_xyr01_permute;
							v.kp.nextsubstate := joyecoz; -- (s38)
							v.dbg.nbstarvrndxyshuf := std_logic_vector(
								unsigned(r.dbg.nbstarvrndxyshuf) + 1);
						end if;
						-- compute new nullity flags for R0 & R1
						-- independently of whether we're entering immediately prezaddc
						-- joye-state (or temporarily switching to state wait_xyr01_permute)
						-- we set the zero flags according to:
						--    - r.kp.pts_are_[equal/oppos] signals which were set at the
						--      end of prezaddu state
						--    - r.ctrl.r[01]z
						--    - kap & kapp inputs (driven by ecc_curve), also used in patchs
						--    - torsion2 input (driven by ecc_curve)
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' then
							if r.kp.pts_are_equal = '1' then -- was set by (s45)
								if kapp = '1' then
									-- whether or not R0 is null is conditioned by result of ZDBL
									v.ctrl.r0z := torsion2;
									-- v.ctrl.r1z := '0'; -- useless (R1 wasn't null, it stays so)
								elsif kapp = '0' then
									-- v.ctrl.r0z := '0' -- useless (R0 wasn't null, it stays so)
									v.ctrl.r1z := torsion2; -- depends on 2-torsion detect in ZDBL
								end if;
							elsif r.kp.pts_are_oppos = '1' then -- was set by (s46)
								-- pragma translate_off
								assert (FALSE)
									report "ERROR - points were opposite in pre-ZADDU: "
									& "we shouldn't be at the end of ZDBLU but at the "
									& "end of ZADDU"
										severity FAILURE;
								-- pragma translate_on
								null;
							else
								-- pragma translate_off
								assert (FALSE)
									report "ERROR - R0 & R1 were neither equal nor opposite "
									& "in pre-ZADDU: we shouldn't be at the end of ZDBLU "
									& "but of ZADDU instead"
										severity FAILURE;
								-- pragma translate_on
								null;
							end if;
						elsif r.ctrl.r0z = '0' and r.ctrl.r1z = '1' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 was not null but R1 was in pre-ZADDU: "
								& "we shouldn't be at the end of ZDBLU but of ZADDU instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '0' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 was null with R1 non-null in pre-ZADDU: "
								& "we shouldn't be at the end of ZDBLU but of ZADDU instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '1' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 & R1 were both null in pre-ZADDU: "
								& "we shouldn't be at the end of ZDBLU but of ZADDC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						end if;
					elsif r.kp.joye.state = zaddc then
						-- Unlike the end of zdblc & znegc, the flags r[01]z need not be
						-- modified at the end of zaddc (they were null when we called
						-- zaddc, meaning none of R0/R1 was null, and they need to stay so)
						null; -- the processing of the end of ZADDC is made below in (s49)
						      -- since it is common to zdblc & znegc
					elsif r.kp.joye.state = prezaddc then
						-- -------------------------------------------
						--             end of pre-ZADDC
						-- -------------------------------------------
						if (r.ctrl.r0z xor r.ctrl.r1z) = '1' then
							v.kp.pts_are_equal := '0';
							v.kp.pts_are_oppos := '0';
						else -- if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' then
							v.kp.pts_are_equal := xmxz and ymyz; -- (s47)
							v.kp.pts_are_oppos := xmxz and not ymyz; -- (s48)
						end if;
						v.int.faddr :=
							EXEC_ADDR(ZADDC_ROUTINE); -- (s39), bypassed by (s41) & (s43)
						v.kp.joye.state := zaddc; -- (s40), bypassed by (s42) & (s44)
						v.kp.zu := '0';
						v.kp.zc := '1';
						v.int.fgo := '1'; -- (s95), see (s67)
						-- if the two points R0 & R1 are either equal or opposite
						-- (and non null), we must call .zdblL instead of .zaddcL
						-- (and switch to zdblc state instead of zaddc)
						-- Likewise, if one of R0 and R1 is null (and not the other)
						-- we must call .negativeL instead of .zaddcL
						-- (and switch to znegc state instead of zaddc)
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' -- neither XR0 nor XR1 = 0
							and ((xmxz = '1' and ymyz = '1') -- R0 = R1 (pts are equal)
									 or (xmxz = '1' and ymyz = '0')) -- R0 = -R1 (opposite pts)
							then
							-- we need to call .zdblL to handle this case
							v.int.faddr := EXEC_ADDR(ZDBL_ROUTINE); -- (s41), bypass of (s39)
							v.kp.joye.state := zdblc; -- (s42), bypass of (s40)
						elsif (r.ctrl.r0z = '0' and r.ctrl.r1z = '1') or
						      (r.ctrl.r0z = '1' and r.ctrl.r1z = '0')
							then
							-- we need to call .negativeL to handle this case
							v.int.faddr := EXEC_ADDR(ZNEGC_ROUTINE); -- (s43), bypass of (s39)
							v.kp.joye.state := znegc; -- (s44), bypass of (s40)
						end if;
						-- note that in case both R1 and R1 are null, the situation is
						-- "handled" artificially by going through .zaddcL routine (see
						-- (s39) above) as some kind of dummy operation (both points being
						-- null means that all mathematical computation are useless from
						-- now on)
					elsif r.kp.joye.state = zdblc then
						-- -------------------------------------------
						--                end of ZDBLC
						-- -------------------------------------------
						-- here we only set r.ctrl.r0z & r.ctrl.r1z. Portion of code (s49)
						-- below, which is common to end of zaddc, zdblc & znegc, will
						-- handle possible end of scalar loop.
						--
						-- (s50) - compute new nullity flags for R0 & R1
						-- i.e set the zero flags according to:
						--    - r.kp.pts_are_[equal/oppos] signals which were set at the
						--      end of prezaddu state
						--    - r.ctrl.r[01]z
						--    - kap & kapp inputs (driven by ecc_curve), also used in patchs
						--    - torsion2 input (driven by ecc_curve)
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' then
							if r.kp.pts_are_equal = '1' then -- was set by (s47)
								if kap = '0' then
									v.ctrl.r0z := '1'; -- R0 is now null
									v.ctrl.r1z := torsion2; -- depends on 2-torsion detect in ZDBL
								elsif kap = '1' then
									v.ctrl.r0z := torsion2; -- depends on 2-torsion detect in ZDBL
									v.ctrl.r1z := '1'; -- R1 is now null
								end if;
							elsif r.kp.pts_are_oppos = '1' then -- was set by (s48)
								if kap = '0' then
									v.ctrl.r0z := torsion2; -- depends on 2-torsion detect in ZDBL
									v.ctrl.r1z := '1'; -- R1 is now null
								elsif kap = '1' then
									v.ctrl.r0z := '1'; -- R0 is now null
									v.ctrl.r1z := torsion2; -- depends on 2-torsion detect in ZDBL
								end if;
							else
								-- pragma translate_off
								assert (FALSE)
									report "ERROR - R0 & R1 were neither equal nor opposite "
									& "in pre-ZADDC: we shouldn't be at the end of ZDBLC "
									& "but of ZADDC instead"
										severity FAILURE;
								-- pragma translate_on
								null;
							end if;
						elsif r.ctrl.r0z = '0' and r.ctrl.r1z = '1' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 was not null but R1 was in pre-ZADDC: "
								& "we shouldn't be at the end of ZDBLC but of NEGC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '0' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 was null with R1 non-null in pre-ZADDC: "
								& "we shouldn't be at the end of ZDBLC but of NEGC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '1' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 & R1 were both null in pre-ZADDC: "
								& "we shouldn't be at the end of ZDBLC but of ZADDC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						end if;
					elsif r.kp.joye.state = znegc then
						-- -------------------------------------------
						--                end of ZNEGC
						-- -------------------------------------------
						-- here we only sets r.ctrl.r0z & r.ctrl.r1z. (s49) below,
						-- which is common to end of zaddc, zdblc & znegc, will handle
						-- possible end of scalar loop.
						-- (s51) - compute new nullity flags for R0 & R1
						-- i.e set the zero flags according to r.ctrl.r[01]z
						if r.ctrl.r0z = '0' and r.ctrl.r1z = '0' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - none of R0/R1 was null in pre-ZADDC: "
								& "we shouldn't be at the end of NEGC but of ZDBLC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						elsif r.ctrl.r0z = '0' and r.ctrl.r1z = '1' then
							--v.ctrl.r0z := '0'; -- useless (R0 wasn't null, it stays so)
							v.ctrl.r1z := '0'; -- R1 is not null anymore
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '0' then
							v.ctrl.r0z := '0'; -- R0 is not null anymore
							--v.ctrl.r1z := '0'; -- useless (R1 wasn't null, it stays so)
						elsif r.ctrl.r0z = '1' and r.ctrl.r1z = '1' then
							-- pragma translate_off
							assert (FALSE)
								report "ERROR - R0 & R1 were both null in pre-ZADDC: "
								& "we shouldn't be at the end of NEGC but of ZADDC instead"
									severity FAILURE;
							-- pragma translate_on
							null;
						end if;
					elsif r.kp.joye.state = zrmsk then
						if r.kp.zrmstep = '0' then
							if zero = '1' then
								-- this means that lambda random is null - this is not acceptable
								-- (despite the fact that it probably indicates a tampering of the
								-- hardware, it will cause arithmetical error when multiplicating
								-- point coordinates)
								-- retry drawing lots
								--v.int.faddr := EXEC_ADDR(DRAWZ_ROUTINE); useless (still set)
								v.int.fgo := '1'; -- (s86), see (s67)
							elsif zero = '0' then
								-- lambda random is not null
								v.int.faddr := EXEC_ADDR(ZREMASK_ROUTINE);
								v.int.fgo := '1'; -- (s87), see (s67)
								-- we stay in the same 'ssetup' state, but the 2nd pass (switch to
								-- Mont. & Jacobian domains, including a call to .pre_zaddU routine
								-- in order to prepare the 3rd & last step) is enforced by asserting
								-- .kp.ssetup_step to "01"
								v.kp.zrmstep := '1';
							end if;
						elsif r.kp.zrmstep = '1' then
							v.kp.joye.state := itoh;
							v.int.faddr := EXEC_ADDR(ITOH_ROUTINE); 
							v.int.fgo := '1';
						end if;
					end if; -- if r.kp.joye.state

					-- (s49)
					-- below is handled the end of ZADDC in common with the end of ZDBLC
					-- and ZNEGC, as it consists in all the 3 states decrementing counter
					-- r.kp.joye.nbbits and testing:
					--   - if we've reached the end of scalar loop (if it has reached 0)
					--     in which case we jump to substractp state
					--   - if, on the contrary, the scalar loop is not over yet (if the
					--     counter hasn't reached 0 yet) in which case we jump back to
					--     'itoh' state (or to 'permutation' state if shuffling is active)
					-- Logic below does not interfere anyway with logic in (s50), (s51)
					-- above, as the latter ones only set r.ctrl.r0z & r.ctrl.r1z
					if r.kp.joye.state = zaddc or r.kp.joye.state = zdblc
						or r.kp.joye.state = znegc
					then
						-- -------------------------------------------
						--       end of ZADDC or ZDBLC or ZNEGC
						--      (to catch the end of scalar loop)
						-- -------------------------------------------
						v.kp.joye.nbbits := r.kp.joye.nbbits - 1;
						if r.kp.joye.nbbits(log2(nn)) = '0' and
							v.kp.joye.nbbits(log2(nn)) = '1'
						then
							-- (s59)
							-- Joye Double-&-Add-Always loop is now complete (blinded
							-- scalar had all its bits parsed one by one to complete [k]P
							-- computation like a "fast exponentiation")
							-- switch from state 'itoh' to state 'subtractp'
							-- There is no need to wait for iterate_shuffle_rdy in this case
							-- (we force the iteration on permutation)
							v.kp.iterate_shuffle_force := '1';
							v.int.faddr := EXEC_ADDR(SUBTRACTP_ROUTINE);
							v.kp.substate := subtractp;
							v.kp.subpstep := '0';
							v.kp.laststep := '1';
							v.kp.joye.state := idle;
							v.int.fgo := '1'; -- (s96), see (s67)
						else
							-- Double-&-Add loop is not over, loop back to 'itoh'
							-- (or to 'permutation' if shuffle is active)
							if doshuffle = '1' then -- (s21)
								v.kp.joye.state := permutation;
								v.int.permute := '1'; -- stays asserted 1 cycle thx to (s4)
								if debug and -- statically resolved by synthesizer
									(r.kp.joye.nbbits = to_unsigned(1, r.kp.joye.nbbits'length))
								then
									v.int.permuteundo := '1';
								end if;
							else
								v.kp.joye.state := itoh; -- (s116), bypassed by (s117)
								v.int.faddr := EXEC_ADDR(ITOH_ROUTINE); -- (s118) byp. by (s119)
								-- If needed, decrement the Z-remasking counter, and possibly
								-- switch to program state 'zrmsk' if underflow is detected
								if zremaskact = '1' then -- statically resolved by synthesizer
									v.kp.zrmcnt := r.kp.zrmcnt - 1;
									if r.kp.zrmcnt = (r.kp.zrmcnt'range => '0') then
										v.kp.zrmcnt := zremaskbits;
										v.kp.joye.state := zrmsk; -- (s117), bypass of (s116)
										v.int.faddr :=
											EXEC_ADDR(DRAWZ_ROUTINE); -- (s119), bypass of (s118)
										v.kp.zrmstep := '0';
									end if;
								end if;
								v.int.fgo := '1'; -- (s97), see (s67)
							end if;
						end if;
						v.kp.zc := '0';
						-- pragma translate_off
						v.sim.logr0r1 := '1';
						v.sim.logr0r1step := 3;
						-- pragma translate_on
					end if; -- common 'if' of zaddc, zdblc & znegc states

				-- ------------------------------
				-- possible last subtraction of P 
				-- ------------------------------
				when subtractp =>
					if r.kp.subpstep = '0' then
						-- we just have finished executing the .pre_zaddcL routine that the
						-- code of .subtractPL has branched to at its end, so we can use the
						-- values of XmXC (difference of X coordinates when entering routine
						-- .pre_zaddcL) and YmY (same for Y coordinates) that just have been
						-- computed to determine:
						--   - if the [k + 1 - k%2]P and P points are possibly equal (and
						--     both non null). This is the case if XmXC = YmY = 0.
						--     We must then execute routine .zdblL (with zc = 1)
						--   - if the [k + 1 - k%2]P and P points are possibly opposite (and
						--     both non null). This is the case if XmXC = 0, YmY != 0.
						--     We must also execute routine .zdblL (with zc = 1)
						--   - if point [k + 1 - k%2]P is possibly null. This is the case
						--     if the last %par bit sampled by the opcode :
						--        "TESTPARs  phi0  3  %par"
						--     in .subtractPL:
						--       - either was 0 and R0 was null at the end of the last
						--         "regular" zdblc or znegc
						--       - or was 1 and it was R1 which was null.
						--     (This is because the bit sampled by the TESTPARs indicates
						--     in which point (R0 or R1) is the final "regular" result
						--     before conditional subtraction).
						--     We must then execute routine .znegcL.
						--   - in the trivial case where point P was null to begin with,
						--     then [k + 1 - k%2]P is also null.
						--     We then choose to execute routine .zaddcL, to simply act
						--     as a dummy operation.
						-- In all cases we also reassign r0z & r1z flags since the content
						-- of R0 and R1 is now known deterministically: R0 = [k+1-k%2]P
						-- and R1 = P (the transition from random to deterministic was done
						-- by the first instructions of .subtractPL routine (before bran-
						-- ching to subroutine .pre_zaddcL) - we couldn't do the reassign-
						-- ment of r[01]z flags at the time we started execution of routine
						-- subtractPL (see (s59) above) because in order to perform the
						-- transition we need signal phimsb to be set, and this is done
						-- by executing the first instruction of "TESTPARs phi0   %par"
						-- (see (s108) & (s109) in ecc_curve.vhd)
						if phimsb = '0' then
							-- [k + 1 - (k%2)]P was in R0 before transition from random to
							-- deterministic R0/R1 positions, and after transition it is still
							-- in R0, while R1 now contains P
							v.ctrl.r0z := r.ctrl.r0z; -- useless (just for readability's sake)
							v.ctrl.r1z := r.ctrl.r1z_init;
						elsif phimsb = '1' then
							-- [k + 1 - (k%2)]P was in R1 before transition from random to
							-- deterministic R0/R1 positions, and after transition it is now
							-- in R0, while R1 now contains P
							v.ctrl.r0z := r.ctrl.r1z;
							v.ctrl.r1z := r.ctrl.r1z_init;
						end if;
						if v.ctrl.r0z = '1' and v.ctrl.r1z = '0'
							-- note tests are made on v.ctrl.r[01]z (not r.ctrl.r[01]z)
							then
							-- point [k + 1 - k%2]P is null but initial point P is not
							v.kp.pts_are_equal := '0';
							v.kp.pts_are_oppos := '0';
							-- execute .znegcL
							v.int.faddr := EXEC_ADDR(ZNEGC_ROUTINE);
							v.kp.subptype := last_znegc;
							-- back from .znegcL routine, we will properly assign r0z and r1z
							-- flags, depending on the parity of the scalar (see (s56) below)
						elsif v.ctrl.r0z = '0' and v.ctrl.r1z = '0' then
							-- note tests are made on v.ctrl.r[01]z (not r.ctrl.r[01]z)
							if xmxz = '1' and ymyz = '1' then
								-- points [k + 1 - k%2]P  and  P are equal (and both non null)
								v.kp.pts_are_equal := '1';
								v.kp.pts_are_oppos := '0';
								-- execute .zdblL with flag zc high
								v.int.faddr := EXEC_ADDR(ZDBL_ROUTINE);
								v.kp.zc := '1';
								v.kp.subptype := last_zdblc;
							elsif xmxz = '1' and ymyz = '0' then
								-- points [k + 1 - k%2]P and P are opposite (and both non null)
								v.kp.pts_are_oppos := '1';
								v.kp.pts_are_equal := '0';
								-- execute .zdblL with flag zc high
								v.int.faddr := EXEC_ADDR(ZDBL_ROUTINE);
								v.kp.zc := '1';
								v.kp.subptype := last_zdblc;
							else -- means xmxz = ymyz = 0
								-- this corresponds to the nominal case ([k + 1 - k%2]P and P
								-- are both non null, and not equal nor opposite).
								v.kp.pts_are_equal := '0';
								v.kp.pts_are_oppos := '0';
								-- execute zaddcL (nominal situation, no exception)
								v.int.faddr := EXEC_ADDR(ZADDC_ROUTINE);
								v.kp.subptype := last_zaddc;
							end if;
						elsif v.ctrl.r0z = '1' and v.ctrl.r1z = '1' then
							-- note tests are made on v.ctrl.r[01]z (not r.ctrl.r[01]z)
							-- R0 = [k + 1 - k%2]P = 0 = P = R1  (R0=R1=0)
							-- this is treated by calling zaddC just as in the default case
							-- (no exception)
							v.kp.pts_are_equal := '0';
							v.kp.pts_are_oppos := '0';
							-- execute zaddcL (nominal situation, no exception)
							v.int.faddr := EXEC_ADDR(ZADDC_ROUTINE);
							v.kp.subptype := last_zaddc;
						elsif v.ctrl.r0z = '0' and v.ctrl.r1z = '1' then
							-- this situation is actually not possible
							-- (R1 = 0 means initial point P is null, therefore R0 can't be
							-- but the null point too)
							null; -- there's no point in signaling an error
						end if;
						v.int.fgo := '1'; -- (s98), see (s67)
						-- we stay in state 'subtractp' to execute the last ZADDC/ZNEGC/
						-- ZDBLC routine, simply we assert r.kp.subpstep for next STOP
						-- to be recognized as the end of the 2nd pass of subtractp
						v.kp.subpstep := '1';
						-- pragma translate_off
						v.sim.logr0r1 := '1';
						v.sim.logr0r1step := 4;
						-- pragma translate_on
					elsif r.kp.subpstep = '1' then
						if r.kp.subptype = last_zdblc then
							-- ------------------------------
							-- we're back from .zdblL routine (with zc = 1)
							-- ------------------------------
							-- R1 (final [k]P point) might be null! This is the case in two
							-- situations:
							--   1st situation: (see first if condition in (s57) below)
							--         - if the input scalar is even
							--     and - the two points [k + 1 - k%2]P and P turned out to be
							--           equal when running subroutine .pre_zaddcL
							--   2nd situation: (see second if condition in (s58) below)
							--         - if the input scalar is even
							--     and - the two points [k + 1 - k%2]P and P turned out to be
							--           opposite when running subroutine .pre_zadduCL
							--     and - if point [k + 1 - k%2]P turned out to be a 2-torsion
							--           point. This shows in the 2-torsion flag ('torsion2')
							--           driven by ecc_curve (set by patch ,p56 & used by
							--           patches ,p22/,p23/,p61 in .zdblL routine) is high
							-- note/reminder: the parity of the scalar is taken into account
							-- here because the point subtraction computed during the second
							-- phase of subtractp state is only effective if the scalar was
							-- EVEN to being with - if it was ODD, the subtraction didn't
							-- actually took place in the sense that neither R0 not R1 were
							-- modified by it by routine .zdblL.
							if (r.kp.pts_are_equal = '1' and kb0end = '0') -- (s57)
								or (r.kp.pts_are_oppos = '1' and kb0end = '0' and -- (s58)
								    torsion2 = '1')
							then
								v.ctrl.r1z := '1'; -- final point R1 (result [k]P) is null
							else
								v.ctrl.r1z := '0'; -- final point R1 (result [k]P) is not null
							end if;
						elsif r.kp.subptype = last_znegc then
							-- --------------------------------
							-- we're back from .znegcL routine
							-- --------------------------------
							-- R1 (final [k]P point) might be null! This is the case if the
							-- input scalar is odd
							if kb0end = '1' then -- (s56) (see (s106)-(s107) in ecc_curve.vhd)
								v.ctrl.r1z := '1'; -- final point R1 (result [k]P) is null
							else
								v.ctrl.r1z := '0'; -- final point R1 (result [k]P) is not null
							end if;
						else -- r.kp.subptype = last_zaddc
							-- -------------------------------
							-- we're back from .zaddcL routine (nominal case), final point R1
							-- can't be null
							-- -------------------------------
							v.ctrl.r1z := '0';
						end if;
						v.kp.subpstep := '0'; -- probably useless
						-- switch from 'subtractp' state to 'exit' state
						v.int.faddr := EXEC_ADDR(EXIT_ROUTINE);
						v.kp.substate := exits;
						v.kp.laststep := '0';
						v.int.fgo := '1'; -- (s99), see (s67)
						-- pragma translate_off
						v.sim.logr0r1 := '1';
						v.sim.logr0r1step := 5;
						-- pragma translate_on
					end if;
				-----------------------------------------
				-- exits:   return to  affine coordinates
				--        & check final point is on curve
				-----------------------------------------
				when exits => -- ("others" stands for exits)
					-- test input 'zero' driven by ecc_curve to check if the
					-- result [k]P actually belongs to the curve
					-- TODO: in the if and the elsif below remove test condition on
					-- .r1z_init (it should not play role, .r1z should be enough)
					if r.ctrl.r1z = '1' or r.ctrl.r1z_init = '1' then
						v.int.aerr_outpt_not_on_curve := '0'; -- no error (0 is on curve)
					elsif r.ctrl.r1z = '0' and r.ctrl.r1z_init = '0' then
						if zero = '0' then -- (s114)
							-- error (output point NOT on curve)
							v.int.aerr_outpt_not_on_curve := '1';
						elsif zero = '1' then
							-- no error (output point on curve)
							v.int.aerr_outpt_not_on_curve := '0';
						end if;
					end if;
					-- the final state of R1 (nut or not null) must be forced high if
					-- initial point P was null to begin with. This is because value
					-- of signal r.ctrl.r1z is based on arithmetic operations all along
					-- the [k]P computation that, when P is actually null, are made on
					-- random noise data. Therefore this register is not reliable to
					-- identify R1 as being null at the end of whole [k]P computation
					-- in this case)
					if r.ctrl.r1z_init = '1' then
						v.ctrl.r1z := '1'; -- (s64)
					end if;
					if tokenact = '1' then
						-- it is the responsability of ecc_axi to enforce that if 'tokenact'
						-- is high then token was generated and read back by the software
						-- before [k]P computation was started (ecc_axi refuses to launch
						-- computation as long as software has not done so, issuing error
						-- STATUS_ERR_KP_FBD whenever it happens). This ensures coherency
						-- in the fact that we're now going to mask the coordinates of [k]P
						-- result with the very same token (which is done by executing
						-- routine .token_kP_maskL, the address of which is pointed to by
						-- MASK_TOKEN_ROUTINE in EXEC_ADDR memory)
						v.kp.substate := token;
						v.int.faddr := EXEC_ADDR(MASK_TOKEN_ROUTINE);
						v.int.fgo := '1'; -- (s111), see (s67)
					elsif tokenact = '0' then
						-- We must no execute token masking routine.
						-- We don't reassert r.int.fgo to '1' again.
						-- Nothing to do, return to idle state is handled
						-- by the main state machine (see (s2) above)
						v.kp.done := '1';
					end if;
					-- pragma translate_off
					v.sim.logr0r1 := '1';
					v.sim.logr0r1step := 6;
					-- pragma translate_on
				-- -----------------------------------------------------
				-- token: unmask the scalar set by software
				-- -----------------------------------------------------
				when token =>
					-- Note: the final masking of the [k]P coordinates cannot be
					-- merged into 'exits' state (hence the 'token' state) because
					-- the 'exits' state must be terminated by a call to .checkoncurveL
					-- the last instruction of which sets the 'zero' input flag to us
					-- so that we can determine if [k]P result point actually is on
					-- the curve, see (s114) above.
					-- This is the only substate where we surely do not reassert
					-- r.int.fgo to '1' again
					-- nothing to do, return to idle state is handled by the main
					-- state machine (see (s112) above)
					v.kp.done := '1';
				when others =>
					null;
			end case;
		end if;

		-- (s6) This part of "joye" state-machine (see (s5)) needs to be separated
		-- from the test (s7), as it does not rely on the "fgo/frdy" handshake with
		-- ecc_curve (it doesn't involve execution of any program in ecc_curve_iram
		-- & depends instead on the handshake "permute/permuterdy" with
		-- ecc_fp_dram_sh (the latter only exists in the 'shuffle_type' /= none
		-- case).
		-- No test is required here on shuffle_type and/or doshuffle: if register
		-- r.kp.joye.state FSM is in permutation state, it means that conditions
		-- (s21) were met.
		if r.kp.joye.state = permutation then
			-- (s23) the test r.int.permute = 0 in (s22) below is mandatory because
			-- in the first clock cycle of permutation state r.int.permute = 1 but
			-- ecc_fp_dram_sh logic can't have yet deasserted permuterdy
			if r.int.permute = '0' then -- (s22)
				if permuterdy = '1' then
					v.kp.joye.state := itoh; -- (s120), bypassed by (s121)
					v.int.faddr := EXEC_ADDR(ITOH_ROUTINE); -- (s122), bypassed by (s123)
					-- If needed, decrement the Z-remasking counter, and possibly
					-- switch to program state 'zrmsk' if underflow is detected
					if (zremaskact = '1') then -- statically resolved by synthesizer
						v.kp.zrmcnt := r.kp.zrmcnt - 1;
						if r.kp.zrmcnt = (r.kp.zrmcnt'range => '0') then
							v.kp.zrmcnt := zremaskbits;
							v.kp.joye.state := zrmsk; -- (s121), bypass of (s120)
							v.int.faddr :=
								EXEC_ADDR(DRAWZ_ROUTINE); -- (s123), bypass of (s122)
							v.kp.zrmstep := '0';
						end if;
					end if;
					v.int.fgo := '1'; -- (s100), see (s67)
				end if;
			end if;
		end if;

		-- handshake with ecc_curve (iterate_shuffle_valid/_rdy)
		if r.kp.iterate_shuffle_valid = '1' and iterate_shuffle_rdy = '1' then
			v.kp.iterate_shuffle_valid := '0';
		end if;

		if r.kp.substate = wait_xyr01_permute then
			-- no deadlock possible here: ecc_curve never waits for our signal
			-- 'r.kp.iterate_shuffle_valid' to be asserted for asserting on its side
			-- the signal 'iterate_shuffle_rdy'
			if iterate_shuffle_rdy = '1' then
				v.kp.substate := r.kp.nextsubstate; -- (s15)
				v.int.fgo := '1'; -- (s101), see (s67)
				-- no need to set r.int.faddr, it was done:
				--   - by (s9) at the end of substate 'ssetup'
				--       (r.int.faddr was then set to EXEC_ADDR(ITOH_ROUTINE))
				--   - by (s10) at the end of Joye-state 'itoh'
				--       (r.int.faddr was then set to EXEC_ADDR(PRE_ZADDU_ROUTINE))
				--   - by (s11) at the end of Joye-state 'zaddu'
				--       (r.int.faddr was then set to EXEC_ADDR(PRE_ZADDC_ROUTINE))
				--   - by (s37) at the end of Joye-state 'zdblu'
				--       (r.int.faddr was then set to EXEC_ADDR(PRE_ZADDC_ROUTINE))
				-- if r.kp.nextsubstate = switch3p then
				-- 	-- v.kp.substate := r.kp.nextsubstate; -- useless, see (s15)
				-- 	-- in this case we must not have the permutation set in
				-- 	-- ecc_curve (on the [XY]R[01] coordinates) taking effet
				-- 	-- right now, so we do not assert r.kp.iterate_shuffle_valid
				-- 	null;
				if r.kp.joye.state = itoh then -- (s13)
					-- v.kp.substate := joyecoz; -- useless already coded by (s14)/(s15)
					v.kp.joye.state := prezaddu;
					if r.kp.firstzaddu = '1' then
						v.kp.firstzaddu := '0';
					elsif r.kp.firstzaddu = '0' then
						v.kp.iterate_shuffle_valid := '1';
					end if;
					-- pragma translate_off
					v.sim.simbit := r.sim.simbit + 1;
					-- pragma translate_on
					v.dbg.joyebit := std_logic_vector(unsigned(r.dbg.joyebit) + 1);
				elsif r.kp.joye.state = zaddu then -- (s18)
					-- v.kp.substate := joyecoz; -- useless already coded by (s16)/(s15)
					v.kp.joye.state := prezaddc;
					v.kp.iterate_shuffle_valid := '1';
				elsif r.kp.joye.state = zdblu then -- (s36)
					-- v.kp.substate := joyecoz; -- useless already coded by (s38)/(s15)
					v.kp.joye.state := prezaddc;
					v.kp.iterate_shuffle_valid := '1';
				end if;
			else
				-- TODO: a wise thing could be to implement a watchdog timer here.
				null;
			end if;
		end if;

		-- upon reset, wait until init actions are over before allowing anything
		-- to happen - in current version there is no job to be performed
		if r.ctrl.uponreset = '1' then
			v.ctrl.uponreset := '0';
			v.int.ardy := '1';
			v.ctrl.initdone := '1'; -- actually equiv. to 'uponreset' (but inverted)
		end if;

		-- hardware synchronous (active low) reset
		-- & software synchronous (active high reset.
		-- Deassertion of reset being synhcronous, glitches on the
		-- combinational logic-or of the two signals 'rstn' and 'swrst'
		-- can be checked against clock delays uring static timing analysis.
		if rstn = '0' or swrst = '1' then
			v.ctrl.active := '0';
			v.ctrl.initdone := '0';
			v.ctrl.uponreset := '1';
			v.int.ardy := '0';
			v.int.fgo := '0';
			v.ctrl.state := idle;
			v.kp.substate := idle;
			v.kp.iterate_shuffle_valid := '0';
			v.kp.iterate_shuffle_force := '0';
			v.kp.initkp := '0';
			-- no need to reset r.kp.firstzaddu
			-- no need to reset r.kp.substate, r.int.faddr, r.kp.blind_nbbits
			-- no need to reset r.kp.k_is_null
			-- no need to reset r.kp.z[uc]
			v.int.aerr_inpt_not_on_curve := '0';
			v.int.aerr_outpt_not_on_curve := '0';
			v.kp.computing := '0';
			v.mty.computing := '0';
			v.mty.computing_a := '0';
			v.pop.computing := '0';
			v.kp.joye.state := idle;
			if shuffle_type /= none then -- statically resolved by synthesizer
				v.int.permute := '0';
			end if;
			-- pragma translate_off
			v.sim.logr0r1 := '0';
			v.sim.logr0r1step := 0;
			v.sim.logfinalresult := '0';
			v.sim.perfcnten := '0';
			v.sim.perfcnt := 0;
			-- pragma translate_on
			v.kp.done := '0';
			v.mty.done := '0';
			v.mty.donea := '0';
			-- no need to reset r.mty.step nor r.mty.cntrshift
			--v.kp.laststep := '0';
			--v.kp.setup := '0';
			if debug then -- statically resolved by synthesizer
				v.int.permuteundo := '0';
			end if;
			v.pop.done := '0';
			-- no need to reset r.pop.equal, r.pop.opp, r.pop.equalx, r.pop.step
			v.pop.yes := '0';
			v.pop.yesen := '0';
			v.int.ar01zien := '0';
			-- no need to reset r.int.ar[01]zi
			v.ctrl.r1z_init := '0';
			-- no need to reset r.kp.ssetup_step nor r.kp.subpstep
			-- no need to reset r.kp.subptype
			-- no need to reset r.kp.first3pz
			v.int.small_k_sz_en_ack := '0';
			-- no need to reset r.int.small_k_sz_kpdone
			v.ctrl.small_k_sz_en := '0';
			v.int.ptadd := '0';
			v.int.tokendone := '0';
			v.int.token_generating := '0';
		end if;

	rin <= v;
	end process comb;

	-- registers
	regs : process(clk)
	begin
		if (clk'event and clk = '1') then
			r <= rin;
		end if;
	end process regs;

	-- drive outputs
	--   interface with ecc_axi
	initdone <= r.ctrl.initdone;
	ardy <= r.int.ardy;
	kpdone <= r.kp.done;
	mtydone <= r.mty.done;
	amtydone <= r.mty.donea;
	popdone <= r.pop.done;
	yes <= r.pop.yes;
	yesen <= r.pop.yesen;
	ar01zien <= r.int.ar01zien;
	ar0zi <= r.int.ar0zi;
	ar1zi <= r.int.ar1zi;
	small_k_sz_en_ack <= r.int.small_k_sz_en_ack;
	small_k_sz_kpdone <= r.int.small_k_sz_kpdone;
	tokendone <= r.int.tokendone;
	token_generating <= r.int.token_generating;
	--   interface with ecc_curve
	fgo <= r.int.fgo;
	faddr <= r.int.faddr;
	initkp <= r.kp.initkp;
	laststep <= r.kp.laststep;
	firstzdbl <= r.kp.firstzdbl;
	firstzaddu <= r.kp.firstzaddu;
	iterate_shuffle_valid <= r.kp.iterate_shuffle_valid;
	iterate_shuffle_force <= r.kp.iterate_shuffle_force;
	zu <= r.kp.zu;
	zc <= r.kp.zc;
	r0z <= r.ctrl.r0z;
	r1z <= r.ctrl.r1z;
	pts_are_equal <= r.kp.pts_are_equal;
	pts_are_oppos <= r.kp.pts_are_oppos;
	first3pz <= r.kp.first3pz;
	ptadd <= r.int.ptadd;
	--   interface with ecc_fp
	compkp <= r.kp.computing; -- also driven to ecc_curve
	compcstmty <= r.mty.computing_del;
	comppop <= r.pop.computing; -- also driven to ecc_curve
	aerr_inpt_not_on_curve <= r.int.aerr_inpt_not_on_curve;
	aerr_outpt_not_on_curve <= r.int.aerr_outpt_not_on_curve;
	--     (this signal is only used in the 'shuffle_type' /= none case)
	permute <= r.int.permute;
	pu: if debug generate -- statically resolved by synthesizer
		permuteundo <= r.int.permuteundo;
	end generate;
	-- pragma translate_off
	--   interface with ecc_fp
	simbit <= r.sim.simbit;
	-- pragma translate_on
	-- debug features
	dbgnbstarvrndxyshuf <= r.dbg.nbstarvrndxyshuf;
	-- TODO: many multicycles can be set on paths r.ctrl.state -> dbg*
	-- TODO: many multicycles can be set on paths r.kp.substate -> dbg*
	-- (on the other hand these are debug only paths, so it does not
	-- really make sense to make effort to improve timing)
	dbgpgmstate <= DEBUG_STATE_IDLE when r.ctrl.state = idle
	  else DEBUG_STATE_CSTMTY when r.ctrl.state = cst
	  else DEBUG_STATE_CHECKONCURVE when r.kp.substate = checkoncurve
	  else DEBUG_STATE_BLINDINIT when r.kp.substate = blindinit
	  else DEBUG_STATE_BLINDBIT when r.kp.substate = blindbit
	  else DEBUG_STATE_BLINDEXIT when r.kp.substate = blindexit
	  else DEBUG_STATE_ADPA when r.kp.substate = adpa
	  else DEBUG_STATE_SETUP when r.kp.substate = ssetup
	  else DEBUG_STATE_ITOH
			when r.kp.substate = joyecoz and r.kp.joye.state = itoh
	  else DEBUG_STATE_ZADDU
			when r.kp.substate = joyecoz and (r.kp.joye.state = prezaddu
			or r.kp.joye.state = zaddu or r.kp.joye.state = zdblu)
	  else DEBUG_STATE_ZADDC
			when r.kp.substate = joyecoz and (r.kp.joye.state = prezaddc
			or r.kp.joye.state = zaddc or r.kp.joye.state = zdblc
			or r.kp.joye.state = znegc)
	  else DEBUG_STATE_SUBTRACTP when r.kp.substate = subtractp
	  else DEBUG_STATE_EXIT when r.kp.substate = exits
	  else "1111";
	-- (s30), see (s29)
	dbgnbbits <= std_logic_vector(resize(r.kp.joye.nbbits, 16))
	                  when r.kp.substate = joyecoz
	             else std_logic_vector(resize(r.kp.blind_nbbits, 16))
	                  when r.kp.substate = blindbit
	             else std_logic_vector(to_unsigned(0, 16));

	-- pragma translate_off
	logr0r1 <= r.sim.logr0r1;
	logr0r1step <= r.sim.logr0r1step;
	logfinalresult <= r.sim.logfinalresult;

	log_fp: process(clk) is
	begin
		if clk'event and clk = '1' then
			rbak_state <= r.ctrl.state;
			rbak_substate <= r.kp.substate;
			rbak_joye_state <= r.kp.joye.state;
			-- log main states
			if (r.ctrl.state = idle and rbak_state /= idle) then
				echo("ECC_SCALAR: ");
				echo("returning to state 'idle' (");
				echo(time'image(now));
				echol(")");
			elsif (r.ctrl.state = cst and rbak_state /= cst) then
				echo("ECC_SCALAR: ");
				echo("entering state 'cst' (");
				echo(time'image(now));
				echol(")");
			elsif (r.ctrl.state = set and rbak_state /= set) then
				echo("ECC_SCALAR: ");
				echo("entering state 'set' (");
				echo(time'image(now));
				echol(")");
			elsif (r.ctrl.state = kp and rbak_state /= kp) then
				echo("ECC_SCALAR: ");
				echo("entering state 'kp' (");
				echo(time'image(now));
				echol(")");
			elsif (r.ctrl.state = pop and rbak_state /= pop) then
				echo("ECC_SCALAR: ");
				echo("entering state 'pop' (");
				echo(time'image(now));
				echol(")");
			end if;
			-- also log substates
			if (r.kp.substate = idle and rbak_substate = checkoncurve) then
				echo("ECC_SCALAR: ");
				echo("input point is NOT on curve, ");
				echo("returning to substate 'idle' (");
				echo(time'image(now));
				echol(")");
			elsif (rbak_substate = exits and r.kp.substate /= exits) then
				echo("ECC_SCALAR: ");
				--if (rbak_substate = exits) then
					if zero = '1' or r.ctrl.r1z = '1' then
						echo("output point IS on curve");
						if r.ctrl.r1z = '1' then
							echol(" (it is null)");
						else
							echol("");
						end if;
					else
						echol("output point IS NOT on curve");
					end if;
				--end if;
				if r.kp.substate = idle then
					echo("ECC_SCALAR: ");
					echo("returning to substate 'idle' (");
					echo(time'image(now));
					echol(")");
					echo("ECC_SCALAR: PERF: ");
					echo(integer'image(r.sim.perfcnt));
					echo(" clock cycles (");
					echo(time'image(now));
					echol(")");
				end if;
			elsif (rbak_substate = token and r.kp.substate = idle) then
				echo("ECC_SCALAR: ");
				echo("returning to substate 'idle' (");
				echo(time'image(now));
				echol(")");
				echo("ECC_SCALAR: PERF: ");
				echo(integer'image(r.sim.perfcnt));
				echo(" clock cycles (");
				echo(time'image(now));
				echol(")");
			elsif (r.kp.substate = checkoncurve and rbak_substate /= checkoncurve)
			then
				echo("ECC_SCALAR: ");
				echo("entering substate 'checkoncurve' (");
				echo(time'image(now));
				echol(")");
			elsif r.kp.substate = blindinit and rbak_substate = checkoncurve then
				if (zero = '1' or r.ctrl.r1z = '1') then
					echo("ECC_SCALAR: ");
					echo("input point IS on curve, ");
					echo("entering substate 'blindinit' (");
					echo(time'image(now));
					echol(")");
				else
					echo("ECC_SCALAR: ");
					echo("input point is NOT on curve (but carrying on...) [");
					echo(time'image(now));
					echol(")");
				end if;
			elsif (r.kp.substate = blindbit and rbak_substate /= blindbit) then
				echo("ECC_SCALAR: ");
				echo("entering substate 'blindbit' (");
				echo(time'image(now));
				echol(")");
				rlog_blind_nbbits <= to_integer(unsigned(blindbits));
			elsif (r.kp.substate = blindbit and
					to_integer(r.kp.blind_nbbits) /= rlog_blind_nbbits) then
				rlog_blind_nbbits <= to_integer(r.kp.blind_nbbits);
				if (r.sim.simblbit mod NB_BITS_LINE = NB_BITS_LINE - 1)
					or (r.sim.simblbit = blbits_max_s - 1)
				then
					echo("ECC_SCALAR: ");
					echo("blinding bits #");
					echo(integer'image(r_sim_prevblbit));
					echo(" ... ");
					echol(integer'image(r.sim.simblbit));
					r_sim_prevblbit <= r.sim.simblbit + 1;
				end if;
			elsif r.kp.substate = adpa and rbak_substate = checkoncurve then
				if (zero = '1' or r.ctrl.r1z = '1') then
					echo("ECC_SCALAR: ");
					echo("input point IS on curve, ");
					echo("entering substate 'adpa' (");
					echo(time'image(now));
					echol(")");
				else
					echo("ECC_SCALAR: ");
					echo("input point is NOT on curve (but carrying on...) [");
					echo(time'image(now));
					echol(")");
				end if;
			elsif (r.kp.substate = ssetup and rbak_substate /= ssetup) then
				echo("ECC_SCALAR: ");
				echo("entering substate 'ssetup' (");
				echo(time'image(now));
				echol(")");
				r_sim_prevbit <= 2;
				r_sim_prevblbit <= 0;
			--elsif (r.kp.substate = switch3p and rbak_substate /= switch3p) then
			--	echo("ECC_SCALAR: ");
			--	echo("entering substate 'switch3p' (");
			--	echo(time'image(now));
			--	echol(")");
			elsif (r.kp.substate = joyecoz and rbak_substate /= joyecoz) then
				echo("ECC_SCALAR: ");
				echo("entering substate 'joyecoz' (");
				echo(time'image(now));
				echol(")");
			elsif (r.kp.joye.state /= zaddc
				and rbak_joye_state = zaddc) then --and (not shuffle or (shuffle and
				--( (debug and doshuffle = '0') or (not debug) )))) then
				if (r.sim.simbit mod NB_BITS_LINE = NB_BITS_LINE - 1)
					or (r.sim.simbit = nnmax_joye_loop_s + 2)
				then
					echo("ECC_SCALAR: ");
					echo("scalar bits #");
					echo(integer'image(r_sim_prevbit));
					echo(" ... ");
					echol(integer'image(r.sim.simbit));
					r_sim_prevbit <= r.sim.simbit + 1;
				end if;
			elsif (r.kp.substate = subtractp and rbak_substate /= subtractp) then
				echo("ECC_SCALAR: ");
				echo("entering substate 'subtractp' (");
				echo(time'image(now));
				echol(")");
			elsif (r.kp.substate = exits and rbak_substate /= exits) then
				echo("ECC_SCALAR: ");
				echo("entering substate 'exits' (");
				echo(time'image(now));
				echol(")");
			end if;
		end if;
	end process log_fp;
	-- pragma translate_on

end architecture rtl;
