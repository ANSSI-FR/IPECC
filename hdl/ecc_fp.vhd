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
use work.ecc_vars.all; -- for LARGE_NB_x constants (& only for simu, see s(142))

-- pragma translate_off
use std.textio.all;
use work.ecc_addr.all;
-- pragma translate_on

entity ecc_fp is
	port(
		clk : in std_logic;
		rstn : in std_logic; -- synchronous reset
		-- software reset
		swrst : in std_logic;
		-- interface with ecc_curve
		opi : in opi_type;
		opo : out opo_type;
		-- interface with Montgomery multipliers
		mmi : out mmi_type;
		mmo : in mmo_type;
		-- interface with ecc_fp_dram
		fpre : out std_logic;
		fpraddr : out std_logic_vector(FP_ADDR - 1 downto 0);
		fprdata : in std_logic_vector(ww - 1 downto 0);
		fpwe : out std_logic;
		fpwaddr : out std_logic_vector(FP_ADDR - 1 downto 0);
		fpwdata : out std_logic_vector(ww - 1 downto 0);
		-- interface with AXI-lite
		--   (to actually have the AXI-lite interface access ecc_fp_dram)
		xwe : in std_logic;
		xaddr : in std_logic_vector(FP_ADDR - 1 downto 0);
		xwdata : in std_logic_vector(ww - 1 downto 0);
		xre : in std_logic;
		xrdata : out std_logic_vector(ww - 1 downto 0);
		nndyn_nnrnd_mask : in std_logic_vector(ww - 1 downto 0);
		nndyn_nnrnd_zerowm1 : in std_logic;
		nndyn_wm1 : in unsigned(log2(w - 1) - 1 downto 0);
		nndyn_wm2 : in unsigned(log2(w - 1) - 1 downto 0);
		nndyn_2wm1 : in unsigned(log2((2*w) - 1) - 1 downto 0);
		-- pragma translate_off
		nndyn_w : in unsigned(log2(w) - 1 downto 0);
		-- pragma translate_on
		-- interface with ecc_trng
		trngvalid : in std_logic;
		trngrdy : out std_logic;
		trngdata : in std_logic_vector(ww - 1 downto 0);
		-- interface with ecc_scalar
		initkp : in std_logic;
		compkp : in std_logic;
		compcstmty : in std_logic;
		comppop : in std_logic;
		compaop : in std_logic;
		-- debug features (interface with ecc_axi)
		dbgtrnguse : in std_logic;
		-- debug feature (ecc_scalar)
		dbghalted : in std_logic
		-- pragma translate_off
		-- interface with ecc_scalar (simu only)
		; logr0r1 : in std_logic;
		logr0r1step : in natural;
		logfinalresult : in std_logic;
		simbit : in natural;
		-- interface with ecc_curve (simu only)
		pc : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0); -- independent of nn
		b : in std_logic;
		bz : in std_logic;
		bsn : in std_logic;
		bodd : in std_logic;
		call : in std_logic;
		callsn : in std_logic;
		ret : in std_logic;
		retpc : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0); -- independent of nn
		nop : in std_logic;
		imma : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0); -- independent of nn
		kap : in std_logic;
		kapp : in std_logic;
		xr0addr : in std_logic_vector(1 downto 0);
		yr0addr : in std_logic_vector(1 downto 0);
		xr1addr : in std_logic_vector(1 downto 0);
		yr1addr : in std_logic_vector(1 downto 0);
		r0z : in std_logic;
		r1z : in std_logic;
		stop : in std_logic;
		patching : in std_logic;
		patchid : in integer;
		-- interface with ecc_fp_dram or ecc_fp_dram_sh (simu only)
		fpdram : in fp_dram_type;
		fprwmask : in std_logic_vector(FP_ADDR - 1 downto 0)
		-- pragma translate_on
	);
end entity ecc_fp;

architecture rtl of ecc_fp is

	constant sramlatp2 : positive range 3 to 4 := sramlat + 2;

	type mm_opc_type is array(natural range 0 to nbmult - 1) of std_logic_operand;

	type push_async_state_type is (waitread, waitenack, waitgoack, waitackack);

	type mm_push_type is record
		do : std_logic;
		busy : std_logic;
		oneavail : std_logic;
		id0 : integer range 0 to nbmult - 1;
		id1 : integer range 0 to nbmult - 1;
		shstart : std_logic_vector(2*sramlatp2 downto 0);
		shmid : std_logic_vector(sramlatp2 + 1 downto 0);
		rd : std_logic;
		rdcnt : unsigned(log2(w - 1) - 1 downto 0);
		opacnt : unsigned(log2(2*n - 1) - 1 downto 0);
		opbcnt : unsigned(log2(2*n - 1) - 1 downto 0);
		opaorb : std_logic;
		-- for 'gosh' only 4 bits kept by synthesizer if shuffle is FALSE
		gosh : std_logic_vector(sramlatp2 + 1 downto 0);
		opic : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		opc : mm_opc_type;
		-- for 'xypushsh' if shuffle is FALSE synthesizer will prune upper bits
		xypushsh : std_logic_vector(sramlatp2 - 1 downto 0);
		async_state : push_async_state_type;
		-- resync registers
		rdy0, rdy1, rdy : std_logic;
		go_ack0, go_ack1, go_ack : std_logic;
		xen_ack0, xen_ack1, xen_ack : std_logic;
		yen_ack0, yen_ack1, yen_ack : std_logic;
	end record;

	type pull_async_state_type is (idle, waitack, writeram, waitackack);

	type mm_pull_type is record
		done : std_logic_vector(0 to nbmult - 1);
		oneavail : std_logic;
		pulling : std_logic;
		done_id0 : integer range 0 to nbmult - 1; -- 1 bit for each mm_ndsp comp.
		done_id1 : integer range 0 to nbmult - 1; -- 1 bit for each mm_ndsp comp.
		opc : std_logic_vector(FP_ADDR - 1 downto 0);
		shstart : std_logic_vector(sramlat + 1 downto 0);
		shend : std_logic_vector(sramlat + 1 downto 0);
		zrencnt : unsigned(log2(w - 1) - 1 downto 0);
		zcntonce : std_logic;
		-- resync registers
		irq0, irq1, irq : std_logic;
		zren_ack0, zren_ack1, zren_ack : std_logic;
		z0, z1, z : std_logic;
		async_state : pull_async_state_type;
	end record;

	type mm_type is record
		busy : std_logic_vector(0 to nbmult - 1); -- 1 bit for each mm_ndsp comp.
		push : mm_push_type;
		pull : mm_pull_type;
		mmi : mmi_type;
		-- resynchronization registers of mmo bus input signals
		mmo0, mmo1, mmo2, mmo3 : mmo_type;
		irq_prev : std_logic_vector(nbmult - 1 downto 0);
		nb_pending_redc : unsigned(log2(nbmult) - 1 downto 0);
		pending_redc : std_logic;
	end record;

	type addsub_type is record
		do : std_logic;
		busy : std_logic;
		rd : std_logic;
		rdcnt : unsigned(log2(2*w - 1) - 1 downto 0);
		-- for shstart & shend 2 bits pruned by synthesizer if shuffle is FALSE
		shstart : std_logic_vector(sramlatp2 + 3 downto 0);
		shend : std_logic_vector(sramlatp2 + 2 downto 0);
		wr : std_logic;
		wrcnt : unsigned(log2(w - 1) - 1 downto 0);
		act : std_logic;
		op0 : std_logic_vector(ww - 1 downto 0);
		op1 : std_logic_vector(ww - 1 downto 0);
		res : std_logic_vector(ww - 1 downto 0);
		carry : std_logic;
		borrow : std_logic;
		weact : std_logic;
		opamsb : std_logic;
		opbmsb : std_logic;
		zero : std_logic;
	end record;

	type xor_type is record
		do : std_logic;
		busy : std_logic;
		rd : std_logic;
		rdcnt : unsigned(log2(2*w - 1) - 1 downto 0);
		-- for shstart & shend 2 bits pruned by synthesizer if shuffle is FALSE
		shstart : std_logic_vector(sramlatp2 + 1 downto 0);
		shend : std_logic_vector(sramlatp2 + 2 downto 0);
		wr : std_logic;
		wrcnt : unsigned(log2(w - 1) - 1 downto 0);
		op0 : std_logic_vector(ww - 1 downto 0);
		op1 : std_logic_vector(ww - 1 downto 0);
		res : std_logic_vector(ww - 1 downto 0);
		weact : std_logic;
	end record;

	type shift_type is record
		do : std_logic;
		busy : std_logic;
		rd : std_logic;
		rdcnt : unsigned(log2(w - 1) - 1 downto 0);
		-- for shstart & shend 2 bits pruned by synthesizer if shuffle is FALSE
		shstart : std_logic_vector(sramlatp2 + 2 downto 0);
		shend : std_logic_vector(sramlatp2 + 3 downto 0);
		wr : std_logic;
		wrcnt : unsigned(log2(w - 1) - 1 downto 0);
		act : std_logic;
		op0 : std_logic_vector(ww - 1 downto 0);
		res : std_logic_vector(ww - 1 downto 0);
		opcincdec : std_logic;
		rcarry, lcarry : std_logic;
		zero : std_logic;
		-- support of NNSRLs & NNSRLf instructions
		rsh : std_logic;
		rshid : std_logic_vector(1 downto 0);
	end record;

	type par_type is record
		do : std_logic;
		busy : std_logic;
		par : std_logic;
		kap : std_logic;
		kapp : std_logic;
		-- for 'sh' only 4 bits kept by synthesizer if shuffle is FALSE
		sh : std_logic_vector(sramlatp2 + 1 downto 0);
	end record;

	-- for rnd operation (NNRND-like instructions)
	constant SZ_SH_REG : positive := 2 * w * ww;
	subtype std_logic_shrnd is std_logic_vector(SZ_SH_REG - 1 downto 0);
	type shrnd_type is array(0 to NB_MSK_SH_REG - 1) of std_logic_shrnd;

	subtype u_shcnt_type is unsigned(log2(SZ_SH_REG - 1) - 1 downto 0);
	type doshxcnt_type is array(0 to NB_MSK_SH_REG - 1) of u_shcnt_type;

	type rnd_type is record
		do : std_logic;
		busy : std_logic;
		trngrdy : std_logic;
		opccnt : unsigned(log2(w - 1) - 1 downto 0);
		data : std_logic_vector(ww - 1 downto 0);
		write : std_logic;
		zero : std_logic;
		last : std_logic;
		masked : std_logic;
		shift : std_logic;
		shiftf : std_logic;
		shregid : unsigned(1 downto 0);
		dosh : std_logic;
		doshcnt : unsigned(log2(ww - 1) - 1 downto 0);
		doshx : std_logic_vector(NB_MSK_SH_REG - 1 downto 0);
		doshxcnt : doshxcnt_type;
		burstdone : std_logic;
		finalizesh : std_logic;
	end record;

	component large_shr is
		generic(size : positive := 2*w*ww);
		port(
			clk : in std_logic;
			ce : in std_logic;
			d : in std_logic;
			q : out std_logic
		);
	end component large_shr;

	type fpram_type is record
		re : std_logic;
		raddr : std_logic_vector(FP_ADDR - 1 downto 0);
		raddrmuxsel : std_logic_vector(1 downto 0);
		we : std_logic;
		waddr : std_logic_vector(FP_ADDR - 1 downto 0);
		wdata : std_logic_vector(ww - 1 downto 0);
		waddrmuxsel : std_logic_vector(2 downto 0);
		-- for 'wecnt' only 3 bits used (but 4 kept by synthesizer) if shuffle
		-- is FALSE (not a big deal)
		wecnt : unsigned(log2(sramlatp2 + 4) - 1 downto 0); -- independent of nn
		wecnten : std_logic;
	end record;

	type ctrl_type is record
		redc : std_logic;
		add : std_logic;
		sub : std_logic;
		ssrl : std_logic; -- srl is a VHDL reserved word, using ssrl instead
		srl32 : std_logic;
		ssll : std_logic; -- sll is a VHDL reserved word, using ssll instead
		sll32 : std_logic;
		rnd : std_logic;
		xxor : std_logic; -- xor is a VHDL reserved word, using xxor instead
		par : std_logic;
		div2 : std_logic;
		extended : std_logic;
		resultz : std_logic;
		resultsn : std_logic;
		resulterr : std_logic;
	end record;

	-- all registers
	type reg_type is record
		-- pragma translate_off	
		active : std_logic;
		-- pragma translate_on
		rdy : std_logic;
		trypull : std_logic;
		done : std_logic;
		ctrl : ctrl_type;
		-- the 5 in the definition of fields op[abc] below accounts for the
		-- size of ecc_fp_dram memory, namely 32 big-numbers
		opa : std_logic_vector(FP_ADDR - 1 downto 0);
		opb : std_logic_vector(FP_ADDR - 1 downto 0);
		opc : std_logic_vector(FP_ADDR - 1 downto 0);
		--opacnt : unsigned(log2(2*n - 1) - 1 downto 0);
		--opbcnt : unsigned(log2(2*n - 1) - 1 downto 0);
		-- multiplication
		mm : mm_type;
		-- addition & subtraction
		addsub : addsub_type;
		-- bitwise xor
		xxor : xor_type;
		-- bit-shift (left & right)
		shift : shift_type;
		-- parity test
		par : par_type;
		-- randomization
		rnd : rnd_type;
		-- ecc_fp_dram access
		fpram : fpram_type;
		compkpdel : std_logic;
		compcstmtydel : std_logic;
		comppopdel : std_logic;
		compaopdel : std_logic;
	end record;

	signal vcc, gnd : std_logic;

	signal r, rin : reg_type;

	-- pragma translate_off
	type blog_reg_type is record
		b : std_logic;
		bz : std_logic;
		bsn : std_logic;
		bodd : std_logic;
		call : std_logic;
		callsn : std_logic;
		ret : std_logic;
		retpc : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		nop : std_logic;
		active : std_logic;
		mmpushdo : std_logic;
	end record;
	signal rblog, rblogbak : blog_reg_type;

	procedure write_addr2(lineo: inout line; address: in std_logic_vector) is
	begin
		if (to_integer(unsigned(address))) < 10 then
			write(lineo, string'("0"));
		end if;
		write(lineo, to_integer(unsigned(address)));
	end procedure write_addr2;

	function div4(i : natural) return positive is
	begin
		if (i mod 4) = 0 then
			return (i / 4);
		else
			return (i / 4) + 1;
		end if;
	end function div4;

	procedure is_new_routine(lineo: inout line;
		pca: in std_logic_vector; newprg: inout boolean) is
		variable v_pca : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	begin
		newprg := FALSE;
		v_pca := pca(IRAM_ADDR_SZ - 1 downto 0);
		-- write() function from STD.textio package is overloaded, which is
		-- the reason for the string' attribute appearing several times below
		-- (without it simulators won't know how to differentiate between
		-- string or bit_vector for the 2nd parameter and will issue an error)
		case v_pca is
			when ECC_IRAM_CONSTMTY_ADDR =>
				write(lineo, string'(".constMTYL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_AMONTY_ADDR =>
				write(lineo, string'(".aMontyL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_CHKCURVE_ADDR =>
				write(lineo, string'(".chkcurveL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_BLINDSTART_ADDR =>
				write(lineo, string'(".blindstartL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_BLNBIT_ADDR =>
				write(lineo, string'(".blnbitL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_BLINDSTOP_ADDR =>
				write(lineo, string'(".blindstopL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_ADPA_ADDR =>
				write(lineo, string'(".adpaL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_SETUP_ADDR =>
				write(lineo, string'(".setupL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_DBL_ADDR =>
				write(lineo, string'(".dblL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_SWITCH3P_ADDR =>
				write(lineo, string'(".switch3pL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_JOYECOZ_ADDR =>
				write(lineo, string'(".joyecozL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_PRE_ZADDU_ADDR =>
				write(lineo, string'(".pre_zadduL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_ZADDU_ADDR =>
				write(lineo, string'(".zadduL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_PRE_ZADDC_ADDR =>
				write(lineo, string'(".pre_zaddcL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_ZADDC_ADDR =>
				write(lineo, string'(".zaddcL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_SUBTRACTP_ADDR =>
				write(lineo, string'(".subtractpL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_EXIT_ADDR =>
				write(lineo, string'(".exitL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_ZDBL_ADDR =>
				write(lineo, string'(".zdblL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when ECC_IRAM_ZNEGC_ADDR =>
				write(lineo, string'(".znegcL [0x"));
				hex_write(lineo, pca);
				write(lineo, string'("]"));
				newprg := TRUE;
			when others =>
				newprg := FALSE;
		end case;
	end procedure is_new_routine;

	procedure log_coords(strcoord : string;
		coord : std_logic_vector; addr : in natural; lineo : inout line) is
	begin
		write(lineo, string'("     @ "));
		write(lineo, addr);
		write(lineo, string'(" "));
		write(lineo, string'(strcoord));
		write(lineo, string'(" = 0x"));
		hex_write(lineo, coord((to_integer(nndyn_w) * ww) - 1 downto 0));
		write(lineo, string'(" =  "));
		for i in to_integer(nndyn_wm1) downto 0 loop
			hex_write(lineo, coord(ww - 1 + (i*ww) downto 0+(i*ww)));
			write(lineo, string'(" "));
		end loop;
	end procedure log_coords;

	-- vtophys() is declared impure so that it can access signal fprwmask
	impure function vtophys(vaddr : integer) return integer is
		variable tmp : std_logic_vector(FP_ADDR - 1 downto 0);
	begin
		assert vaddr <= (2**(FP_ADDR)) - 1
			report "call to function vtophys() w/ an out-of-RAM index"
				severity WARNING; -- only concerns simulation log
		tmp := std_logic_vector(to_unsigned(vaddr, FP_ADDR));
		return to_integer(unsigned(tmp xor fprwmask));
	end function vtophys;
	-- pragma translate_on

	signal redc_2nd_input_s : boolean := FALSE;

begin

	-- large shift-register (support for NNRNDs & NNRNDf instructions)
	s0: for i in 0 to NB_MSK_SH_REG - 1 generate
		s0i : large_shr
			generic map(size => 2*w*ww)
			port map(
				clk => clk,
				ce => r.rnd.doshx(i),
				d => r.rnd.data(0),
				q => opo.shr(i)
		);
	end generate;

	-- combinational process
	comb : process(r, rstn,
	               opi, mmo, fprdata, xwe, xaddr, xwdata, xre, initkp,
	               compkp, compcstmty, comppop, compaop, trngdata, trngvalid,
	               dbgtrnguse, dbghalted,
	               nndyn_nnrnd_mask, nndyn_nnrnd_zerowm1, nndyn_wm1, nndyn_wm2,
								 nndyn_2wm1, swrst)
		variable v : reg_type;
		variable v_op0 : unsigned(ww downto 0);
		variable v_op1 : unsigned(ww downto 0);
		variable v_subres : unsigned(ww downto 0);
		variable v_borrow : unsigned(ww downto 0);
		variable v_addres : unsigned(ww downto 0);
		variable v_carry  : unsigned(ww downto 0);
	begin
		v := r;

		v.done := '0'; -- (s7), see (s31), (s137), (s138), (s139), (s140), (s8)

		-- resynchronization of mmo bus input signals
		v.mm.mmo0 := mmo;
		v.mm.mmo1 := r.mm.mmo0;
		v.mm.mmo2 := r.mm.mmo1;
		v.mm.mmo3 := r.mm.mmo2;


		-- -----------------------------------------------------------
		--    Continously (at each cycle) gather information about
		--    multipliers:
		--
		--      - which ones are available for a new computation
		--        (= we drive r.mm.push.id0
		--                  & r.mm.push.oneavail)
		-- -----------------------------------------------------------
		-- (s0)
		v.mm.push.oneavail := '0';
		for i in 0 to nbmult - 1 loop
			if (not async and mmo(i).rdy = '1' and r.mm.busy(i) = '0')
				or (async and r.mm.mmo2(i).rdy = '1' and r.mm.busy(i) = '0')
			then
				v.mm.push.oneavail := '1';
				v.mm.push.id0 := i;
				exit; -- TODO: check the effect on synthesis of that
			end if;
		end loop;

		-- -----------------------------------------------------------
		--    Continously (at each cycle) gather information about
		--    multipliers:
		--
		--      - which ones have completed their computation and
		--        have their result pending & available for read-back
		--        (= we drive r.mm.pull.done
		--                    r.mm.pull.oneavail
		--                  & r.mm.pull.done_id0)
		-- -----------------------------------------------------------
		-- clean detection of irq raising calls for comparison of the
		-- current value of irq signal value with the one at previous cycle
		if not async then -- statically resolved by syntheiszer
			for i in 0 to nbmult - 1 loop
				v.mm.irq_prev(i) := mmo(i).irq;
			end loop;
		else -- async case
			for i in 0 to nbmult - 1 loop
				v.mm.irq_prev(i) := r.mm.mmo2(i).irq;
			end loop;
		end if;
		for i in 0 to nbmult - 1 loop
			-- mind that in the async = FALSE case the irq is asserted only 1 cycle
			-- by Montgomery multipliers
			if ((not async) and mmo(i).irq = '1' and r.mm.irq_prev(i) = '0') -- (s130)
			  or (async and r.mm.mmo2(i).irq = '1' and r.mm.irq_prev(i) = '0')
				-- testing the previous value .irq_prev in (s130) is particularly
				-- important in the asynchronous case, when the clock of Montgomery
				-- multipliers is not fast enough to ensure that their IRQ is already
				-- lowered down by the time (s13) deasserts .done (if it is not,
				-- then (s12) will assert .done again, which in turn will trigger
				-- assertion of .oneavail by (s92) and that is an error)
			then
				-- for (s12) right down below, .done(i) will be reset low when
				-- pulling result back from the Montgomery multiplier is over
				v.mm.pull.done(i) := '1'; -- (s12), bypassed by (s13)
				-- note that the (s13) bypass of (s12) cannot accidently mask an
				-- assertion of .done(i) made by (s12), because for an obvious
				-- functionnal reason, assertion on .done(i) can only happen after
				-- result is pulled back from the corresponding Montgomery multiplier.
				-- If a .done(i) is reset in current cycle by (s13), the early
				-- assertion made by (s12) can only concern another value j different
				-- from i
				v.mm.mmi(i).irq_ack := '1';
			end if;
			if async and r.mm.mmi(i).irq_ack = '1' and r.mm.mmo2(i).irq = '0' then
				v.mm.mmi(i).irq_ack := '0'; -- acknowledge was seen, lower it down
			end if;
		end loop;

		-- r.mm.pull.oneavail holds no memory with it (it is deasserted low by
		-- default at each cycle by (s129) and is high only if one of .done(i)
		-- signal is also high)
		v.mm.pull.oneavail := '0'; -- (s129)
		for i in 0 to nbmult - 1 loop
			if r.mm.pull.done(i) = '1' then
				v.mm.pull.oneavail := '1'; -- (s92)
				v.mm.pull.done_id0 := i; -- (s32)
				exit; -- TODO: check the effect on synthesis of that
			end if;
		end loop;

		-- ---------------------------------------------------------------------
		--      (s1) detect end of one REDC multiplication computation
		--   Basically what we do here is asserting r.mm.pull.pulling (s93),
		-- asserting the MSbit of r.mm.pull.shstart (s119) for startup sequence
		--  We also assert the read-enable to the proper Montgomery multiplier,
		--   see (s120). Reading back words of the REDC result is done by (s2).
		-- ---------------------------------------------------------------------

		v.mm.pull.shstart := '0' & r.mm.pull.shstart(sramlat + 1 downto 1);
		if r.trypull = '1' then -- (s124)
			if r.mm.pull.oneavail = '1' and r.mm.pull.pulling = '0' then -- (s126)
				v.mm.mmi(r.mm.pull.done_id0).zren := '1'; -- (s120)
				-- save the content of r.mm.pull.done_id0 into .done_id1
				-- as (s32) might change the content of .done_id0 at any one time.
				-- From now on, all logic used to handle result of multiplication
				-- and write it back into ecc_fp_dram (see (s2) below) should use
				-- .done_id1 (and NOT .done_id0)
				v.mm.pull.done_id1 := r.mm.pull.done_id0;
				v.mm.pull.pulling := '1'; -- (s93)
				-- pragma translate_off
				v.active := '1';
				-- pragma translate_on
				v.mm.pull.shstart(sramlat + 1) := '1'; -- (s119)
				v.mm.pull.zrencnt := nndyn_wm1; -- (s121)
				v.mm.pull.zcntonce := '1';
				v.fpram.waddrmuxsel := "110"; -- (s18) (see (s20))
				-- r.rdy is necessarily already low when r.trypull is asserted high,
				-- so it simply stays that way, which is why (s122) below is useless
				--v.rdy := '0'; -- (s122)
				v.trypull := '0';
			elsif r.mm.push.do = '0' then
				v.rdy := '1';
				v.trypull := '0'; -- (s125)
			elsif r.mm.push.do = '1' and r.mm.pending_redc = '0' then
				-- (s134) is about unlocking (s133) so as to avoid deadlock in case
				-- an FPREDC has already been accepted from ecc_curve (r.mm.push.do
				-- = 1) and we just finished pulling data from the last FPREDC that
				-- was pending in the previous cycle (which just had r.mm.pending_redc
				-- set back to 0 as per (s135)) - in this situation indeed, if
				-- r.trypull happens to be asserted, keeping it that way would lead
				-- to never pass the combo of conditions (s123) - (s133) - (s136)
				-- that is required to trigger pulling an FRREDC result data.
				-- (note that the conditions we are currently in {.trypull = .do =
				-- .oneavail = 1 & .pulling = 0} differs only from (s123)+(s133)+(s136)
				-- (which is {.do = .oneavail = 1 & .pulling = .trypull = 0}) only
				-- by .trypull being different in the two sets of conditions
				v.trypull := '0'; -- (s134), this is to unlock (s133)
			end if;
		end if;

		-- -----------------------------------------------------------
		--            trigger start of overall computation
		--               (of one opcode execution) (s21)
		-- -----------------------------------------------------------
		if r.rdy = '1' and opi.valid = '0' then
			-- although r.rdy is high by deasserting it we won't cheat ecc_curve in
			-- believing we're accepting an operation from it, since opi.valid = 0
			-- means it is not driving us an operation to do
			v.rdy := '0';
			-- assert r.trypull to test if there is an FPREDC whose result might be
			-- ready to be pulled from one of the Montgomery multipliers
			v.trypull := '1';
		elsif r.rdy = '1' and opi.valid = '1' then -- (s22)
			-- deassert opo.rdy so that not to cheat ecc_curve at next cycle
			v.rdy := '0';
			-- now set different control signals according to the nature
			-- of the operation submitted by ecc_curve
			if opi.redc = '1' then
				v.mm.push.opaorb := '1';
				-- latch address of opcodes A, B & C
				v.opa := opi.a & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.opb := opi.b & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.mm.push.opic := opi.c; -- (s10)
				v.mm.push.do := '1';
				v.ctrl.redc := '1';
			elsif opi.sub = '1' or opi.add = '1' then
				-- subtraction or addition
				v.addsub.do := '1';
				-- latch address of opcodes A, B & C addresses
				v.opa := opi.a & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.opb := opi.b & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.opc := opi.c & std_logic_vector(to_unsigned(0, log2(n - 1)));
				if opi.sub = '1' then
					v.ctrl.sub := '1';
				elsif opi.add = '1' then
					v.ctrl.add := '1';
				end if;
				v.ctrl.extended := opi.extended;
			elsif opi.xxor = '1' then
				-- bitwise xor
				v.xxor.do := '1';
				-- latch address of opcodes A, B & C addresses
				-- note that ecc_curve guarantees that op[abc](0) = 0
				-- for a double-size operation
				v.opa := opi.a & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.opb := opi.b & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.opc := opi.c & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.ctrl.xxor := '1';
			elsif (opi.ssrl or opi.ssll or opi.div2) = '1' then
				-- bit shift
				v.shift.do := '1';
				-- latch address of opcodes A, B & C addresses
				if opi.ssrl = '1' or opi.div2 = '1' then -- opcode NNSRL
					v.opa := opi.a
					  & std_logic_vector(
					      -- n > w and nndyn_wm1 is an unsigned, so resize
				        -- function can't but extend it with 0 MSbits
					      resize(nndyn_wm1, log2(n - 1)));
					v.opc := opi.c
					  & std_logic_vector(
					      -- n > w and nndyn_wm1 is an unsigned, so resize
				        -- function can't but extend it with 0 MSbits
					      resize(nndyn_wm1, log2(n - 1)));
					-- instruction NNDIV2 is handled as a special case of NNSRL
					if opi.div2 = '1' then
						v.ctrl.div2 := '1';
					else
						v.ctrl.ssrl := '1';
					end if;
				else -- can be nothing but opcode NNSLL
					v.ctrl.ssll := '1';
					v.opa := opi.a & std_logic_vector(to_unsigned(0, log2(n - 1)));
					v.opc := opi.c & std_logic_vector(to_unsigned(0, log2(n - 1)));
				end if;
				v.ctrl.extended := opi.extended;
				if opi.ssrl = '1' and opi.ssrl_sh = '1' then
					v.shift.rsh := '1';
					v.shift.rshid := opi.b(1 downto 0);
				else
					v.shift.rsh := '0';
				end if;
			elsif opi.par = '1' then
				-- parity test
				v.par.do := '1';
				v.ctrl.par := '1';
				v.opa := opi.a & std_logic_vector(to_unsigned(0, log2(n - 1)));
			elsif opi.rnd = '1' then
				-- randomization
				v.rnd.do := '1';
				v.ctrl.rnd := '1';
				v.opc := opi.c & std_logic_vector(to_unsigned(0, log2(n - 1)));
				v.rnd.masked := opi.m;
				v.rnd.shift := opi.sh;
				v.rnd.shiftf := opi.shf;
				v.rnd.shregid := unsigned(opi.b(1 downto 0));
			end if;
		end if;

		-- -------------------------------------------------------------
		--                multiplication input processing
		--          (feeding input operands to REDC operation)
		-- -------------------------------------------------------------

		-- shift-register for events involved at computation start
		-- (s94) is bypassed by (s95)
		if shuffle then -- statically resolved by synthesizer
			v.mm.push.shstart(sramlatp2 + 1 downto 0) :=
				'0' & r.mm.push.shstart(sramlatp2 + 1 downto 1); -- (s94)
		else
			v.mm.push.shstart(sramlat + 1 downto 0) :=
				'0' & r.mm.push.shstart(sramlat + 1 downto 1); -- (s94)
		end if;

		-- read operand-words from ecc_fp_dram unit and feed them to the selected
		-- multiplier - processing the result is handled asynchronously (see (s1)
		-- and (s2))
		if r.mm.push.do = '1' then
			-- if a multiplication operation (REDC) is pending we must check for
			-- availability of at least one Montgomery multiplier before we
			-- actually start processing the operation (that's the reason for
			-- condition r.mm.push.oneavail = 1 below)
			-- we must also ensure that the logic pulling result from the Montgomery
			-- multipliers when one has completed its computation is not about
			-- to start doing so (that's the reason for the part 'r.mm.pull.pulling
			-- and r.mm.pull.oneavail = 0' below)
			if r.mm.push.oneavail = '1' -- (s123) one Montgomery multiplier is avail.
				and r.trypull = '0' -- (s133), see (s134)
				and r.mm.pull.pulling = '0' -- (s136) not currently pulling REDC data
			then
				v.mm.push.do := '0';
				-- pragma translate_off
				v.active := '1';
				-- pragma translate_on
				-- (s34) means that address will now be driven by r.opa, see (s17)
				v.fpram.raddrmuxsel := "00"; -- (s34)
				v.mm.push.busy := '1';
				-- increment the nb of FPREDC computations that are currently posted/
				-- pending to the Montgomery multipliers.
				-- Note that there cannot be a simultaneous decrease of register
				-- r.mm.nb_pending_redc in the current cycle (although the process of
				-- reading back result from the Montgomery multipliers is a completely
				-- asynchronous process of the one pushing data to them to compute)
				-- as r.mm.push.do being asserted (as it is right now) means no pulling
				-- data from a Montgomery multiplier can't be currenly happening in
				-- the same cycle: hence there is no by-pass of (s131)
				v.mm.nb_pending_redc := r.mm.nb_pending_redc + 1; -- (s131)
				v.mm.pending_redc := '1';
				-- book the multiplier so that selection algo in (s0) above
				-- does exclude it from its arbitration
				v.mm.busy(r.mm.push.id0) := '1';
				v.mm.push.id1 := r.mm.push.id0; -- (s5) see also (s33)
				-- we register the value of opc into 'r.mm.push.opc(r.mm.push.id0)'
				-- (this is the address where to store the result of multiplica-
				-- tion afterwards, when it is time to pull it from the Montgomery
				-- multiplier & push it into ecc_fp_dram)
				-- Indeed, if we were to do this into r.opc, by the time multipli-
				-- cation is over r.opc might have been already latched with a new
				-- value (of another operation, whatever mult., subtraction,
				-- or addition). Hence r.opc is only used to store the result
				-- address of other operation than multiplication, as their result
				-- is pushed back into ecc_fp_dram synchronously to their computation,
				-- (i.e with no other operation being accepted coming from ecc_curve
				-- before themselves are completely carried out)
				v.mm.push.opc(r.mm.push.id0) := r.mm.push.opic; -- (s91)
				if shuffle then -- statically resolved by synthesizer
					v.mm.push.shstart(sramlatp2 + 1) := '1'; -- (s95) bypass of (s94)
				else
					v.mm.push.shstart(sramlat + 1) := '1'; -- (s95) bypass of (s94)
				end if;
				v.mm.push.rdcnt := nndyn_wm1;
				v.mm.push.rd := '1';
			else -- .oneavail etc
				-- (s127)
				-- we can't simply stall until r.mm.push.oneavail is asserted again
				-- because it can create deadlock: we must give room to the process
				-- of pulling result data from the Montgomery multipliers (that is,
				-- logic described by (s124) & (s126)) otherwise r.mm.push.oneavail
				-- might never be asserted again (that would be the case if all
				-- Montgomery multipliers are currently busy) and condition (s123)
				-- might never be "unlocked" again.
				-- Besides, r.trypull only stays asserted one cycle if there is act-
				-- ually no data to pull back from the Montgomery multipliers (see
				-- (s124) & (s125)) so chance will be given to (s22) logic to accept
				-- the next opcode from ecc_curve.
				-- Note finally that no deadlock can happen from giving priority
				-- to pulling (FPREDC-result-)data from the Montgomery multipliers.
				if r.mm.pending_redc = '1' then
					v.trypull := '1'; -- see also (s128)
				elsif r.mm.pending_redc = '0' then
					v.trypull := '0';
				end if;
			end if; -- .oneavail
		end if; -- .do

		-- (s96) is bypassed by (s97)
		if shuffle then -- statically resolved by synthesizer
			v.mm.push.shmid := -- (sramlatp2 + 1 downto 0) implied
				'0' & r.mm.push.shmid(sramlatp2 + 1 downto 1); -- (s96)
		else
			v.mm.push.shmid(sramlat + 1 downto 0) :=
				'0' & r.mm.push.shmid(sramlat + 1 downto 1); -- (s96)
		end if;

		if shuffle then -- statically resolved by synthesizer
			v.mm.push.gosh := -- (sramlatp2 + 1 downto 0) implied
				'0' & r.mm.push.gosh(sramlatp2 + 1 downto 1);
		else
			v.mm.push.gosh(sramlat + 1 downto 0) :=
				'0' & r.mm.push.gosh(sramlat + 1 downto 1);
		end if;

		-- driving r.fpram.re
		if r.mm.push.busy = '1' then
			v.fpram.re := r.mm.push.rd;
		end if;

		if r.mm.push.rd = '1' then
			-- decrement .rdcnt
			v.mm.push.rdcnt := r.mm.push.rdcnt - 1;
			-- increment r.opa or r.opb depending on .opaorb
			if r.mm.push.opaorb = '1' then
				v.opa(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opa(log2(n - 1) - 1 downto 0)) + 1);
			elsif r.mm.push.opaorb = '0' then
				v.opb(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opb(log2(n - 1) - 1 downto 0)) + 1);
			end if;
			if r.mm.push.rdcnt = (r.mm.push.rdcnt'range => '0') then
				if r.mm.push.opaorb = '1' then
					-- switch .opaorb so that to record that we're now starting the
					-- second operand read burst
					v.mm.push.opaorb := '0';
					-- re-arm counter for that 2nd read burst
					v.mm.push.rdcnt := nndyn_wm1;
					-- arm shmid shift-register so as to prepare the switch between
					-- asserting xen and asserting yen to the Montgomery multiplier
					if shuffle then -- statically resolved by synthesizer
						v.mm.push.shmid(sramlatp2 + 1) := '1'; -- (s97) bypass of (s96)
					else
						v.mm.push.shmid(sramlat + 1) := '1'; -- (s97) bypass of (s96)
					end if;
					-- switch .raddrmuxsel so that now r.opb is used to drive ecc_fp_dram
					-- read address (instead of r.opa)
					-- (s35) has the effect that address will now be driven by r.opb,
					-- see (s17)
					v.fpram.raddrmuxsel := "01"; -- (s35)
				elsif r.mm.push.opaorb = '0' then
					v.mm.push.rd := '0';
					if shuffle then -- statically resolved by synthesizer
						v.mm.push.gosh(sramlatp2 + 1) := '1';
					else
						v.mm.push.gosh(sramlat + 1) := '1';
					end if;
				end if;
			end if;
		end if;

		-- assertion/deassertion of xen & yen to the selected Montgomery mult.
		if r.mm.push.shstart(0) = '1' then
			v.mm.mmi(r.mm.push.id1).xen := '1';
		end if;

		-- switch between xen & yen (data strobes to the Montgomery multiplier)
		if r.mm.push.shmid(0) = '1'
		then
			v.mm.mmi(r.mm.push.id1).xen := '0';
			v.mm.mmi(r.mm.push.id1).yen := '1';
		end if;

		for i in 0 to nbmult - 1 loop
			v.mm.mmi(i).go := '0'; -- (s6)
		end loop;
		-- give selected multiplier a go so that Montgomery multiplication
		-- is actually started
		if r.mm.push.gosh(0) = '1' then
			v.mm.mmi(r.mm.push.id1).yen := '0';
			v.mm.mmi(r.mm.push.id1).go := '1'; -- asserted 1 cycle thx to (s6)
		end if;

		-- data-path feeding X & Y (input operands) to selected Montgomery
		-- multiplier
		-- (consists in driving signal r.mm.mmi(r.mm.push.id1).xy)
		if shuffle then -- statically resolved by synthesizer
			v.mm.push.xypushsh := -- (sramlatp2 - 1 downto 0) implied
				r.fpram.re & r.mm.push.xypushsh(sramlatp2 - 1 downto 1);
		else
			if sramlat > 1 then -- statically resolved by synthesizer
				v.mm.push.xypushsh(sramlat - 1 downto 0) :=
					r.fpram.re & r.mm.push.xypushsh(sramlat - 1 downto 1);
			elsif sramlat = 1 then
				v.mm.push.xypushsh(0) := r.fpram.re;
			end if;
		end if;
		if r.mm.push.xypushsh(0) = '1' and r.mm.push.busy = '1' then
			v.mm.mmi(r.mm.push.id1).xy := fprdata; --r.fpram.fprdata;
		end if;

		if r.mm.push.gosh(0) = '1' then
			-- signal end of operation to ecc_curve, along with
			-- availability for accepting a new operation
			-- (ecc_curve does not need the multiplication to be completed
			-- to present us with a new operation, no more than we need the
			-- multiplication to be completed to accept any new operation -
			-- multiplication is handled asynchronously, which means that
			-- writing its result in memory will be done many cycles later,
			-- with execution of other instructions taking place in-between)
			-- The barrier flag in instructions' opcode is precisely made
			-- to allow execution synchronization from a higher level point
			-- of view
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.ctrl.redc := '0';
			v.mm.push.busy := '0';
			-- note that r.mm.busy(r.mm.push.id1) is not modified (reset)
			-- so that selection algo in (s0) won't select the multiplier
			-- again (this should not happen before we have pulled back
			-- the result of multiplication from it - see (s11))

			-- we could reassert r.rdy but let's give priority to pulling
		 	-- data back from Montgomery multipliers	
			v.trypull := '1'; -- (s128), same remark as for (s127)
		end if;

		-- -------------------------------------------------------------
		--               addition & subtraction processing
		-- -------------------------------------------------------------
		-- read operand-words from ecc_fp_dram unit and push them into
		-- the registers on which addition or substraction is done -
		-- processing result is handled synchronously (i.e words of result
		-- are written back into ecc_fp_dram in the same course as the input
		-- operands are read from it)

		-- shift-register for events involved at computation start
		-- (s70) is bypassed by (s71)
		if shuffle then -- statically resolved by synthesizer
			v.addsub.shstart(sramlatp2 + 1 downto 0) :=
				'0' & r.addsub.shstart(sramlatp2 + 1 downto 1); -- (s70)
		else
			v.addsub.shstart(sramlat + 1 downto 0) :=
				'0' & r.addsub.shstart(sramlat + 1 downto 1); -- (s70)
		end if;

		if r.addsub.do = '1' then -- an addition or subtraction op is pending
			v.addsub.do := '0';
			if shuffle then -- statically resolved by synthesizer
				v.addsub.shstart(sramlatp2 + 1) := '1'; -- (s71) bypass of (s70)
			else
				v.addsub.shstart(sramlat + 1) := '1'; -- (s71) bypass of (s70)
			end if;
			-- pragma translate_off
			v.active := '1';
			-- pragma translate_on
			v.addsub.busy := '1';
			v.fpram.raddrmuxsel := "00"; -- (s26) (see (s17))
			v.fpram.waddrmuxsel := "000"; -- (s28) (see (s20))
			v.addsub.zero := '1'; -- (s68) bypassed by (s69)
			if shuffle then -- statically resolved by synthesizer
				v.fpram.wecnt :=
					to_unsigned(sramlatp2 + 4, log2(sramlatp2 + 4));
			else
				v.fpram.wecnt :=
					to_unsigned(sramlat + 4, log2(sramlatp2 + 4));
			end if;
			v.fpram.wecnten := '1';
		end if;

		-- assertion of r.fpram.re (see (s41) for deassertion)
		if (shuffle and r.addsub.shstart(sramlatp2 + 1) = '1')
			or ((not shuffle) and r.addsub.shstart(sramlat + 1) = '1')
		then
			v.fpram.re := '1'; -- (s29) bypassed by (s41)
			v.addsub.rdcnt := nndyn_2wm1;
			v.addsub.rd := '1';
		end if;

		-- shift-register for events involved at end of computation
		-- (s72) is bypassed by (s73)
		if shuffle then -- statically resolved by synthesizer
			v.addsub.shend := -- (sramlatp2 + 2 downto 0) implied
				 '0' & r.addsub.shend(sramlatp2 + 2 downto 1); -- (s72)
		else
			v.addsub.shend(sramlat + 2 downto 0) :=
				'0' & r.addsub.shend(sramlat + 2 downto 1); -- (s72)
		end if;

		-- end of operands reading + arm shift-register controlling end of ops
		if r.addsub.rd = '1' then
			v.addsub.rdcnt := r.addsub.rdcnt - 1;
			if r.addsub.rdcnt = (r.addsub.rdcnt'range => '0') then
				v.fpram.re := '0'; -- (s41) bypass of (s29)
				v.addsub.rd := '0';
				if shuffle then -- statically resolved by synthesizer
					v.addsub.shend(sramlatp2 + 2) := '1'; -- (s73) bypass of (s72)
				else
					v.addsub.shend(sramlat + 2) := '1'; -- (s73) bypass of (s72)
				end if;
			end if;
		end if;

		-- (s27) r.fpram.raddrmuxsel toggling (to drive r.fpram.raddr either from
		--       r.opa or r.opb, see (s17))
		if r.addsub.busy = '1' then
			if r.fpram.raddrmuxsel = "00" then
				v.fpram.raddrmuxsel := "01"; -- means drive r.fpram.addr from r.opb
			else
				v.fpram.raddrmuxsel := "00"; -- means drive r.fpram.addr from r.opa
			end if;
		end if;

		-- r.opa & r.opb addresses increment
		if r.addsub.busy = '1' then
			if r.fpram.raddrmuxsel = "00" then
				v.opa(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opa(log2(n - 1) - 1 downto 0)) + 1);
			else --if r.fpram.raddrmuxsel = "01" then
				v.opb(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opb(log2(n - 1) - 1 downto 0)) + 1);
			end if;
		end if;

		-- latch actual 'ww'-bits operands (on which to perform the addition)
		-- The target register (either r.addsub.op0 or r.addsub.op1) into which
		-- fprdata is written depends on the combination of r.fpram.raddrmuxsel
		-- with boolean 'shuffle' (which encodes the presence of the ecc_fp_dram's
		-- shuffling countermeasure)
		if r.addsub.busy = '1' then
			if shuffle then -- statically resolved by synthesizer
				if sramlatp2 mod 2 = 0 then
					if r.fpram.raddrmuxsel = "01" then
						v.addsub.op0 := fprdata;
					else
						v.addsub.op1 := fprdata;
					end if;
				else -- sramlatp2 mod 2 = 1
					if r.fpram.raddrmuxsel = "01" then
						v.addsub.op1 := fprdata;
					else
						v.addsub.op0 := fprdata;
					end if;
				end if;
			else
				if sramlat mod 2 = 0 then
					if r.fpram.raddrmuxsel = "01" then
						v.addsub.op0 := fprdata;
					else
						v.addsub.op1 := fprdata;
					end if;
				else -- sramlat mod 2 = 1
					if r.fpram.raddrmuxsel = "01" then
						v.addsub.op1 := fprdata;
					else
						v.addsub.op0 := fprdata;
					end if;
				end if;
			end if;
		end if;

		-- assertion of r.addsub.act
		if r.addsub.shstart(0) = '1' then
			v.addsub.act := '1';
		end if;

		-- actual addition
		-- TODO: set a multicycle (2 periods) on paths:
		--       r.addsub.op0/1 -> r.addsub.res
		--       r.addsub.carry -> r.addsub.res
		--       r.addsub.carry -> itself (does it make sense?)
		--       set a multicycle of 6 periods on paths:
		--       r.addsub.busy -> r.addsub.res
		--       r.addsub.busy -> r.addsub.carry
		if shuffle then -- statically resolved by synthesizer
			if sramlatp2 mod 2 = 0 then
				if r.addsub.act = '1'	and r.fpram.raddrmuxsel = "01" then
					v_op0 := unsigned('0' & r.addsub.op0);
					v_op1 := unsigned('0' & r.addsub.op1);
					v_carry := to_unsigned(0, ww) & r.addsub.carry;
					v_borrow := to_unsigned(0, ww) & r.addsub.borrow;
					if r.ctrl.add = '1' then
						v_addres := v_op0 + v_op1 + v_carry; -- (s87)
						v.addsub.res := std_logic_vector(v_addres(ww - 1 downto 0));
						v.addsub.carry := v_addres(ww); -- (s51) bypassed by (s52)
					else --if r.ctrl.sub = '1' then
						v_subres := v_op0 - v_op1 - v_borrow; -- (s88)
						v.addsub.res := std_logic_vector(v_subres(ww - 1 downto 0));
						v.addsub.borrow := v_subres(ww); -- (s89) bypassed by (s90)
					end if;
				end if;
			else -- sramlatp2 mod 2 = 1
				if r.addsub.act = '1' and r.fpram.raddrmuxsel = "00" then
					v_op0 := unsigned('0' & r.addsub.op0);
					v_op1 := unsigned('0' & r.addsub.op1);
					v_carry := to_unsigned(0, ww) & r.addsub.carry;
					v_borrow := to_unsigned(0, ww) & r.addsub.borrow;
					if r.ctrl.add = '1' then
						v_addres := v_op0 + v_op1 + v_carry; -- (s87)
						v.addsub.res := std_logic_vector(v_addres(ww - 1 downto 0));
						v.addsub.carry := v_addres(ww); -- (s51) bypassed by (s52)
					else --if r.ctrl.sub = '1' then
						v_subres := v_op0 - v_op1 - v_borrow; -- (s88)
						v.addsub.res := std_logic_vector(v_subres(ww - 1 downto 0));
						v.addsub.borrow := v_subres(ww); -- (s89) bypassed by (s90)
					end if;
				end if;
			end if;
		else -- not shuffle
			if sramlat mod 2 = 0 then
				if r.addsub.act = '1' and r.fpram.raddrmuxsel = "01" then
					v_op0 := unsigned('0' & r.addsub.op0);
					v_op1 := unsigned('0' & r.addsub.op1);
					v_carry := to_unsigned(0, ww) & r.addsub.carry;
					v_borrow := to_unsigned(0, ww) & r.addsub.borrow;
					if r.ctrl.add = '1' then
						v_addres := v_op0 + v_op1 + v_carry; -- (s87)
						v.addsub.res := std_logic_vector(v_addres(ww - 1 downto 0));
						v.addsub.carry := v_addres(ww); -- (s51) bypassed by (s52)
					else --if r.ctrl.sub = '1' then
						v_subres := v_op0 - v_op1 - v_borrow; -- (s88)
						v.addsub.res := std_logic_vector(v_subres(ww - 1 downto 0));
						v.addsub.borrow := v_subres(ww); -- (s89) bypassed by (s90)
					end if;
				end if;
			else -- sramlat mod 2 = 1
				if r.addsub.act = '1' and r.fpram.raddrmuxsel = "00" then
					v_op0 := unsigned('0' & r.addsub.op0);
					v_op1 := unsigned('0' & r.addsub.op1);
					v_carry := to_unsigned(0, ww) & r.addsub.carry;
					v_borrow := to_unsigned(0, ww) & r.addsub.borrow;
					if r.ctrl.add = '1' then
						v_addres := v_op0 + v_op1 + v_carry; -- (s87)
						v.addsub.res := std_logic_vector(v_addres(ww - 1 downto 0));
						v.addsub.carry := v_addres(ww); -- (s51) bypassed by (s52)
					else --if r.ctrl.sub = '1' then
						v_subres := v_op0 - v_op1 - v_borrow; -- (s88)
						v.addsub.res := std_logic_vector(v_subres(ww - 1 downto 0));
						v.addsub.borrow := v_subres(ww); -- (s89) bypassed by (s90)
					end if;
				end if;
			end if;
		end if;

		-- deassertion of r.addsub.act
		if r.addsub.shend(2) = '1' then
			v.addsub.act := '0';
		end if;

		-- force initialization of carry (resp. borrow) just before useful first
		-- ww-bit word addition (resp. subtraction) if required (that is, if this
		-- is not an instruction of type eXtended)
		if r.addsub.shstart(0) = '1' then
			-- if the addition (resp. subtraction) instruction is an extended one,
			-- we must not reset the carry (resp. borrow) since the output carry
			-- (resp. borrow) which is the one generated by (s51) (resp. (s89))
			-- when last large number addition (resp. subtraction) happened, must
			-- be used as the input carry (resp. borrow) to the current large number
			-- addition (resp. subtraction) see (s87) (resp. (s88))
			if r.ctrl.extended = '0' then
				if r.ctrl.add = '1' then
					v.addsub.carry := '0'; -- (s52) bypass of (s51)
				else --if r.ctrl.sub = '1' then
					v.addsub.borrow := '0'; -- (s90) bypass of (s89)
				end if;
			end if;
		end if;

		-- the latch of 'ww'-bit addition result into r.fpram.wdata is described
		-- with MUX (s20) below

		-- pushing result back into ecc_fp_dram
		if (r.ctrl.add = '1' or r.ctrl.sub = '1')
		  and r.fpram.wecnten = '1' and r.fpram.wecnt = "0000"
		then
			v.fpram.we := '1';
			v.addsub.weact := '1';
			v.addsub.wr := '1';
			v.addsub.wrcnt := nndyn_wm1;
		end if;

		-- toggle state of r.fpram.we
		if r.addsub.weact = '1' then
			-- assertion of write-enable must follow the constraint of 2-cycles
			-- latency for each 'ww'-bit addition/subtraction issued
			v.fpram.we := not r.fpram.we;
		end if;

		-- definitive deassertion of r.fpram.we along w/ deassert. of r.addsub.weact
		-- along w/ increment of r.opc (address where addition result is written)
		if r.addsub.wr = '1' and r.fpram.we = '1' then
			v.addsub.wrcnt := r.addsub.wrcnt - 1;
			if r.addsub.wrcnt = (r.addsub.wrcnt'range => '0') then
				v.fpram.we := '0';
				v.addsub.wr := '0';
				v.addsub.weact := '0';
			end if;
			v.opc(log2(n - 1) - 1 downto 0) :=
				std_logic_vector(unsigned(r.opc(log2(n - 1) - 1 downto 0)) + 1);
		end if;

		-- detection of a null result
		if r.addsub.busy = '1' and r.fpram.we = '1' then
			if r.fpram.wdata /= std_logic_vector(to_unsigned(0, ww)) then
				v.addsub.zero := '0'; -- (s69) bypass of (s68)
			end if;
		end if;

		-- deassertion of r.addsub.busy
		if r.addsub.shend(0) = '1' then
			v.addsub.busy := '0';
		end if;

		-- to detect an addition/subtraction overflow, we need to record the sign
		-- of opA
		-- TODO: set multicycle constraint (2 periods) on path:
		--       r.addsub.op0 -> r.addsub.opamsb
		-- (but not on r.addsub.shend(3) -> r.addsub.opamsb)
		-- the cycle when r.addsub.shend(3) = 1 matches the one when r.addsub.op0
		-- holds the value of the MSWord of opA (for the second consecutive cycle,
		-- hence the multicycle tip above) so latching the MSbit of r.addsub.op0
		-- in that cycle gives us the sign of opA
		if r.addsub.shend(3) = '1' then
			v.addsub.opamsb := r.addsub.op0(ww - 1);
		end if;

		-- TODO: set a multicycle constraint (2 periods) on path:
		--       r.addsub.op1 -> r.addsub.opbmsb
		-- (but not on r.addsub.shend(2) -> r.addsub.opbmsb)
		-- the cycle when r.addsub.shend(2) = 1 matches the one when r.addsub.op1
		-- holds the value of the MSWord of opB (same remark on multicycle as for
		-- opA above) so latching the MSbit of r.addsub.op1 in that cycle gives
		-- us the sign of opB
		if r.addsub.shend(2) = '1' then
			v.addsub.opbmsb := r.addsub.op1(ww - 1);
		end if;

		-- signaling of a negative result
		-- TODO: set a multicycle constraint (2 periods) on path:
		--       r.addsub.res -> r.ctrl.resultsn
		-- (but not on r.addsub.shend(1) -> r.ctrl.resultsn)
		-- the cycle when r.addsub.shend(1) = 1 matches the one when r.addsub.res
		-- holds the value of the MSWord of the result opC (same remark on multi-
		-- cycle as for opA & opB above) so latching the MSbit of r.addsub.res in
		-- that cycle gives us the sign of the result
		if r.addsub.shend(1) = '1' then
			v.ctrl.resultsn := r.addsub.res(ww - 1);
		end if;

		-- end of computation for addition/subtraction operation
		-- (deassertion of r.active, assertion of r.done
		--  & signaling of a possible null result) - note that finally no error
		-- is actually generated here (r.ctrl.resulterr will be trimmed away
		-- by synthesizer and connected to a gnd hard connection instead)
		if r.addsub.shend(0) = '1' then
			v.done := '1'; -- (s31) stays asserted only 1 cycle thx to (s7)
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.ctrl.resultz := r.addsub.zero;
			if r.ctrl.add = '1' then
				-- Overflow (which always indicates an error in signed arithmetic)
				-- occurs on addition if both operands have the same sign and the
				-- sign of the sum is different
					--v.ctrl.resulterr := (not (r.addsub.opamsb xor r.addsub.opbmsb)) and
					-- (r.addsub.opamsb xor r.ctrl.resultsn);
				v.ctrl.resulterr := '0';
			else --if r.ctrl.sub = '1'
				-- Overflow occurs on subtraction if the operands have different
				-- signs and the sign of the difference differs from the sign of
				-- first operand
					--v.ctrl.resulterr := (r.addsub.opamsb xor r.addsub.opbmsb) and
					-- (r.addsub.opamsb xor r.ctrl.resultsn);
				v.ctrl.resulterr := '0';
			end if;
			-- signal end of operation to ecc_curve, along with
			-- availability for accepting a new operation
			v.rdy := '1';
			v.ctrl.add := '0';
			v.ctrl.sub := '0';
		end if;

		-- -------------------------------------------------------------
		--                   bitwise xor processing
		-- -------------------------------------------------------------
		-- read operand-words from ecc_fp_dram unit and push them
		-- into the registers on which the bitwise xor is done - processing
		-- result is handled synchronously (i.e words of result are written
		-- back into ecc_fp_dram in the same course the input operands
		-- are read from it)

		-- shift-register for events involved at computation start
		if shuffle then -- statically resolved by synthesizer
			v.xxor.shstart := -- (sramlatp2 + 1 downto 0) implied
				'0' & r.xxor.shstart(sramlatp2 + 1 downto 1);
		else
			v.xxor.shstart(sramlat + 1 downto 0) :=
				'0' & r.xxor.shstart(sramlat + 1 downto 1);
		end if;

		if r.xxor.do = '1' then -- a bitwise xor operation is pending
			v.xxor.do := '0';
			if shuffle then -- statically resolved by synthesizer
				v.xxor.shstart(sramlatp2 + 1) := '1';
			else
				v.xxor.shstart(sramlat + 1) := '1';
			end if;
			-- pragma translate_off
			v.active := '1';
			-- pragma translate_on
			v.xxor.busy := '1';
			v.fpram.raddrmuxsel := "00"; -- (s44)
			v.fpram.waddrmuxsel := "010"; -- (s45) (see (s20))
			if shuffle then -- statically resolved by synthesizer
				v.fpram.wecnt :=
					to_unsigned(sramlatp2 + 4, log2(sramlatp2 + 4));
			else
				v.fpram.wecnt :=
					to_unsigned(sramlat + 4, log2(sramlatp2 + 4));
			end if;
			v.fpram.wecnten := '1';
		end if;

		-- assertion of r.fpram.re
		if (shuffle and r.xxor.shstart(sramlatp2 + 1) = '1')
			or ((not shuffle) and r.xxor.shstart(sramlat + 1) = '1')
		then
			v.fpram.re := '1';
			v.xxor.rdcnt := nndyn_2wm1;
			v.xxor.rd := '1';
		end if;

		-- shift-register for events involved at computation end
		if shuffle then -- statically resolved by synthesizer
			v.xxor.shend := -- (sramlatp2 + 2 downto 0) implied
				'0' & r.xxor.shend(sramlatp2 + 2 downto 1);
		else
			v.xxor.shend(sramlat + 2 downto 0) :=
				'0' & r.xxor.shend(sramlat + 2 downto 1);
		end if;

		-- end of operands reading + arm shift-register controlling end of ops
		if r.xxor.rd = '1' then
			v.xxor.rdcnt := r.xxor.rdcnt - 1;
			if r.xxor.rdcnt = (r.xxor.rdcnt'range => '0') then
				v.fpram.re := '0';
				v.xxor.rd := '0';
				if shuffle then -- statically resolved by synthesizer
					v.xxor.shend(sramlatp2 + 2) := '1';
				else
					v.xxor.shend(sramlat + 2) := '1';
				end if;
			end if;
		end if;

		-- (s15)
		-- r.fpram.raddrmuxsel toggling (to drive r.fpram.raddr either from
		-- r.opa or r.opb, see (s17))
		if r.xxor.busy = '1' then
			if r.fpram.raddrmuxsel = "00" then
				v.fpram.raddrmuxsel := "01"; -- means drive r.addr from r.opb, see (s17)
			else
				v.fpram.raddrmuxsel := "00"; -- means drive r.addr from r.opa, see (s17)
			end if;
		end if;

		-- r.opa & r.opb addresses increment
		if r.xxor.busy = '1' then
			if r.fpram.raddrmuxsel = "00" then
				v.opa(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opa(log2(n - 1) - 1 downto 0)) + 1);
			else --if r.fpram.raddrmuxsel = "01" then
				v.opb(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opb(log2(n - 1) - 1 downto 0)) + 1);
			end if;
		end if;

		-- latch actual 'ww'-bits operands (on which to perform the bitwise xor)
		-- The target register (either r.add.op0 or r.add.op1) into which
		-- fprdata is written depends on the combination of r.fpram.raddrmuxsel
		-- with boolean 'shuffle' (which encodes the presence of the ecc_fp_dram's
		-- shuffling countermeasure)
		if r.xxor.busy = '1' then
			if shuffle then -- statically resolved by synthesizer
				if sramlatp2 mod 2 = 0 then
					if r.fpram.raddrmuxsel = "01" then
						v.xxor.op0 := fprdata;
					else
						v.xxor.op1 := fprdata;
					end if;
				else -- sramlatp2 mod 2 = 1
					if r.fpram.raddrmuxsel = "01" then
						v.xxor.op1 := fprdata;
					else
						v.xxor.op0 := fprdata;
					end if;
				end if;
			else -- not shuffle
				if sramlat mod 2 = 0 then
					if r.fpram.raddrmuxsel = "01" then
						v.xxor.op0 := fprdata;
					else
						v.xxor.op1 := fprdata;
					end if;
				else -- sramlat mod 2 = 1
					if r.fpram.raddrmuxsel = "01" then
						v.xxor.op1 := fprdata;
					else
						v.xxor.op0 := fprdata;
					end if;
				end if;
			end if;
		end if;

		-- actual bitwise xor
		-- TODO: set multicycle (2 periods) on path r.xxor.op0/1 -> r.xxor.res
		--                  and (6 periods) on path r.xxor.busy -> r.xxor.res
		if shuffle then -- statically resolved by synthesizer
			if sramlatp2 mod 2 = 0 then
				if r.xxor.busy = '1' and r.fpram.raddrmuxsel = "01" then
					v.xxor.res := r.xxor.op0 xor r.xxor.op1;
				end if;
			else -- sramlatp2 mod 2 = 1
				if r.xxor.busy = '1' and r.fpram.raddrmuxsel = "00" then
					v.xxor.res := r.xxor.op0 xor r.xxor.op1;
				end if;
			end if;
		else
			if sramlat mod 2 = 0 then
				if r.xxor.busy = '1' and r.fpram.raddrmuxsel = "01" then
					v.xxor.res := r.xxor.op0 xor r.xxor.op1;
				end if;
			else -- sramlat mod 2 = 1
				if r.xxor.busy = '1' and r.fpram.raddrmuxsel = "00" then
					v.xxor.res := r.xxor.op0 xor r.xxor.op1;
				end if;
			end if;
		end if;

		-- Note that the latch of 'ww'-bit bitwise xor result into r.fpram.wdata
		-- is described with MUX (s20) below

		-- pushing result back into ecc_fp_dram
		if r.ctrl.xxor = '1'
			and r.fpram.wecnten = '1' and r.fpram.wecnt = "0000"
		then
			v.fpram.we := '1';
			v.xxor.weact := '1';
			v.xxor.wr := '1';
			v.xxor.wrcnt := nndyn_wm1;
		end if;

		-- toggle state of r.fpram.we
		if r.xxor.weact = '1' then
			-- assertion of write-enable must follow the constraint of 2-cycles
			-- latency for each 'ww'-bit bitwise xor issued
			v.fpram.we := not r.fpram.we; -- (s54)
		end if;

		-- definitive deassertion of r.fpram.we along w/ deassert. of r.xxor.weact
		-- along w/ incr. of r.opc (address where bitwise xor result is written)
		if r.xxor.wr = '1' and r.fpram.we = '1' then
			v.xxor.wrcnt := r.xxor.wrcnt - 1;
			if r.xxor.wrcnt = (r.xxor.wrcnt'range => '0') then
				v.fpram.we := '0';
				v.xxor.wr := '0';
				v.xxor.weact := '0';
			end if;
			v.opc(log2(n - 1) - 1 downto 0) :=
				std_logic_vector(unsigned(r.opc(log2(n - 1) - 1 downto 0)) + 1);
		end if;

		-- deassertion of r.xxor.busy
		if r.xxor.shend(0) = '1' then
			v.xxor.busy := '0';
		end if;

		-- end of computation for bitwise xor operation
		-- (deassertion of r.active, assertion of r.done)
		if r.xxor.shend(0) = '1' then
			v.done := '1'; -- (s137) stays asserted only 1 cycle thx to (s7)
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			-- signal end of operation to ecc_curve, along with
			-- availability for accepting a new operation
			v.rdy := '1';
			v.ctrl.xxor := '0';
		end if;

		-- -------------------------------------------------------------
		--                     bit-shift processing
		--                        (left & right)
		-- -------------------------------------------------------------
		-- read operand-words from ecc_fp_dram unit and push them into
		-- the registers on which the bit shift is done - processing
		-- result is handled synchronously (i.e words of result are written
		-- back into ecc_fp_dram in the same course the input operands
		-- are read from it)

		-- shift-register for events involved at computation start
		if shuffle then -- statically resolved by synthesizer
			v.shift.shstart(sramlatp2 + 2 downto 0) :=
				'0' & r.shift.shstart(sramlatp2 + 2 downto 1);
		else
			v.shift.shstart(sramlat + 2 downto 0) :=
				'0' & r.shift.shstart(sramlat + 2 downto 1);
		end if;

		if r.shift.do = '1' then -- a bitshift operation is pending
			v.shift.do := '0';
			-- pragma translate_off
			v.active := '1';
			-- pragma translate_on
			v.shift.busy := '1';
			if shuffle then -- statically resolved by synthesizer
				v.shift.shstart(sramlatp2 + 2) := '1';
			else
				v.shift.shstart(sramlat + 2) := '1';
			end if;
			v.fpram.raddrmuxsel := "00"; -- (s16) (see (s17))
			v.fpram.waddrmuxsel := "011"; -- (s56) (see (s20))
			v.shift.zero := '1';
			if shuffle then -- statically resolved by synthesizer
				v.fpram.wecnt :=
					to_unsigned(sramlatp2 + 3, log2(sramlatp2 + 4));
			else
				v.fpram.wecnt :=
					to_unsigned(sramlat + 3, log2(sramlatp2 + 4));
			end if;
			v.fpram.wecnten := '1';
			-- support of NNSRLs & NNSRLf instructions: we assert the shift-enable
			-- of the appropriate shift-register for just one cycle, see (s111).
			-- Note that (s114) cannot interfere with (s109) or (s115) (nor can
			-- these can interfere with (s114)) because (s109) is protected by
			-- condition r.rnd.dosh=1 and (s115) is protected by condition
			-- r.rnd.finalizesh=1, neither of which can happen simultaneously
			-- to condition r.shift.do=1 which protects (s114).
			if r.shift.rsh = '1' then
				v.rnd.doshx(to_integer(unsigned(r.shift.rshid))) := '1'; -- (s114)
			end if;
		end if;

		if r.shift.busy = '1' then
			-- note that (s111) cannot interfere with (s112) or (s113) (nor can these
			-- can interfere with (s111)) because (s112) is protected by condition
			-- r.rnd.busy=1 and (s113) is protected by condition r.rnd.dosh=1,
			-- neither of which can happen simultaneously to condition r.shift.busy=1
			-- which protects (s111).
			v.rnd.doshx := (others => '0'); -- (s111)
		end if;

		-- assertion of r.fpram.re
		if (shuffle and r.shift.shstart(sramlatp2 + 2) = '1')
			or ((not shuffle) and r.shift.shstart(sramlat + 2) = '1')
		then
			v.fpram.re := '1';
			-- we need to read exactly w ww-bit terms from ecc_fp_dram
			v.shift.rdcnt := nndyn_wm1;
			v.shift.rd := '1';
		end if;

		-- shift-register for events involved at computation end
		if shuffle then -- statically resolved by synthesizer
			v.shift.shend :=
				'0' & r.shift.shend(sramlatp2 + 3 downto 1);
		else
			v.shift.shend(sramlat + 3 downto 0) :=
				'0' & r.shift.shend(sramlat + 3 downto 1);
		end if;

		-- end of operands reading + arm shift-register controlling end of ops
		if r.shift.rd = '1' then
			v.shift.rdcnt := r.shift.rdcnt - 1;
			if r.shift.rdcnt = (r.shift.rdcnt'range => '0') then
				v.fpram.re := '0';
				v.shift.rd := '0';
				if shuffle then -- statically resolved by synthesizer
					v.shift.shend(sramlatp2 + 3) := '1';
				else
					v.shift.shend(sramlat + 3) := '1';
				end if;
			end if;
		end if;

		-- r.opa increment/decrement
		if r.shift.busy = '1' then
			if r.ctrl.ssll = '1' then
				-- for left-shift address must be incremented
				v.opa(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opa(log2(n - 1) - 1 downto 0)) + 1);
			else --if r.ctrl.srll = '1' or r.ctrl.div2 = '1' then
				-- for right-shift address must be decremented
				v.opa(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opa(log2(n - 1) - 1 downto 0)) - 1);
			end if;
		end if;

		-- latch actual ww-bit operand (on which to perform the bit shift)
		if r.shift.busy = '1' then
			v.shift.op0 := fprdata; --r.fpram.fprdata;
		end if;

		-- assertion of r.shift.act
		if r.shift.shstart(1) = '1' then
			v.shift.act := '1';
		end if;

		-- actual bit-shift
		-- TODO: set a multicycle constraint here!
		if r.shift.act = '1' then
			if r.ctrl.ssrl = '1' or r.ctrl.srl32 = '1' or r.ctrl.div2 = '1' then
				-- from left to right
				v.shift.res := r.shift.rcarry & r.shift.op0(ww - 1 downto 1);
				v.shift.rcarry := r.shift.op0(0);
			else
				-- from right to left
				v.shift.res := r.shift.op0(ww - 2 downto 0) & r.shift.lcarry;
				v.shift.lcarry := r.shift.op0(ww - 1);
			end if;
		end if;

		-- deassertion of r.shift.act
		if r.shift.shend(3) = '1' then
			v.shift.act := '0';
		end if;

		-- force initialization of carry just before useful first bit-shift
		-- if required (that is, if this is not an instruction of type eXtended
		-- or if it's a division by 2)
		if r.shift.shstart(1) = '1' then
			if r.ctrl.div2 = '1' then
				if r.ctrl.extended = '0' then
					-- the only difference between instructions NNDIV2 & NNSRL is that
					-- NNDIV2 must preserve the sign of the number, so we just have to
					-- use the MSbit of the first word right-shifted as a carry
					v.shift.rcarry := fprdata(ww - 1); -- (s82) bypass of (s57) & (s58)
				end if;
			elsif r.ctrl.extended = '0' then
				if r.ctrl.ssrl = '1' then
					v.shift.rcarry := '0';
				else --if r.ctrl.ssll = '1'
					v.shift.lcarry := '0';
				end if;
			end if;
		end if;

		-- the latch of 'ww'-bit result into r.fpram.wdata is described
		-- with MUX (s20) below

		-- pushing result back into ecc_fp_dram
		if r.shift.busy = '1'
		  and r.fpram.wecnten = '1' and r.fpram.wecnt = "0000"
		then
			v.fpram.we := '1';
			v.shift.wr := '1';
			v.shift.wrcnt := nndyn_wm1;
		end if;

		-- deassertion of r.fpram.we along w/ increment of r.opc (address where
		-- bit-shift result is written)
		if r.shift.wr = '1' then
			v.shift.wrcnt := r.shift.wrcnt - 1;
			if r.shift.wrcnt = (r.shift.wrcnt'range => '0') then
				v.fpram.we := '0';
				v.shift.wr := '0';
			end if;
		end if;

		-- assertion of r.shift.opcincdec
		if r.shift.shstart(0) = '1' then
			v.shift.opcincdec := '1';
		end if;

		if r.shift.opcincdec = '1' then
			if r.ctrl.ssll = '1' then
				-- for left-shift address must be incremented
				v.opc(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opc(log2(n - 1) - 1 downto 0)) + 1);
			else --if r.ctrl.srll = '1' or r.ctrl.div2 = '1' then
				-- for right-shift address must be decremented
				v.opc(log2(n - 1) - 1 downto 0) :=
					std_logic_vector(unsigned(r.opc(log2(n - 1) - 1 downto 0)) - 1);
			end if;
		end if;

		-- detection of a null result
		if r.shift.busy = '1' and r.fpram.we = '1' then
			if r.fpram.wdata /= std_logic_vector(to_unsigned(0, ww)) then
				v.shift.zero := '0';
			end if;
		end if;

		-- deassertion of r.shift.opcincdec
		if r.shift.shend(2) = '1' then
			v.shift.opcincdec := '0';
		end if;

		-- deassertion of r.shift.busy
		if r.shift.shend(0) = '1' then
			v.shift.busy := '0';
		end if;

		-- end of computation for bit-shift operation
		-- (deassertion of r.active, assertion of r.done
		--  & signaling of a possible null result)
		if r.shift.shend(0) = '1' then
			v.done := '1'; -- (s138), stays asserted only 1 cycle thx to (s7)
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.ctrl.resultz := r.shift.zero;
			-- signal end of operation to ecc_curve, along with
			-- availability for accepting a new operation
			v.rdy := '1';
			v.ctrl.ssrl := '0';
			v.ctrl.ssll := '0';
			v.ctrl.div2 := '0';
		end if;

		-- -------------------------------------------------------------
		--                        randomization
		-- -------------------------------------------------------------
		-- write the operand in ecc_fp_dram with 'w' x 'ww'-bit words of
		-- random data

		if r.rnd.do = '1' then -- a 'generate-random' operation is pending
			v.rnd.do := '0';
			-- pragma translate_off
			v.active := '1';
			-- pragma translate_on
			v.rnd.busy := '1';
			v.rnd.trngrdy := '1'; -- to pull random numbers
			v.rnd.opccnt := nndyn_wm1;
			v.fpram.waddrmuxsel := "100"; -- (s141), see (s20)
			v.rnd.zero := '1';
			v.rnd.burstdone := '0';
		end if;

		-- actual transfer of random words into ecc_fp_dram memory
		-- (taking into account the possible masking of the most significant
		-- ww-bit word, so as to guarantee that the size of the random big number
		-- is nn (or nn_dyn) bits
		v.rnd.write := '0'; -- (s116)
		if r.rnd.busy = '1' then
			if r.rnd.trngrdy = '1' -- (s107)
			  and (trngvalid = '1' or (debug and dbgtrnguse = '0'))
			then
				v.rnd.write := '1';
				if r.rnd.masked = '0' then
					v.rnd.data := trngdata(ww - 1 downto 0);
				elsif r.rnd.masked = '1' then
					if r.rnd.opccnt = to_unsigned(0, log2(w - 1)) then
						-- last word case
						if nndyn_nnrnd_zerowm1 = '1' then
							-- (s101) last word must be set to 0 (see also (s102) below)
							v.rnd.data := (others => '0');
						elsif nndyn_nnrnd_zerowm1 = '0' then
							-- last word must be masked w/ nndyn_nnrnd_mask
							if dbgtrnguse = '1' then
								v.rnd.data := trngdata(ww - 1 downto 0) and nndyn_nnrnd_mask;
							elsif dbgtrnguse = '0' then
								v.rnd.data := nndyn_nnrnd_mask; -- set 1 where mask bits are 1
							end if;
						end if;
					elsif r.rnd.opccnt = to_unsigned(1, log2(w - 1)) then
						-- nex-to-the-last word case
						if nndyn_nnrnd_zerowm1 = '1' then
							-- (s102) if last word must be set to 0 (see (s101) above)
							-- then it means mask 'nndyn_nnrnd_mask' is to be applied
							-- to the next-to-the-last one, i.e now
							if dbgtrnguse = '1' then
								v.rnd.data := trngdata(ww - 1 downto 0) and nndyn_nnrnd_mask;
							elsif dbgtrnguse = '0' then
								v.rnd.data := nndyn_nnrnd_mask; -- set 1 where mask bits are 1
							end if;
						elsif nndyn_nnrnd_zerowm1 = '0' then
							-- if last word is not to be set to 0 (see (s101) above)
							-- then the next-to-the-last word is to be handled as any
							-- other one (i.e no mask, as in the nominal case)
							v.rnd.data := trngdata(ww - 1 downto 0);
						end if;
					else
						-- nominal case (r.rnd.opccnt modulo w is neither 0 nor 1)
						v.rnd.data := trngdata(ww - 1 downto 0);
					end if; -- r.rnd.opccnt
				end if; -- r.rnd.masked
				-- if we're dealing w/ an NNRNDs instruction (or an NNRNDf one)
				-- (that is if r.rnd.shift = '1') then we must deassert trngrdy so
				-- as to stall the interface with ecc_trng and allow us some cycles
				-- to transfer the random ww-bit data word into the adequate
				-- shift-register
				if r.rnd.shift = '1' then
					v.rnd.trngrdy := '0'; -- (s108)
					v.rnd.doshx(to_integer(r.rnd.shregid)) := '1'; -- (s112)
					v.rnd.dosh := '1';
					v.rnd.doshcnt := to_unsigned(ww - 1, log2(ww - 1));
				end if;
			end if;
		end if;

		if r.rnd.busy = '1' then -- (s117)
			if r.rnd.write = '1' then
				v.fpram.we := '1';
			else
				v.fpram.we := '0';
			end if;
		end if;

		-- detection of a null result
		if r.rnd.busy = '1' and r.fpram.we = '1' then
			if r.fpram.wdata /= std_logic_vector(to_unsigned(0, ww)) then
				v.rnd.zero := '0'; -- (s80) bypass of (s79)
			end if;
		end if;

		-- support for NNRNDs and NNRNDf instructions
		v.rnd.last := '0';
		if r.rnd.dosh = '1' then
			-- right-shift r.rnd.data (to empty it)
			v.rnd.data := '0' & r.rnd.data(ww - 1 downto 1);
			-- decrement the total shift nb for the targeted shift-reg
			v.rnd.doshxcnt(to_integer(r.rnd.shregid)) :=
				r.rnd.doshxcnt(to_integer(r.rnd.shregid)) - 1;
			-- decrement the common counter
			v.rnd.doshcnt := r.rnd.doshcnt - 1;
			-- detect possible end of write-burst (same as (s104) below for
			-- the nominal NNRND opcode (i.e the one that is neither NNRNDs
			-- nor NNRNDf))
			if r.rnd.doshcnt(log2(ww-1)-1) = '0' and v.rnd.doshcnt(log2(ww-1)-1) = '1'
			then
				v.rnd.dosh := '0';
				v.rnd.doshx := (others => '0'); -- (s109)
				--if r.rnd.shift = '1' then -- can be but asserted since .dosh = 1
					if r.rnd.shiftf = '0' then
						if r.rnd.burstdone = '1' then -- (s105)
							v.rnd.last := '1';
							--v.rnd.trngrdy := '0'; useless, already deasserted thx to (s108)
						elsif r.rnd.burstdone = '0' then
							-- (s106) will re-authorize TRNG incoming data
							v.rnd.trngrdy := '1'; -- (s106), see (s107) above
						end if;
					elsif r.rnd.shiftf = '1' then
						if r.rnd.burstdone = '1' then -- (s118)
							if r.rnd.doshxcnt(to_integer(r.rnd.shregid)) =
								(r.rnd.doshxcnt(0)'range => '0')
							then
								v.rnd.last := '1';
								--v.rnd.trngrdy := '0'; useless, already deass. thx to (s108)
							else
								-- (s113) is a bypass of (s109)
								v.rnd.doshx(to_integer(r.rnd.shregid)) := '1'; -- (s113)
								v.rnd.finalizesh := '1';
								v.rnd.data(0) := '0'; -- nasty, but works
							end if;
						elsif r.rnd.burstdone = '0' then
							-- (s106) will re-authorize TRNG incoming data
							v.rnd.trngrdy := '1'; -- (s106), see (s107) above
						end if;
					end if;  -- r.rnd.shiftf
				--end if; -- r.rnd.shift
			end if;
			-- pragma translate_off
			assert ( not ((r.rnd.doshxcnt(to_integer(r.rnd.shregid)) =
			              (r.rnd.doshxcnt'range => '0'))
			           and (r.rnd.doshcnt /= (r.rnd.doshxcnt'range => '0'))) )
				report "ecc_fp.vhd: inconsistent state was met while executing "
				     & "opcode NNRNDs or NNRNDf"
					severity FAILURE;
			-- pragma translate_on
		end if;

		-- finalization of the shift-register (alignment of data at right top).
		if r.rnd.finalizesh = '1' then
			-- decrement the total shift nb for the targeted shift-reg
			v.rnd.doshxcnt(to_integer(r.rnd.shregid)) :=
				r.rnd.doshxcnt(to_integer(r.rnd.shregid)) - 1;
			-- detect end of shift
			if r.rnd.doshxcnt(to_integer(r.rnd.shregid))(log2(SZ_SH_REG-1)-1) = '0'
				and v.rnd.doshxcnt(to_integer(r.rnd.shregid))(log2(SZ_SH_REG-1)-1) = '1'
			then
				v.rnd.doshx := (others => '0'); -- (s115)
				v.rnd.finalizesh := '0';
				v.rnd.last := '1';
				--v.rnd.trngrdy := '0'; useless, already deasserted thx to (s108)
			end if;
		end if;

		-- increment of write-address (r.opc) and r.rnd.opccnt
		if r.rnd.write = '1' then
			v.opc(log2(n - 1) - 1 downto 0) :=
				std_logic_vector(unsigned(r.opc(log2(n - 1) - 1 downto 0)) + 1);
			v.rnd.opccnt := r.rnd.opccnt - 1;
			-- (s104) detect end of write-burst (except for NNRNDs & NNRNDf opcodes)
			if r.rnd.opccnt(log2(w-1)-1) = '0' and v.rnd.opccnt(log2(w-1) - 1) = '1'
			then
				if r.rnd.shift = '0' then
					v.rnd.last := '1';
					v.rnd.trngrdy := '0';
				elsif r.rnd.shift = '1' then
					-- end of write-bursts is handled by (s103) above, just post info
					-- here that the burst is over so that (s105) can later detect &
					-- handle it
					v.rnd.burstdone := '1';
				end if;
			end if;
		end if;

		-- initialization of r.rnd.doshxcnt for the shift-registers upon the
		-- start of each new [k]P computation
		if initkp = '1' then
			for i in 0 to NB_MSK_SH_REG - 1 loop
				v.rnd.doshxcnt(i) := to_unsigned((2*w*ww) - 1, log2((2*w*ww) - 1));
			end loop;
		end if;

		if r.rnd.last = '1' then
			v.done := '1'; -- (s139), stays asserted only 1 cycle thx to (s7)
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.ctrl.resultz := r.rnd.zero;
			v.rnd.busy := '0';
			v.fpram.we := '0'; -- probably useless
			-- signal end of operation to ecc_curve, along with
			-- availability to accept a new operation
			v.rdy := '1';
			v.ctrl.rnd := '0';
		end if;

		-- -------------------------------------------------------------
		--                         parity test
		-- -------------------------------------------------------------
		-- read the LSWord of the operand from ecc_fp_dram into register
		-- to test for its parity - processing is handled synchronously
		-- (i.e the result is given back to ecc_curve before a new
		-- operation is accepted from it)

		if shuffle then -- statically resolved by synthesizer
			v.par.sh(sramlatp2 + 1 downto 0) := '0' & r.par.sh(sramlatp2 + 1 downto 1);
		else
			v.par.sh(sramlat + 1 downto 0) := '0' & r.par.sh(sramlat + 1 downto 1);
		end if;

		if r.par.do = '1' then -- a parity-test operation is pending
			v.par.do := '0';
			-- pragma translate_off
			v.active := '1';
			-- pragma translate_on
			v.par.busy := '1';
			v.fpram.raddrmuxsel := "00"; -- (s74) see (s17)
			if shuffle then -- statically resolved by synthesizer
				v.par.sh(sramlatp2 + 1) := '1';
			else
				v.par.sh(sramlat + 1) := '1';
			end if;
		end if;

		if (shuffle and r.par.sh(sramlatp2 + 1) = '1')
			or (not shuffle and r.par.sh(sramlat + 1) = '1')
		then
			v.fpram.re := '1';
		elsif (shuffle and r.par.sh(sramlatp2) = '1')
		        or (not shuffle and r.par.sh(sramlat) = '1') then
			v.fpram.re := '0';
		elsif r.par.sh(0) = '1' then
			v.par.par := fprdata(0); -- (s75) drives output 'opresultpar' (see (s76))
			v.done := '1'; -- (s140), stays asserted only 1 cycle thx to (s7)
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			-- signal end of operation to ecc_curve, along with
			-- availability for accepting a new operation
			v.rdy := '1';
			v.ctrl.par := '0';
			v.par.busy := '0';
		end if;

		-- -------------------------------------------------------------
		--             multiplication result processing (s2)
		-- -------------------------------------------------------------
		-- read back the ww-bit words of the result of multiplication from
		-- one selected multiplier that is showing "job done", and push them
		-- into ecc_fp_dram
		-- also deassert r.mm.pull.done(r.mm.pull.done_id1)

		-- r.mm.pull.zrencnt was initialized by (s121) (at the same time
		-- the .shstart register was armed to control the sequence of events
		-- for the starting part of 'pulling' action): when .zrencnt reaches 0
		-- now it is the .shend shift-register which is armed, now to control
		-- the sequence of events for the ending part of operations

		v.mm.pull.shend := '0' & r.mm.pull.shend(sramlat + 1 downto 1);
		if r.mm.pull.pulling = '1'
			--and r.mm.pull.zcntonce = '1' -- this condition is superfluous
		then
			v.mm.pull.zrencnt := r.mm.pull.zrencnt - 1;
			-- detect end of data pull from multiplier
			if r.mm.pull.zrencnt(log2(w - 1) - 1) = '0'
				and v.mm.pull.zrencnt(log2(w - 1) - 1) = '1'
			then
				v.mm.mmi(r.mm.pull.done_id1).zren := '0';
				v.mm.pull.done(r.mm.pull.done_id1) := '0'; -- (s13), bypass of (s12)
				if r.mm.pull.zcntonce = '1' then
					v.mm.pull.shend(sramlat + 1) := '1';
				end if;
				v.mm.pull.zcntonce := '0';
			end if;
		end if;
		-- we need to load content of register r.mm.push.opc(r.mm.pull.done_id1)
		-- (in which was saved the value of opi.c by (s10) & (s91), i.e the
		-- the address where to write the result of the Montgomery multiplication)
		-- into r.mm.pull.opc as we're going to increment it 'w' times in order
		-- to burst-write the result of multiplication into ecc_fp_dram
		if r.mm.pull.shstart(1) = '1' then
			v.mm.pull.opc := r.mm.push.opc(r.mm.pull.done_id1)
				& std_logic_vector(to_unsigned(0, log2(n - 1)));
		elsif r.mm.pull.pulling = '1' then
			v.mm.pull.opc(log2(n - 1) - 1 downto 0) := std_logic_vector(
				unsigned(r.mm.pull.opc(log2(n - 1) - 1 downto 0)) + 1);
		end if;

		-- assertion of r.fpram.we (write strobe into ecc_fp_dram)
		if r.mm.pull.shstart(0) = '1' then
			v.fpram.we := '1';
		end if;

		-- end of processing of multiplication result
		-- (along with:
		--  - deassertion of r.mm.pull.pulling, r.active, r.fpram.we,
		--    r.mm.busy
		--  - 1-cycle assertion of r.done, to notify ecc_curve that the
		--    overall multiplication/opcode execution is now completely
		--    carried out, that is: including the read back of the result
		--    and its transfer into ecc_fp_dram)
		if r.mm.pull.shend(0) = '1' then
			v.mm.pull.pulling := '0';
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.fpram.we := '0';
			v.done := '1'; -- (s8), stays asserted only 1 cycle thx to (s7)
			v.mm.busy(r.mm.pull.done_id1) := '0'; -- (s11)
			if r.mm.push.do = '0' then
				v.rdy := '1';
			end if;
			v.mm.nb_pending_redc := r.mm.nb_pending_redc - 1; -- (s132)
			if r.mm.nb_pending_redc = to_unsigned(1, log2(nbmult)) then
				-- (means .nb_pending_redc is about to be set back to 0 by (s132))
				v.mm.pending_redc := '0'; -- (s135)
			end if;
		end if;

		-- -------------------------------------------------------------
		--          granting access to ecc_fp_dram from AXI-lite
		--             (for initialization of elliptic curve
		--           parameters & point, and readback of result)
		-- -------------------------------------------------------------

		-- test on compkp is a security: ecc_scalar unit drives compkp high
		-- all along the computation of one [k]P scalar multiplication on
		-- the curve and during all that time, the outside interface
		-- (AXI-lite) cannot access ecc_fp_dram (RAM used to store interme-
		-- diate terms of [k]P computation) neither for write nor for read
		v.compkpdel := compkp;
		v.compcstmtydel := compcstmty;
		v.comppopdel := comppop;
		v.compaopdel := compaop;
		if (compkp = '0' and compcstmty = '0' and comppop = '0' and compaop = '0')
			or (debug and dbghalted = '1') then -- (s98), see (s100) in ecc_curve.vhd
			v.fpram.waddrmuxsel := "111"; -- (s37), see (s20)
			v.fpram.raddrmuxsel := "11"; -- (s36), see (s17)
			v.fpram.we := xwe;
			v.fpram.re := xre;
		else
			-- the test below is here so that when entering computation
			-- of Montgomery constants or when entering computation of [k]P
			-- or entering any of point-based operations or F_p arithmetic
			-- operations, we don't leave r.fpram.we inadvertently asserted
			if   (r.compkpdel = '0' and compkp = '1')
			  or (r.compcstmtydel = '0' and compcstmty = '1')
			  or (r.comppopdel = '0' and comppop = '1')
			  or (r.compaopdel = '0' and compaop = '1')
			then
				v.fpram.we := '0';
				v.fpram.re := '0';
			end if;
		end if;

		-- -------------------------------------------------------------
		--                  MUX to access ecc_fp_dram
		--                  (both read & write ports)
		-- -------------------------------------------------------------

		--                           r e a d

		-- (s17) MUX select of r.fpram.raddr
		-- (see also (s15), (s16), (s34), (s35), (s26), (s27), (s44), (s74)
		--  & (s36))
		case r.fpram.raddrmuxsel is
			-- take address from r.opa (redc, sub, add, shift, xor, par)
			when "00" => v.fpram.raddr := r.opa;
			-- take address from r.opb (redc, sub, add, shift, xor)
			when "01" => v.fpram.raddr := r.opb;
			-- take address from AXI-lite interface
			when others => -- "11"
				v.fpram.raddr := xaddr;
		end case;

		--                          w r i t e

		-- (s20) MUX select for r.fpram.waddr & r.fpram.wdata
		-- (see also (s18), (s28), (s37), (s45), (s56) & (s141))
		-- NOTE: addition allows to set a multicycle of 2 periods
		-- on path r.opc -> r.fpram.wdata, because r.opc is set
		-- 1 cycle before r.fpram.we is asserted high (BUT CHECK
		-- IF OTHER OPERATIONS ALLOW IT TOO)
		case r.fpram.waddrmuxsel is
			-- addition/subtraction logic
			when "000" => v.fpram.waddr := r.opc;
			              v.fpram.wdata := r.addsub.res;
			-- bitwise xor logic
			when "010" => v.fpram.waddr := r.opc;
			              v.fpram.wdata := r.xxor.res;
			-- right-shift logic
			when "011" => v.fpram.waddr := r.opc;
			              v.fpram.wdata := r.shift.res;
			-- randomization
			when "100" => v.fpram.waddr := r.opc;
										v.fpram.wdata := r.rnd.data;
			-- result of multiplication (redc)
			when "110" => v.fpram.waddr := r.mm.pull.opc;
										v.fpram.wdata := mmo(r.mm.pull.done_id1).z;
			-- AXI-lite access ("111")
			when "111" => v.fpram.waddr := xaddr;
		                v.fpram.wdata := xwdata;
			-- ("001" & "101" are values never driven on r.fpram.waddrmuxsel)
			when others => null;
		end case;

		-- decount cycles before asserting WE to ecc_fp_dram
		if r.fpram.wecnten = '1' then
			v.fpram.wecnt := r.fpram.wecnt - 1;
			if r.fpram.wecnt = "0000" then
				v.fpram.wecnten := '0';
			end if;
		end if;

		-- synchronous (active-low) reset
		if rstn = '0' or swrst = '1' then
			-- pragma translate_off
			v.active := '0';
			-- pragma translate_on
			v.rdy := '1';
			v.trypull := '0';
			v.done := '0';
			for i in 0 to nbmult - 1 loop
				v.mm.mmi(i).xen := '0';
				v.mm.mmi(i).yen := '0';
				v.mm.mmi(i).go := '0';
				v.mm.mmi(i).zren := '0';
			end loop;
			v.fpram.we := '0';
			v.fpram.wecnten := '0';
			v.mm.busy := (others => '0');
			v.mm.pull.done := (others => '0');
			v.mm.pull.oneavail := '0';
			v.mm.push.gosh := (others => '0'); -- mandat. alas it'll prevent SRL optim
			v.mm.pull.pulling := '0';
			v.ctrl.resulterr := '0';
			-- redc
			v.mm.push.busy := '0';
			v.mm.push.do := '0';
			v.mm.nb_pending_redc := (others => '0');
			v.mm.pending_redc := '0';
			-- add & sub
			v.addsub.busy := '0';
			v.addsub.do := '0';
			v.addsub.weact := '0';
			-- xor
			v.xxor.busy := '0';
			v.xxor.do := '0';
			v.xxor.weact := '0';
			-- shift (srl/srl32/sll32)
			v.shift.busy := '0';
			v.shift.do := '0';
			-- par
			v.par.busy := '0';
			v.par.do := '0';
			-- rnd
			v.rnd.busy := '0';
			v.rnd.do := '0';
			v.rnd.trngrdy := '0';
			v.rnd.dosh := '0';
			v.rnd.doshx := (others => '0');
			v.rnd.finalizesh := '0';
			-- ---------------------------------------
			-- registers that do not need to be reset:
			-- ---------------------------------------
			-- r.op[abc], r.mm.push.opaorb, r.op[abc]cnt,
			-- r.mm.mmi(i).xy,
			-- r.mm.push.opc(i), r.mm.push.oneavail, r.mm.push.id[012],
			-- r.mm.push.xypushsh,
			-- r.mm.pull.done_id[01], r.mm.pull.zrencnt,
			-- r.mm.pull.opc,
			-- r.add.res, r.add.op0, r.add.op1, r.add.carry, r.add.sh,
			-- r.fpram.re (does no harm if it is reset to a high value),
			-- r.fpram.raddr, r.fpram.raddrmuxsel, r.fpram.waddr, r.fpram.wdata,
			-- r.fpram.waddrmuxsel
			-- r.rnd.last
			-- r.rnd.burstdone
			-- r.rnd.write: no need to reset it (even if it leaves the reset state
			-- in logic high, it will stay so for just one cycle (thx to (s116))
			-- during which r.fpram.we will be protected by (s117) anyway)
			v.ctrl.redc := '0';
			v.ctrl.add := '0'; v.ctrl.sub := '0';
			v.ctrl.srl32 := '0'; v.ctrl.ssrl := '0'; v.ctrl.sll32 := '0';
			v.ctrl.ssll := '0'; v.ctrl.xxor := '0';
			v.ctrl.par := '0'; v.ctrl.rnd := '0';
		end if;

		rin <= v;
	end process comb;

	vcc <= '1';
	gnd <= '0';

	-- registers
	regs : process(clk)
	begin
		if (clk'event and clk = '1') then
			r <= rin;
		end if;
	end process regs;

	-- pragma translate_off
	-- (s142) simulation process to log all microcode execution in file which
	-- pathname is given by constant 'simlog' of package ecc_customize.vhd
	fplog: process(clk)
		file output : TEXT open write_mode is simlog;
		variable lineout : line;
		variable vres : std_logic_vector(2*w*ww - 1 downto 0);
		variable vi : natural range 0 to 2*n - 1;
		variable vip : natural range 0 to 2*n - 1;
		variable vaddra, vaddrb, vaddrc : std_logic_vector(4 downto 0);
		variable newprg : boolean;
		variable x0, y0, x1, y1, z : std_logic_vector(ww*w - 1 downto 0);
		variable pa : natural;
		variable vfp : std_logic_vector(ww - 1 downto 0);
		variable perm_match : boolean;
		variable addr_mismatch : natural;
		variable vw : positive; --:= to_integer(nndyn_w);
		variable v_addr_xr0 : natural;
		variable v_addr_yr0 : natural;
		variable v_addr_xr1 : natural;
		variable v_addr_yr1 : natural;
		variable vpar : std_logic;
		variable vfpnbc, vfpnbc0 : integer;
		variable vanbc, vanbc0 : integer;
		variable vadec : integer;
		variable vptch : integer;
		variable vj  : integer;
	begin
		-- write() function from STD.textio package is overloaded, which is
		-- the reason for the string' attribute appearing several times below
		-- (without it simulators won't know how to differentiate between
		-- string or bit_vector for the 2nd parameter and will issue an error)
		if clk'event and clk = '1' then
			if rstn = '0' then
				rblog.b <= '0';
				rblog.bz <= '0';
				rblog.bsn <= '0';
				rblog.bodd <= '0';
				rblog.call <= '0';
				rblog.callsn <= '0';
				rblog.ret <= '0';
				rblog.nop <= '0';
				rblog.active <= '0';
				rblog.mmpushdo <= '0';
			else
				rblog.b <= b;
				rblog.bz <= bz;
				rblog.bsn <= bsn;
				rblog.bodd <= bodd;
				rblog.call <= call;
				rblog.callsn <= callsn;
				rblog.ret <= ret;
				rblog.retpc <= retpc;
				rblog.nop <= nop;
				rblog.active <= r.active;
				rblog.mmpushdo <= r.mm.push.do;
				-- 1-cycle delayed version of rblog
				rblogbak <= rblog;
				vw := to_integer(nndyn_w);
				-- compute vfpnbc
				if (vw * ww) mod 4 = 0 then
					vfpnbc0 := (vw * ww) / 4;
				else
					vfpnbc0 := ((vw * ww) / 4) + 1;
				end if;
				vfpnbc := vfpnbc0;
				-- compute vanbc
				if IRAM_ADDR_SZ mod 4 = 0 then
					vanbc := IRAM_ADDR_SZ / 4;
				else
					vanbc := (IRAM_ADDR_SZ / 4) + 1;
				end if;
				vanbc0 := vanbc;
				if vfpnbc = vanbc then
					vanbc := 0;
					vfpnbc := 0;
				elsif vfpnbc > vanbc then
					vanbc := vfpnbc - vanbc;
					vfpnbc := 0;
				else
					vfpnbc := vanbc - vfpnbc;
					vanbc := 0;
				end if;
				assert (nbopcodes > 0)
					report "nbopcodes in ecc_customize.vhd doesn't make sense"
						severity FAILURE;
				vadec := (3*log10(nblargenb)) + 13;
				vptch := log10((2**OP_PATCH_SZ) - 1);
				-- ==============================
				-- LOG of ARITHmetic instructions
				-- ==============================
				if (r.addsub.do or r.xxor.do or r.shift.do or r.par.do
					or r.rnd.do) = '1'
				then
					vi := 0;
					vaddra := r.opa(4 + log2(n - 1) downto log2(n - 1));
					vaddrb := r.opb(4 + log2(n - 1) downto log2(n - 1));
					vaddrc := r.opc(4 + log2(n - 1) downto log2(n - 1));
				end if;
				if (r.fpram.we = '0' and r.mm.pull.pulling = '1') then
					vip := 0;
					vaddra := r.opa(4 + log2(n - 1) downto log2(n - 1));
					vaddrb := r.opb(4 + log2(n - 1) downto log2(n - 1));
					vaddrc := r.opc(4 + log2(n - 1) downto log2(n - 1));
				end if;
				if r.active = '1' then
					-- -------------------------------
					-- LOG of FPREDC instruction input (Montgomery Multiplication)
					-- -------------------------------
					if rblog.mmpushdo = '1' and r.mm.push.do = '0' and
						r.mm.push.busy = '1'
					then
						if redc_2nd_input_s then
							redc_2nd_input_s <= FALSE;
						else
							redc_2nd_input_s <= TRUE;
							newprg := FALSE;
							is_new_routine(lineout, pc, newprg);
							if newprg then
								writeline(output, lineout);
							end if;
						end if;
						write(lineout, string'("[0x"));
						hex_write(lineout, pc);
						write(lineout, string'("] "));
						write(lineout, string'("  FPREDC   "));
						vj := vfpnbc0;
						while vj > 0 loop
							write(lineout, string'(" "));
							vj := vj - 1;
						end loop;
						write(lineout, string'("  ("));
						write_addr2(lineout, r.mm.push.opc(r.mm.push.id1));
						write(lineout, string'(" <- "));
						write_addr2(lineout, r.opa(4 + log2(n - 1) downto log2(n - 1)));
						write(lineout, string'("  x  "));
						write_addr2(lineout, r.opb(4 + log2(n - 1) downto log2(n - 1)));
						write(lineout, string'(")  ["));
						write(lineout, time'image(now));
						write(lineout, string'("]"));
						writeline(output, lineout);
						-- handle possible STOP (end of routine)
						if stop = '1' then
							vj := vanbc0 + 9;
							while vj > 0 loop
								write(lineout, string'(" "));
								vj := vj - 1;
							end loop;
							write(lineout, string'("STOP"));
							writeline(output, lineout);
							write(lineout, string'(""));
							writeline(output, lineout);
						end if;
					end if;
					-- --------------------------------
					-- LOG of FPREDC instruction result
					-- --------------------------------
					if r.mm.pull.pulling = '1' then
						if r.fpram.we = '1' then
							vres(ww*vip + ww - 1 downto ww*vip) := r.fpram.wdata;
							vip := vip + 1;
							if vip = vw then
								-- last word is being written, log out whole result on console
								write(lineout, string'("        "));
								write(lineout, string'("  FPREDC 0x"));
								hex_write(lineout, vres(vw*ww - 1 downto 0));
								write(lineout, string'("  ("));
								write_addr2(lineout,
									r.mm.pull.opc(FP_ADDR - 1 downto log2(n - 1)));
								write(lineout, string'("             )  ["));
								write(lineout, time'image(now));
								write(lineout, string'("]"));
								writeline(output, lineout);
								vip := 0;
							end if;
						end if;
					end if;
					-- --------------------------------
					-- LOG of NNADD & NNSUB instruction
					-- --------------------------------
					if r.addsub.busy = '1' then
						if r.fpram.we = '1' then
							vres(ww*vi + ww - 1 downto ww*vi) := r.fpram.wdata;
							vi := vi + 1;
							if vi = vw then
								newprg := FALSE;
								is_new_routine(lineout, pc, newprg);
								if newprg then
									writeline(output, lineout);
								end if;
								-- last word is being written, log out whole result on console
								write(lineout, string'("[0x"));
								hex_write(lineout, pc);
								write(lineout, string'("] "));
								if r.ctrl.add = '1' then
									write(lineout, string'("   NNADD 0x"));
								else --if r.ctrl.sub = '1'
									write(lineout, string'("   NNSUB 0x"));
								end if;
								hex_write(lineout, vres(vw*ww - 1 downto 0));
								vj := vfpnbc;
								while vj > 0 loop
									write(lineout, string'(" "));
									vj := vj - 1;
								end loop;
								write(lineout, string'("  ("));
								write_addr2(lineout, vaddrc);
								write(lineout, string'(" <- "));
								write_addr2(lineout, vaddra);
								if r.ctrl.add = '1' then
									write(lineout, string'("  +  "));
								else --if r.ctrl.sub = '1'
									write(lineout, string'("  -  "));
								end if;
								write_addr2(lineout, vaddrb);
								write(lineout, string'(")  ["));
								write(lineout, time'image(now));
								write(lineout, string'("]"));
								writeline(output, lineout);
								vi := 0;
								-- handle possible STOP (end of routine)
								if stop = '1' then
									vj := vanbc0 + 9;
									while vj > 0 loop
										write(lineout, string'(" "));
										vj := vj - 1;
									end loop;
									write(lineout, string'("STOP"));
									writeline(output, lineout);
									write(lineout, string'(""));
									writeline(output, lineout);
								end if;
							end if;
						end if;
					end if;
					-- ------------------------
					-- LOG of NNXOR instruction
					-- ------------------------
					if r.xxor.busy = '1' then
						if r.fpram.we = '1' then
							vres(ww*vi + ww - 1 downto ww*vi) := r.fpram.wdata;
							vi := vi + 1;
							if vi = vw then
								-- last word is being written, log out whole result on console
								newprg := FALSE;
								is_new_routine(lineout, pc, newprg);
								if newprg then
									writeline(output, lineout);
								end if;
								-- last word is being written, log out whole result on console
								write(lineout, string'("[0x"));
								hex_write(lineout, pc);
								write(lineout, string'("] "));
								write(lineout, string'("   NNXOR 0x"));
								hex_write(lineout, vres(vw*ww - 1 downto 0));
								write(lineout, string'("  ("));
								write_addr2(lineout, vaddrc);
								write(lineout, string'(" <- "));
								write_addr2(lineout, vaddra);
								write(lineout, string'(" (+) "));
								write_addr2(lineout, vaddrb);
								write(lineout, string'(")  ["));
								write(lineout, time'image(now));
								write(lineout, string'("]"));
								writeline(output, lineout);
								vi := 0;
								-- handle possible STOP (end of routine)
								if stop = '1' then
									vj := vanbc0 + 9;
									while vj > 0 loop
										write(lineout, string'(" "));
										vj := vj - 1;
									end loop;
									write(lineout, string'("STOP"));
									writeline(output, lineout);
									write(lineout, string'(""));
									writeline(output, lineout);
								end if;
							end if;
						end if;
					end if;
					-- LOG of shift-like instructions
					if r.shift.busy = '1' then
						-- ------------------------
						-- LOG of NNSRL instruction
						-- ------------------------
						if r.ctrl.ssrl = '1' then
							if r.fpram.we = '1' then
								vres(ww*(vw-1-vi) + ww - 1 downto ww*(vw-1-vi)) := r.fpram.wdata;
								vi := vi + 1;
								if vi = vw then
									-- last word is being written, log out whole result on console
									newprg := FALSE;
									is_new_routine(lineout, pc, newprg);
									if newprg then
										writeline(output, lineout);
									end if;
									write(lineout, string'("[0x"));
									hex_write(lineout, pc);
									write(lineout, string'("] "));
									write(lineout, string'("   NNSRL 0x"));
									hex_write(lineout, vres(vw*ww - 1 downto 0));
									write(lineout, string'("  ("));
									write_addr2(lineout, vaddrc);
									write(lineout, string'(" <- "));
									write_addr2(lineout, vaddra);
									write(lineout, string'("  >>  1"));
									write(lineout, string'(")  ["));
									write(lineout, time'image(now));
									write(lineout, string'("]"));
									writeline(output, lineout);
									vi := 0;
									-- handle possible STOP (end of routine)
									if stop = '1' then
										vj := vanbc0 + 9;
										while vj > 0 loop
											write(lineout, string'(" "));
											vj := vj - 1;
										end loop;
										write(lineout, string'("STOP"));
										writeline(output, lineout);
										write(lineout, string'(""));
										writeline(output, lineout);
									end if;
								end if;
							end if;
						-- ------------------------
						-- LOG of NNSLL instruction
						-- ------------------------
						elsif r.ctrl.ssll = '1' then
							if r.fpram.we = '1' then
								vres(ww*vi + ww - 1 downto ww*vi) := r.fpram.wdata;
								vi := vi + 1;
								if vi = vw then
									newprg := FALSE;
									is_new_routine(lineout, pc, newprg);
									if newprg then
										writeline(output, lineout);
									end if;
									-- last word is being written, log out whole result on console
									write(lineout, string'("[0x"));
									hex_write(lineout, pc);
									write(lineout, string'("] "));
									write(lineout, string'("   NNSLL 0x"));
									hex_write(lineout, vres(vw*ww - 1 downto 0));
									write(lineout, string'("  ("));
									write_addr2(lineout, vaddrc);
									write(lineout, string'(" <- "));
									write_addr2(lineout, vaddra);
									write(lineout, string'("  <<  1"));
									write(lineout, string'(")  ["));
									write(lineout, time'image(now));
									write(lineout, string'("]"));
									writeline(output, lineout);
									vi := 0;
									-- handle possible STOP (end of routine)
									if stop = '1' then
										vj := vanbc0 + 9;
										while vj > 0 loop
											write(lineout, string'(" "));
											vj := vj - 1;
										end loop;
										write(lineout, string'("STOP"));
										writeline(output, lineout);
										write(lineout, string'(""));
										writeline(output, lineout);
									end if;
								end if;
							end if;
						-- -------------------------
						-- LOG of NNDIV2 instruction
						-- -------------------------
						elsif r.ctrl.div2 = '1' then
							if r.fpram.we = '1' then
								vres(ww*(vw-1-vi) + ww - 1 downto ww*(vw-1-vi)) := r.fpram.wdata;
								vi := vi + 1;
								if vi = vw then
									newprg := FALSE;
									is_new_routine(lineout, pc, newprg);
									if newprg then
										writeline(output, lineout);
									end if;
									-- last word is being written, log out whole result on console
									write(lineout, string'("[0x"));
									hex_write(lineout, pc);
									write(lineout, string'("] "));
									write(lineout, string'("  NNDIV2 0x"));
									hex_write(lineout, vres(vw*ww - 1 downto 0));
									write(lineout, string'("  ("));
									write_addr2(lineout, vaddrc);
									write(lineout, string'(" <- "));
									write_addr2(lineout, vaddra);
									write(lineout, string'("  /  2 "));
									write(lineout, string'(")  ["));
									write(lineout, time'image(now));
									write(lineout, string'("]"));
									writeline(output, lineout);
									vi := 0;
									-- handle possible STOP (end of routine)
									if stop = '1' then
										vj := vanbc0 + 9;
										while vj > 0 loop
											write(lineout, string'(" "));
											vj := vj - 1;
										end loop;
										write(lineout, string'("STOP"));
										writeline(output, lineout);
										write(lineout, string'(""));
										writeline(output, lineout);
									end if;
								end if;
							end if;
						end if;
					end if; -- r.shift.busy = 1
					-- --------------------------
					-- LOG of TESTPAR instruction
					-- --------------------------
					if r.par.sh(0) = '1' then
						newprg := FALSE;
						is_new_routine(lineout, pc, newprg);
						if newprg then
							writeline(output, lineout);
						end if;
						write(lineout, string'("[0x"));
						hex_write(lineout, pc);
						write(lineout, string'("] "));
						if opi.parsh = '0' then
							write(lineout, string'(" TESTPAR     "));
						elsif opi.parsh = '1' then
							write(lineout, string'(" TESTPARs    "));
						end if;
						vj := vfpnbc0;
						while vj > 0 loop
							write(lineout, string'(" "));
							vj := vj - 1;
						end loop;
						write(lineout, string'("("));
						write_addr2(lineout, vaddra);
						-- 2 different logs, depending on whether TESTPAR or TESTPARs
						if opi.parsh = '0' then
							if fprdata(0) = '0' then
								write(lineout, string'(" is   even   )  ["));
							else
								write(lineout, string'(" is    odd   )  ["));
							end if;
							write(lineout, time'image(now));
							write(lineout, string'("]"));
						elsif opi.parsh = '1' then
							vpar := fprdata(0) xor opi.oposhr;
							if vpar = '0' then
								write(lineout, string'(" is   even   )  ["));
							else
								write(lineout, string'(" is    odd   )  ["));
							end if;
							write(lineout, time'image(now));
							write(lineout, string'("] ("));
							if vpar = '0' then
								write(lineout, std_logic'image(fprdata(0)));
								write(lineout, string'(" was unmasked by "));
								write(lineout, std_logic'image(opi.oposhr));
								write(lineout, string'(")"));
							else
								write(lineout, std_logic'image(fprdata(0)));
								write(lineout, string'(" was unmasked by "));
								write(lineout, std_logic'image(opi.oposhr));
								write(lineout, string'(")"));
							end if;
						end if;
						writeline(output, lineout);
						-- handle possible STOP (end of routine)
						if stop = '1' then
							vj := vanbc0 + 9;
							while vj > 0 loop
								write(lineout, string'(" "));
								vj := vj - 1;
							end loop;
							write(lineout, string'("STOP"));
							writeline(output, lineout);
							write(lineout, string'(""));
							writeline(output, lineout);
						end if;
					end if; -- r.par.sh(0) = 1
					-- ------------------------
					-- LOG of NNRND instruction
					-- ------------------------
					if r.rnd.busy = '1' then
						if r.fpram.we = '1' then
							vres(ww*vi + ww - 1 downto ww*vi) := r.fpram.wdata;
							vi := vi + 1;
							if vi = vw then
								newprg := FALSE;
								is_new_routine(lineout, pc, newprg);
								if newprg then
									writeline(output, lineout);
								end if;
								-- last word is being written, log out whole result on console
								write(lineout, string'("[0x"));
								hex_write(lineout, pc);
								write(lineout, string'("] "));
								write(lineout, string'("   NNRND 0x"));
								hex_write(lineout, vres(vw*ww - 1 downto 0));
								write(lineout, string'("  ("));
								write_addr2(lineout, vaddrc);
								write(lineout, string'(" <- "));
								write(lineout, string'(" random  )  ["));
								write(lineout, time'image(now));
								write(lineout, string'("]"));
								writeline(output, lineout);
								vi := 0;
								-- handle possible STOP (end of routine)
								if stop = '1' then
									vj := vanbc0 + 9;
									while vj > 0 loop
										write(lineout, string'(" "));
										vj := vj - 1;
									end loop;
									write(lineout, string'("STOP"));
									writeline(output, lineout);
									write(lineout, string'(""));
									writeline(output, lineout);
								end if;
							end if;
						end if;
					end if; -- r.rnd.busy = 1
				end if; -- r.active = 1
				-- ========================
				-- LOG of JUMP instructions
				-- ========================
				-- --------------------
				-- LOG of J instruction
				-- --------------------
				if rblog.b = '1' and rblogbak.b = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("       J 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- ---------------------
				-- LOG of Jz instruction
				-- ---------------------
				elsif rblog.bz = '1' and rblogbak.bz = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("      Jz 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- ----------------------
				-- LOG of Jsn instruction
				-- ----------------------
				elsif rblog.bsn = '1' and rblogbak.bsn = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("     Jsn 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- -----------------------
				-- LOG of Jodd instruction
				-- -----------------------
				elsif rblog.bodd = '1' and rblogbak.bodd = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("    Jodd 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- ---------------------
				-- LOG of JL instruction
				-- ---------------------
				elsif rblog.call = '1' and rblogbak.call = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("      JL 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- -----------------------
				-- LOG of JLsn instruction
				-- -----------------------
				elsif rblog.callsn = '1' and rblogbak.callsn = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("  JLsn 0x"));
					hex_write(lineout, imma);
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  ["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- ----------------------
				-- LOG of RET instruction
				-- ----------------------
				elsif rblog.ret = '1' and rblogbak.ret = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("     RET (0x"));
					hex_write(lineout, retpc);
					write(lineout, string'(")"));
					vj := vanbc;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
				-- ======================
				-- LOG of NOP instruction
				-- ======================
				elsif rblog.nop = '1' and rblogbak.nop = '0' then
					newprg := FALSE;
					is_new_routine(lineout, pc, newprg);
					if newprg then
						writeline(output, lineout);
					end if;
					write(lineout, string'("[0x"));
					hex_write(lineout, pc);
					write(lineout, string'("] "));
					write(lineout, string'("     NOP "));
					write(lineout, string'("  "));
					vj := vfpnbc0;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					vj := vadec;
					while vj > 0 loop
						write(lineout, string'(" "));
						vj := vj - 1;
					end loop;
					write(lineout, string'("  "));
					write(lineout, string'("["));
					write(lineout, time'image(now));
					write(lineout, string'("]"));
					writeline(output, lineout);
					-- handle possible STOP (end of routine)
					if stop = '1' then
						vj := vanbc0 + 9;
						while vj > 0 loop
							write(lineout, string'(" "));
							vj := vj - 1;
						end loop;
						write(lineout, string'("STOP"));
						writeline(output, lineout);
						write(lineout, string'(""));
						writeline(output, lineout);
					end if;
				end if;
				-- =====================================
				-- LOG the coordinates of points R0 & R1 (along with Z-coord)
				-- =====================================
				if logr0r1 = '1' then
					-- get randomized coordinates of the four point [XY]R[01]
					if logr0r1step = 0 or logr0r1step = 1 or logr0r1step = 2 then
						v_addr_xr0 := 4 + to_integer(unsigned(xr0addr));
						v_addr_yr0 := 4 + to_integer(unsigned(yr0addr));
						v_addr_xr1 := 4 + to_integer(unsigned(xr1addr));
						v_addr_yr1 := 4 + to_integer(unsigned(yr1addr));
					elsif logr0r1step = 3 then -- at debut or at end (no shuffling)
						v_addr_xr0 := LARGE_NB_XR0_ADDR;
						v_addr_yr0 := LARGE_NB_YR0_ADDR;
						v_addr_xr1 := LARGE_NB_XR1_ADDR;
						v_addr_yr1 := LARGE_NB_YR1_ADDR;
					end if;
					if shuffle then
						for i in 0 to vw-1 loop
							x0(ww*(i+1) - 1 downto ww*i) := fpdram(
								vtophys((v_addr_xr0*n) + i));
							y0(ww*(i+1) - 1 downto ww*i) := fpdram(
								vtophys((v_addr_yr0*n) + i));
							x1(ww*(i+1) - 1 downto ww*i) := fpdram(
								vtophys((v_addr_xr1*n) + i));
							y1(ww*(i+1) - 1 downto ww*i) := fpdram(
								vtophys((v_addr_yr1*n) + i));
							z(ww*(i+1) - 1 downto ww*i) := fpdram(
								vtophys((LARGE_NB_ZR01_ADDR*n) + i));
						end loop;
					else
						for i in 0 to vw-1 loop
							x0(ww*(i+1) - 1 downto ww*i) := fpdram((v_addr_xr0*n) + i);
							y0(ww*(i+1) - 1 downto ww*i) := fpdram((v_addr_yr0*n) + i);
							x1(ww*(i+1) - 1 downto ww*i) := fpdram((v_addr_xr1*n) + i);
							y1(ww*(i+1) - 1 downto ww*i) := fpdram((v_addr_yr1*n) + i);
							z(ww*(i+1) - 1 downto ww*i) := fpdram((LARGE_NB_ZR01_ADDR*n) + i);
						end loop;
					end if;
					if logr0r1step = 0 then -- a step other than zaddu or zaddc
						write(lineout, string'("R0/R1 coordinates :"));
						writeline(output, lineout);
					else
						if logr0r1step = 1 then -- zaddu
							write(lineout, string'("R0/R1 coordinates after ZADDU of BIT "));
						elsif logr0r1step = 2 then -- zaddc
							write(lineout, string'("R0/R1 coordinates after ZADDC of BIT "));
						elsif logr0r1step = 3 then -- last zaddc
							write(lineout, string'(
								"R0/R1 coordinates (addresses not shuffled here)"));
						end if;
						if logr0r1step = 1 or logr0r1step = 2 then
							write(lineout, simbit);
							write(lineout, string'(" (kappa_"));
							write(lineout, simbit);
							write(lineout, string'(" = "));
							if kap = '0' then
								write(lineout, string'("0"));
							elsif kap = '1' then
								write(lineout, string'("1"));
							else
								write(lineout, string'("X"));
							end if;
							write(lineout, string'(", "));
							write(lineout, string'(" kappa'_"));
							write(lineout, simbit);
							write(lineout, string'(" = "));
							if kapp = '0' then
								write(lineout, string'("0"));
							elsif kapp = '1' then
								write(lineout, string'("1"));
							else
								write(lineout, string'("X"));
							end if;
							write(lineout, string'(")"));
						end if;
						writeline(output, lineout);
					end if;
					-- due to the countermeasure aiming at balancing the address of
					-- coordinates of points R0 & R1 in ZADD[UC], we have to switch the
					-- display of their coordinates for them to match the Sage log
					-- script result (otherwise user might get confused)
					if logr0r1step = 1 then
						-- ZADDU
						log_coords("  XR0", x0, v_addr_xr0, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR0", y0, v_addr_yr0, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  XR1", x1, v_addr_xr1, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR1", y1, v_addr_yr1, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
					elsif logr0r1step = 0 or logr0r1step = 2 then
						-- ZADDC
						log_coords("  XR0", x0, v_addr_xr0, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR0", y0, v_addr_yr0, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  XR1", x1, v_addr_xr1, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR1", y1, v_addr_yr1, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
					elsif logr0r1step = 3 then
						-- last ZADDC (the one to condtionnaly subtract P)
						log_coords("  XR0", x0, LARGE_NB_XR0_ADDR, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR0", y0, LARGE_NB_YR0_ADDR, lineout);
						if r0z = '1' then
							write(lineout, string'("  but R0 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  XR1", x1, LARGE_NB_XR1_ADDR, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
						log_coords("  YR1", y1, LARGE_NB_YR1_ADDR, lineout);
						if r1z = '1' then
							write(lineout, string'("  but R1 = 0"));
						end if;
						writeline(output, lineout);
					end if;
					log_coords("ZR01", z, LARGE_NB_ZR01_ADDR, lineout);
					writeline(output, lineout);
					write(lineout, string'(""));
					writeline(output, lineout);
				end if;
			end if; -- rstn
		end if; -- clk'event
	end process;

	-- LOG final result (coordinates [k]P.x & [k]P.y)
	process(clk)
		file output0 : TEXT open write_mode is "STD_OUTPUT";
		variable lineout0 : line;
		file output1 : TEXT open write_mode is "resultkP.log";
		variable lineout1 : line;
		variable xkp, ykp : std_logic_vector(ww*w - 1 downto 0);
		variable xmsb, ymsb : integer;
	begin
		if clk'event and clk = '1' then
			if logfinalresult = '1' then
				xkp := (others => '0');
				ykp := (others => '0');
				if shuffle then
					for i in 0 to to_integer(nndyn_w) - 1 loop
						xkp(ww*(i+1) - 1 downto ww*i) := fpdram(
							vtophys((LARGE_NB_XR1_ADDR*n)+i));
						ykp(ww*(i+1) - 1 downto ww*i) := fpdram(
							vtophys((LARGE_NB_YR1_ADDR*n)+i));
					end loop;
				else
					for i in 0 to to_integer(nndyn_w) - 1 loop
						xkp(ww*(i+1) - 1 downto ww*i) := fpdram(
							(LARGE_NB_XR1_ADDR*ge_pow_of_2(n))+i);
						ykp(ww*(i+1) - 1 downto ww*i) := fpdram(
							(LARGE_NB_YR1_ADDR*ge_pow_of_2(n))+i);
					end loop;
				end if;
				xmsb := xkp'high;
				for i in xkp'high downto 0 loop
					if xkp(i) /= '0' then
						exit;
					end if;
					xmsb := xmsb - 1;
				end loop;
				if (xmsb <= 0) then
					write(lineout0, string'("ECC_FP: found no high bit in [k]P.x"));
					writeline(output, lineout0);
				end if;
				ymsb := ykp'high;
				for i in ykp'high downto 0 loop
					if ykp(i) /= '0' then
						exit;
					end if;
					ymsb := ymsb - 1;
				end loop;
				if (ymsb <= 0) then
					write(lineout0, string'("ECC_FP: found no high bit in [k]P.y"));
					writeline(output, lineout0);
				end if;
				write(lineout0, string'("ECC_FP: [k]P.x = 0x"));
				hex_write(lineout0, xkp(max(xmsb, ymsb) downto 0));
				writeline(output0, lineout0);
				write(lineout0, string'("ECC_FP: [k]P.y = 0x"));
				hex_write(lineout0, ykp(max(xmsb, ymsb) downto 0));
				writeline(output0, lineout0);
				write(lineout1, string'("[k]P.x = 0x"));
				hex_write(lineout1, xkp(max(xmsb, ymsb) downto 0));
				writeline(output1, lineout1);
				write(lineout1, string'("[k]P.y = 0x"));
				hex_write(lineout1, ykp(max(xmsb, ymsb) downto 0));
				writeline(output1, lineout1);
			end if; -- logfinalresult
		end if; -- clk'event
	end process;
	-- pragma translate_on

	-- drive outputs
	--   to ecc_curve
	opo.rdy <= r.rdy;
	opo.resultz <= r.ctrl.resultz;
	opo.resultsn <= r.ctrl.resultsn;
	opo.resultpar <= r.par.par; -- (s76), see (s75)
	opo.resulterr <= r.ctrl.resulterr;
	opo.done <= r.done;
	--   to multipliers
	mmi <= r.mm.mmi;
	--   to ecc_fp_dram
	fpre <= r.fpram.re;
	fpraddr <= r.fpram.raddr;
	fpwe <= r.fpram.we;
	fpwaddr <= r.fpram.waddr;
	fpwdata <= r.fpram.wdata;
	--   to ecc_trng
	trngrdy <= r.rnd.trngrdy;
	--   to ecc_axi
	-- the point here is not to let the software possibly spy on the intermediate
	-- values pushed/pulled into/from 'ecc_fp_dram' during [k]P computations.
	-- Software is not necessariy malicious - it is the software that
	-- provides the secret scalar... -, however it is safer to forbid any spying
	-- into memory during the computation in case software has been compromised
	-- TODO: set a multicycle constraint (using a large value, e.g 4 or even 8
	-- or more) on the paths compkp -> xrdata
	--                   and compcstmty -> xrdata
	--  (but NOT on the path fprdata -> xrdata)
	xrdata <= fprdata when (   (compkp = '0' and compcstmty = '0')
	                        or (       debug and dbghalted = '1')   )
	                  else (others => '0');  -- (s99), see (s100) in ecc_curve.vhd

end architecture rtl;
