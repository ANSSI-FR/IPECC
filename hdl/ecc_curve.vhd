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

use work.ecc_custom.all;
use work.ecc_utils.all;
use work.ecc_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity ecc_curve is
	port(
		clk : in std_logic;
		rstn : in std_logic; -- synchronous reset
		-- software reset
		swrst : in std_logic;
		-- interface with ecc_axi
		masklsb : in std_logic;
		doblinding : in std_logic;
		-- interface with ecc_scalar
		frdy  : out std_logic;
		fgo   : in  std_logic;
		faddr : in  std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		initkp : in std_logic;
		ferr : out std_logic;
		zero : out std_logic;
		laststep : in std_logic;
		setup : in std_logic;
		iterate_shuffle_valid : in std_logic;
		iterate_shuffle_rdy : out std_logic;
		iterate_shuffle_force : in std_logic;
		fr0z : in std_logic;
		fr1z : in std_logic;
		x_are_equal : out std_logic;
		y_are_equal : out std_logic;
		y_are_opposite : out std_logic;
		first_2p_is_null : out std_logic;
		p_is_of_order_3 : in std_logic;
		xmxz : out std_logic;
		ymyz : out std_logic;
		torsion2 : out std_logic;
		kap : out std_logic;
		kapp : out std_logic;
		compkp : in std_logic;
		comppop : in std_logic;
		compaop : in std_logic;
		zu : in std_logic;
		zc : in std_logic;
		r0z : in std_logic;
		r1z : in std_logic;
		pts_are_equal : in std_logic;
		pts_are_oppos : in std_logic;
		phimsb : out std_logic;
		kb0end : out std_logic;
		-- interface with ecc_curve_iram
		ire : out std_logic;
		iraddr : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		irdata : in  std_logic_vector(OPCODE_SZ - 1 downto 0);
		-- interface with ecc_fp
		opi : out opi_type;
		opo : in opo_type;
		-- interface with mm_ndsp(s)
		ppen : out std_logic;
		-- interface with ecc_trng
		trng_data : in std_logic_vector(1 downto 0);
		trng_valid : in std_logic;
		trng_rdy : out std_logic;
		-- debug features (interface with ecc_axi)
		dbgbreakpoints : in breakpoints_type;
		dbgnbopcodes : in std_logic_vector(15 downto 0);
		dbgdosomeopcodes : in std_logic;
		dbgresume : in std_logic;
		dbghalt : in std_logic;
		dbghalted : out std_logic;
		dbgdecodepc : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		dbgbreakpointid : out std_logic_vector(1 downto 0);
		dbgbreakpointhit : out std_logic;
		dbgremainingopcodes : out std_logic_vector(15 downto 0);
		dbgpdops : out unsigned(PENDING_OPS_NBBITS - 1 downto 0);
		-- debug features (interface with ecc_scalar)
		dbgpgmstate : in std_logic_vector(3 downto 0);
		dbgnbbits : in std_logic_vector(15 downto 0)
		-- pragma translate_off
		;pc : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		b : out std_logic;
		bz : out std_logic;
		bsn : out std_logic;
		bodd : out std_logic;
		call : out std_logic;
		callsn : out std_logic;
		ret : out std_logic;
		retpc : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		nop : out std_logic;
		imma : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		xr0addr : out std_logic_vector(1 downto 0);
		yr0addr : out std_logic_vector(1 downto 0);
		xr1addr : out std_logic_vector(1 downto 0);
		yr1addr : out std_logic_vector(1 downto 0);
		stop : out std_logic;
		patching : out std_logic;
		patchid : out integer
		-- pragma translate_on
	);
end entity ecc_curve;

architecture rtl of ecc_curve is

	constant NB_ERR_FLAGS : integer := 4;

	type state_type is (idle, running, errorr);

	type fetch_state_type is (idle, fetch, wwait);
	type decode_state_type is (idle, decode, patch, arith, waitarith,
	                           branch, barrier, errorr, breakpoint, waitb4bkpt);

	type fetch_reg_type is record
		state : fetch_state_type;
		pc : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		ramresh : std_logic_vector(sramlat downto 0);
		opcode : std_logic_vector(OPCODE_SZ - 1 downto 0);
		valid : std_logic;
	end record;

	type patch_reg_type is record
		as : std_logic;
		p : std_logic;
		-- for opa
		opax0, opax1, opay0, opay1 : std_logic;
		opax0next, opay0next : std_logic;
		opax1next, opay1next : std_logic;
		opax0det, opay0det : std_logic;
		opax1det, opay1det : std_logic;
		opaxtmp, opaytmp : std_logic;
		opaz, opax1noshuf : std_logic;
		-- for opb
		opbx0, opbx1, opby0, opby1 : std_logic;
		opbx0next, opby0next : std_logic;
		opbx1next, opby1next : std_logic;
		opbz, opbr : std_logic;
		-- for opc
		opcx0, opcx1, opcy0, opcy1 : std_logic;
		opcx0next, opcy0next : std_logic;
		opcx1next, opcy1next : std_logic;
		opcvoid, opccopiesopa : std_logic;
		opcbl0, opcbl1 : std_logic;
		opcx0det, opcy0det : std_logic;
		opcx1det, opcy1det : std_logic;
		-- pragma translate_off
		applying : std_logic;
		nb : std_logic_vector(OP_PATCH_MSB - OP_PATCH_LSB downto 0);
		applying_but_not_p5 : std_logic;
		nb_not_p5 : std_logic_vector(OP_PATCH_MSB - OP_PATCH_LSB downto 0);
		-- pragma translate_on
	end record;

	type decode_common_reg_type is record
		opcode : std_logic_vector(OP_OP_SZ - 1 downto 0);
		optype : std_logic_vector(OP_TYPE_SZ - 1 downto 0);
		patch : std_logic;
		extended : std_logic;
		kb0 : std_logic;
		mu0 : std_logic;
		par : std_logic;
		kap : std_logic;
		kapp : std_logic;
		r : std_logic;
		-- barrier & stop
		barrier : std_logic;
		stop : std_logic;
	end record;

	type decode_arith_reg_type is record
		opa : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		opb : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		opc : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		popa : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		popb : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		popc : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		add : std_logic;
		sub : std_logic;
		ssrl : std_logic;
		ssll : std_logic;
		xxor : std_logic;
		rnd : std_logic;
		redc : std_logic;
		tpar : std_logic;
		tparsh : std_logic;
		div2 : std_logic;
		redcm : std_logic;
		rndm : std_logic;
		rndsh : std_logic;
		rndshf : std_logic;
		ssrl_sh : std_logic;
	end record;

	type decode_branch_reg_type is record
		b : std_logic;
		z : std_logic;
		sn : std_logic;
		odd : std_logic;
		call : std_logic;
		callsn : std_logic;
		ret : std_logic;
		imma : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	end record;

	type decode_reg_type is record
		rdy : std_logic;
		state : decode_state_type;
		pc : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		-- common instructions decoding
		c : decode_common_reg_type;
		-- ARITHmetic instructions decoding
		a : decode_arith_reg_type;
		-- BRANCH instructions decoding
		b : decode_branch_reg_type;
		valid : std_logic;
		barnop : std_logic;
		barbra : std_logic;
		patch : patch_reg_type;
	end record;

	type ctrl_reg_type is record
		x_are_equal : std_logic;
		y_are_equal : std_logic;
		y_are_opposite : std_logic;
		test_x_equality : std_logic;
		test_y_equality : std_logic;
		test_y_opposite : std_logic;
		detect2pz : std_logic;
		first2pz : std_logic;
		detectxmxz, detectymyz : std_logic;
		detecttorsion2 : std_logic;
		xmxz, ymyz : std_logic;
		torsion2 : std_logic;
		kb0 : std_logic;
		mu0 : std_logic;
		kap : std_logic;
		kapp : std_logic;
		z : std_logic;
		sn : std_logic;
		par : std_logic;
		ret : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		pending_ops : unsigned(PENDING_OPS_NBBITS - 1 downto 0);
		kb0end : std_logic;
		phimsb : std_logic;
	end record;

	type shuffle_reg_type is record
		zero : std_logic_vector(1 downto 0);
		one : std_logic_vector(1 downto 0);
		two : std_logic_vector(1 downto 0);
		three : std_logic_vector(1 downto 0);
		next_zero: std_logic_vector(1 downto 0);
		next_one : std_logic_vector(1 downto 0);
		next_two : std_logic_vector(1 downto 0);
		next_three : std_logic_vector(1 downto 0);
		next_next_zero: std_logic_vector(1 downto 0);
		next_next_one : std_logic_vector(1 downto 0);
		next_next_two : std_logic_vector(1 downto 0);
		next_next_three : std_logic_vector(1 downto 0);
		trng_rdy : std_logic;
		trng_data : std_logic_vector(1 downto 0);
		trng_valid : std_logic;
		sw3 : std_logic_vector(1 downto 0);
		sw2 : std_logic_vector(1 downto 0);
		sw1 : std_logic_vector(1 downto 0);
		step : natural range 1 to 3;
		state : std_logic_vector(1 downto 0);
		start : std_logic;
	end record;

	-- debug features
	type debug_reg_type is record
		breakpointid : std_logic_vector(1 downto 0);
		severalopcodes : std_logic;
		nbopcodes : unsigned(15 downto 0);
		halted : std_logic;
		halt_b : std_logic;
		breakpointhit : std_logic;
		halt_pending : std_logic;
	end record;

	type reg_type is record
		active : std_logic;
		state : state_type;
		fetch : fetch_reg_type;
		decode : decode_reg_type;
		ctrl : ctrl_reg_type;
		frdy : std_logic;
		stop : std_logic;
		err : std_logic;
		err_flags: std_logic_vector(NB_ERR_FLAGS - 1 downto 0);
		shuffle : shuffle_reg_type;
		-- debug features
		debug : debug_reg_type;
		-- pragma translate_off
		shuffle_zero : std_logic_vector(1 downto 0);
		shuffle_zero_sw3 : std_logic_vector(1 downto 0);
		shuffle_zero_sw2 : std_logic_vector(1 downto 0);
		shuffle_zero_sw1 : std_logic_vector(1 downto 0);
		shuffle_one : std_logic_vector(1 downto 0);
		shuffle_one_sw3 : std_logic_vector(1 downto 0);
		shuffle_one_sw2 : std_logic_vector(1 downto 0);
		shuffle_one_sw1 : std_logic_vector(1 downto 0);
		shuffle_two : std_logic_vector(1 downto 0);
		shuffle_two_sw3 : std_logic_vector(1 downto 0);
		shuffle_two_sw2 : std_logic_vector(1 downto 0);
		shuffle_two_sw1 : std_logic_vector(1 downto 0);
		shuffle_three : std_logic_vector(1 downto 0);
		shuffle_three_sw3 : std_logic_vector(1 downto 0);
		shuffle_three_sw2 : std_logic_vector(1 downto 0);
		shuffle_three_sw1 : std_logic_vector(1 downto 0);
		-- pragma translate_on
	end record;

	constant ERR_INVALID_OPCODE : integer := 0;
	constant ERR_OVERFLOW : integer := 1;
	constant ERR_UPDATE_R0R1 : integer := 2;

	signal r, rin : reg_type;

	-- address of variable OPC_VOID below must be chosen in such a way that
	-- it does not bash any useful variable (variable OPC_VOID is used as a
	-- dummy target varaible:
	--   - during blinding when the result of the instruction opcode must be
	--     discarded due to the patch, instead of being written to variable
	--     kb0 or kb1)
	--   - during .setupL routine, when returning back from .dblL, in case
	--     initial point P was of order 2, because in this situation ZR01
	--     must be restored back from ZPBK
	constant C_PATCH_OPC_VOID : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(23, FP_ADDR_MSB)); --"10111";
	-- address of variable _KB0 (resp. _KB1) below must be kept the same as the
	-- address of kb0 (resp. kb1) in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_KB0 : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(4, FP_ADDR_MSB)); -- "00100"
	constant C_PATCH_KB1 : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(5, FP_ADDR_MSB)); -- "00101"
	-- address of variable _RED0 below must be kept identical to the
	-- address of red0 variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_RED0 : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(22, FP_ADDR_MSB)); -- "10110"
	-- address of variable _ZERO below must be kept identical to the
	-- address of zero variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_ZERO : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(31, FP_ADDR_MSB)); -- "11111"
	-- address of variable _P below must be kept identical to the
	-- address of p variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_P : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(0, FP_ADDR_MSB)); -- "00000"
	-- address of variable _TWOP below must be kept identical to the
	-- address of twop variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_TWOP : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(24, FP_ADDR_MSB)); -- "11000"
	-- address of variable _R below must be kept identical to the
	-- address of R variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_R : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(29, FP_ADDR_MSB)); -- "11000"
	-- address of variable _XTMP below must be kept identical to the
	-- address of Xtmp variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_XTMP : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(20, FP_ADDR_MSB)); -- "11000"
	-- address of variable _YTMP below must be kept identical to the
	-- address of Xtmp variable in file <ecc_curve_iram/vardefs.csv>
	constant C_PATCH_YTMP : std_logic_vector(FP_ADDR_MSB - 1 downto 0) :=
		std_logic_vector(to_unsigned(21, FP_ADDR_MSB)); -- "11000"

	constant XYR01_UP : integer := FP_ADDR_MSB - 1;
	constant XYR01_LO : integer := FP_ADDR_MSB - 3;
	constant XYR01_MSB : std_logic_vector(2 downto 0) :=
		CST_ADDR_XR0(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3);

	-- Note that constants CST_ADDR_[XY]R[01] which are defined in
	-- <ecc_pkg.vhd> also must be kept consistent with the values
	-- in <vardesf.csv> (of folder ecc_curve_iram/asm_src/

	-- pragma translate_off
	signal r_op_plus : std_logic;
	signal r_op_moins : std_logic;
	-- pragma translate_on

	-- pragma translate_off
	signal rbak_first2pz : std_logic := '0';
	signal rbak_torsion2 : std_logic := '0';
	-- pragma translate_on

begin

	assert( (CST_ADDR_XR0(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3) =
	         CST_ADDR_YR0(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3))  and
	        (CST_ADDR_YR0(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3) =
	         CST_ADDR_XR1(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3))  and
	        (CST_ADDR_XR1(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3) =
	         CST_ADDR_YR1(FP_ADDR_MSB - 1 downto FP_ADDR_MSB - 3))  )
		report "patch mechanims implemented in ecc_curve rely on four "
		     & "variables XR0, YR0, XR1 & YR1 having their address "
		     & "aligned on the same multiple-of-4 in ecc_fp_dram"
			severity FAILURE;

	-- combinational process
	comb : process(r, rstn, masklsb, initkp, laststep, setup, fgo, faddr, irdata,
	               trng_data, trng_valid, fr0z, fr1z, compkp, comppop, compaop,
	               iterate_shuffle_valid, iterate_shuffle_force, dbghalt,
	               doblinding, opo, dbgbreakpoints, dbgpgmstate, dbgnbbits,
								 dbgnbopcodes, dbgdosomeopcodes, dbgresume, swrst,
								 zu, zc, r0z, r1z,
								 pts_are_equal, pts_are_oppos, p_is_of_order_3)
		variable v : reg_type;
		variable vtmp0 : std_logic_vector(14 downto 0);
		variable vtmp1 : std_logic_vector(2 downto 0);
		variable vopsincr : boolean;
		variable vdobranch : boolean;
		variable v_breakpointhit : boolean;
		variable v_breakpointnb : natural range 0 to 3;
		variable v_shuffle_zero : std_logic_vector(1 downto 0);
		variable v_shuffle_zero_sw3 : std_logic_vector(1 downto 0);
		variable v_shuffle_zero_sw2 : std_logic_vector(1 downto 0);
		variable v_shuffle_zero_sw1 : std_logic_vector(1 downto 0);
		variable v_shuffle_one : std_logic_vector(1 downto 0);
		variable v_shuffle_one_sw3 : std_logic_vector(1 downto 0);
		variable v_shuffle_one_sw2 : std_logic_vector(1 downto 0);
		variable v_shuffle_one_sw1 : std_logic_vector(1 downto 0);
		variable v_shuffle_two : std_logic_vector(1 downto 0);
		variable v_shuffle_two_sw3 : std_logic_vector(1 downto 0);
		variable v_shuffle_two_sw2 : std_logic_vector(1 downto 0);
		variable v_shuffle_two_sw1 : std_logic_vector(1 downto 0);
		variable v_shuffle_three : std_logic_vector(1 downto 0);
		variable v_shuffle_three_sw3 : std_logic_vector(1 downto 0);
		variable v_shuffle_three_sw2 : std_logic_vector(1 downto 0);
		variable v_shuffle_three_sw1 : std_logic_vector(1 downto 0);
		variable vpar : std_logic;
	begin
		v := r;

		vopsincr := FALSE;
		vdobranch := FALSE;

		-- (s106), see also (s107)
		-- r.ctrl.kb0end bit directly drives output 'kb0end' to ecc_scalar
		-- this bit is used by ecc_scalar after the conditional subtraction of P
		-- to determine if the result ([k]P) is possibly null
		if laststep = '1' then
			if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
			or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0) = '1') then
				v.ctrl.kb0end := '1'; -- original scalar is actually odd
			else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
				v.ctrl.kb0end := '0'; -- original scalar is actually even
			end if;
		elsif laststep = '0' then
			v.ctrl.kb0end := '0'; -- do not give info before it's needed
		end if;

		-- (s108), see also (s109)
		if laststep = '1' then
			v.ctrl.phimsb := r.ctrl.par;
		elsif laststep = '0' then
			v.ctrl.phimsb := '0'; -- do not give info before it's needed
		end if;

		-- catch a possible debug halt order coming from software
		v.debug.halt_b := dbghalt;
		if (dbghalt = '1' and r.debug.halt_b = '0') then
			v.debug.halt_pending := '1';
		end if;

		-- (s40) breakpoints (generation of v_breakpointhit & v_breakpointnb
		--       which are used in (s41) below)
		-- TODO: condition the following logic (for breakpoints)  w/ regard to
		--       whether or not debug features are present (unless it would
		--       naturally be trimmed by synthesizer when they are not)
		v_breakpointhit := FALSE;
		v_breakpointnb := 0; -- to avoid inference of latches
		for i in 0 to 3 loop
			if debug
				and dbgbreakpoints(i).act = '1'
				and r.fetch.pc = dbgbreakpoints(i).addr
				and (dbgbreakpoints(i).state = "0000"
					or (   (dbgpgmstate /= DEBUG_STATE_BLINDBIT)
				     and (dbgpgmstate /= DEBUG_STATE_ITOH)
				     and (dbgpgmstate /= DEBUG_STATE_ZADDU)
				     and (dbgpgmstate /= DEBUG_STATE_ZADDC)
				     and (dbgbreakpoints(i).state = dbgpgmstate))
					or (dbgpgmstate = DEBUG_STATE_BLINDBIT
					   and dbgbreakpoints(i).state = DEBUG_STATE_BLINDBIT
					   and (dbgbreakpoints(i).nbbits = dbgnbbits
					    or  dbgbreakpoints(i).nbbits = "0000000000000000"))
					or (dbgpgmstate = DEBUG_STATE_ITOH
					   and dbgbreakpoints(i).state = DEBUG_STATE_ITOH
					   and (dbgbreakpoints(i).nbbits = dbgnbbits
					    or  dbgbreakpoints(i).nbbits = "0000000000000000"))
					or (dbgpgmstate = DEBUG_STATE_ZADDU
					   and dbgbreakpoints(i).state = DEBUG_STATE_ZADDU
					   and (dbgbreakpoints(i).nbbits = dbgnbbits
					    or  dbgbreakpoints(i).nbbits = "0000000000000000"))
					or (dbgpgmstate = DEBUG_STATE_ZADDC
					   and dbgbreakpoints(i).state = DEBUG_STATE_ZADDC
					   and (dbgbreakpoints(i).nbbits = dbgnbbits
					    or  dbgbreakpoints(i).nbbits = "0000000000000000")))
			then
				v_breakpointhit := TRUE;
				v_breakpointnb := i;
			end if;
		end loop;

		-- ----------------------------------------------
		--               MAIN STATE MACHINE
		-- ----------------------------------------------

		-- monitor initialization of a new [k]P computation or a new program
		-- execution

		-- shift register for read-enable from ecc_curve_iram
		v.fetch.ramresh :=
			'0' & r.fetch.ramresh(sramlat downto 1); -- (s0) bypassed by (s11)-(s13)

		if r.state = idle then
			if initkp = '1' then
				-- reset all error flags
				v.err := '0';
				v.err_flags := (others => '0');
				-- reinitialize number of pending instructions
				v.ctrl.pending_ops := (others => '0');
				v.shuffle.start := '1';
				v.shuffle.zero := "00";
				v.shuffle.one := "01";
				v.shuffle.two := "10";
				v.shuffle.three := "11";
				v.shuffle.step := 3;
				v.shuffle.state := "00";
				v.shuffle.trng_rdy := '1';
				-- it is important that .kapp be reset to 0 at the begining of each
				-- new [k]P computation, so as to make a certain number of patches
				-- to behave as if Kappa' = 0
				v.ctrl.kapp := '0'; -- (s45) see below (s46) to (s60)
			elsif r.frdy = '1' and fgo = '1' then
				-- trigger of a new program execution
				v.state := running;
				v.frdy := '0'; -- (s32) bypassed by (s31)
				v.fetch.pc := faddr; -- (s8) bypassed by (s9), (s10) & (s28)
				v.fetch.ramresh(sramlat) := '1'; -- (s11) high only 1 cycle thx to (s0)
				v.fetch.state := fetch;
				v.active := '1';
				-- v.stop := '0'; -- (s34) useless due to (s30) + (s33)
			end if;
		end if;

		-- ----------------------------------------------
		--         STATE MACHINE FOR FETCH STAGE
		-- ----------------------------------------------

		if r.fetch.state = fetch then
			if r.fetch.ramresh(0) = '1' then
				v.fetch.opcode := irdata;
				v.fetch.valid := '1'; -- (s14) bypassed by (s15) & (s16)
				v.fetch.state := wwait;
			end if;
		elsif r.fetch.state = wwait then
			if r.decode.rdy = '1' then
				v.fetch.state := fetch;
				v.fetch.pc := -- (s9) bypass of (s8), see also (s10) & (s28)
					std_logic_vector(unsigned(r.fetch.pc) + 1);
				-- (s12) arm shift-reg 'r.fetch.ramresh' (see (s0) above) so that
				-- 'r.fetch.valid' is asserted by (s14) sramlat+1 cycles later
				v.fetch.ramresh(sramlat) := '1'; -- (s12) stays high 1 cycle thx to (s0)
				-- (s12) is bypassed by (s37) below
			end if;
		end if;

		-- deassertion of 'r.fetch.valid' as soon as the decode
		-- stage has acknowledged it
		if r.fetch.valid = '1' and r.decode.rdy = '1' then
			v.fetch.valid := '0'; -- (s15) bypass of (s14)
		end if;

		-- detect possible end of program (STOP) and if so cancel possible
		-- pending fetch from ecc_curve_iram (otherwise this could lead
		-- to the decode stage accepting an ARITHmetic or a BRANCH instruction
		-- opcode which is not supposed to be executed)
		if r.decode.c.stop = '1' or r.stop = '1' then
			v.fetch.ramresh := (others => '0'); -- (s37) bypass of (s12)
			v.fetch.state := idle; -- (s38) redundant with (s39)
			v.fetch.valid := '0';
		end if;

		-- ----------------------------------------------
		--         STATE MACHINE FOR DECODE STAGE
		-- ----------------------------------------------

		-- deassertion of 'r.decode.valid' as soon as ecc_fp has acknowledged it
		if r.decode.valid = '1' and opo.rdy = '1' then
			v.decode.valid := '0'; -- (s4)
		end if;

		case r.decode.state is
			-- ----------
			-- idle state
			-- ----------
			when idle =>
				if r.decode.c.stop = '1' then
					-- r.decode.c.stop = 1 necessarily comes from the last instruction
				 	-- that was executed
					v.stop := '1';
					v.decode.c.stop := '0';
				elsif r.fetch.valid = '1' then
					-- no need to also test 'r.decode.rdy' since we are in 'idle' state
					v.decode.state := decode;
					v.decode.rdy := '0';
					v.decode.pc := r.fetch.pc;
					-- (s7)
					-- dispatch 'r.fetch.opcode' in different fields
					-- 1/ fields common to all types of instructions
					v.decode.c.stop := r.fetch.opcode(OP_S_POS); -- 31
					v.decode.c.barrier := r.fetch.opcode(OP_B_POS); -- 30
					v.decode.c.optype :=
						r.fetch.opcode(OP_TYPE_MSB downto OP_TYPE_LSB); -- 29..28
					v.decode.c.opcode :=
						r.fetch.opcode(OP_OP_MSB downto OP_OP_LSB); -- 27..24
					-- 2/ fields related to ARITHmetic operations
					v.decode.c.extended := r.fetch.opcode(OP_X_POS); -- 23
					v.decode.c.patch := r.fetch.opcode(OP_P_POS); -- 22
					v.decode.a.redcm := r.fetch.opcode(OP_M_POS); -- 15
					v.decode.a.opa := r.fetch.opcode(OPA_MSB downto OPA_LSB); -- 14..10
					-- r.decode.a.opb is also used for TESTPARs
					v.decode.a.opb := r.fetch.opcode(OPB_MSB downto OPB_LSB); -- 9..5
					-- r.decode.a.opc is also used for TESTPAR
					v.decode.a.opc := r.fetch.opcode(OPC_MSB downto OPC_LSB); -- 4..0
					-- 3/ fields related to BRANCH instructions
					v.decode.b.imma := r.fetch.opcode(OP_BR_IMM_SZ - 1 downto 0);
					-- 4/ fields related to the TESTPAR/TESTPARs instruction
					v.decode.c.mu0 := r.fetch.opcode(4);
					v.decode.c.kb0 := r.fetch.opcode(3);
					v.decode.c.par := r.fetch.opcode(2);
					v.decode.c.kap := r.fetch.opcode(1);
					v.decode.c.kapp := r.fetch.opcode(0);

					-- ----------------- /DEBUG BREAKPOINTS/ -----------------------
					-- (s41) breakpoint detection & step-by-step execution
					if debug then
						if v_breakpointhit or r.debug.halt_pending = '1' then
							-- (s100)
							-- if there is an asynchronous operation pending (an FPREDC)
							-- we switch to state 'waitb4bkpt' (instead of 'breakpoint')
							-- in which we'll wait until all pending ops are completed
							-- before actualy entering the 'breakpoint' state and setting
							-- r.debug.halted to 1.
							-- This is for consistancy towards the debug driver software.
							-- Furthermore, it is absolutely necessary not to raise
							-- r.debug.halted before all pending ops are over, for two
							-- reasons:
							--   1. because this signal (which is driven to ecc_axi as
							--      'dbghalted') is polled by software to determine
							--      if the IP is halted: thus software could decide
							--      to read or write ecc_fp_dram however some FPREDC
							--      operation is still running, thus messing with these
							--   2. because as soon as dbghalted is raised, ecc_fp
							--      (to which dbghalted is also wired) grants to ecc_axi
							--      the access muxes to ecc_fp_dram (see (s98) & (s99)
							--      in ecc_fp.vhd) so the FPREDC operators won't be able
							--      to write their result back in ecc_fp_dram
							if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
								v.decode.state := breakpoint;
								v.debug.halted := '1';
								v.debug.halt_pending := '0';
							else
								v.decode.state := waitb4bkpt;
							end if;
							if v_breakpointhit then
								v.debug.breakpointid :=
									std_logic_vector(to_unsigned(v_breakpointnb, 2));
								v.debug.breakpointhit := '1';
							else -- means we were halted by software writing W_DBG_HALT
								v.debug.breakpointhit := '0';
							end if;
						elsif r.debug.severalopcodes = '1' then
							v.debug.nbopcodes := r.debug.nbopcodes - 1;
							if r.debug.nbopcodes(15) = '0' and v.debug.nbopcodes(15) = '1'
							then
								if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
									v.decode.state := breakpoint;
									v.debug.halted := '1';
								else
									v.decode.state := waitb4bkpt;
								end if;
								v.debug.severalopcodes := '0';
								-- we keep r.debug.nbopcodes to 0 for sake of DEBUG_STATUS
								-- register readability
								v.debug.nbopcodes := r.debug.nbopcodes; -- (= 0 here)
							end if;
						else
							--v.debug.breakpointid := "00"; -- doesn't make sense, why 0?
							v.debug.breakpointhit := '0';
						end if;
					end if;
					-- ----------------- \DEBUG BREAKPOINTS\ -----------------------

				else
					v.decode.rdy := '1';
				end if;
			-- ------------
			-- decode state
			-- ------------
			when decode =>
				-- the aim of the 'decode' state is:
				--   - for ARITHmetic operations (see (s22) below): to prepare the
				--     signals to be driven out to ecc_fp while in 'arith' state
				--     (see (s20) below)
				--   - for BRANCH operations (see (s23) below): to prepare the signals
				--     for the logical test (if any) on which the branch depends,
				--     that will be carried out while in the state 'branch' (see (s21)
				--     below)
				--   - for ARITHmetic instructions for which a patch is needed,
				--     all assignments made below in (s22) are kept valid, except that
				--     bypass (s18) will enforce to keep 'r.decode.valid' deasserted
				--     and bypass (s24) will reroute 'r.decode.state' to 'patch' state.
				--   - for ARITHmetic instructions for a which a barrier (synchroni-
				--     zation) is needed, all assignments made below in (s22) are kept
				--     valid, except that bypass (s19) will enforce to keep
				--     'r.decode.valid' deasserted and bypass (s25) will reroute
				--     'r.decode.state' to 'barrier' state.
				--   - for ARITHmetic instructions for which both a patch and a
				--     barrier are required, the order in which the states are taken
				--     is: 1. 'patch', 2. 'barrier', and 3. 'arith'.
				-- by default all flags are deasserted (and only one may be
				-- asserted high by present cycle)
				v.decode.b.b := '0'; v.decode.b.z := '0'; v.decode.b.sn := '0';
				v.decode.b.odd := '0'; v.decode.b.ret := '0';
				v.decode.b.call := '0'; v.decode.b.callsn :='0';
				v.decode.a.add := '0'; v.decode.a.sub := '0';
				v.decode.a.ssrl := '0'; v.decode.a.ssrl_sh := '0';
				v.decode.a.ssll := '0'; v.decode.a.xxor := '0';
				v.decode.a.redc := '0'; v.decode.a.div2 := '0';
				v.decode.a.tpar := '0'; v.decode.a.tparsh := '0';
				v.decode.a.rnd := '0'; v.decode.a.rndm := '0';
				v.decode.a.rndsh := '0'; v.decode.a.rndshf := '0';
				-- decode the type of operation
				case r.decode.c.optype is
					-- ----------------------
					-- decode NOP instruction
					-- ----------------------
					when OPCODE_NOP =>
						if r.decode.c.barrier = '1' then
							-- the NOP has its barrier flag set
							if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
								-- no pending operations, can switch to next opcode
								v.decode.state := idle;
								v.decode.rdy := '1';
							else
								-- at least one pending op, switch to barrier state
								-- to wait for completion of all pending operations
								v.decode.state := barrier;
								v.decode.valid := '0'; -- probably useless (already deasserted)
								-- record that we entered in 'barrier' state for a
								-- NOP instruction
								v.decode.barnop := '1';
							end if;
						elsif r.decode.c.barrier = '0' then
							-- the NOP has the barrier flag unset, can switch to next opcode
							v.decode.state := idle;
							v.decode.rdy := '1';
						end if;
					-- ------------------------------
					-- decode ARITHmetic instructions
					-- ------------------------------
					when OPCODE_ARITH => -- (s22)
						-- It is an arithmetic operation (with no need of a patch)
						-- so we decode the type of operation we need to ask 'ecc_fp'
						-- for, and we switch to 'arith' state
						v.decode.state := arith; -- (s26)
						v.decode.valid := '1'; -- (s17) bypassed by (s18) & (s19)
						-- initialize r.decode.a.pop[abc] registers w/ fields
						-- given in the opcode - they may stay like that by default
						-- or will be edited some more if we go into 'patch' state
						v.decode.a.popa := r.decode.a.opa;
						v.decode.a.popb := r.decode.a.opb;
						v.decode.a.popc := r.decode.a.opc;
						-- we decode the ARITHmetic operation subtype
						v.decode.a.add := '0'; v.decode.a.sub := '0';
						v.decode.a.ssrl := '0'; v.decode.a.ssll := '0';
						v.decode.a.xxor := '0'; v.decode.a.rnd := '0';
						v.decode.a.redc := '0'; v.decode.a.tpar := '0';
						v.decode.a.div2 := '0';
						case r.decode.c.opcode is
							when OPCODE_ARITH_ADD => v.decode.a.add := '1';
							when OPCODE_ARITH_SUB => v.decode.a.sub := '1';
							when OPCODE_ARITH_SRL => v.decode.a.ssrl := '1';
							when OPCODE_ARITH_SRH => v.decode.a.ssrl := '1';
							                         v.decode.a.ssrl_sh := '1';
							when OPCODE_ARITH_SLL => v.decode.a.ssll := '1';
							when OPCODE_ARITH_XOR => v.decode.a.xxor := '1';
							when OPCODE_ARITH_RND => v.decode.a.rnd := '1';
							when OPCODE_ARITH_RED => v.decode.a.redc := '1';
							when OPCODE_ARITH_TST => v.decode.a.tpar := '1';
							when OPCODE_ARITH_TSH => v.decode.a.tpar := '1';
							                         v.decode.a.tparsh := '1';
							when OPCODE_ARITH_DIV => v.decode.a.div2 := '1';
							when OPCODE_ARITH_RNM => v.decode.a.rnd := '1';
							                         v.decode.a.rndm := '1';
							when OPCODE_ARITH_RNH => v.decode.a.rnd := '1';
							                         v.decode.a.rndsh := '1';
							when OPCODE_ARITH_RNF => v.decode.a.rnd := '1';
							                         v.decode.a.rndsh := '1';
							                         v.decode.a.rndshf := '1';
							when others => -- unknown opcode error
								v.err_flags(ERR_INVALID_OPCODE) := '1';
								v.decode.state := errorr; -- 'error' is a VHDL reserved word
						end case;
						-- (note: no need to decode the 'extended' bit (bit 24 of the
						-- opcode) as it directly drives the 'extended' output (see
						-- (s1) below))

						-- is there a patch needed?
						v.decode.patch.p := '0';
						v.decode.patch.as := '0';
						-- reset of patch ctrl bits for opa
						v.decode.patch.opax0 := '0'; v.decode.patch.opax1 := '0';
						v.decode.patch.opay0 := '0'; v.decode.patch.opay1 := '0';
						v.decode.patch.opax0next := '0'; v.decode.patch.opax1next := '0';
						v.decode.patch.opay0next := '0'; v.decode.patch.opay1next := '0';
						v.decode.patch.opax0det := '0'; v.decode.patch.opay0det := '0';
						v.decode.patch.opax1det := '0'; v.decode.patch.opay1det := '0';
						v.decode.patch.opaxtmp := '0'; v.decode.patch.opaytmp := '0';
						v.decode.patch.opaz := '0';
						v.decode.patch.opax1noshuf := '0';
						-- reset of patch ctrl bits for opb
						v.decode.patch.opbx0 := '0'; v.decode.patch.opbx1 := '0';
						v.decode.patch.opby0 := '0'; v.decode.patch.opby1 := '0';
						v.decode.patch.opbx0next := '0'; v.decode.patch.opbx1next := '0';
						v.decode.patch.opby0next := '0'; v.decode.patch.opby1next := '0';
						v.decode.patch.opbz := '0'; v.decode.patch.opbr := '0';
						-- reset of patch ctrl bits for opc
						v.decode.patch.opcx1 := '0';
						v.decode.patch.opcy1 := '0';
						v.decode.patch.opcx0 := '0';
						v.decode.patch.opcy0 := '0';
						v.decode.patch.opcx0next := '0'; v.decode.patch.opcy0next := '0';
						v.decode.patch.opcx1next := '0'; v.decode.patch.opcy1next := '0';
						v.decode.patch.opcvoid := '0';
						v.decode.patch.opccopiesopa := '0';
						v.decode.patch.opcbl0 := '0'; v.decode.patch.opcbl1 := '0';
						v.decode.patch.opcx0det := '0'; v.decode.patch.opcy0det := '0';
						v.decode.patch.opcx1det := '0'; v.decode.patch.opcy1det := '0';
						-- TODO: set a multicycle constraint on paths:
						--   laststep -> r.decode.patch.*
						--   r.ctrl.kb0 -> r.decode.patch.*
						if r.decode.c.patch = '1' then
							-- switch to 'patch' state
							v.decode.state := patch; -- (s24) bypass of (s26)
							-- pragma translate_off
							v.decode.patch.applying := '1';
							v.decode.patch.nb :=
								r.fetch.opcode(OP_PATCH_MSB downto OP_PATCH_LSB);
							if r.fetch.opcode(OP_PATCH_MSB downto OP_PATCH_LSB) /= "000101"
							then
								v.decode.patch.applying_but_not_p5 := '1';
								v.decode.patch.nb_not_p5 :=
									r.fetch.opcode(OP_PATCH_MSB downto OP_PATCH_LSB);
							end if;
							-- pragma translate_on
							v.decode.valid := '0'; -- (s18) bypass of (s17)
							-- decode patch flags
							case r.fetch.opcode(OP_PATCH_MSB downto OP_PATCH_LSB) is -- 21..16
								when "000000" => -- set opa for ",p0" patch
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- the original scalar is actually ODD: the subtraction
											-- performed by ZADDC must NOT take place, and instead
											-- XR0 must be copied into XR1
											v.decode.patch.opax0det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- the original scalar is actually EVEN: the subtraction
											-- performed by ZADDC MUST take place
											null; -- opa by default to XSUB in zaddc.s for this opcode
										end if;
									elsif laststep = '0' then
										if r.ctrl.kap = '1' then
											v.decode.patch.opcx1next := '1';
										elsif r.ctrl.kap = '0' then
											v.decode.patch.opcx0next := '1';
										end if;
									end if;
								when "000001" => -- set opa for ",p1" patch
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- the original scalar is actually ODD: the subtraction
											-- performed by ZADDC must NOT take place, and instead
											-- YR0 must be copied into YR1
											v.decode.patch.opay0det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- the original scalar is actually EVEN: the subtraction
											-- performed by ZADDC MUST take place
											null; -- opa by default to YSUB in zaddc.s for this opcode
										end if;
									elsif laststep = '0' then
										if r.ctrl.kap = '1' then
											v.decode.patch.opcy1next := '1';
										elsif r.ctrl.kap = '0' then
											v.decode.patch.opcy0next := '1';
										end if;
									end if;
								when "000010" => -- set opc for ",p2"
									if laststep = '1' then
										if ((doblinding = '0' and ((r.ctrl.kb0 xor masklsb) = '1'))
										  or
										  (doblinding = '1' and ((r.ctrl.kb0 xor r.ctrl.mu0)='1')))
										then
											-- the original scalar is actually ODD: the subtraction
											-- performed by ZADDC must NOT take place, so ZR01 must
											-- not be updated
											v.decode.patch.opccopiesopa := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											null; -- opc by default to ZR01 in zaddc.s for this opcode
										end if;
									elsif laststep = '0' then
										null; -- opc by default to ZR01 in zaddc.s for this opcode
									end if;
								when "000011" => -- set opc for ",p3" patch
									if laststep = '1' then
										-- this is the FPREDC instruction that computes ZR01
										-- in ZADDC on behalf of ZADDU: it must NOT happen
										-- when in the last step
										v.decode.patch.opccopiesopa := '1';
									elsif laststep = '0' then
										null; -- opc by default to ZR01 in zaddc.s for this opcode
									end if;
								when "000100" => -- ",p4" patch
									v.decode.patch.p := '1';
								when "000101" => -- ",p5"
									v.decode.patch.as := '1';
								when "000110" => -- ",p6" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										v.decode.patch.opay1det := '1';
									elsif laststep = '0' then
										if r0z = '0' and r1z = '1' then
											v.decode.patch.opay0 := '1';
										elsif r0z = '1' and r1z = '0' then
											v.decode.patch.opay1 := '1';
										end if;
									end if;
								when "000111" => -- set opa & opb for ",p7" patch
									-- setup is not used here because it is equivalent
									-- to kapp = 0 (see (s46) just below)
									if r.ctrl.kapp = '1' then
										v.decode.patch.opax1 := '1';
										v.decode.patch.opbx0 := '1';
									elsif r.ctrl.kapp = '0' then -- or setup = 1 (s46), see (s45)
										v.decode.patch.opax0 := '1';
										v.decode.patch.opbx1 := '1';
									end if;
								when "001000" => -- set opa & opb for ",p8" patch
									if r.ctrl.kapp = '0' then -- or setup = 1 (s47), see (s45)
										v.decode.patch.opay0 := '1';
										v.decode.patch.opby1 := '1';
									elsif r.ctrl.kapp = '1' then
										v.decode.patch.opay1 := '1';
										v.decode.patch.opby0 := '1';
									end if;
								when "001001" => -- ",p9" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										v.decode.patch.opax1det := '1';
									elsif laststep = '0' then
										if r0z = '0' and r1z = '1' then
											v.decode.patch.opax0 := '1';
										elsif r0z = '1' and r1z = '0' then
											v.decode.patch.opax1 := '1';
										end if;
									end if;
								when "001010" => -- set opa for ",p10" patch
									--if setup = '1' then
									--	v.decode.patch.opax0 := '1';
									--elsif setup = '0' then
										if r.ctrl.kapp = '0' then -- (s48), see (s45)
											v.decode.patch.opax0 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax1 := '1';
										end if;
									--end if;
								when "001011" => -- set opa & opc for ",p11" patch (in .zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										-- .zadduL called by .setupL and initial point P is a
										-- 2-torsion point ([2]P = 0)
										v.decode.patch.opbr := '1';
										v.decode.patch.opcx0next := '1';
									elsif setup = '1' and p_is_of_order_3 = '1' then
										-- .zadduL called after .setupL with a 3-torsion point
										v.decode.patch.opbr := '1';
										if r.ctrl.kap = '0' then
											-- kappa_1 = 0 (R0 & R1 must switch places)
											v.decode.patch.opcx0next := '1';
										elsif r.ctrl.kap = '1' then
											-- kappa_1 = 1
											v.decode.patch.opcx1next := '1';
										end if;
									elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcx0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcx1next := '1';
										end if;
									elsif r0z = '0' and r1z = '1' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcx1next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcx0next := '1';
										end if;
									elsif r0z = '1' and r1z = '0' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcx1next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcx0next := '1';
										end if;
									else
										-- default case
										-- (including setup = 1 and .first2pz = 0)
										if setup = '1' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opcx0next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opcx1next := '1';
											end if;
										elsif setup = '0' then
											if r.ctrl.kapp = '0' then -- (s49), see (s45)
												v.decode.patch.opcx0next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opcx1next := '1';
											end if;
										end if;
									end if;
								when "001100" => -- set opa & opc for ",p12" patch (in .zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										-- .zadduL called by .setupL and initial point P is a
										-- 2-torsion point ([2]P = 0)
										v.decode.patch.opbr := '1';
										v.decode.patch.opcy0next := '1';
									elsif setup = '1' and p_is_of_order_3 = '1' then
										-- .zadduL called after .setupL with a 3-torsion point
										v.decode.patch.opbr := '1';
										if r.ctrl.kap = '0' then
											-- kappa_1 = 0 (R0 & R1 must switch places)
											v.decode.patch.opcy0next := '1';
										elsif r.ctrl.kap = '1' then
											-- kappa_1 = 1
											v.decode.patch.opcy1next := '1';
										end if;
									elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcy0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcy1next := '1';
										end if;
									elsif r0z = '0' and r1z = '1' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcy1next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcy0next := '1';
										end if;
									elsif r0z = '1' and r1z = '0' then
										v.decode.patch.opbr := '1';
										if r.ctrl.kapp = '0' then
											v.decode.patch.opcy1next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcy0next := '1';
										end if;
									else -- default case
										if setup = '1' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opcy0next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opcy1next := '1';
											end if;
										elsif setup = '0' then
											if r.ctrl.kapp = '0' then -- (s50), see (s45)
												v.decode.patch.opcy0next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opcy1next := '1';
											end if;
										end if;
									end if;
								when "001101" => -- set opc for ",p13" patch
									if laststep = '1' then
										if ((doblinding='0' and ((r.ctrl.kb0 xor masklsb) = '1'))
										  or
										  (doblinding='1' and ((r.ctrl.kb0 xor r.ctrl.mu0) = '1')))
										then
											-- the original scalar is actually ODD: the subtraction
											-- performed by ZADDC must NOT take place
											v.decode.patch.opccopiesopa := '1';
										else
											-- the original scalar is actually EVEN: the subtraction
											-- performed by ZADDC MUST take place
											null; -- opc by default to XR0 in zaddc.s for this opcode
										end if;
									elsif laststep = '0' then
										if r.ctrl.kap = '1' then
											v.decode.patch.opcx0next := '1';
										elsif r.ctrl.kap = '0' then
											v.decode.patch.opcx1next := '1';
										end if;
									end if;
								when "001110" => -- set opb for ",p14" patch
									if laststep = '1' then
										null; -- opb by default to XR0 in zaddc.s for this opcode
									elsif r.ctrl.kap = '1' then
										v.decode.patch.opbx0next := '1';
									elsif r.ctrl.kap = '0' then
										v.decode.patch.opbx1next := '1';
									end if;
								when "001111" => -- set opc for ",p15" patch
									if laststep = '1' then
										if ((doblinding='0' and ((r.ctrl.kb0 xor masklsb) = '1'))
										  or
										  (doblinding='1' and ((r.ctrl.kb0 xor r.ctrl.mu0) = '1')))
										then
											-- the original scalar is actually ODD: the subtraction
											-- performed by ZADDC must NOT take place
											v.decode.patch.opccopiesopa := '1';
										else
											-- the original scalar is actually EVEN: the subtraction
											-- performed by ZADDC MUST take place
											null; -- opc by default to YR0 in zaddc.s for this opcode
										end if;
									elsif laststep = '0' then
										if r.ctrl.kap = '1' then
											v.decode.patch.opcy0next := '1';
										elsif r.ctrl.kap = '0' then
											v.decode.patch.opcy1next := '1';
										end if;
									end if;
								when "010000" => -- set opc for ",p16" patch
									if r.ctrl.par = '1' then
										v.decode.patch.opcbl0 := '1';
									elsif r.ctrl.par = '0' then
										v.decode.patch.opcvoid := '1';
									end if;
								when "010001" => -- set opc for ",p17" patch
									if r.ctrl.par = '1' then
										v.decode.patch.opcbl1 := '1';
									elsif r.ctrl.par = '0' then
										v.decode.patch.opcvoid := '1';
									end if;
								when "010010" => -- set opc for ",p18" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										if ((doblinding = '0' and ((r.ctrl.kb0 xor masklsb) = '1'))
										  or
										  (doblinding ='1' and ((r.ctrl.kb0 xor r.ctrl.mu0) = '1')))
										then
											-- the original scalar is actually ODD
											v.decode.patch.opaz := '1';
										else
											-- the original scalar is actually EVEN
											null; -- keep opa to address of variable 'Yopp'
										end if;
										v.decode.patch.opcy1det := '1';
									elsif laststep = '0' then
										if r0z = '0' and r1z = '1' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
												v.decode.patch.opcy0next := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
												v.decode.patch.opcy1next := '1';
											else
												v.decode.patch.opcvoid := '1';
											end if;
										elsif r0z = '1' and r1z = '0' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
												v.decode.patch.opcy0next := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
												v.decode.patch.opcy1next := '1';
											else
												v.decode.patch.opcvoid := '1';
											end if;
										end if;
									end if;
								when "010011" => -- set opc for ",p19" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										v.decode.patch.opaz := '1';
										v.decode.patch.opcy0det := '1';
									elsif laststep = '0' then
										if r0z = '0' and r1z = '1' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
												v.decode.patch.opcy0next := '1';
											else
												v.decode.patch.opcy0next := '1';
											end if;
										elsif r0z = '1' and r1z = '0' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
												v.decode.patch.opcy0next := '1';
											else
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									end if;
								when "010100" => -- set opa for ",p20" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										if ((doblinding = '0' and ((r.ctrl.kb0 xor masklsb) = '1'))
										  or
										  (doblinding ='1' and ((r.ctrl.kb0 xor r.ctrl.mu0) = '1')))
										then
											-- the original scalar is actually ODD
											v.decode.patch.opaz := '1';
										else
											-- the original scalar is actually EVEN
											null; -- keep opa to address of variable 'Yopp'
										end if;
										v.decode.patch.opcx1det := '1';
									elsif laststep = '0' then
										v.decode.patch.opcx0next := '1';
									end if;
								when "010101" => -- set opa for ",p21" patch (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										v.decode.patch.opaz := '1';
										v.decode.patch.opcx0det := '1';
									elsif laststep = '0' then
										v.decode.patch.opcx1next := '1';
									end if;
								when "010110" => -- set opc for ",p22" patch
									if r.ctrl.torsion2 = '1' then
										v.decode.patch.opaz := '1';
										v.decode.patch.opbz := '1';
									end if;
								when "010111" => -- set opc for ",p23" patch
									if r.ctrl.torsion2 = '1' then
										v.decode.patch.opax1noshuf := '1';
									end if;
								when "011000" => -- set opc for ",p24" patch
									if setup = '1' then
										if r.ctrl.first2pz = '1' then
											-- .zadduL called by .setupL and initial point P is a
											-- 2-torsion point ([2]P = 0)
											v.decode.patch.opax0next := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcx1next := '1';
										elsif r.ctrl.first2pz = '0' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opcx1next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opcx0next := '1';
											end if;
										end if;
									elsif setup = '0' then
										if (r0z xor r1z) = '1' then
											v.decode.patch.opcvoid := '1';
										elsif (r0z xor r1z) = '0' then
											if r.ctrl.kapp = '0' then -- (s51), see (s45)
												v.decode.patch.opcx1next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opcx0next := '1';
											end if;
										end if;
									end if;
								when "011001" => -- set opb for ",p25" patch
									if setup = '1' then
										if r.ctrl.kap = '0' then
											-- kappa_1 = 0 (R0 & R1 must switch places)
											v.decode.patch.opbx0next := '1';
										elsif r.ctrl.kap = '1' then
											-- kappa_1 = 1
											v.decode.patch.opbx1next := '1';
										end if;
									elsif setup = '0' then
										if r.ctrl.kapp = '0' then -- (s52), see (s45)
											v.decode.patch.opbx0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opbx1next := '1';
										end if;
									end if;
								when "011010" => -- set opa & opb ",p26" patch
									if setup = '1' then
										if r.ctrl.kap = '0' then
											-- kappa_1 = 0 (R0 & R1 must switch places)
											v.decode.patch.opax0next := '1';
											v.decode.patch.opbx1next := '1';
										elsif r.ctrl.kap = '1' then
											-- kappa_1 = 1
											v.decode.patch.opax1next := '1';
											v.decode.patch.opbx0next := '1';
										end if;
									elsif setup = '0' then
										if r.ctrl.kapp = '0' then -- (s53), see (s45)
											v.decode.patch.opax0next := '1';
											v.decode.patch.opbx1next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax1next := '1';
											v.decode.patch.opbx0next := '1';
										end if;
									end if;
								when "011011" => -- set opc for ",p27" patch
									if setup = '1' then
										if r.ctrl.first2pz = '1' then
											-- .zadduL called by .setupL and initial point P is a
											-- 2-torsion point ([2]P = 0)
											v.decode.patch.opcy1next := '1';
										elsif r.ctrl.first2pz = '0' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									elsif setup = '0' then
										if (r0z xor r1z) = '1' then
											v.decode.patch.opcvoid := '1';
										elsif (r0z xor r1z) = '0' then
											if r.ctrl.kapp = '0' then -- (s54), see (s45)
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									end if;
								when "011100" => -- set opa, opb & opc for ",p28" patch
									if setup = '1' then
										if r.ctrl.first2pz = '1' then
											-- .zadduL called by .setupL and initial point P is a
											-- 2-torsion point ([2]P = 0)
											v.decode.patch.opay0next := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcy1next := '1';
										elsif r.ctrl.first2pz = '0' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opay1next := '1';
												v.decode.patch.opby0next := '1';
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opay0next := '1';
												v.decode.patch.opby1next := '1';
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									elsif setup = '0' then
										if (r0z xor r1z) = '1' then
											v.decode.patch.opcvoid := '1';
										elsif (r0z xor r1z) = '0' then
											if r.ctrl.kapp = '0' then -- (s55), see (s45)
												v.decode.patch.opay1next := '1';
												v.decode.patch.opby0next := '1';
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opay0next := '1';
												v.decode.patch.opby1next := '1';
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									end if;
								when "011101" => -- set opa & opb for ",p29" patch
									if laststep = '1' then
										null; -- opa/opb already set to XR1/XR0 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opax0 := '1';
											v.decode.patch.opbx1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax1 := '1';
											v.decode.patch.opbx0 := '1';
										end if;
									end if;
								when "011110" => -- set opa & opb for ",p30" patch
									if laststep = '1' then
										null; -- opa/opb already set to YR1/YR0 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opay0 := '1';
											v.decode.patch.opby1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opay1 := '1';
											v.decode.patch.opby0 := '1';
										end if;
									end if;
								when "011111" => -- set opa & opb for ",p31" patch
									if laststep = '1' then
										null; -- opa/opb already set to YR0/YR1 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opay1 := '1';
											v.decode.patch.opby0 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opay0 := '1';
											v.decode.patch.opby1 := '1';
										end if;
									end if;
								when "100000" => -- set opa for ",p32" patch
									if laststep = '1' then
										null; -- opa already set to XR0 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opax1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax0 := '1';
										end if;
									end if;
								when "100001" => -- set opa for ",p33" patch
									if laststep = '1' then
										null; -- opa already set to XR1 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opax0 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax1 := '1';
										end if;
									end if;
								when "100010" => -- set opa for ",p34" patch
									if laststep = '1' then
										null; -- opa already set to YR0 in zaddc.s
									elsif laststep = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opay1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opay0 := '1';
										end if;
									end if;
								when "100011" => -- set opa & opc for ",p35" patch (in .zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										-- .zadduL called by .setupL and initial point P is a
										-- 2-torsion point ([2]P = 0)
										v.decode.patch.opay1 := '1';
									elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opay1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opay0 := '1';
										end if;
									elsif r0z = '0' and r1z = '1' then
										v.decode.patch.opay0 := '1';
									elsif r0z = '1' and r1z = '0' then
										v.decode.patch.opay1 := '1';
									else
										-- default case
										-- (including setup = 1 and .first2pz = 0 thx to (s56))
										if r.ctrl.kapp = '0' then -- (s56), see (s45)
											v.decode.patch.opay1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opay0 := '1';
										end if;
									end if;
								when "100100" => -- ",p36" patch (in .zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										-- .zadduL called by .setupL and initial point P is a
										-- 2-torsion point ([2]P = 0)
										v.decode.patch.opax1 := '1';
									elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opax1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax0 := '1';
										end if;
									elsif r0z = '0' and r1z = '1' then
										v.decode.patch.opax0 := '1';
									elsif r0z = '1' and r1z = '0' then
										v.decode.patch.opax1 := '1';
									else
										-- default case
										-- (including setup = 1 and .first2pz = 0 thx to (s57))
										if r.ctrl.kapp = '0' then -- (s57), see (s45)
											v.decode.patch.opax1 := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opax0 := '1';
										end if;
									end if;
								when "100101" => -- ",p37" patch
									if setup = '1' then
										if r.ctrl.kap = '0' then
											-- kappa_1 = 0 (R0 & R1 must switch places)
											v.decode.patch.opbx0next := '1';
										elsif r.ctrl.kap = '1' then
											-- kappa_1 = 1
											v.decode.patch.opbx1next := '1';
										end if;
									elsif setup = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opbx0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opbx1next := '1';
										end if;
									end if;
								when "100110" => -- set opa & opc for ",p38" patch (in zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										-- .zadduL called by .setupL and initial point P is a
										-- 2-torsion point ([2]P = 0)
										v.decode.patch.as := '1'; -- same as ,p5 patch
										v.decode.patch.opax1next := '1';
										v.decode.patch.opcx1next := '1';
									elsif r0z = '0' and r1z = '1' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opax1next := '1';
											v.decode.patch.opcx0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opaxtmp := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcx1next := '1';
										end if;
									elsif r0z = '1' and r1z = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opaxtmp := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcx0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcx1next := '1';
										end if;
									else -- default case (including r0z = r1z = 0 and pts opposed)
										v.decode.patch.as := '1'; -- same as ,p5 patch
										if setup = '1' then -- 
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opax1next := '1';
												v.decode.patch.opcx1next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opax0next := '1';
												v.decode.patch.opcx0next := '1';
											end if;
										elsif setup = '0' then
											if r.ctrl.kapp = '0' then -- (s59), see (s45)
												v.decode.patch.opax1next := '1';
												v.decode.patch.opcx1next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opax0next := '1';
												v.decode.patch.opcx0next := '1';
											end if;
										end if;
									end if;
								when "100111" => -- set opa & opc for ",p39" patch (in .zadduL)
									if setup = '1' and r.ctrl.first2pz = '1' then
										v.decode.patch.as := '1'; -- same as ,p5 patch
										v.decode.patch.opay1next := '1';
										v.decode.patch.opcy1next := '1';
									elsif r0z = '0' and r1z = '1' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opay1next := '1';
											v.decode.patch.opcy0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opaytmp := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcy1next := '1';
										end if;
									elsif r0z = '1' and r1z = '0' then
										if r.ctrl.kapp = '0' then
											v.decode.patch.opaytmp := '1';
											v.decode.patch.opbz := '1';
											v.decode.patch.opcy0next := '1';
										elsif r.ctrl.kapp = '1' then
											v.decode.patch.opcy1next := '1';
										end if;
									else
										-- default case, including:
										--  - r0z = r1z = 0 and pts opposed)
										--  - setup = 1 and r.ctrl.first2pz = 0
										v.decode.patch.as := '1'; -- same as ,p5 patch
										if setup = '1' then
											if r.ctrl.kap = '0' then
												-- kappa_1 = 0 (R0 & R1 must switch places)
												v.decode.patch.opay1next := '1';
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kap = '1' then
												-- kappa_1 = 1
												v.decode.patch.opay0next := '1';
												v.decode.patch.opcy0next := '1';
											end if;
										elsif setup = '0' then
											if r.ctrl.kapp = '0' then -- (s60), see (s45)
												v.decode.patch.opay1next := '1';
												v.decode.patch.opcy1next := '1';
											elsif r.ctrl.kapp = '1' then
												v.decode.patch.opay0next := '1';
												v.decode.patch.opcy0next := '1';
											end if;
										end if;
									end if;
								when "101000" => -- set opa for ",p40" patch
									if r.ctrl.par = '0' then
										-- result of the scalar loop is in R0
										v.decode.patch.opax0 := '1';
									elsif r.ctrl.par = '1' then
										-- result of the scalar loop is in R1
										v.decode.patch.opax1 := '1';
									end if;
								when "101001" => -- set opa for ",p41" patch
									if r.ctrl.par = '0' then
										-- result of the scalar loop is in R0
										v.decode.patch.opay0 := '1';
									elsif r.ctrl.par = '1' then
										-- result of the scalar loop is in R1
										v.decode.patch.opay1 := '1';
									end if;
								when "101010" => -- set opa for ",p42" patch
									-- means this instruction, once executed, must set XR0==XR1
									v.ctrl.test_x_equality := '1';
									v.decode.patch.p := '1';
								when "101011" => -- set opa for ",p43" patch
									-- means this instruction, once executed, must set YR0==YR1
									v.ctrl.test_y_equality := '1';
									v.decode.patch.p := '1';
								when "101100" => -- set opa for ",p44" patch
									-- means this instruction, once executed, must set YR0==-YR1
									v.ctrl.test_y_opposite := '1';
									v.decode.patch.p := '1';
								when "101101" => -- set opa for ",p45" patch
									if fr0z = '1' and fr1z = '0' then -- R0 = 0 and R1 != 0
										v.decode.patch.opcx1 := '1';
									elsif fr0z = '0' and fr1z = '1' then -- R0 != 0 and R1 = 0
										v.decode.patch.opcx1 := '1';
										v.decode.patch.opax0 := '1';
									end if;
								when "101110" => -- set opa for ",p46" patch
									if fr0z = '1' and fr1z = '0' then -- R0 = 0 and R1 != 0
										v.decode.patch.opcy1 := '1';
									elsif fr0z = '0' and fr1z = '1' then -- R0 != 0 and R1 = 0
										v.decode.patch.opcy1 := '1';
										v.decode.patch.opay0 := '1';
									end if;
								when "101111" => -- detect possible 0-result for patch ,p47"
									-- patch ,p47 includes the same functionality as ,p4
									v.ctrl.detect2pz := '1';
									v.decode.patch.p := '1';
								when "110000" => -- detect possible 0-result for patch ",p48"
									-- patch ,p48 includes the same functionality as ,p4
									v.ctrl.detectxmxz := '1';
									v.decode.patch.p := '1';
								when "110001" => -- detect possible 0-result for patch ",p49"
									-- patch ,p49 includes the same functionality as ,p4
									v.ctrl.detectymyz := '1';
									v.decode.patch.p := '1';
								when "110010" => -- detect possible 0-result for patch ",p50"
									null;
								when "110011" => -- possibly restore ZR01 for patch ",p51"
									-- if first2pz = 1 then [2]P = 0, so we must restore
									-- back ZR01 from ZPBK in this case, so we must NOT
									-- modify the opcode tagged w/ ,p51 in this case!
									v.decode.patch.opcvoid := not r.ctrl.first2pz;
								when "110100" => -- possibly restore ZR01 for patch ",p52"
									-- if first2pz = 1 then [2]P = 0, so we must modify
									-- the opcodes tagged w/ ,p52 so that opc is set to
									-- a dummy target address
									v.decode.patch.opcvoid := r.ctrl.first2pz;
								when "110101" => -- patch ",p53" (in .zdblL)
									if laststep = '1' then
										v.decode.patch.opax0det := '1';
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opax0 := '1';
													--v.decode.patch.opcx1 := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opax1 := '1';
													--v.decode.patch.opcx1 := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												v.decode.patch.opax1 := '1';
												--v.decode.patch.opcx1 := '1';
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												--v.decode.patch.opcx1 := '1';
												if r.ctrl.kapp = '0' then
													v.decode.patch.opax1 := '1';
												elsif r.ctrl.kapp = '1' then
													v.decode.patch.opax0 := '1';
												end if;
											end if;
										end if;
									end if;
								when "110110" => -- patch ",p54" (in .zdblL)
									if laststep = '1' then
										v.decode.patch.opay0det := '1';
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opay0 := '1';
													--v.decode.patch.opcy1 := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opay1 := '1';
													--v.decode.patch.opcy1 := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												v.decode.patch.opay1 := '1';
												--v.decode.patch.opcy1 := '1';
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												--v.decode.patch.opcy1 := '1';
												if r.ctrl.kapp = '0' then
													v.decode.patch.opay1 := '1';
												elsif r.ctrl.kapp = '1' then
													v.decode.patch.opay0 := '1';
												end if;
											end if;
										end if;
									end if;
								when "110111" => -- patch ",p55" (in .znegcL)
									-- ZNEGC
									if laststep = '1' then
										v.decode.patch.opaz := '1';
										v.decode.patch.opcy0det := '1';
									elsif laststep = '0' then
										if r0z = '0' and r1z = '1' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
												v.decode.patch.opcvoid := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
												v.decode.patch.opcvoid := '1';
											else
												v.decode.patch.opcy1next := '1';
											end if;
										elsif r0z = '1' and r1z = '0' then
											if r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
												v.decode.patch.opcvoid := '1';
											elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
												v.decode.patch.opcvoid := '1';
											else
												v.decode.patch.opcy1next := '1';
											end if;
										end if;
									end if;
								when "111000" => -- detect possible 0-result for patch ",p56"
									v.ctrl.detecttorsion2 := '1';
									v.decode.patch.p := '1';
								when "111001" => -- patch ",p57" (in .zdblL)
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- original scalar is actually ODD
											v.decode.patch.opcx1det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- original scalar is actually EVEN
											if pts_are_equal = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcx1det := '1';
											elsif pts_are_oppos = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcx0det := '1';
											end if;
										end if;
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opcx1next := '1';
													--v.decode.patch.opax1 := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opcx0next := '1';
													--v.decode.patch.opax1 := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												--v.decode.patch.opax1 := '1';
												if r.ctrl.kap = '0' then
													v.decode.patch.opcx0next := '1';
												elsif r.ctrl.kap = '1' then
													v.decode.patch.opcx1next := '1';
												end if;
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												--v.decode.patch.opax1 := '1';
												if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
													v.decode.patch.opcx1next := '1';
												elsif r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
													v.decode.patch.opcx1next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
													v.decode.patch.opcx0next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
													v.decode.patch.opcx0next := '1';
												end if;
											end if;
										end if;
									end if;
								when "111010" => -- patch ",p58" (in .zdblL)
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- original scalar is actually ODD
											v.decode.patch.opcy1det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- original scalar is actually EVEN
											if pts_are_equal = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcy1det := '1';
											elsif pts_are_oppos = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcy0det := '1';
											end if;
										end if;
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opcy1next := '1';
													--v.decode.patch.opay1 := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opcy0next := '1';
													--v.decode.patch.opay1 := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												--v.decode.patch.opay1 := '1';
												if r.ctrl.kap = '0' then
													v.decode.patch.opcy0next := '1';
												elsif r.ctrl.kap = '1' then
													v.decode.patch.opcy1next := '1';
												end if;
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												--v.decode.patch.opay1 := '1';
												if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
													v.decode.patch.opcy1next := '1';
												elsif r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
													v.decode.patch.opcy1next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
													v.decode.patch.opcy0next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
													v.decode.patch.opcy0next := '1';
												end if;
											end if;
										end if;
									end if;
								when "111011" => -- patch ",p59" (in .zdblL)
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- original scalar is actually ODD
											v.decode.patch.opaz := '1';
											v.decode.patch.opcx0det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- original scalar is actually EVEN
											if pts_are_equal = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcx0det := '1';
											elsif pts_are_oppos = '1' then
												v.decode.patch.opcx1det := '1';
											end if;
										end if;
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opcx0next := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opcx1next := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kap = '0' then
													v.decode.patch.opcx1next := '1';
												elsif r.ctrl.kap = '1' then
													v.decode.patch.opcx0next := '1';
												end if;
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
													v.decode.patch.opcx0next := '1';
												elsif r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
													v.decode.patch.opcx0next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
													v.decode.patch.opcx1next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
													v.decode.patch.opcx1next := '1';
												end if;
											end if;
										end if;
									end if;
								when "111100" => -- patch ",p60" (in .zdblL)
									if laststep = '1' then
										if (doblinding = '0' and (r.ctrl.kb0 xor masklsb) = '1')
											or (doblinding = '1' and (r.ctrl.kb0 xor r.ctrl.mu0)='1')
										then
											-- original scalar is actually ODD
											v.decode.patch.opaz := '1';
											v.decode.patch.opcy0det := '1';
										else -- (r.ctrl.kb0 xor "LSB of approp. mask") = '0'
											-- original scalar is actually EVEN
											if pts_are_equal = '1' then
												v.decode.patch.opaz := '1';
												v.decode.patch.opcy0det := '1';
											elsif pts_are_oppos = '1' then
												v.decode.patch.opcy1det := '1';
											end if;
										end if;
									elsif laststep = '0' then
										if zu = '1' and zc = '0' then
											-- ZDBLU
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kapp = '1' then
													v.decode.patch.opcy0next := '1';
												elsif r.ctrl.kapp = '0' then
													v.decode.patch.opcy1next := '1';
												end if;
											end if;
										elsif zu = '0' and zc = '1' then
											-- ZDBLC
											if r0z = '0' and r1z = '0' and pts_are_equal = '1' then
												if r.ctrl.kap = '0' then
													v.decode.patch.opcy1next := '1';
												elsif r.ctrl.kap = '1' then
													v.decode.patch.opcy0next := '1';
												end if;
											elsif r0z = '0' and r1z = '0' and pts_are_oppos = '1' then
												if r.ctrl.kap = '0' and r.ctrl.kapp = '0' then
													v.decode.patch.opcy0next := '1';
												elsif r.ctrl.kap = '0' and r.ctrl.kapp = '1' then
													v.decode.patch.opcy0next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '0' then
													v.decode.patch.opcy1next := '1';
												elsif r.ctrl.kap = '1' and r.ctrl.kapp = '1' then
													v.decode.patch.opcy1next := '1';
												end if;
											end if;
										end if;
									end if;
								when "111101" => -- patch ",p61" (in .zdblL)
									v.decode.patch.opcvoid := r.ctrl.torsion2;
								when "111110" => -- possibly restore ZR01 for patch ",p62"
									-- if first2pz = 1 then [2]P = 0, so we must modify
									-- the opcodes tagged w/ ,p62 so that opc is set to
									-- a dummy target address
									v.decode.patch.opcvoid := r.ctrl.first2pz;
									v.decode.patch.opbr := p_is_of_order_3;
								when "111111" => -- possibly not clobber ZR01 for patch ",p63"
									v.decode.patch.opcvoid :=
										r0z or r1z or pts_are_equal or pts_are_oppos
										or (r.ctrl.first2pz and setup);
								when others =>
									null;
							end case;
						end if;

						-- is there a barrier?
						if r.decode.c.barrier = '1' then
							-- the opcode has its barrier flag set
							if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
								-- the opcode has its barrier flag set, but there is no
								-- pending operation, all state transitions made above
								-- are legitimate: change nothing (in particular assertion
								-- of r.decode.valid made by (s17) & switch to 'arith' state
								-- made by (s26)
								null;
							else
								-- the opcode has its barrier flag set, and there IS at least
								-- one pending op
								if r.decode.c.patch = '0' then
									-- there is no patch to perform on the opcode, so switch
							 		-- to 'barrier' state to wait for completion of all pending
									-- ops
									v.decode.state := barrier; -- (s25) bypass of (s26)
									v.decode.valid := '0'; -- (s19) bypass of (s17)
								elsif r.decode.c.patch = '1' then
									-- (s111) there is a patch to perform on the opcode but
									-- (s24) (switch of r.decode.state to 'patch' state) still
									-- is valid: waiting for pending operations to complete will
									-- be done later: from the 'patch' state we'll switch to
									-- 'barrier' state, having kept in memory that a barrier is
									-- present on the opcode (thx to register r.decode.c.barrier,
									-- see (s110))
									null;
								end if; -- patch
							end if; -- pending_ops
						end if; -- barrier

					-- --------------------------
					-- decode BRANCH instructions
					-- --------------------------
					when OPCODE_BRANCH => -- (s23)
						-- it is a branch instruction: we decode the condition flags,
						-- and switch to 'branch' state
						v.decode.b.b := '0'; v.decode.b.z := '0'; v.decode.b.sn := '0';
						v.decode.b.odd := '0'; v.decode.b.ret := '0';
						v.decode.b.call := '0'; v.decode.b.callsn :='0';
						case r.decode.c.opcode is
							when OPCODE_BRA_B => v.decode.b.b := '1';
							when OPCODE_BRA_BZ => v.decode.b.z := '1';
							when OPCODE_BRA_BSN => v.decode.b.sn := '1';
							when OPCODE_BRA_BODD => v.decode.b.odd := '1';
							when OPCODE_BRA_CALL => v.decode.b.call := '1';
							when OPCODE_BRA_CALLSN => v.decode.b.callsn := '1';
							when OPCODE_BRA_RET => v.decode.b.ret := '1';
							when others => -- unknown opcode error
								v.err_flags(ERR_INVALID_OPCODE) := '1';
								v.decode.state := errorr;
						end case;
						if r.decode.c.barrier = '1' then
							-- branch opcode has its barrier flag set
							if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
								-- there is no pending op, we can switch to 'branch'
								-- state to actually perform the branch
								v.decode.state := branch;
							else
								-- there is at least one pending op, so switch to 'barrier'
								-- state to wait for all pending ops to complete before
								-- actually performing the branch
								v.decode.state := barrier;
								-- record that we entered in 'barrier' state for a
								-- branch instruction
								v.decode.barbra := '1';
							end if;
						else
							-- branch opcode has the barrier flag unset, so directly switch
							-- to the 'branch' state to actually perform the branch
							v.decode.state := branch;
						end if;

					when others => null;
				end case;
			-- -----------
			-- patch state
			-- -----------
			when patch =>
				-- apply patch, that is compute appropriate values of operands
				-- opA, opB and opC (resp.) in registers 'r.decode.a.popa',
				-- 'r.decode.a.popb' and 'r.decode.a.popc' (resp.)
				-- handle 'P' flag
				if r.decode.patch.p = '1' then
					if r.ctrl.sn = '1' then
						v.decode.a.popb := C_PATCH_P;
					elsif r.ctrl.sn = '0' then
						v.decode.a.popb := C_PATCH_ZERO;
					end if;
				end if;
				-- handle 'AS' flag
				if r.decode.patch.as = '1' then
					if r.ctrl.sn = '0' then
						v.decode.a.popb := C_PATCH_ZERO;
					elsif r.ctrl.sn = '1' then
						v.decode.a.popb := C_PATCH_TWOP;
					end if;
				end if;
				-- handle other numerical values of patch field
				if compkp = '1' then
					-- ---
					-- opa
					-- ---
					if r.decode.patch.opax0det  = '1' then
						v.decode.a.popa := CST_ADDR_XR0;
					elsif r.decode.patch.opay0det  = '1' then
						v.decode.a.popa := CST_ADDR_YR0;
					elsif r.decode.patch.opax1det  = '1' then
						v.decode.a.popa := CST_ADDR_XR1;
					elsif r.decode.patch.opay1det  = '1' then
						v.decode.a.popa := CST_ADDR_YR1;
					elsif r.decode.patch.opax0 = '1' then
						v.decode.a.popa := -- (1 downto 0)
	 						XYR01_MSB & r.shuffle.zero;
					elsif r.decode.patch.opay0 = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.one;
					elsif r.decode.patch.opax1 = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.two;
					elsif r.decode.patch.opay1 = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.three;
					elsif r.decode.patch.opax0next = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_zero;
					elsif r.decode.patch.opay0next = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_one;
					elsif r.decode.patch.opax1next = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_two;
					elsif r.decode.patch.opay1next = '1' then
						v.decode.a.popa := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_three;
					elsif r.decode.patch.opaxtmp = '1' then
						v.decode.a.popa := C_PATCH_XTMP;
					elsif r.decode.patch.opaytmp = '1' then
						v.decode.a.popa := C_PATCH_YTMP;
					elsif r.decode.patch.opaz = '1' then
						v.decode.a.popa := C_PATCH_ZERO;
					elsif r.decode.patch.opax1noshuf = '1' then
						v.decode.a.popa := CST_ADDR_XR1;
					end if;
					-- ---
					-- opb
					-- ---
					if r.decode.patch.opbx0 = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.zero;
					elsif r.decode.patch.opby0 = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.one;
					elsif r.decode.patch.opbx1 = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.two;
					elsif r.decode.patch.opby1 = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.three;
					elsif r.decode.patch.opbx0next = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_zero;
					elsif r.decode.patch.opby0next = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_one;
					elsif r.decode.patch.opbx1next = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_two;
					elsif r.decode.patch.opby1next = '1' then
						v.decode.a.popb := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_three;
					elsif r.decode.patch.opbz = '1' then
						v.decode.a.popb := C_PATCH_ZERO;
					elsif r.decode.patch.opbr = '1' then
						v.decode.a.popb := C_PATCH_R;
					end if;
					-- ---
					-- opc
					-- ---
					if r.decode.patch.opcx1 = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.two;
					elsif r.decode.patch.opcy1 = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.three;
					elsif r.decode.patch.opcx0next = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_zero;
					elsif r.decode.patch.opcy0next = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_one;
					elsif r.decode.patch.opcx1next = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_two;
					elsif r.decode.patch.opcy1next = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.next_three;
					elsif r.decode.patch.opccopiesopa = '1' then
						v.decode.a.popc := r.decode.a.popa;
					elsif r.decode.patch.opcvoid = '1' then
						v.decode.a.popc := C_PATCH_OPC_VOID;
					elsif r.decode.patch.opcbl0 = '1' then
						v.decode.a.popc := C_PATCH_KB0;
					elsif r.decode.patch.opcbl1 = '1' then
						v.decode.a.popc := C_PATCH_KB1;
					elsif r.decode.patch.opcx0 = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.zero;
					elsif r.decode.patch.opcy0 = '1' then
						v.decode.a.popc := -- (1 downto 0)
							XYR01_MSB & r.shuffle.one;
					elsif r.decode.patch.opcx0det = '1' then
						v.decode.a.popc := CST_ADDR_XR0;
					elsif r.decode.patch.opcy0det = '1' then
						v.decode.a.popc := CST_ADDR_YR0;
					elsif r.decode.patch.opcx1det = '1' then
						v.decode.a.popc := CST_ADDR_XR1;
					elsif r.decode.patch.opcy1det = '1' then
						v.decode.a.popc := CST_ADDR_YR1;
					end if;
				elsif comppop = '1' then
					-- opa
					if r.decode.patch.opax0 = '1' then
						v.decode.a.popa := CST_ADDR_XR0BK;
					elsif r.decode.patch.opay0 = '1' then
						v.decode.a.popa := CST_ADDR_YR0BK;
					end if;
					-- opc
					if r.decode.patch.opcx1 = '1' then
						v.decode.a.popc := CST_ADDR_XR1;
					elsif r.decode.patch.opcy1 = '1' then
						v.decode.a.popc := CST_ADDR_YR1;
					end if;
				end if; -- compkp/comppop
				-- now switch to next state ('arith' or 'barrier')
				if r.decode.c.barrier = '1' then -- (s110), see (s111)
					v.decode.state := barrier;
				else
					-- BRANCH instructions never being patched, it's necessarily
					-- an ARITHmetic instruction, so we switch to 'arith' state
					v.decode.state := arith;
					v.decode.valid := '1';
				end if;
				-- note that patching is assumed not to be compatible with the
				-- 'r' flag (so we don't even test it here)
				-- pragma translate_off
				v.decode.patch.applying := '0';
				v.decode.patch.applying_but_not_p5 := '0';
				-- pragma translate_on
			-- -------------
			-- barrier state (TODO)
			-- -------------
			when barrier =>
				-- we stall until the balance between pending requests sent to
				-- ecc_fp and the ones it has completed is reached again, that
				-- is when 'r.ctrl.pending_ops' is 0
				if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
					-- all pending ops have completed, we can stop waiting
					if r.decode.barnop = '1' then
						v.decode.state := idle;
						v.decode.rdy := '1';
						v.decode.barnop := '0';
					elsif r.decode.barbra = '1' then
						v.decode.state := branch;
						v.decode.barbra := '0';
					else
						-- the end of barrier stalling now allows to reach 'arith' state
						v.decode.state := arith;
						v.decode.valid := '1';
					end if;
				end if;
			-- -----------
			-- arith state
			-- -----------
			when arith => -- (s20)
				-- the 'arith' state means that we have presented an ARITHmetic
				-- instruction (including TESTPAR) to ecc_fp (together with asserting
				-- r.decode.valid, which directly drives the 'valid' input of ecc_fp,
				-- see (s3) below) and we are waiting for its acknowledgement
				if opo.rdy = '1' then
					v.decode.state := waitarith;
					v.ctrl.pending_ops :=
						r.ctrl.pending_ops + 1; -- (s5) - see also (s6) for decrement
					vopsincr := TRUE;
					-- note that thx to (s4) r.decode.valid will be deasserted
					-- immediately after (= 1 cycle later) acknowledgement by ecc_fp
				end if;
			-- ---------------
			-- waitarith state
			-- ---------------
			when waitarith =>
				-- either an ARITHmetic instruction or a TESTPAR instruction has been
				-- presented to ecc_fp which acknowledged our request.
				-- We wait until 'opo.rdy' is asserted by ecc_fp, meaning the
				-- ARITHmetic operation is completed and result flags are
				-- available (on 'opo.resultz', 'opo.resultsn', 'opo.resultpar'
				-- & 'opo.resulterr')
				-- so we latch the registers Rpar, Rkap & RkapP accordingly,
				-- along with Rz and Rsn, and return to 'idle' state while
				-- asserting 'r.decode.rdy' high
				if opo.rdy = '1' then
					v.decode.state := idle; -- (s36)
					v.decode.rdy := '1';
					-- always update r.ctrl.z
					v.ctrl.z := opo.resultz;
					-- always update r.ctrl.sn
					v.ctrl.sn := opo.resultsn;
					-- on the other hand, assignment of 'r.decode.c.par/kap/kapp' must
					-- be protected by a test on 'r.decode.a.tpar', as the 3 flags
					-- 'par', 'kap' & 'kapP' are shared with the 'opC' field in ARITH-
					-- metic instructions
					if r.decode.a.tpar = '1' then
						vpar := opo.resultpar;
						if r.decode.a.tparsh = '1' then
							vpar := vpar xor
							  opo.shr(to_integer(unsigned(r.decode.a.popb(1 downto 0))));
						end if;
						if    r.decode.c.par = '1'  then v.ctrl.par  := vpar;
						elsif r.decode.c.kap = '1'  then v.ctrl.kap  := vpar;
						elsif r.decode.c.kapp = '1' then v.ctrl.kapp := vpar;
						elsif r.decode.c.kb0 = '1'  then v.ctrl.kb0  := vpar;
						elsif r.decode.c.mu0 = '1'  then v.ctrl.mu0  := vpar;
						end if;
					end if;
					-- detect possible error
					-- (we don't switch to any error-like state as this is not a
					-- control/flow error, but an arithmetic error - we just record
					-- that an error occured, using 'r.err' and 'r.err_flags', so that
					-- later on we can notify the user/software that the final result
					-- is wrong)
					-- Note: for now errors are not driven to upper layers (ecc_scalar &
					-- ecc_axi) - so synthesis will trim away both r.err & r.err_flags
					if opo.resulterr = '1' then
						v.err := '1';
						v.err_flags(ERR_OVERFLOW) := '1';
						v.state := idle;
						v.fetch.state := idle;
						--v.decode.state := idle; -- not needed thx to (s36)
						v.frdy := '1';
					end if;
					-- implement tests based on patches
					if r.ctrl.test_x_equality = '1' then
						if opo.resultz = '1' then
							v.ctrl.x_are_equal := '1';
						elsif opo.resultz = '0' then
							v.ctrl.x_are_equal := '0';
						end if;
					end if;
					if r.ctrl.test_y_equality = '1' then
						if opo.resultz = '1' then
							v.ctrl.y_are_equal := '1';
						elsif opo.resultz = '0' then
							v.ctrl.y_are_equal := '0';
						end if;
					end if;
					if r.ctrl.test_y_opposite = '1' then
						if opo.resultz = '1' then
							v.ctrl.y_are_opposite := '1';
						elsif opo.resultz = '0' then
							v.ctrl.y_are_opposite := '0';
						end if;
					end if;
					if r.ctrl.detect2pz = '1' then
						v.ctrl.first2pz := opo.resultz;
					end if;
					if r.ctrl.detectxmxz = '1' then
						v.ctrl.xmxz := opo.resultz;
					end if;
					if r.ctrl.detectymyz = '1' then
						v.ctrl.ymyz := opo.resultz;
					end if;
					if r.ctrl.detecttorsion2 = '1' then
						v.ctrl.torsion2 := opo.resultz;
					end if;
					-- reset flags (after each arithmetic opcode executed)
					v.ctrl.test_x_equality := '0';
					v.ctrl.test_y_equality := '0';
					v.ctrl.test_y_opposite := '0';
					v.ctrl.detect2pz := '0';
					v.ctrl.detectxmxz := '0';
					v.ctrl.detectymyz := '0';
					v.ctrl.detecttorsion2 := '0';
				end if; -- opo.rdy = 1
			-- ------------
			-- branch state
			-- ------------
			when branch => -- (s21)
				if r.decode.b.b = '1' then
					vdobranch := TRUE;
				elsif r.decode.b.z = '1' and r.ctrl.z = '1' then
					vdobranch := TRUE;
				elsif r.decode.b.sn = '1' and r.ctrl.sn = '1' then
					vdobranch := TRUE;
				elsif r.decode.b.odd = '1' and r.ctrl.par = '1' then
					vdobranch := TRUE;
				elsif r.decode.b.call = '1' then
					vdobranch := TRUE;
					v.ctrl.ret := std_logic_vector(unsigned(r.decode.pc) + 1);
				elsif r.decode.b.callsn = '1' and r.ctrl.sn = '1' then
					vdobranch := TRUE;
					v.ctrl.ret := std_logic_vector(unsigned(r.decode.pc) + 1);
				elsif r.decode.b.ret = '1' then
					vdobranch := TRUE;
				end if;
				if vdobranch then
					v.fetch.ramresh :=
						(sramlat => '1', others => '0'); -- (s13) only 1 clk thx to (s0)
					v.fetch.state := fetch;
					-- if 'r.fetch.valid' was already currently asserted, then having
					-- 'r.decode.state' return to 'idle' state (see (s27) below) would
					-- make the decode stage acknowledge & accept the pending address
					-- currently driven by the fetch state, which is NOT the address
					-- we want to be decoded next since we are about to ask for a
					-- "refetch" to a new address due to the BRANCH instruction:
					-- that's why we force a deassert of 'r.fetch.valid' below
					v.fetch.valid := '0'; -- (s16) bypass of (s14)
					if r.decode.b.ret = '1' then
						v.fetch.pc := r.ctrl.ret; -- (s28)
					else
						v.fetch.pc := r.decode.b.imma; -- (s10)
					end if;
				else
					-- if vdobranch is FALSE, it means that the condition which the
					-- branch instruction depends upon is not satisfied: we then
					-- simply get back to 'idle' state, and asserts again 'r.decode.rdy'
				end if;
				v.decode.state := idle; -- (s27)
				v.decode.rdy := '1';
			-- ----------------
			-- breakpoint state (debug)
			-- ----------------
			when breakpoint =>
				if dbgresume = '1' then
					v.decode.state := decode;
					v.debug.halted := '0';
					v.debug.breakpointhit := '0';
				elsif dbgdosomeopcodes = '1' then
					v.decode.state := decode;
					v.debug.halted := '0';
					v.debug.severalopcodes := '1';
					if dbgnbopcodes = x"0000" then
						v.debug.nbopcodes := x"0000";
					else
						v.debug.nbopcodes := unsigned(dbgnbopcodes) - 1;
					end if;
					v.debug.breakpointhit := '0';
				end if;
			-- -------------------------------------
			-- state to wait for an FPREDC to finish before breakpoint halt (debug)
			-- -------------------------------------
			when waitb4bkpt =>
				-- we stall until the balance between pending requets sent to
				-- ecc_fp and the ones it has completed is reached again, that
				-- is when 'r.ctrl.pending_ops' is 0; only then do we enter
				-- 'breakpoint' state (and we clear possible pending halt-order
				-- coming from software)
				if r.ctrl.pending_ops = to_unsigned(0, PENDING_OPS_NBBITS) then
					v.decode.state := breakpoint;
					v.debug.halted := '1';
					v.debug.halt_pending := '0';
				end if;
			when others => -- stands for 'errorr' state
				v.stop := '1';
				v.err := '1';
		end case;

		-- decrement of 'r.ctrl.pending_ops' when 'opo.done' is asserted
		-- (note that this can happen at the same time that 'r.ctrl.pending_ops'
		-- is incremented by (s5) above, that's the reason for the combinational
		-- signal 'vopsincr')
		if opo.done = '1' then
			if not vopsincr then
				v.ctrl.pending_ops := r.ctrl.pending_ops - 1; -- (s6)
			else
				v.ctrl.pending_ops := r.ctrl.pending_ops; -- to compensate for (s5)
			end if;
		end if;

		-- handle STOP state
		if r.stop = '1' then -- (s29)
			v.state := idle;
			v.decode.state := idle;
			v.fetch.state := idle; -- (s39) redundant w/ (s38) (try remove it)
			v.frdy := '1'; -- (s31)
			-- we need to deassert r.stop by (s30) so that (s29) is not triggered
			-- again which would reassert r.frdy through (s31) and therefore
			-- erronously bypass (s32) when another program follows
			v.stop := '0'; -- (s30)
			v.debug.halted := '0';
		end if;

		-- ======================================================================
		-- shuffle feature (countermeasure against possible SCA leak of operands'
		-- address of the four variables XR0, XR1, YR0 and YR1)
		-- ======================================================================

		-- handshake with ecc_trng
		if trng_valid = '1' and r.shuffle.trng_rdy = '1' then
			v.shuffle.trng_data := trng_data;
			v.shuffle.trng_valid := '1';
			v.shuffle.trng_rdy := '0';
		end if;

		-- ------------------------
		-- creating the permutation (using randomness)
		-- ------------------------
		-- use random data from r.shuffle.trng_data, creating a sequence of three
		-- random transpositions of the set {0,1,2,3} according to the Fisher-
		-- Yates/Knuth algorithm. In the end we thus get a (uniformly distributed)
		-- random permutation of the set {0,1,2,3}.
		if r.shuffle.state(0) = '0' and r.shuffle.trng_valid = '1' then
			if r.shuffle.step = 3 then
				-- in this step all possible 2-bit values can be used (no TRNG data
				-- shall be lost)
				v.shuffle.sw3 := r.shuffle.trng_data;
				v.shuffle.trng_valid := '0';
				v.shuffle.trng_rdy := '1';
				v.shuffle.step := 2;
				if r.shuffle.state(1) = '1' then
					v.shuffle.start := '0';
				end if;
			elsif r.shuffle.step = 2 then
				-- in this step only 2-bit values 00, 01 and 10 are acceptable
				-- (TRNG data 11 is useless and must be discarded)
				if r.shuffle.trng_data = "00" or r.shuffle.trng_data = "01" or
			 		r.shuffle.trng_data = "10"
				then
					v.shuffle.sw2 := r.shuffle.trng_data;
					v.shuffle.step := 1;
				end if;
				v.shuffle.trng_valid := '0';
				v.shuffle.trng_rdy := '1';
			elsif r.shuffle.step = 1 then
				-- in this step only 2-bit values 00 and 01 are acceptable
				-- but we can avoid losing TRNG data by regrouping 00 and 10
				-- as one single element and doing the same for 01 and 11
				-- values
				v.shuffle.sw1 := '0' & r.shuffle.trng_data(0);
				-- prepare next random draw from TRNG
				v.shuffle.trng_valid := '0';
				v.shuffle.trng_rdy := '1'; -- (s42)
				-- switch to next state
				if r.shuffle.start = '1' then
					v.shuffle.state := "10";
				elsif r.shuffle.start = '0' then
					v.shuffle.state := "01"; -- (s43)
				end if;
				v.shuffle.step := 3; -- (s44)
			end if;
		end if;

		-- ------------------------
		-- applying the permutation (using r.shuffle.sw[123] computed previously)
		-- ------------------------
		-- all v_shuffle_xxx[_sw[321]] variables below designate combinational
		-- signals (whatever the if statement they go through their value is
		-- always defined) and are only here to store as intermediate results
		-- in the computation of r.shuffle.next_zero/one/two/three registers

		-- ---------------------------------------------------------------------
		--   1st stem of permutation (r.shuffle.zero)
		-- ---------------------------------------------------------------------
		--     select input
		--       (depending on either this is the first time of [k]P computation
		--       or not, permutation should be made on r.shuffle.zero if it's the
		--       first time or from r.shuffle.next_zero otherwise)
		if r.shuffle.start = '1' then
			v_shuffle_zero := r.shuffle.zero;
		else --if r.shuffle.start = '0' then
			v_shuffle_zero := r.shuffle.next_zero;
		end if;
		--     1st transposition
		if v_shuffle_zero = "11" then
			v_shuffle_zero_sw3 := r.shuffle.sw3;
		elsif v_shuffle_zero = r.shuffle.sw3 then
			v_shuffle_zero_sw3 := "11";
		else
			v_shuffle_zero_sw3 := v_shuffle_zero;
		end if;
		--     2nd transposition
		if v_shuffle_zero_sw3 = "10" then
			v_shuffle_zero_sw2 := r.shuffle.sw2;
		elsif v_shuffle_zero_sw3 = r.shuffle.sw2 then
			v_shuffle_zero_sw2 := "10";
		else
			v_shuffle_zero_sw2 := v_shuffle_zero_sw3;
		end if;
		--     3rd transposition (last)
		if v_shuffle_zero_sw2 = "01" then
			v_shuffle_zero_sw1 := r.shuffle.sw1;
		elsif v_shuffle_zero_sw2 = r.shuffle.sw1 then
			v_shuffle_zero_sw1 := "01";
		else
			v_shuffle_zero_sw1 := v_shuffle_zero_sw2;
		end if;
		--     select output
		--       (depending on this is the first time or not of [k]P computation
		--       permutation should be iterated into r.shuffle.next_zero (if it's
		--       the first time, or into r.shuffle.next_next_zero otherwise)
		--           TODO: set a multicycle on all paths:
		--                       r.shuffle.zero -> r.shuffle.next_zero
		--                       r.shuffle.sw[321] -> r.shuffle.next_zero
		--                       r.shuffle.next_zero -> r.shuffle.next_next_zero
		--                       r.shuffle.sw[321] -> r.shuffle.next_next_zero
		--           (but in this case arm a small counter & wait for it before
		--           having (s43) asserting r.shuffle.state)
		if r.shuffle.start = '1' then
			v.shuffle.next_zero := v_shuffle_zero_sw1;
		else --if r.shuffle.start = '0' then
			v.shuffle.next_next_zero := v_shuffle_zero_sw1;
		end if;

		-- pragma translate_off
		v.shuffle_zero := v_shuffle_zero;
		v.shuffle_zero_sw3 := v_shuffle_zero_sw3;
		v.shuffle_zero_sw2 := v_shuffle_zero_sw2;
		v.shuffle_zero_sw1 := v_shuffle_zero_sw1;
		-- pragma translate_on

		-- ---------------------------------------------------------------------
		--   2nd stem of permutation (r.shuffle.one)
		-- ---------------------------------------------------------------------
		--     select input
		--       (depending on this is the first time or not of [k]P computation
		--       permutation should be iterated on r.shuffle.one (if it's the
		--       first time, or from r.shuffle.next_one otherwise)
		-- ---------------------------------------------------------------------
		if r.shuffle.start = '1' then
			v_shuffle_one := r.shuffle.one;
		else --if r.shuffle.start = '0' then
			v_shuffle_one := r.shuffle.next_one;
		end if;
		--     1st transposition
		if v_shuffle_one = "11" then
			v_shuffle_one_sw3 := r.shuffle.sw3;
		elsif v_shuffle_one = r.shuffle.sw3 then
			v_shuffle_one_sw3 := "11";
		else
			v_shuffle_one_sw3 := v_shuffle_one;
		end if;
		--     2nd transposition
		if v_shuffle_one_sw3 = "10" then
			v_shuffle_one_sw2 := r.shuffle.sw2;
		elsif v_shuffle_one_sw3 = r.shuffle.sw2 then
			v_shuffle_one_sw2 := "10";
		else
			v_shuffle_one_sw2 := v_shuffle_one_sw3;
		end if;
		--     3rd transposition (last)
		if v_shuffle_one_sw2 = "01" then
			v_shuffle_one_sw1 := r.shuffle.sw1;
		elsif v_shuffle_one_sw2 = r.shuffle.sw1 then
			v_shuffle_one_sw1 := "01";
		else
			v_shuffle_one_sw1 := v_shuffle_one_sw2;
		end if;
		--     select output
		--       (depending on this is the first time or not of [k]P computation
		--       permutation should be iterated into r.shuffle.next_one (if it's
		--       the first time, or into r.shuffle.next_next_one otherwise)
		--           TODO: set a multicycle on all paths:
		--                       r.shuffle.one -> r.shuffle.next_one
		--                       r.shuffle.sw[321] -> r.shuffle.next_one
		--                       r.shuffle.next_one -> r.shuffle.next_next_one
		--                       r.shuffle.sw[321] -> r.shuffle.next_next_one
		--           (but in this case arm a small counter & wait for it before
		--           having (s43) asserting r.shuffle.state)
		if r.shuffle.start = '1' then
			v.shuffle.next_one := v_shuffle_one_sw1;
		else --if r.shuffle.start = '0' then
			v.shuffle.next_next_one := v_shuffle_one_sw1;
		end if;

		-- pragma translate_off
		v.shuffle_one := v_shuffle_one;
		v.shuffle_one_sw3 := v_shuffle_one_sw3;
		v.shuffle_one_sw2 := v_shuffle_one_sw2;
		v.shuffle_one_sw1 := v_shuffle_one_sw1;
		-- pragma translate_on

		-- ---------------------------------------------------------------------
		--   3rd stem of permutation (r.shuffle.two)
		-- ---------------------------------------------------------------------
		--     select input
		--       (depending on this is the first time or not of [k]P computation
		--       permutation should be iterated on r.shuffle.two (if it's the
		--       first time, or from r.shuffle.next_two otherwise)
		-- ---------------------------------------------------------------------
		if r.shuffle.start = '1' then
			v_shuffle_two := r.shuffle.two;
		else --if r.shuffle.start = '0' then
			v_shuffle_two := r.shuffle.next_two;
		end if;
		--     1st transposition
		if v_shuffle_two = "11" then
			v_shuffle_two_sw3 := r.shuffle.sw3;
		elsif v_shuffle_two = r.shuffle.sw3 then
			v_shuffle_two_sw3 := "11";
		else
			v_shuffle_two_sw3 := v_shuffle_two;
		end if;
		--     2nd transposition
		if v_shuffle_two_sw3 = "10" then
			v_shuffle_two_sw2 := r.shuffle.sw2;
		elsif v_shuffle_two_sw3 = r.shuffle.sw2 then
			v_shuffle_two_sw2 := "10";
		else
			v_shuffle_two_sw2 := v_shuffle_two_sw3;
		end if;
		--     3rd transposition (last)
		if v_shuffle_two_sw2 = "01" then
			v_shuffle_two_sw1 := r.shuffle.sw1;
		elsif v_shuffle_two_sw2 = r.shuffle.sw1 then
			v_shuffle_two_sw1 := "01";
		else
			v_shuffle_two_sw1 := v_shuffle_two_sw2;
		end if;
		--     select ouput
		--       (depending on this is the first time or not of [k]P computation
		--       permutation should be iterated into r.shuffle.next_two (if it's
		--       the first time, or into r.shuffle.next_next_two otherwise)
		--           TODO: set a multicycle on all paths:
		--                       r.shuffle.two -> r.shuffle.next_two
		--                       r.shuffle.sw[321] -> r.shuffle.next_two
		--                       r.shuffle.next_two -> r.shuffle.next_next_two
		--                       r.shuffle.sw[321] -> r.shuffle.next_next_two
		--           (but in this case arm a small counter & wait for it before
		--           having (s43) asserting r.shuffle.state)
		if r.shuffle.start = '1' then
			v.shuffle.next_two := v_shuffle_two_sw1;
		else --if r.shuffle.start = '0' then
			v.shuffle.next_next_two := v_shuffle_two_sw1;
		end if;

		-- pragma translate_off
		v.shuffle_two := v_shuffle_two;
		v.shuffle_two_sw3 := v_shuffle_two_sw3;
		v.shuffle_two_sw2 := v_shuffle_two_sw2;
		v.shuffle_two_sw1 := v_shuffle_two_sw1;
		-- pragma translate_on

		-- ---------------------------------------------------------------------
		--   4th stem of permutation (r.shuffle.three)
		--     (depending on this is the first time or not of [k]P computation
		--     permutation should be iterated on r.shuffle.three (if it's the
		--     first time, or from r.shuffle.next_three otherwise)
		-- ---------------------------------------------------------------------
		if r.shuffle.start = '1' then
			v_shuffle_three := r.shuffle.three;
		else --if r.shuffle.start = '0' then
			v_shuffle_three := r.shuffle.next_three;
		end if;
		--     1st transposition
		if v_shuffle_three = "11" then
			v_shuffle_three_sw3 := r.shuffle.sw3;
		elsif v_shuffle_three = r.shuffle.sw3 then
			v_shuffle_three_sw3 := "11";
		else
			v_shuffle_three_sw3 := v_shuffle_three;
		end if;
		--     2nd transposition
		if v_shuffle_three_sw3 = "10" then
			v_shuffle_three_sw2 := r.shuffle.sw2;
		elsif v_shuffle_three_sw3 = r.shuffle.sw2 then
			v_shuffle_three_sw2 := "10";
		else
			v_shuffle_three_sw2 := v_shuffle_three_sw3;
		end if;
		--     3rd transposition (last)
		if v_shuffle_three_sw2 = "01" then
			v_shuffle_three_sw1 := r.shuffle.sw1;
		elsif v_shuffle_three_sw2 = r.shuffle.sw1 then
			v_shuffle_three_sw1 := "01";
		else
			v_shuffle_three_sw1 := v_shuffle_three_sw2;
		end if;
		--     (depending on this is the first time or not of [k]P computation
		--     permutation should be iterated into r.shuffle.next_three (if it's
		--     the first time, or into r.shuffle.next_next_three otherwise)
		--         TODO: set a multicycle on all paths:
		--                     r.shuffle.three -> r.shuffle.next_three
		--                     r.shuffle.sw[321] -> r.shuffle.next_three
		--                     r.shuffle.next_three -> r.shuffle.next_next_three
		--                     r.shuffle.sw[321] -> r.shuffle.next_next_three
		--         (but in this case arm a small counter & wait for it before
		--         having (s43) asserting r.shuffle.state)
		if r.shuffle.start = '1' then
			v.shuffle.next_three := v_shuffle_three_sw1;
		else -- if r.shuffle.start = '0' then
			v.shuffle.next_next_three := v_shuffle_three_sw1;
		end if;
		
		-- pragma translate_off
		v.shuffle_three := v_shuffle_three;
		v.shuffle_three_sw3 := v_shuffle_three_sw3;
		v.shuffle_three_sw2 := v_shuffle_three_sw2;
		v.shuffle_three_sw1 := v_shuffle_three_sw1;
		-- pragma translate_on

		-- handshake w/ ecc_scalar
		if r.shuffle.state(0) = '1' and iterate_shuffle_valid = '1' then
			v.shuffle.zero := r.shuffle.next_zero;
			v.shuffle.one := r.shuffle.next_one;
			v.shuffle.two := r.shuffle.next_two;
			v.shuffle.three := r.shuffle.next_three;
			v.shuffle.next_zero := r.shuffle.next_next_zero;
			v.shuffle.next_one := r.shuffle.next_next_one;
			v.shuffle.next_two := r.shuffle.next_next_two;
			v.shuffle.next_three := r.shuffle.next_next_three;
			v.shuffle.state := "00";
			-- v.shuffle.step := 3; -- useless, already done by (s44)
			-- no need to reassert r.shuffle.trng_rdy, this was already done by (s42)
		elsif iterate_shuffle_force = '1' then
			v.shuffle.zero := r.shuffle.next_zero;
			v.shuffle.one := r.shuffle.next_one;
			v.shuffle.two := r.shuffle.next_two;
			v.shuffle.three := r.shuffle.next_three;
		end if;

		-- synchronous (active-low) reset
		if rstn = '0' or swrst = '1' then
			v.active := '0';
			v.state := idle;
			v.fetch.state := idle;
			-- no need to reset r.fetch.pc
			-- no need to reset r.fetch.ramresh
			-- no need to reset r.fetch.opcode
			v.fetch.valid := '0';
			v.decode.state := idle;
			-- no need to reset r.decode.pc
			-- no need to reset none of r.decode.c.xxx
			-- no need to reset none of r.decode.a.xxx
			-- no need to reset none of r.decode.b.xxx
			v.decode.barnop  := '0';
			v.decode.barbra  := '0';
			v.decode.rdy := '1';
			v.decode.valid := '0';
			-- no need to reset r.ctrl.kap/kapp
			-- no need to reset r.ctrl.z/sn/par
			-- no need to reset r.ctrl.ret
			-- no need to reset r.ctrl.phimsb nor r.ctrl.kb0end
			v.ctrl.pending_ops := (others => '0');
			v.frdy := '1';
			v.stop := '0'; -- (s33) see (s30) & (s34)
			v.err := '0';
			v.err_flags := (others => '0');
			-- shuffle
			v.shuffle.trng_rdy := '0';
			-- no need to reset r.shuffle.zero/.one/.two/.three
			-- no need to reset r.shuffle.step/.state/.start
			v.shuffle.trng_valid := '0';
			-- no need to reset the r.shuffle.next_ registers
			-- no need to reset the r.shuffle.sw[321] registers
			-- debug features
			v.debug.severalopcodes := '0';
			v.debug.halted := '0';
			-- no need to reset r.ctrl.[xy]_are_equal nor r.ctrl.y_are_opposite
			-- no need tot reset r.debug.breakpointid
			v.debug.breakpointhit := '0';
			v.debug.halt_pending := '0';
			-- pragma translate_off
			v.ctrl.first2pz := '0'; -- (s102), see (s103)
			v.ctrl.torsion2 := '0'; -- (s104), see (s105)
			-- pragma translate_on
		end if;

		rin <= v;
	end process comb;

	-- pragma translate_off
	r_op_moins <= '1' when opo.done = '1'
	             else '0';
	r_op_plus <= '1' when r.decode.state = arith and opo.rdy = '1'
	             else '0';
	-- pragma translate_on

	-- registers
	regs : process(clk)
	begin
		if (clk'event and clk = '1') then
			r <= rin;
		end if;
	end process regs;

	-- pragma translate_off
	log: process(clk)
	begin
		if clk'event and clk = '1' then
			rbak_first2pz <= r.ctrl.first2pz; -- (s103)
			-- log message when detecting the input point (the one given
			-- by software) is a 2-torsion point
			if rbak_first2pz = '0' and r.ctrl.first2pz = '1' then
				echol("ECC_CURVE: detected initial 2-torsion point ([2]P = 0)");
			end if;
			-- log message when detecting we're doubling a point (in .zdblL)
			-- and it happens to be a 2-torsion point
			rbak_torsion2 <= r.ctrl.torsion2;
			if rbak_torsion2 = '0' and r.ctrl.torsion2 = '1' then -- (s105)
				echol("ECC_CURVE: detected doubling of a 2-torsion point (result = 0)");
			end if;
		end if;
	end process log;
	-- pragma translate_on

	-- drive outputs
	--   to ecc_scalar
	frdy <= r.frdy;
	ferr <= r.err;
	zero <= r.ctrl.z;
	iterate_shuffle_rdy <= r.shuffle.state(0);
	x_are_equal <= r.ctrl.x_are_equal;
	y_are_equal <= r.ctrl.y_are_equal;
	y_are_opposite <= r.ctrl.y_are_opposite;
	first_2p_is_null <= r.ctrl.first2pz;
	xmxz <= r.ctrl.xmxz;
	ymyz <= r.ctrl.ymyz;
	torsion2 <= r.ctrl.torsion2;
	kap <= r.ctrl.kap;
	kapp <= r.ctrl.kapp;
	phimsb <= r.ctrl.phimsb; -- (s109), see (s108)
	kb0end <= r.ctrl.kb0end; -- (s107), see (s106)
	--   to ecc_curve_iram
	ire <= r.fetch.ramresh(sramlat);
	iraddr <= r.fetch.pc;
	--   to ecc_fp
	opi.a <= r.decode.a.popa;
	opi.b <= r.decode.a.popb;
	opi.c <= r.decode.a.popc;
	opi.add <= r.decode.a.add;
	opi.sub <= r.decode.a.sub;
	opi.ssrl <= r.decode.a.ssrl;
	opi.ssll <= r.decode.a.ssll;
	opi.rnd <= r.decode.a.rnd;
	opi.xxor <= r.decode.a.xxor;
	opi.redc <= r.decode.a.redc;
	opi.extended <= r.decode.c.extended; -- (s1)
	opi.par <= r.decode.a.tpar;
	opi.div2 <= r.decode.a.div2;
	opi.m <= r.decode.a.rndm;
	opi.sh <= r.decode.a.rndsh;
	opi.shf <= r.decode.a.rndshf;
	opi.ssrl_sh <= r.decode.a.ssrl_sh;
	opi.valid <= r.decode.valid; -- (s3)
	--   to mm_ndsp(s)
	ppen <= r.decode.a.redcm;
	--   to ecc_trng
	trng_rdy <= r.shuffle.trng_rdy;
	--   to ecc_axi (debug features)
	dbghalted <= r.debug.halted;
	dbgdecodepc <= r.decode.pc;
	dbgbreakpointid <= r.debug.breakpointid;
	dbgbreakpointhit <= r.debug.breakpointhit;
	dbgremainingopcodes <= std_logic_vector(r.debug.nbopcodes);
	dbgpdops <= r.ctrl.pending_ops;

	-- pragma translate_off
	pc <= r.decode.pc;
	b <= '1' when r.decode.state = branch and r.decode.b.b = '1' else '0';
	bz <= '1' when r.decode.state = branch and r.decode.b.z = '1' else '0';
	bsn <= '1' when r.decode.state = branch and r.decode.b.sn = '1' else '0';
	bodd <= '1' when r.decode.state = branch and r.decode.b.odd = '1' else '0';
	call <= '1' when r.decode.state = branch and r.decode.b.call = '1' else '0';
	callsn <= '1' when r.decode.state = branch and r.decode.b.callsn = '1' else
						'0';
	ret <= '1' when r.decode.state = branch and r.decode.b.ret = '1' else '0';
	retpc <= r.ctrl.ret;
	nop <= '1' when r.decode.state = decode and r.decode.c.optype = OPCODE_NOP
				 else '0';
	imma <= r.decode.b.imma;
	xr0addr <= r.shuffle.next_zero;
	yr0addr <= r.shuffle.next_one;
	xr1addr <= r.shuffle.next_two;
	yr1addr <= r.shuffle.next_three;
	opi.parsh <= r.decode.a.tparsh;
	opi.oposhr <= opo.shr(to_integer(unsigned(r.decode.a.popb(1 downto 0))));
	stop <= r.decode.c.stop;
	patching <= r.decode.c.patch;
	patchid <= to_integer(unsigned(
						 r.fetch.opcode(OP_PATCH_MSB downto OP_PATCH_LSB)));
	-- pragma translate_on

end architecture rtl;
