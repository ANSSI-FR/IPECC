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
use work.ecc_vars.all; -- for LARGE_NB_R_ADDR - see (s79), (s80) & (s81)
use work.ecc_soft.all;
use work.mm_ndsp_pkg.all;
use work.ecc_trng_pkg.all;
-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity ecc_axi is
	generic(
		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH : integer := axi32or64; -- (s194), see (s195)
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH : integer := AXIAW); -- in ecc_pkg
	port(
		-- AXI clock & reset
		s_axi_aclk : in std_logic;
		s_axi_aresetn : in std_logic;
		-- AXI write-address channel
		s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
		s_axi_awprot : in std_logic_vector(2 downto 0); -- ignored
		s_axi_awvalid : in std_logic;
		s_axi_awready : out std_logic;
		-- AXI write-data channel
		s_axi_wdata : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		s_axi_wstrb : in std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
		s_axi_wvalid : in std_logic;
		s_axi_wready : out std_logic;
		-- AXI write-response channel
		s_axi_bresp : out std_logic_vector(1 downto 0);
		s_axi_bvalid : out std_logic;
		s_axi_bready : in std_logic;
		-- AXI read-address channel
		s_axi_araddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
		s_axi_arprot : in std_logic_vector(2 downto 0); -- ignored
		s_axi_arvalid : in std_logic;
		s_axi_arready : out std_logic;
		-- AXI read-data channel
		s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		s_axi_rresp : out std_logic_vector(1 downto 0);
		s_axi_rvalid : out std_logic;
		s_axi_rready : in std_logic;
		-- interrupt
		irq : out std_logic;
		-- interface with ecc_scalar
		--   general
		initdone : in std_logic;
		ardy : in std_logic;
		aerr_inpt_not_on_curve : in std_logic;
		aerr_outpt_not_on_curve : in std_logic;
		aerr_inpt_ack : out std_logic;
		aerr_outpt_ack : out std_logic;
		ar01zien : in std_logic;
		ar0zi : in std_logic;
		ar1zi : in std_logic;
		ar0zo : out std_logic;
		ar1zo : out std_logic;
		--   [k]P computation
		agokp : out std_logic;
		kpdone : in std_logic;
		doblinding : out std_logic;
		blindbits : out std_logic_vector(log2(nn) - 1 downto 0);
		doshuffle : out std_logic;
		k_is_null : out std_logic;
		small_k_sz_en : out std_logic;
		small_k_sz_en_en : out std_logic;
		small_k_sz : out unsigned(log2(nn) - 1 downto 0);
		small_k_sz_en_ack : in std_logic;
		small_k_sz_kpdone : in std_logic;
		--   Montgomery constants computation
		agocstmty : out std_logic;
		mtydone : in std_logic;
		--   constant 'a' Montgomery transform
		agomtya : out std_logic;
		amtydone : in std_logic;
		--   other point-based computations
		dopop : out std_logic;
		popid : out std_logic_vector(2 downto 0); -- id defined in ecc_pkg
		popdone : in std_logic;
		yes : in std_logic;
		yesen : in std_logic;
		--   arihtmetic computations
		doaop : out std_logic;
		aopid : out std_logic_vector(2 downto 0); -- id defined in ecc_pkg
		aopdone : in std_logic;
		--   /debug only
		laststep : in std_logic;
		firstzdbl : in std_logic;
		firstzaddu : in std_logic;
		first2pz : in std_logic;
		first3pz : in std_logic;
		torsion2 : in std_logic;
		kap : in std_logic;
		kapp : in std_logic;
		zu : in std_logic;
		zc : in std_logic;
		r0z : in std_logic;
		r1z : in std_logic;
		pts_are_equal : in std_logic;
		pts_are_oppos : in std_logic;
		phimsb : in std_logic;
		kb0end : in std_logic;
		--   end of debug only/
		-- interface with ecc_curve
		masklsb : out std_logic;
		-- interface with ecc_fp (access to ecc_fp_dram)
		xwe : out std_logic;
		xaddr : out std_logic_vector(FP_ADDR - 1 downto 0);
		xwdata : out std_logic_vector(ww - 1 downto 0);
		xre : out std_logic;
		xrdata : in std_logic_vector(ww - 1 downto 0);
		nndyn_nnrnd_mask : out std_logic_vector(ww - 1 downto 0);
		nndyn_nnrnd_zerowm1 : out std_logic;
		-- interface with ecc_trng
		trngvalid : in std_logic;
		trngrdy : out std_logic;
		trngdata : in std_logic_vector(ww - 1 downto 0);
		trngaxiirncount : in std_logic_vector(log2(irn_fifo_size_axi) - 1 downto 0);
		trngefpirncount : in std_logic_vector(log2(irn_fifo_size_fp) - 1 downto 0);
		trngcurirncount : in std_logic_vector(log2(irn_fifo_size_curve)-1 downto 0);
		trngshfirncount : in std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
		-- broadcast interface to Montgomery multipliers
		pen : out std_logic;
		nndyn_mask : out std_logic_vector(ww - 1 downto 0);
		nndyn_shrcnt : out unsigned(log2(ww) - 1 downto 0);
		nndyn_shlcnt : out unsigned(log2(ww) - 1 downto 0);
		nndyn_w : out unsigned(log2(w) - 1 downto 0);
		nndyn_wm1 : out unsigned(log2(w - 1) - 1 downto 0);
		nndyn_wm2 : out unsigned(log2(w - 1) - 1 downto 0);
		nndyn_2wm1 : out unsigned(log2(2*w - 1) - 1 downto 0);
		nndyn_wmin : out unsigned(log2(2*w - 1) - 1 downto 0);
		nndyn_wmin_excp_val : out unsigned(log2(2*w - 1) - 1 downto 0);
		nndyn_wmin_excp : out std_logic;
		nndyn_mask_wm2 : out std_logic;
		nndyn_nnp1 : out unsigned(log2(nn + 1) - 1 downto 0);
		nndyn_nnm3 : out unsigned(log2(nn) - 1 downto 0);
		-- busy signal for [k]P computation
		kppending : out std_logic;
		-- software reset (to other components of the IP)
		swrst : out std_logic;
		-- debug features (interface with ecc_scalar)
		dbgpgmstate : in std_logic_vector(3 downto 0);
		dbgnbbits : in std_logic_vector(15 downto 0);
		dbgjoyebit : in std_logic_vector(log2(2*nn - 1) - 1 downto 0);
		dbgnbstarvrndxyshuf : in std_logic_vector(15 downto 0);
		-- debug features (interface with ecc_curve)
		dbgbreakpoints : out breakpoints_type;
		dbgnbopcodes : out std_logic_vector(15 downto 0);
		dbgdosomeopcodes : out std_logic;
		dbgresume : out std_logic;
		dbghalt : out std_logic;
		dbgnoxyshuf : out std_logic;
		dbghalted : in std_logic;
		dbgdecodepc : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		dbgbreakpointid : in std_logic_vector(1 downto 0);
		dbgbreakpointhit : in std_logic;
		-- debug features (interface with ecc_curve_iram)
		dbgiaddr : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		dbgiwdata : out std_logic_vector(OPCODE_SZ - 1 downto 0);
		dbgiwe : out std_logic;
		-- debug features (interface with ecc_fp)
		dbgtrnguse : out std_logic;
		-- debug features (interface with ecc_trng)
		dbgtrngta : out unsigned(19 downto 0);
		dbgtrngrawreset : out std_logic;
		dbgtrngirnreset : out std_logic;
		dbgtrngrawfull : in std_logic;
		dbgtrngrawwaddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawraddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawdata : in std_logic;
		dbgtrngppdeact : out std_logic;
		dbgtrngcompletebypass : out std_logic;
		dbgtrngcompletebypassbit : out std_logic;
		dbgtrngrawduration : in unsigned(31 downto 0);
		dbgtrngvonneuman : out std_logic;
		dbgtrngidletime : out unsigned(3 downto 0);
		-- debug feature (off-chip trigger)
		dbgtrigger : out std_logic
	);
end entity ecc_axi;

architecture rtl of ecc_axi is

	constant axiw : natural range 3 to 10 := log2(C_S_AXI_DATA_WIDTH - 1);
	constant CST_AXI_RESP_OKAY : std_logic_vector(1 downto 0) := "00";

	constant btw : natural := max(log2(nn) + 2, log2(ww));

	constant readlat : positive := set_readlat;

	type state_type is
		(idle, writeln, readln, -- ln stands for large number
		 newnn, -- used only when nn_dynamic = TRUE
		 readraw); -- stands for raw random numbers (vs 'internal' in AIS31 terms)

	type reg_axi_type is record
		awpending : std_logic;
		dwpending : std_logic;
		waddr : std_logic_vector(C_S_AXI_ADDR_WIDTH - 4 downto 0);
		-- write signals
		awready : std_logic;
		wready : std_logic;
		bvalid : std_logic;
		wdatax : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- AXI W data
		-- read signals
		arready : std_logic;
		rvalid : std_logic;
		rdatax : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- AXI R data
	end record;

	type reg_rnd_write_type is record
		irn : std_logic_vector(ww - 1 downto 0);
		irnempty : std_logic;
		trngrdy : std_logic;
		kmask, kmasked : std_logic_vector(ww - 1 downto 0);
		kmaskfull : std_logic;
		bitsirn : unsigned(log2(ww - 1) - 1 downto 0);
		bitsww : unsigned(log2(ww - 1) - 1 downto 0);
		bitstotal : unsigned(log2(nn) downto 0);
		carry : natural range 0 to 1;
		doshift, doshiftbk : std_logic;
		avail4mask : std_logic;
		trailingzeros : std_logic;
		--shiftdone : std_logic;
		wait4rnd : std_logic;
		wreadybk : std_logic;
		enough_random : std_logic;
		write_mask_sh : std_logic_vector(1 downto 0);
		maskaddr : std_logic_vector(FP_ADDR - 1 downto 0);
		fpaddr_bkup : std_logic_vector(FP_ADDR - 1 downto 0);
		masklsb : std_logic;
		firstwwmask : std_logic;
		wecnt : unsigned(log2(w - 1) - 1 downto 0);
		dowecnt : std_logic;
		realign : std_logic;
	end record;

	type reg_write_type is record
		bitsww : unsigned(log2(ww - 1)  - 1 downto 0);
		bitsaxi : unsigned(axiw - 1 downto 0);
		bitstotal : unsigned(log2(nn) - 1 downto 0);
		shdataww : std_logic_vector(ww - 1 downto 0); -- 'ww'-bit shift-register
		doshift : std_logic;
		new32 : std_logic;
		fpwe, fpwe0 : std_logic;
		trailingzeros : std_logic_vector(1 downto 0);
		fpwdata : std_logic_vector(ww - 1 downto 0);
		rnd : reg_rnd_write_type;
		active : std_logic;
		busy : std_logic;
	end record;

	type reg_read_type is record
		bitsww : unsigned(log2(ww - 1) - 1 downto 0);
		bitsaxi : unsigned(axiw - 1 downto 0);
		bitstotal : unsigned(log2(nn) - 1 downto 0);
		shdataww : std_logic_vector(ww - 1 downto 0); -- 'ww'-bit shift-register
		shdatawwcanbeemptied : std_logic;
		fpre, fpre0 : std_logic;
		-- some of resh's upper bits may be pruned depending on shuffle
		resh : std_logic_vector(readlat downto 0);
		arpending : std_logic;
		rdatax : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		rdataxcanbefilled : std_logic;
		availx : std_logic;
		lastwordx : std_logic;
		active : std_logic;
		busy : std_logic;
		trngreading : std_logic;
	end record;

	constant BLNDSHSZ : natural := 4;
	type ctrl_reg_type is record
		state : state_type;
		ierrid : std_logic_vector(31 downto 16); -- error field in R_STATUS register
		newp : std_logic;
		newa : std_logic;
		wk : std_logic;
		k_is_null : std_logic;
		agocstmty : std_logic;
		mtypending : std_logic;
		mtyirq_postponed : std_logic;
		agokp : std_logic;
		agomtya : std_logic;
		amtypending : std_logic;
		doblinding : std_logic;
		savedoblinding : std_logic;
		blindbits : unsigned(log2(nn) - 1 downto 0);
		doblindsh : std_logic_vector(0 to BLNDSHSZ - 1);
		nbbldnn : unsigned(btw - 1 downto 0);
		blindmodww : unsigned(log2(ww) - 1 downto 0);
		nn_extrabits : unsigned(log2(ww) - 1 downto 0);
		doblindcheck : std_logic;
		kppending : std_logic;
		lockaxi : std_logic;
		pen : std_logic;
		penupsh: std_logic_vector(1 downto 0);
		pendownsh: std_logic_vector(3 downto 0);
		irq : std_logic;
		irqsh : std_logic_vector(3 downto 0);
		irqen : std_logic;
		mtydone_d : std_logic;
		amtydone_d : std_logic;
		kpdone_d : std_logic;
		doshuffle : std_logic;
		dopop : std_logic;
		popid : std_logic_vector(2 downto 0); -- id defined in ecc_pkg
		doaop : std_logic;
		aopid : std_logic_vector(2 downto 0); -- id defined in ecc_pkg
		poppending : std_logic;
		aoppending : std_logic;
		popdone_d : std_logic;
		aopdone_d : std_logic;
		yes : std_logic;
		r0_is_null : std_logic;
		r1_is_null : std_logic;
		p_set : std_logic;
		p_set_and_mty : std_logic;
		a_set : std_logic;
		a_set_and_mty : std_logic;
		b_set : std_logic;
		q_set : std_logic;
		k_set : std_logic;
		k_is_being_set : std_logic;
		x_set : std_logic;
		y_set : std_logic;
		read_forbidden : std_logic;
		-- pragma translate_off
		wlock : std_logic;
		busy : std_logic;
		-- pragma translate_on
		aerr_inpt_ack : std_logic;
		aerr_outpt_ack : std_logic;
		-- small scalar size feature
		do_ksz_test : std_logic;
		small_k_sz : unsigned(log2(nn) - 1 downto 0);
		small_k_sz_en : std_logic;
		small_k_sz_en_en : std_logic;
		small_k_sz_is_on : std_logic;
		-- software reset
		swrst : std_logic;
		swrst_cnt : unsigned(2 downto 0);
	end record; -- ctrl

	type nndyn_reg_type is record
		valnntest : unsigned(log2(nn) - 1 downto 0);
		valnn : unsigned(log2(nn) - 1 downto 0);
		valnnp1 : unsigned(log2(nn + 1) - 1 downto 0);
		valnnm1 : unsigned(log2(nn) - 1 downto 0);
		valnnp2 : unsigned(log2(nn + 2) - 1 downto 0);
		valnnp3 : unsigned(log2(nn + 3) - 1 downto 0);
		valnnp4 : unsigned(log2(nn + 4) - 1 downto 0);
		valnnm3 : unsigned(log2(nn) - 1 downto 0);
		valw, valwtmp : unsigned(log2(w) - 1 downto 0);
		valwerr : std_logic;
		mask, masktmp : std_logic_vector(ww - 1 downto 0);
		shrcnt : unsigned(log2(ww) - 1 downto 0);
		shlcnt : unsigned(log2(ww) - 1 downto 0);
		start : std_logic;
		testnn : std_logic;
		savnnp2p3p4 : std_logic;
		tmp0 : unsigned(log2(nn + 2) downto 0);
		tmpprev0 : unsigned(log2(nn + 2) downto 0);
		tmp00, tmp00prev, valnnp2dww : unsigned(log2(w) - 1 downto 0);
		valnnp2dww_rdy : std_logic;
		dodec0 : std_logic;
		active : std_logic;
		shcnt : unsigned(log2(ww - 1) - 1 downto 0);
		doshcnt : std_logic;
		cnt32 : unsigned(4 downto 0);
		docnt32 : std_logic;
		docnt32done : std_logic;
		tmp1 : unsigned(log2(nn) downto 0);
		tmpprev1 : unsigned(log2(nn) downto 0);
		dodec1 : std_logic;
		nn_mod_ww : unsigned(log2(ww) downto 0);
		nbtrailzeros : unsigned(log2(2*ww) - 1 downto 0);
		tmp2 : unsigned(log2(nn + 4) downto 0);
		tmp22a, tmp22b, tmp22bprev : unsigned(log2(w) downto 0);
		brlwmin : unsigned(log2(w) downto 0);
		brlwmin_rdy : std_logic;
		tmp3, tmp3b, tmpprev3b : unsigned(log2(nn) downto 0);
		dodec2, dodec22 : std_logic;
		dodec3, dodec3b : std_logic;
		dodec0done, dodec3done : std_logic;
		shcnt3b : unsigned(log2(ww) - 1 downto 0);
		doshcnt3b : std_logic;
		masktmp3b : std_logic_vector(ww - 1 downto 0);
		valw3, valwtmp3 : unsigned(log2(w) - 1 downto 0);
		nnrnd_mask : std_logic_vector(ww - 1 downto 0);
		doburst01 : std_logic;
		burst01cnt : unsigned(log2(n - 1) - 1 downto 0);
		burst0or1 : std_logic;
		burst01done : std_logic;
		dosingle1 : std_logic;
		valw4m1 : unsigned(log2(w) - 1 downto 0);
		r_burstwr, r_singlewr : std_logic;
		r_burstwrcnt : unsigned(log2(n - 1) - 1 downto 0);
		--rwritedone : std_logic; 
		exception : std_logic;
	end record;

	type raw_reg_type is record
		raddr : std_logic_vector(log2(raw_ram_size - 1) - 1 downto 0);
	end record;

	type trng_reg_type is record
		ta : unsigned(19 downto 0);
		using : std_logic;
		rawreset : std_logic;
		irnreset : std_logic;
		raw : raw_reg_type;
		ppdeact : std_logic;
		completebypass : std_logic;
		completebypassbit : std_logic;
		vonneuman : std_logic;
		idletime : unsigned(3 downto 0);
	end record;

	-- debug features
	type debug_reg_type is record
		iaddr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		iwdata : std_logic_vector(OPCODE_SZ - 1 downto 0);
		iwe : std_logic;
		counter : unsigned(31 downto 0);
		idatabeat : std_logic;
		trigger : std_logic;
		trigup : std_logic_vector(31 downto 0);
		trigdown : std_logic_vector(31 downto 0);
		trigactive : std_logic;
		breakpoints : breakpoints_type;
		nbopcodes : std_logic_vector(15 downto 0);
		dosomeopcodes : std_logic;
		resume : std_logic;
		trng : trng_reg_type;
		fpwdata : std_logic_vector(ww - 1 downto 0);
		halt : std_logic;
		shwon : std_logic_vector(1 downto 0);
		readrdy : std_logic;
		readsh : std_logic_vector(readlat downto 0);
		noxyshuf : std_logic;
		noaxirnd : std_logic;
	end record;

	-- all registers
	type reg_type is record
		axi : reg_axi_type;
		fpaddr0 : std_logic_vector(FP_ADDR - 1 downto 0);
		fpaddr : std_logic_vector(FP_ADDR - 1 downto 0);
		write : reg_write_type;
		read : reg_read_type;
		ctrl : ctrl_reg_type;
		nndyn : nndyn_reg_type;
		debug : debug_reg_type;
	end record;

	signal r, rin : reg_type;
	signal nndyn_mask_s : std_logic_vector(ww - 1 downto 0);
	signal nndyn_mask_is_zero_s : std_logic;
	signal nndyn_mask_is_all1_but_msb_s : std_logic;
	signal nndyn_wm1_s : unsigned(log2(w - 1) - 1 downto 0);
	signal nndyn_wm2_s : unsigned(log2(w - 1) - 1 downto 0);
	signal nndyn_2wm1_s : unsigned(log2(2*w - 1) - 1 downto 0);

	--signal nndyn_shlcnt_s : unsigned(log2(ww) - 1 downto 0);
	signal nndyn_mask_wm2_s : std_logic;
	signal nndyn_wmin_s : unsigned(log2(2*w - 1) - 1 downto 0);
	signal nndyn_nnrnd_zerowm1_s : std_logic;
	signal nndyn_nnp1_s : unsigned(log2(nn + 1) - 1 downto 0);
	signal nndyn_nnm3_s : unsigned(log2(nn) - 1 downto 0);

	-- pragma translate_off
	signal r_ctrl_wk : std_logic;
	constant xnn : positive := C_S_AXI_DATA_WIDTH*div(2*nn, C_S_AXI_DATA_WIDTH);
	signal r_k : std_logic_vector(2*nn - 1 downto 0);
	signal r_mask : std_logic_vector(2*nn - 1 downto 0);
	signal r_k_masked : std_logic_vector(2*nn - 1 downto 0);
	signal r_k_seq : std_logic;
	signal rkw : natural;
	signal rkx : natural;
	signal rkx_on : std_logic;
	-- pragma translate_on

begin

	-- (s35), see (s31)
	assert(log2(nn) <= C_S_AXI_DATA_WIDTH)
		report "ecc_axi.vhd: value of nn too large"
			severity FAILURE;

	-- (s44), see (s45)
	assert(ww >= 4)
		report "ecc_axi.vhd: value of ww too small (must be greater or equal to 4)"
			severity FAILURE;

	-- (s51), see (s50)
	assert((debug and C_S_AXI_DATA_WIDTH > ww) or (not debug))
		report "ecc_axi.vhd: in debug mode, ww must be smaller "
			   & "than C_S_AXI_DATA_WIDTH"
			severity FAILURE;

	-- (s77), see (s76) & (s78)
	assert (16 + FP_ADDR_MSB - 1 < 32)
		report "ecc_axi.vhd: large numbers' address too large to fit in W_CTRL reg"
			severity FAILURE;

	-- (s79), see (s80) & (s81)
	assert (LARGE_NB_R_ADDR < 2**(FP_ADDR_MSB))
		report "ecc_axi.vhd: constant R address is incompatible "
		     & "w/ ecc_fp_dram size"
			severity FAILURE;

	-- (s83), see (s84) & (s85)
	assert ( (debug and (OPCODE_SZ <= 2 * C_S_AXI_DATA_WIDTH)) or (not debug))
		report "value of parameter nblargenb incompatible w/ size "
		     & "of ecc_curve_iram in debug mode"
			severity FAILURE;

	-- (s87), see (s88)
	assert ( ( debug and (IRAM_ADDR_SZ <= 13)) or (not debug))
		report "value of parameter nbopcodes too large to be compatible "
		     & "w/ debug mode (value of Program Counter read by SW in "
				 & "register R_DBG_STATUS wouldn't be correct)"
			severity FAILURE;

	-- (s195), see (s194)
	assert (axi32or64 = 32 or axi32or64 = 64)
		report "wrong value of parameter axi32or64 in ecc_customize.vhd "
		     & " (must be 32 or 64)"
			severity FAILURE;

	-- (s144), see (s145)
	assert ( (not debug) or ww <= C_S_AXI_DATA_WIDTH )
		report "in debug mode ww must be smaller than or equal to "
		     & "C_S_AXI_DATA_WIDTH"
			severity FAILURE;

	-- (s146), see (s147)
	assert (nbopcodes <= 2**16)
		report "in debug mode nbopcodes must be smaller than or equal to 65536"
			severity FAILURE;

	-- (s150), see (s151)
	assert (log2(raw_ram_size) <= C_S_AXI_DATA_WIDTH)
		report "in debug mode bit-width of parameter raw_ram_size must not "
		     & "exceed C_S_AXI_DATA_WIDTH"
			severity FAILURE;

	-- (s152), see (s153)
	assert (dbgdecodepc'length <= 12)
		report "in debug mode address of instructions is limited to 12 bits "
				 & "(which means nbopcodes must be smaller than or equal to 4096 "
				 & "in ecc_customize.vhd)"
			severity FAILURE;

	-- (s155), see (s156)
	assert ( ( debug and (4 + IRAM_ADDR_SZ - 1 < 16)) or (not debug))
		report "value of parameter nbopcodes too large to be compatible "
		     & "w/ debug mode (address of SW breakpoints set in register "
				 & "W_DBG_BKPT wouldn't all be sampled by hardware)"
			severity FAILURE;

	-- combinational logic
	comb: process(s_axi_aresetn, r,
	              s_axi_awaddr, s_axi_awprot, s_axi_awvalid,
	              s_axi_wdata, s_axi_wvalid, s_axi_bready,
	              s_axi_araddr, s_axi_arprot, s_axi_arvalid,
	              s_axi_rready, ardy, aerr_inpt_not_on_curve,
	              aerr_outpt_not_on_curve,
	              kpdone, mtydone, popdone, aopdone, yes, yesen, xrdata,
	              trngvalid, trngdata, initdone,
	              trngaxiirncount, trngefpirncount, trngcurirncount,
	              trngshfirncount,
	              ar01zien, ar0zi, ar1zi, amtydone,
	              -- debug features
	              dbghalted, dbgdecodepc, dbgbreakpointid,
	              dbgpgmstate, dbgnbbits, dbgbreakpointhit,
	              dbgtrngrawfull, dbgtrngrawwaddr,
	              dbgtrngrawdata, dbgtrngrawduration,
	              dbgnbstarvrndxyshuf
	              -- nndyn_x_s signals looped back for AXI register reads
	              , nndyn_wm2_s, nndyn_wm1_s, nndyn_2wm1_s,
	              nndyn_mask_is_zero_s, nndyn_mask_is_all1_but_msb_s,
	              nndyn_mask_wm2_s, nndyn_wmin_s, nndyn_nnrnd_zerowm1_s,
	              nndyn_nnm3_s, nndyn_nnp1_s,
	              small_k_sz_en_ack, small_k_sz_kpdone
	              -- debug from ecc_scalar
	              , laststep, firstzdbl, firstzaddu, first2pz, first3pz, 
	              torsion2, kap, kapp, zu, zc, r0z, r1z, dbgjoyebit,
	              pts_are_equal, pts_are_oppos, phimsb, kb0end)
		variable v : reg_type;
		variable vbk : natural range 0 to 3;
		variable v_nn_mod_ww_sub : unsigned(log2(ww) downto 0); -- log2(ww) + 1 bits
		variable v_nndyn_testnn : unsigned(31 - CAP_NNMAX_LSB downto 0);
		variable v_debug_not_prod : std_logic;
		variable v_write_rnd_kmasked : unsigned(ww downto 0); -- ww + 1 bit
		constant v_size : natural := max(log2(irn_fifo_size_axi),log2(w)) + 3;
		variable v_rnd_required_qty : unsigned(log2(w) + 1 downto 0);
		variable v_diff : unsigned(v_size - 1 downto 0);
		variable v_writebn_accepted : boolean;
		variable vtmp0 : signed(log2(nn + 2) downto 0);
		variable vtmp1 : unsigned(log2(nn + 2) downto 0);
		variable vtmp2 : unsigned(log2(ww) - 1 downto 0);
		variable vtmp3 : unsigned(log2(w) + 1 downto 0);
		variable vtmp4 : unsigned(log2(w) + 1 downto 0);
		variable vtmp5 : unsigned(log2(w) + 1 downto 0);
		variable dw : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		variable v_pop_possible, v_kp_possible : boolean;
		variable v_busy, v_wlock : boolean;
		variable vtmp6 : unsigned(31 - BLD_BITS_LSB downto 0);
		variable vtmp7 : unsigned(31 - BLD_BITS_LSB downto 0);
		variable v_blindiff : unsigned(31 - BLD_BITS_LSB downto 0);
		variable vtmp8, vtmp9, vtmp10, vtmp11, vtmp12 : unsigned(log2(nn) downto 0);
		variable vtmp13, vtmp14 : unsigned(log2(nn) downto 0);
		variable vtmp15 : signed(log2(nn) downto 0);
		variable vtmp16, vtmp17 : unsigned(log2(ww) downto 0);
		variable vtmp18 : signed(log2(ww) downto 0);
		variable v_axi_wdatax_msb : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		variable v_fpaddr0_msb : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
	begin
		v := r;

		-- software reset (acts as a hardware reset for all other components of the
		-- IP except for ecc_axi)
		if r.ctrl.swrst = '1' then
			v.ctrl.swrst_cnt := r.ctrl.swrst_cnt - 1;
			if r.ctrl.swrst_cnt = (r.ctrl.swrst_cnt'range => '0') then
				v.ctrl.swrst := '0';
				v.axi.wready := '1'; -- (s197), see (s198)
			end if;
		end if;

		v.ctrl.aerr_inpt_ack := '0';
		v.ctrl.aerr_outpt_ack := '0';

		v.debug.halt := '0'; -- (s154)

		-- v_pop_possible must be always defined to avoid spurious latch inference
		-- TODO: multicycle constraints are possible  on the following paths (which
		--   all go through combinational signals v_pop_possible & v_kp_possible):
		-- r.ctrl.[pab]_set -> r.ctrl.agokp (see (s174))
		--                  -> r.ctrl.lockaxi (see (s68))
		--                  -> r.ctrl.ierrid (see (s176)-(s176))
		-- r.ctrl.[pa]_set_and_mty -> r.ctrl.agokp
		--                         -> r.ctrl.lockaxi
		--                         -> r.ctrl.ierrid
		--   The max number of cycles for the constraint should match the minimum
		--   nb of cycles to be expected between 2 AXI transactions
		if (r.ctrl.p_set and r.ctrl.p_set_and_mty and r.ctrl.a_set and
			r.ctrl.a_set_and_mty and r.ctrl.b_set) = '1'
		then
			v_pop_possible := TRUE;
		else
			v_pop_possible := FALSE;
		end if;

		-- v_kp_possible must be always defined to avoid spurious latch inference
		-- TODO: multicycle constraints are possible on the following paths (which
		-- all go through combinational signal v_kp_possible):
		--   r.ctrl.doblinding -> r.ctrl.agokp/r.ctrl.lockaxi/r.ctrl.ierrid
		--   r.ctrl.[kq]_set -> r.ctrl.agokp/r.ctrl.lockaxi/r.ctrl.ierrid
		--   r.nndyn.valwerr -> r.ctrl.agokp/r.ctrl.lockaxi/r.ctrl.ierrid
		v_kp_possible := v_pop_possible and r.ctrl.k_set = '1' -- (s114)
			and ((not nn_dynamic) or (nn_dynamic and r.nndyn.valwerr = '0')) and
		  (r.ctrl.doblinding = '0' or (r.ctrl.doblinding and r.ctrl.q_set) = '1');

		-- (s30) v_busy determines the value of the BUSY bit in R_STATUS register,
		--       see (s160)
		-- Simply put, if:
		--      - we are computing a [k]P product
		--   or - we are computing Montgomery constants
		--   or - we are processing a point operation or an Fp operation
		--   or - we are writing or reading portion of a large number
		--   or - we are in the process of computing signals associated
		--        to a new value of nn (prime size, nn_dynamic = TRUE)
		--   or - we are reading TRNG data (debug = TRUE only)
		--   or - AXI interface is briefly "locked" to avoid race condition
		-- then the BUSY bit in R_STATUS register is set and software is not
		-- supposed to perform any action other than polling the BUSY bit
		-- until it is low (or wait for the asynchronous irq if it programmed one).
		-- Note: difference between r.write.active and r.write.busy is that the
		-- the former is asserted high during the whole process of reading or
		-- writing a complete large number (which requires several AXI data
		-- 32/64 bit transfers given cryptographic number sizes), while the
		-- latter is asserted high only during the processing of one AXI data
		-- transfer (among the several ones which are involved in the writing
		-- or the reading of the same one large number), which is why it appears
		-- in computation of v_busy. Register r.write.busy appearing here instead
		-- of r.write.active allows software to poll R_STATUS register inbetween
		-- the different single 32 (or 64) bit data transfers involved in one
		-- large number read or write.
		v_busy := (initdone = '0') or r.ctrl.kppending = '1'
		         or r.ctrl.mtypending = '1' or r.ctrl.agocstmty = '1'
		         or r.ctrl.amtypending = '1' or r.ctrl.agomtya = '1'
		         or r.ctrl.poppending = '1' or r.ctrl.aoppending = '1'
		         or r.write.busy = '1' or r.read.busy = '1'
		         or (nn_dynamic and r.nndyn.active = '1')
		         or r.read.trngreading = '1'
		         or r.ctrl.lockaxi = '1';
		-- (s161) - Compared to v_busy, v_wlock adds the condition that the last
		-- prime size set by software did not incur an error - thus preventing
		-- software from performing undesirable actions when nn is not set properly
		-- yet (this concerns the following write registers: W_CTRL, W_R[01]_NULL,
		-- W_BLINDING, W_IRQ & W_SMALL_SCALAR, see (s162) - (s168)).
		v_wlock := v_busy or (nn_dynamic and r.nndyn.valwerr = '1');

		-- pragma translate_off
		if v_wlock then v.ctrl.wlock := '1'; else v.ctrl.wlock := '0'; end if;
		if v_busy then v.ctrl.busy := '1'; else v.ctrl.busy := '0'; end if;
		-- pragma translate_on

		-- ----------------------------------------------
		-- generation of signal r.write.rnd.enough_random
		-- ----------------------------------------------
		-- threshold used to raise the flag depends on whether blinding is
		-- activated or not
		if r.ctrl.doblinding = '1' then
			-- four times the value of nndyn_w (if nn_dynamic = TRUE) or w
			-- (otherwise) is required for the number of IRN
			if nn_dynamic then -- statically resolved by synthesizer
				v_rnd_required_qty := r.nndyn.valw & "00"; -- (x 4)
				v_diff := resize(unsigned(trngaxiirncount), v_size)
				        - resize(v_rnd_required_qty, v_size);
				if v_diff(v_size - 1) = '0' then -- trngaxiirncount >= required qty
					v.write.rnd.enough_random := '1';
				else
					v.write.rnd.enough_random := '0';
				end if;
			else -- nn_dynamic = FALSE
				v_rnd_required_qty := to_unsigned(w, log2(w)) & "00"; -- (x 4)
				v_diff := resize(unsigned(trngaxiirncount), v_size)
				        - resize(v_rnd_required_qty, v_size);
				if v_diff(v_size - 1) = '0' then -- trngaxiirncount >= required qty
					v.write.rnd.enough_random := '1';
				else
					v.write.rnd.enough_random := '0';
				end if;
			end if;
		elsif r.ctrl.doblinding = '0' then
			-- the required number or IRN is nnndyn_w or w
			if nn_dynamic then -- statically resolved by synthesizer
				v_rnd_required_qty := resize(r.nndyn.valw, log2(w) + 2);
				v_diff := resize(unsigned(trngaxiirncount), v_size)
				        - resize(v_rnd_required_qty, v_size);
				if v_diff(v_size - 1) = '0' then -- trngaxiirncount >= required qty
					v.write.rnd.enough_random := '1';
				else
					v.write.rnd.enough_random := '0';
				end if;
			else -- nn_dynamic = FALSE
				v_rnd_required_qty := to_unsigned(w, log2(w) + 2);
				v_diff := resize(unsigned(trngaxiirncount), v_size)
				        - resize(v_rnd_required_qty, v_size);
				if v_diff(v_size - 1) = '0' then -- trngaxiirncount >= required qty
					v.write.rnd.enough_random := '1';
				else
					v.write.rnd.enough_random := '0';
				end if;
			end if;
		end if;

		-- ------------------------------------------------------------------
		--  check that value set to W_SMALL_SCALAR is in the authorized range
		--  (>= 3 & <= dynamic nn)
		-- ------------------------------------------------------------------
		if r.ctrl.do_ksz_test = '1' then
			-- small k size transmitted by software must be greater (or equal) to 3
			vtmp8 := '0' & unsigned(r.axi.wdatax(log2(nn) - 1 downto 0));
			vtmp9 := to_unsigned(3, log2(nn) + 1);
			vtmp10 := vtmp8 - vtmp9;
			-- small k size transmitted by software must also be smaller (or equal)
			-- to dynamic value of nn
			vtmp11 := resize(r.nndyn.valnn, log2(nn) + 1);
			vtmp12 := vtmp11 - vtmp8;
			-- now test that the results of both subtractions are positive or null
			if vtmp10(log2(nn)) = '0' and vtmp12(log2(nn)) = '0' then
				v.ctrl.small_k_sz := unsigned(r.axi.wdatax(log2(nn) - 1 downto 0));
				v.ctrl.small_k_sz_en := '1';
				v.ctrl.small_k_sz_en_en := '1';
				v.ctrl.doblinding := '0';
				v.ctrl.savedoblinding := r.ctrl.doblinding;
				v.ctrl.small_k_sz_is_on := '1';
			else
				v.ctrl.small_k_sz_en := '0';
				v.ctrl.small_k_sz_en_en := '1';
			end if;
			v.ctrl.do_ksz_test := '0';
		end if;

		if small_k_sz_en_ack = '1' then
			v.ctrl.small_k_sz_en := '0';
			v.ctrl.small_k_sz_en_en := '0';
			-- assert back r.axi.wready
			v.axi.wready := '1'; -- (s158), see (s157)
		end if;

		if small_k_sz_kpdone = '1' then
			v.ctrl.doblinding := r.ctrl.savedoblinding;
			v.ctrl.small_k_sz_is_on := '0';
		end if;

		-- ---------------------------------------------------------------------
		-- Blinding: check of correctness of nb of blinding bits set by software
		-- ---------------------------------------------------------------------
		-- bitwidth of numbers used to compare nb of blinding bits set by software
		-- is the complete (32 - BLD_BITS_LSB) bits available in W_BLINDING register
		-- so that software driver can be compiled without any prejudice regarding
		-- the value set for nn at synthesis time in ecc_customize.vhd. Value of nn
		-- is made available to software at runtime through R_CAPABILITIES register,
		-- see (s171).
		if r.ctrl.doblindcheck = '1' then -- (s127), .doblindcheck was set by (s128)
			v.ctrl.doblindcheck := '0';
			if nn_dynamic then -- statically resolved by synthesizer
				vtmp6 := resize(r.nndyn.valnnm1, 32 - BLD_BITS_LSB);
			else
				vtmp6 := to_unsigned(nn - 1, 32 - BLD_BITS_LSB);
			end if;
			vtmp7 := -- (s130) see (s129)
				resize(r.ctrl.blindbits, 32 - BLD_BITS_LSB);
			-- compute "nn" - "nb of blinding bits"
			v_blindiff := vtmp6 - vtmp7;
			if v_blindiff(31 - BLD_BITS_LSB) = '1' then
				-- means blindbits > nn - 1 (this is an error, signaled back to
				-- software driver with bit STATUS_ERR_BLN of R_STATUS register)
				v.ctrl.doblinding := '0';
				v.ctrl.ierrid(STATUS_ERR_BLN) := '1';
				-- (s126), set back the AXI handshake signals, see (s125)
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			elsif v_blindiff(31 - BLD_BITS_LSB) = '0' then
				-- means nn - 1 > blindbits (or equal)
				v.ctrl.doblindsh(0) := '1';
				-- until the tests triggered by setting .doblindsh(0) to 1 are not
				-- done, .doblinding stays at 0
				v.ctrl.doblinding := '0';
				v.ctrl.ierrid(STATUS_ERR_BLN) := '0';
			end if;
		end if;

		-- 1st step: compute max(size of alpha, 4)
		if r.ctrl.doblindsh(0) = '1' then
			vtmp13 := resize(r.ctrl.blindbits, log2(nn) + 1);
			vtmp14 := to_unsigned(4, log2(nn) + 1);
			vtmp15 := signed(vtmp13) - signed(vtmp14);
			if vtmp15(log2(nn)) = '1' then
				-- means size of alpha < 4 (in this case, force to 4)
				v.ctrl.blindbits := to_unsigned(4, log2(nn)); -- (s209)
			elsif vtmp15(log2(nn)) = '0' then
				-- means size of alpha >= 4
				null; -- nothing to do, size of alpha is already in r.ctrl.blindbits
			end if;
			v.ctrl.doblindsh := '0' & r.ctrl.doblindsh(0 to BLNDSHSZ - 2);
		end if;

		-- 2nd step: compute sum of nn (static or dynamic) + size of alpha + 1
		if r.ctrl.doblindsh(1) = '1' then
			if nn_dynamic then
				v.ctrl.nbbldnn := resize(r.ctrl.blindbits, btw)
					+ resize(r.nndyn.valnn, btw)
					+ 1; -- extra bit that we must ensure to set to 0 for random scalar
			else -- not nn_dynamic
				v.ctrl.nbbldnn := resize(r.ctrl.blindbits, btw)
					+ to_unsigned(nn, btw)
					+ 1; -- extra bit that we must ensure to set to 0 for random scalar
			end if;
			v.ctrl.doblindsh := '0' & r.ctrl.doblindsh(0 to BLNDSHSZ - 2);
		end if;

		-- 3rd step: compute (nn + size of alpha + 1) mod ww by subtracting ww
		-- to it until we reach a strictly negative value
		-- In (s205) below we truncate r.ctrl.nnbldnn but it's Ok because in
		-- the cycle the transfer of r.ctrl.nbbldnn into r.ctrl.blindmodww is
		-- actually useful, we know that r.ctrl.nbbldnn will hold a residue
		-- mod ww, hence a valule which is strictly less than ww
		if r.ctrl.doblindsh(2) = '1' then
			v.ctrl.nbbldnn := resize(r.ctrl.nbbldnn, btw) - to_unsigned(ww, btw);
			if r.ctrl.nbbldnn(btw - 1) = '1' then
				-- means previous value of r.ctrl.nbbldnn (currently buffered in
				-- r.ctrl.blindmodww) holds the value (nn + size of alpha + 1) mod ww
				-- we stop the subtractions by ww
				v.ctrl.doblindsh := '0' & r.ctrl.doblindsh(0 to BLNDSHSZ - 2);
			elsif r.ctrl.nbbldnn(btw - 1) = '0' then
				v.ctrl.blindmodww := r.ctrl.nbbldnn(log2(ww) - 1 downto 0); -- (s205)
			end if;
		end if;

		-- 4th step: compute r.ctrl.nn_extrabits = ww - r.ctrl.blindmodww
		if r.ctrl.doblindsh(3) = '1' then
			vtmp16 := to_unsigned(ww, log2(ww) + 1);
			vtmp17 := resize(r.ctrl.blindmodww, log2(ww) + 1);
			vtmp18 := signed(vtmp16) - signed(vtmp17);
			v.ctrl.nn_extrabits := unsigned(vtmp18(log2(ww) - 1 downto 0));
			if r.ctrl.small_k_sz_is_on = '1' then
				v.ctrl.savedoblinding := '1';
			elsif r.ctrl.small_k_sz_is_on = '0' then
				v.ctrl.doblinding := '1';
			end if;
			-- end the four sequences cycle of tests
			v.ctrl.doblindsh := '0' & r.ctrl.doblindsh(0 to BLNDSHSZ - 2);
			-- (s207), see (s206) for why these statements on AXI ready/valid
			-- handshake signals are here
			v.axi.wready := '1';
			v.axi.awready := '1';
			v.axi.arready := '1';
			v.axi.bvalid := '1';
		end if;

		-- some registers require default reset
		v.write.new32 := '0';
		v.write.fpwe0 := '0'; -- (s24)
		v.write.fpwe := r.write.fpwe0;
		v.read.fpre0 := '0'; -- (s49)
		v.read.fpre := r.read.fpre0;
		v.nndyn.testnn := '0'; -- (s169)
		v.nndyn.start := '0'; -- (s124)
		v.write.rnd.avail4mask := '0';

		v.debug.trng.rawreset := '0'; -- (s58)
		v.debug.trng.irnreset := '0'; -- (s59)

		-- (s96) yesen high means ecc_scalar drives the answer to a point-based test
		-- (this signal is driven high by ecc_scalar during 1 cycle only)
		if yesen = '1' then
			v.ctrl.yes := yes; -- read in R_STATUS register, see (s98)
		end if;

		-- ecc_scalar
		if ar01zien = '1' then
			v.ctrl.r0_is_null := ar0zi;
			v.ctrl.r1_is_null := ar1zi;
		end if;

		if r.ctrl.wk = '1' then
			if r.write.rnd.write_mask_sh(0) = '1' then
				v.write.fpwdata := r.write.rnd.kmasked;
			elsif r.write.rnd.write_mask_sh(1) = '1' then
				v.write.fpwdata := r.write.rnd.kmask;
			end if;
		elsif r.ctrl.wk = '0' then
			v.write.fpwdata := r.write.shdataww;
		end if;

		v.fpaddr := r.fpaddr0;

		-- ----------------------------------------------------------
		--                   A X I   W r i t e s
		-- ----------------------------------------------------------

		-- handshake over AXI address-write channel
		if s_axi_awvalid = '1' and r.axi.awready = '1' then
			v.axi.awpending := '1';
			v.axi.waddr := s_axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 3);
			v.axi.awready := '0';
			v.axi.arready := '0';
		end if;

		-- handshake over AXI data-write channel
		if s_axi_wvalid = '1' and r.axi.wready = '1' then
			v.axi.dwpending := '1';
			-- note that r.axi.wdatax, which content is both pulled from AXI bus
			-- and pushed into r.write.shdataww in shift-register mode, cannot be
			-- smashed by an AXI write access during the process of its shift-
			-- register/emptying into register r.write.shdataww (see (s22)) as
			-- WREADY signal is deasserted as soon as one AXI write has been
			-- performed (see (s0) just below) and it is not reasserted again
			-- until the whole 32-bit (or 64-bit) data has been shifted into
			-- r.write.shdataww (see (s2) below) and/or when a total of (dynamic-
			-- value-of-)nn bits is pushed in ecc_fp_dram memory (see (s172))
			v.axi.wdatax := s_axi_wdata;
			v.axi.wready := '0'; -- (s0)
		end if;

		-- handshake over AXI write-response channel
		if r.axi.bvalid = '1' and s_axi_bready = '1' then
			v.axi.bvalid := '0';
		end if;

		v_writebn_accepted := TRUE; -- (s54) see (s56)

		-- -----------------------------------------------------------
		-- r.axi.awpending & r.axi.dwpending both HIGH: new write-beat
		-- -----------------------------------------------------------
		-- debug feature
		v.debug.iwe := '0'; -- (s82)
		v.debug.resume := '0'; -- (s173)
		v.debug.dosomeopcodes := '0'; -- (s33)
		v.ctrl.penupsh := '0' & r.ctrl.penupsh(1);
		v.debug.shwon := '0' & r.debug.shwon(1);
		v.debug.readsh := '0' & r.debug.readsh(readlat downto 1);
		if r.debug.readsh(0) = '1' then
			v.debug.readrdy := '1';
		end if;
		if r.axi.awpending = '1' and r.axi.dwpending = '1' then
			v.axi.awpending := '0';
			v.axi.dwpending := '0';
			-- -------------------------------------------------
			-- decoding write of W_CTRL register
			-- -------------------------------------------------
			if (debug and r.axi.waddr = W_CTRL)
				or ((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_CTRL(ADB - 2 downto 0))
			then
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (s162), see (s161)
					-- in debug mode we always grant write access to W_CTRL register
					-- (so use with care)
					-- Decode content of W_CTRL register. Since sevaral actions can
					-- be triggered by software here, we need to prioritize them,
					-- which is done below (action 1 has the highest priority, action 5
					-- has the lowest)
					--   1. software wants to write a large number, see (s186)
					--   2. software wants to read a large number, see (s187)
					--   3. software wants to start a [k]P computation, see (s188)
					--   4. software asks for a point-based operation (other than [k]P),
					--      see (s189)
					--   5. software asks for a field-arithmetic operation, see (s190)
					-- In any other case, error flag STATUS_ERR_WREG_FBD is raised in
					-- R_STATUS register. Note that no error flag is raised in case
					-- several actions are asked for in the same W_CTRL write, instead
					-- priorities described above simply are applied
					-- (TODO: multicycle constraints are possible on a few paths below)
					if r.axi.wdatax(CTRL_WRITE_NB) = '1' then
						-- ----------------------------------------------------------
						--         start of a new large number WRITE sequence
						-- ----------------------------------------------------------
						-- (s186)
						-- sample address from W_CTRL register content
						-- (width of the address field is given by FP_ADDR_MSB, see ecc_pkg)
						if debug then
							-- (s76), see (s77)
							v.fpaddr0 := r.axi.wdatax(
								CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
								& std_logic_vector(to_unsigned(0, log2(n - 1)));
						else
							-- if not in debug mode, the only large numbers writable by
							-- software are the first eight ones: p, a, b, q, and the four
							-- affine coordinates [XY]R[01] of points R0 & R1
							v.fpaddr0 := std_logic_vector(to_unsigned(0, FP_ADDR_MSB - 3))
								& r.axi.wdatax(CTRL_NBADDR_LSB + 2 downto CTRL_NBADDR_LSB)
								& std_logic_vector(to_unsigned(0, log2(n - 1)));
						end if;
						-- by default the large number to write is not 'a', but see bypass
						-- (s121) below
						v.ctrl.newa := '0'; -- (s120)
						-- (s177)
						-- set some flags according to the address of the large nb software
						-- says he's about to modify, so that ecc_axi knows what curve
						-- parameters have been written and which have not been
						--   - when SW starts a large nb write sequence by writing its
						--     address in the W_CTRL register (point where we are now)
						--     the corresponding flag is deasserted
						--   - once the transfer of the large nb is over, only then is the
						--     flag asserted, see (s178)
						-- TODO: multicycle constraints are possible here on a few paths:
						--         r.axi.wdatax(addr) -> r.ctrl.[pabqxy]_set
						--         r.axi.wdatax(addr) -> r.ctrl.a_set_and_mty
						v_axi_wdatax_msb := r.axi.wdatax(
								CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB);
						if v_axi_wdatax_msb = CST_ADDR_P then
							v.ctrl.p_set := '0'; -- see (s112)
							v.ctrl.p_set_and_mty := '0'; -- (s179), see (s110)
							-- writing a new value of 'p' immediately invalidates
							-- the current value of curve parameter 'a'
							v.ctrl.a_set := '0';
							v.ctrl.a_set_and_mty := '0';
						elsif v_axi_wdatax_msb = CST_ADDR_A then
							v.ctrl.a_set := '0'; -- (s181), see (s113)
							v.ctrl.a_set_and_mty := '0'; -- (s182), see (s111)
							v.ctrl.newa := '1'; -- (s121), bypass of (s120)
						elsif v_axi_wdatax_msb = CST_ADDR_B then
							v.ctrl.b_set := '0';
						elsif v_axi_wdatax_msb = CST_ADDR_Q then
							v.ctrl.q_set := '0';
						elsif v_axi_wdatax_msb = CST_ADDR_XR1 then
							v.ctrl.x_set := '0';
							v.ctrl.r1_is_null := '0';
						elsif v_axi_wdatax_msb = CST_ADDR_YR1 then
							v.ctrl.y_set := '0';
							v.ctrl.r1_is_null := '0';
						elsif (v_axi_wdatax_msb = CST_ADDR_XR0) or
							(v_axi_wdatax_msb = CST_ADDR_YR0)
						then
							v.ctrl.r0_is_null := '0';
						end if;
						if not debug then -- statically resolved by synthesizer
							v.ctrl.read_forbidden := '1';
						end if;
						if r.axi.wdatax(
								CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
							= CST_ADDR_P
						then
							-- --------------------------------------
							-- user wants to write the prime number p
							-- --------------------------------------
							-- assert r.ctrl.newp so that we can trigger the computation
							-- (by ecc_scalar) of the 2 new Montgomery constants associated
							-- with the new value of p as soon as (see (s11) below) the
							-- whole large number value of p has been written through AXI-
							-- fabric.
							-- r.ctrl.newp will be deasserted either by (s8) (when ecc_scalar
							-- acknowledges the order to recompute the Montgomery constants)
							-- or by (s10) (when the next large number write sequence is
							-- programmed for a number other than p)
							v.ctrl.newp := '1';
							-- assert r.ctrl.pen (directly drives output 'pen', see (s9))
							-- so that the Montgomery mult. components are aware they should
							-- sample the 'w' x 'ww'-bit words of p at the same time they
							-- are being written into ecc_fp_dram
							v.ctrl.penupsh(1) := '1'; -- (s184), see (s185)
							-- writing p means all current curve parameters become obsolete
							v.ctrl.p_set := '0'; -- see (s112)
							v.ctrl.p_set_and_mty := '0'; -- (s180), see (s110)
							v.ctrl.a_set_and_mty := '0'; -- (s183), see (s111)
						else
							v.ctrl.newp := '0'; -- (s10)
						end if; -- prime p
						if r.axi.wdatax(
							CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
								= CST_ADDR_K
							and r.axi.wdatax(CTRL_WRITE_K) = '1'
						then
							-- --------------------------------
							-- user wants to write the scalar k
							-- --------------------------------
							v.ctrl.k_set := '0';
							v.ctrl.k_is_being_set := '1'; -- (s122), see (s123)
							if r.write.rnd.enough_random = '1' then
								v.ctrl.wk := '1';
								v.ctrl.k_is_null := '1';
								-- (s72) init of wecnt, used only when blinding is active,
								-- see (s73)
								if nn_dynamic then
									v.write.rnd.wecnt := nndyn_wm2_s;
								else
									v.write.rnd.wecnt := to_unsigned(w - 2, log2(w - 1));
								end if;
								if r.ctrl.doblinding = '1' then
									v.write.rnd.dowecnt := '1';
								end if;
								v.write.rnd.trailingzeros := '0'; -- (s215), see (s214) & (s216)
								--v.write.rnd.shiftdone := '0'; -- (s217), see (s218)-(s220)
								v.write.rnd.firstwwmask := '1';
								-- a note on statements (s210)-(s213) below: the value computed
								-- in .bitstotal register is actually not a count but the value
								-- of initialization of a (de)counter; indeed later on this
								-- register will be decounted downto 0 included, hence the
								-- actual total count is given by the init value of .bitstotal
								-- plus one
								if r.ctrl.doblinding = '1' then
									-- blinding is active
									-- in this case the masking of the scalar is arithmetic
									-- ("+ m") and we need a qty of random bits equal to the
									-- size of scalar plus the size of the blinding scalar,
									-- plus 1
									if nn_dynamic then -- statically resolved by synthesizer
										v.write.rnd.bitstotal :=
											  resize(r.nndyn.valnn, log2(nn) + 1)
											+ resize(r.ctrl.blindbits, log2(nn) + 1); -- (s210)
									else
										v.write.rnd.bitstotal := to_unsigned(nn, log2(nn) + 1)
											+ resize(r.ctrl.blindbits, log2(nn) + 1); -- (s211)
									end if;
									-- use the address of arithmetic masking
									v.write.rnd.maskaddr(FP_ADDR - 1 downto log2(n - 1)) :=
										std_logic_vector(to_unsigned(
											CST_ARITH_MASK_0, FP_ADDR_MSB));
									v.write.rnd.maskaddr(log2(n - 1) - 1 downto 0) :=
										(others => '0');
								elsif r.ctrl.doblinding = '0' then
									-- blinding is deactivated
									-- in this case the masking of the scalar is linear ("xor m")
									-- and we need a qty of random bits equal to the size of
									-- scalar
									if nn_dynamic then -- statically resolved by synthesizer
										v.write.rnd.bitstotal :=
											resize(r.nndyn.valnnm1, log2(nn)+1); -- (s212)
									else
										v.write.rnd.bitstotal :=
											to_unsigned(nn - 1, log2(nn) + 1); -- (s213)
									end if;
									-- use the address of logic (xor) masking
									v.write.rnd.maskaddr(FP_ADDR - 1 downto log2(n - 1)) :=
										std_logic_vector(
											to_unsigned(CST_LOGIC_MASK_0, FP_ADDR_MSB));
									v.write.rnd.maskaddr(log2(n - 1) - 1 downto 0) :=
										(others => '0');
								end if;
								v.write.rnd.bitsirn := to_unsigned(ww - 1, log2(ww - 1));
								v.write.rnd.bitsww := to_unsigned(ww - 1, log2(ww - 1));
								v.write.rnd.carry := 0;
							else -- not enough random
								v_writebn_accepted := FALSE; -- (s55) see (s56)
							end if;
						else
							v.ctrl.wk := '0';
						end if; -- scalar k
						v.write.active := '1'; -- (s116), will be reset by (s117)
						-- initialize some counters
						v.write.bitsww := to_unsigned(ww - 1, log2(ww - 1));
						v.write.bitsaxi := to_unsigned(C_S_AXI_DATA_WIDTH - 1, axiw);
						if nn_dynamic then
							v.write.bitstotal := r.nndyn.valnnm1;
						else
							v.write.bitstotal := to_unsigned(nn - 1, log2(nn));
						end if;
						v.write.trailingzeros := "00";
						if v_writebn_accepted then -- (s56) see (s54) & (s55)
							-- thx to (s55) above, if there is not enough random to mask the
							-- scalar, attempting to write it will fail (subsequent writes
							-- of data words to the WRITE_DATA register will simply be
							-- discarded due to r.ctrl.state not being switched to 'writeln'
							-- (see (s57))
							v.ctrl.state := writeln;
						end if;
					elsif r.axi.wdatax(CTRL_READ_NB) = '1' then
						-- ----------------------------------------------------------
						--        start of a new large number READ sequence
						-- ----------------------------------------------------------
						-- (s187)
						-- sample address from W_CTRL register content
						--   (actually sample only the LSB of the address field,
						--   as the external interface is only allowed to read
						--   XR1 and YR1 locations from ecc_fp_dram)
						if (not debug) and r.ctrl.read_forbidden = '1' then
							v.ctrl.ierrid(STATUS_ERR_RDNB_FBD) := '1';
						else
							v.ctrl.ierrid(STATUS_ERR_RDNB_FBD) := '0';
							if debug then -- statically resolved by synthesizer
								-- (s78), see (s77)
								v.fpaddr0 := r.axi.wdatax(
									CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
									& std_logic_vector(to_unsigned(0, log2(n - 1)));
							else
								-- not debug
								if r.axi.wdatax(CTRL_NBADDR_LSB) = '0' then
									-- read is targeting XR1
									v.fpaddr0 := CST_ADDR_XR1
										& std_logic_vector(to_unsigned(0, log2(n - 1)));
								elsif r.axi.wdatax(CTRL_NBADDR_LSB) = '1' then
									-- read is targeting YR1
									v.fpaddr0 := CST_ADDR_YR1
										& std_logic_vector(to_unsigned(0, log2(n - 1)));
								end if;
							end if;
							v.read.fpre0 := '1';
							v.read.rdataxcanbefilled := '1';
							v.read.shdatawwcanbeemptied := '0';
							v.read.bitsww := to_unsigned(ww - 1, log2(ww - 1));
							v.read.bitsaxi := to_unsigned(C_S_AXI_DATA_WIDTH - 1, axiw);
							v.read.active := '1'; -- (s118), will be reset by (s119)
							v.read.busy := '1'; -- (s138), will be deasserted by (s139)
							if nn_dynamic then -- statically resolved by synthesizer
								v.read.bitstotal := r.nndyn.valnnm1;
							else
								v.read.bitstotal := to_unsigned(nn - 1, log2(nn));
							end if;
							v.ctrl.state := readln;
							-- deassertion of r.axi.rvalid by (s192) means: no valid read
							-- data available from the IP yet on AXI read-data channel
							v.axi.rvalid := '0'; -- (s192)
						end if;
					elsif r.axi.wdatax(CTRL_KP) = '1' then
						-- ----------------------------------------------------------
						--              start of a new [k]P computation
						-- ----------------------------------------------------------
						-- (s188)
						if v_kp_possible then -- (s115)
							v.ctrl.agokp := '1'; -- (s174)
							v.ctrl.lockaxi := '1'; -- (s68), will be deasserted by (s69)
							v.ctrl.ierrid(STATUS_ERR_KP_FBD) := '0'; -- (s175)
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_KP_FBD) := '1'; -- (s176)
						end if;
					-- ----------------------------------------------------------
					--               other point-based operations
					-- ----------------------------------------------------------
					-- (s189)
					elsif r.axi.wdatax(CTRL_PT_ADD) = '1' then
						-- SW is asking for a point addition
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_ADD;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					elsif r.axi.wdatax(CTRL_PT_DBL) = '1' then
						-- SW is asking for a point doubling
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_DBL;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					elsif r.axi.wdatax(CTRL_PT_CHK) = '1' then
						-- SW is asking to check if a point is on curve
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_CHK;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					elsif r.axi.wdatax(CTRL_PT_NEG) = '1' then
						-- SW wants to compute the opposite of a given point
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_NEG;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					elsif r.axi.wdatax(CTRL_PT_EQU) = '1' then
						-- SW wants to compute the opposite of a given point
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_EQU;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					elsif r.axi.wdatax(CTRL_PT_OPP) = '1' then
						-- SW wants to compute the opposite of a given point
						if v_pop_possible then
							v.ctrl.dopop := '1';
							v.ctrl.popid := ECC_AXI_POINT_OPP;
							v.ctrl.lockaxi := '1'; -- (s89), will be deasserted by (s90)
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '0';
						else
							-- SW settings are not enough to perform a point-computation
							v.ctrl.ierrid(STATUS_ERR_POP_FBD) := '1';
						end if;
					-- ----------------------------------------------------------
					--                 field arithmetic operations
					--            (finally we only left REDC operation)
					-- ----------------------------------------------------------
					-- (s190)
					elsif r.axi.wdatax(CTRL_FP_MUL) = '1' then
						-- SW is asking for an Fp MUL
						v.ctrl.doaop := '1';
						v.ctrl.aopid := ECC_AXI_FP_MUL;
						v.ctrl.lockaxi := '1'; -- (s91), will be deasserted by (s92)
					end if; -- decoding content of W_CTRL register
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0'; -- clr possible past error
				else
					-- raise error flag (illicite register write)
					-- (s191)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if; -- v_wlock or debug
			-- -------------------------------------------------------
			-- decoding write of W_WRITE_DATA register
			-- -------------------------------------------------------
			elsif (debug and r.axi.waddr = W_WRITE_DATA)
				or ((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_WRITE_DATA(ADB - 2 downto 0))
			then
				v.axi.awready := '1'; -- (s3)
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1'; -- (s4)
				if r.ctrl.state = writeln then -- (s57)
					v.write.new32 := '1';
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
					-- AWREADY is asserted again (we can accept a new address again)
					-- but NOT WREADY: we CANNOT accept that a new data be pushed to us.
					-- Assertion of WREADY (which is currently low thx to (s0) see above)
					-- will happen later, either when all the 32 (or 64) bits of
					-- r.axi.wdatax are shifted into r.write.shdataww (see (s2) below)
					-- or when the total of nn bits of the large number being written
					-- have actually been transferred into ecc_fp_dram memory (see (s172))
					v.write.busy := '1'; -- (s134), will be deasserted by (s135)
				else -- r.ctrl.state /= writeln
					-- we are not currently in the process of writing large number data
					-- into ecc_fp_dram (no write into W_CTRL register was previously
					-- made to set that) therefore this write into W_WRITE_DATA register
					-- makes no sense: we simply ignore it, by responding OKAY (already
					-- done from (s4)) & reasserting s_axi_wready, which is currently
					-- low from (s0)
					v.axi.wready := '1';
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			-- ------------------------------------------------------
			-- decoding write of W_R0_NULL register
			-- ------------------------------------------------------
			elsif (debug and r.axi.waddr = W_R0_NULL) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_R0_NULL(ADB - 2 downto 0))
			then
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (163), see (s161)
					v.ctrl.r0_is_null := r.axi.wdatax(WR0_IS_NULL);
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			-- ------------------------------------------------------
			-- decoding write of W_R1_NULL register
			-- ------------------------------------------------------
			elsif (debug and r.axi.waddr = W_R1_NULL) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_R1_NULL(ADB - 2 downto 0))
			then
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (s164), see (s161)
					v.ctrl.r1_is_null := r.axi.wdatax(WR1_IS_NULL);
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			-- -------------------------------------------------------------
			-- decoding write of W_PRIME_SIZE register (s41)
			-- -------------------------------------------------------------
			elsif (debug and r.axi.waddr = W_PRIME_SIZE) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_PRIME_SIZE(ADB - 2 downto 0))
			then
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if nn_dynamic then -- statically resolved by synthesizer
					if (not v_busy) or debug then -- not v_wlock, otherwise deadlock
						v.nndyn.valnntest := unsigned (
							r.axi.wdatax(log2(nn) - 1 downto 0) ); -- (s31) see (s35)
						-- note: from value of nn latched in r.nndyn.valnn by (s31),
						-- value of nn - 1 will be latched into r.nndyn.valnnm1 after
						-- 2 cycles by (s34) as well as value of nn + 2 will be
						-- latched into r.nndyn.valnnp2 by (s36) and that of nn + 4
						-- will be latched into r.nndyn.valnnp4 by (s47)
						v.ctrl.state := newnn;
						v.nndyn.active := '1';
						v.nndyn.testnn := '1'; -- asserted only 1 cycle, see (s169)
						-- clear possible past error
						v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
					else
						-- raise error flag (illicite register write)
						v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
					end if;
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			-- -----------------------------------------------------
			-- decoding write of W_BLINDING register
			-- -----------------------------------------------------
			elsif (debug and r.axi.waddr = W_BLINDING) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_BLINDING(ADB - 2 downto 0))
			then
				-- (s125) For the W_BLINDING register, a test on the number of
				-- blinding bits set by software must occur before we release
				-- the bus so the assertion of the 4 AXI signals {a*wready, arreday
				-- & bvalid} is delayed to (s126) (this of course only concerns
				-- the case where software sets BLD_EN bit to 1)
				if (not v_wlock) or debug then -- (s165), see (s161)
					if r.axi.wdatax(BLD_EN) = '1' then
						-- test that size set is not null, otherwise it should not
						-- set blinding on
						if r.axi.wdatax(BLD_BITS_MSB downto BLD_BITS_LSB) /= -- (s170)
							std_logic_vector(to_unsigned(0, BLD_BITS_MSB - BLD_BITS_LSB + 1))
						then
							v.ctrl.blindbits := -- (s129), see (s130)
								unsigned(r.axi.wdatax(BLD_BITS_MSB downto BLD_BITS_LSB));
							v.ctrl.doblindcheck := '1'; -- (s128), will trigger (s127)
						else
							--v.ctrl.doblinding := '0'; -- useless (already deasserted)
							-- (s206) the four statements below on AXI ready/valid signals
							-- are deferred to (s207), which is when computations required
							-- on r.ctrl.blindbits are completed
							--v.axi.wready := '1';
							--v.axi.awready := '1';
							--v.axi.arready := '1';
							--v.axi.bvalid := '1';
						end if;
					elsif r.axi.wdatax(BLD_EN) = '0' then
						v.ctrl.doblinding := '0';
						v.axi.wready := '1';
						v.axi.awready := '1';
						v.axi.arready := '1';
						v.axi.bvalid := '1';
					end if;
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
					v.axi.wready := '1';
					v.axi.awready := '1';
					v.axi.arready := '1';
					v.axi.bvalid := '1';
				end if;
			-- ------------------------------------------------
			-- decoding write of W_IRQ register
			-- ------------------------------------------------
			elsif (debug and r.axi.waddr = W_IRQ) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_IRQ(ADB - 2 downto 0))
			then
				-- TODO: set multicycle constraint on path:
				--    r.axi.wdatax -> r.ctrl.irqen
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (s167), see (s161)
					v.ctrl.irqen := r.axi.wdatax(IRQ_EN);
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			-- ------------------------------------------------
			-- decoding write to W_ERR_ACK register
			-- ------------------------------------------------
			-- writing W_ERR_ACK register is always allowed
			elsif (debug and r.axi.waddr = W_ERR_ACK) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_ERR_ACK(ADB - 2 downto 0))
			then
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				v.ctrl.ierrid := r.ctrl.ierrid and not (r.axi.wdatax(31 downto 16));
				-- .aerr_inpt_ack & .aerr_outpt_ack, if asserted, stay asserted only
				-- 1 cycle
				v.ctrl.aerr_inpt_ack := r.axi.wdatax(STATUS_ERR_IN_PT_NOT_ON_CURVE);
				v.ctrl.aerr_outpt_ack := r.axi.wdatax(STATUS_ERR_OUT_PT_NOT_ON_CURVE);
			-- ------------------------------------------------
			-- decoding write to W_SMALL_SCALAR register
			-- ------------------------------------------------
			elsif (debug and r.axi.waddr = W_SMALL_SCALAR) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_SMALL_SCALAR(ADB - 2 downto 0))
			then
				-- (s157), we assert AWREADY but NOT WREADY yet, postponed to (s158)
				-- because we first need to sanity check the value set by software
				-- (unless the access was forbidden, in which case we assert WREADY
				-- immediately, see (s159))
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (s168), see (s161)
					--v.axi.ksz_test := unsigned(r.axi.datax(log2(nn) - 1 downto 0));
					v.ctrl.do_ksz_test := '1';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
					v.axi.wready := '1'; -- (s159), see (s157)
				end if;
			-- ------------------------------------------------
			-- decoding write to W_SOFT_RESET register
			-- ------------------------------------------------
			elsif (debug and r.axi.waddr = W_SOFT_RESET) or
				((not debug) and r.axi.waddr(ADB - 2 downto 0) =
					W_SOFT_RESET(ADB - 2 downto 0)) 
			then
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				-- (s198), we don't assert back WREADY yet, this will be done later
				-- by (s197) when swrst output has been asserted a sufficient number
				-- of clock cycles so as to have its high pulse be seen by every
				-- sub-component of the IP
				v.ctrl.swrst := '1';
				v.ctrl.swrst_cnt := (others => '1');
			-- ------------------------------
			-- below are DEBUG only registers
			-- ------------------------------
			-- (note that until now, the 'debug' boolean constant was only used
			-- for proper address decoding - now in the following registers,
			-- 'debug=TRUE' is used as a required condition for the hardware
			-- inference of each of them, meaning these registers only exist
			-- in debug mode)
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_HALT register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_HALT then
				if r.axi.wdatax(DBG_HALT) = '1'  then
					v.debug.halt := '1'; -- stays asserted only 1 cycle thx to (s154)
				end if;
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_BKPT register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_BKPT then
				vbk := to_integer(
					unsigned(r.axi.wdatax(DBG_BKPT_ID_MSB downto DBG_BKPT_ID_LSB)));
				v.debug.breakpoints(vbk).addr := -- (s156) see (s155)
					r.axi.wdatax(DBG_BKPT_ADDR_MSB downto DBG_BKPT_ADDR_LSB);
				v.debug.breakpoints(vbk).act := r.axi.wdatax(DBG_BKPT_EN);
				v.debug.breakpoints(vbk).state :=
					r.axi.wdatax(DBG_BKPT_STATE_MSB downto DBG_BKPT_STATE_LSB);
				v.debug.breakpoints(vbk).nbbits := std_logic_vector(
					resize(unsigned(r.axi.wdatax(
						DBG_BKPT_NBBIT_MSB downto DBG_BKPT_NBBIT_LSB)), 16));
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- --------------------------------------------------------
			-- decoding write of W_DBG_STEPS register
			-- --------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_STEPS then
				if r.axi.wdatax(DBG_RESUME) = '1' then
					v.debug.resume := '1'; -- stays asserted 1 cycle thx to (s173)
				elsif r.axi.wdatax(DBG_OPCODE_RUN) = '1' then
					v.debug.dosomeopcodes := '1'; -- stays asserted 1 cycle thx to (s33)
					v.debug.nbopcodes := r.axi.wdatax(
						DBG_OPCODE_NB_MSB downto DBG_OPCODE_NB_LSB);
				end if;
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- ----------------------------------------------------------------
			-- decoding write of W_DBG_TRIG_ACT register
			-- ----------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_TRIG_ACT then
				v.debug.trigactive := r.axi.wdatax(0);
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- ----------------------------------------------------------
			-- decoding write of W_DBG_TRIG_UP register
			-- ----------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_TRIG_UP then
				v.debug.trigup := r.axi.wdatax(31 downto 0);
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- ------------------------------------------------------------
			-- decoding write of W_DBG_TRIG_DOWN register
			-- ------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_TRIG_DOWN then
				v.debug.trigdown := r.axi.wdatax(31 downto 0);
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- --------------------------------------------------------------
			-- decoding write of W_DBG_OP_ADDR register
			-- --------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_OP_ADDR then
				v.debug.iaddr := r.axi.wdatax(IRAM_ADDR_SZ - 1 downto 0);
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- ---------------------------------------------------------------
			-- decoding write of W_DBG_WR_OPCODE register
			-- ---------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_WR_OPCODE then
				if OPCODE_SZ > C_S_AXI_DATA_WIDTH then -- statically resolved by synth.
					if r.debug.idatabeat = '0' then
						v.debug.idatabeat := '1';
						v.debug.iwdata(
							C_S_AXI_DATA_WIDTH - 1 downto 0) := r.axi.wdatax;
					elsif r.debug.idatabeat = '1' then
						v.debug.idatabeat := '0';
						v.debug.iwdata( -- (s84), see (s83)
							C_S_AXI_DATA_WIDTH + (OPCODE_SZ mod C_S_AXI_DATA_WIDTH) - 1
								downto C_S_AXI_DATA_WIDTH)
							:= r.axi.wdatax((OPCODE_SZ mod C_S_AXI_DATA_WIDTH) - 1 downto 0);
						v.debug.iwe := '1'; -- stays asserted only 1 cycle thx to (s82)
					end if;
				else
					v.debug.iwdata := r.axi.wdatax(OPCODE_SZ - 1 downto 0);
					v.debug.iwe := '1'; -- stays asserted only 1 cycle thx to (s82)
				end if;
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
			-- ------------------------------------------------------------
			-- decoding write of W_DBG_TRNGCTR register
			-- ------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_TRNGCTR then
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
				if r.axi.wdatax(DBG_TRNG_RAW_READ) = '1' then
					-- ----------------------------------------------------------
					--            start of a new TRNG READ sequence
					--                   (for raw random bit)
					-- ----------------------------------------------------------
					-- sample address from register content
					--   (actually sample only the meaningful part of the address,
					--   that is the least significant bits which are in number
					--   log2(raw_ram_size-1))
					if r.ctrl.state = idle then
						v.debug.trng.raw.raddr :=
							r.axi.wdatax(DBG_TRNG_RAW_ADDR_MSB downto DBG_TRNG_RAW_ADDR_LSB);
						v.ctrl.state := readraw;
						-- deassertion r.axi.rvalid by (s26) (drives output s_axi_rvalid)
						-- means no valid read data are available from us yet on AXI read
						-- data channel
						v.axi.rvalid := '0'; -- (s26) - will be asserted by (s27)
						v.read.trngreading := '1';
					end if;
				elsif r.axi.wdatax(DBG_TRNG_RAW_RESET) = '1' then
					-- ----------------------------------------------------------
					--       debug software is asking for a TRNG raw reset
					-- ----------------------------------------------------------
					v.debug.trng.rawreset := '1'; -- stays asserted 1 cycle thx to (s58)
				elsif r.axi.wdatax(DBG_TRNG_IRN_RESET) = '1' then
					-- ----------------------------------------------------------
					--       debug software is asking for a TRNG irn reset
					-- ----------------------------------------------------------
					v.debug.trng.irnreset := '1'; -- stays asserted 1 cycle thx to (s59)
				end if;
				-- activation/deactivation of TRNG post-processing
				v.debug.trng.ppdeact := r.axi.wdatax(8);
			-- --------------------------------------------------------------
			-- decoding write of W_DBG_TRNGCFG register
			-- --------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_TRNGCFG then
				v.debug.trng.vonneuman := r.axi.wdatax(DBG_TRNG_VONM);
				v.debug.trng.completebypass := r.axi.wdatax(DBG_TRNG_COMPLETE_BYPASS);
				v.debug.trng.completebypassbit := r.axi.wdatax(
					DBG_TRNG_COMPLETE_BYPASS_BIT);
				v.debug.trng.ta :=
					unsigned(r.axi.wdatax(DBG_TRNG_TA_MSB downto DBG_TRNG_TA_LSB));
				v.debug.trng.idletime :=
					unsigned(r.axi.wdatax(DBG_TRNG_IDLE_MSB downto DBG_TRNG_IDLE_LSB));
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_FP_WADDR register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_FP_WADDR then
				v.fpaddr0 := r.axi.wdatax(FP_ADDR - 1 downto 0);
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_FP_WDATA register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_FP_WDATA then
				v.write.fpwe0 := '1'; -- stays asserted only 1 cycle thx to (s24)
				v.debug.fpwdata := r.axi.wdatax(ww - 1 downto 0); -- (s145), see (s144)
				v.debug.shwon(1) := '1';
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_FP_RADDR register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_FP_RADDR then
				v.fpaddr0 := r.axi.wdatax(FP_ADDR - 1 downto 0);
				v.read.fpre0 := '1'; -- stays asserted only 1 cycle thx to (s49)
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- deassert ready bit in R_DBG_FP_RDATA_RDY register
				v.debug.readrdy := '0';
				-- arm latency counter (shift-reg)
				v.debug.readsh(readlat) := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_CFG_NOXYSHUF register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_CFG_NOXYSHUF then
				v.debug.noxyshuf := r.axi.wdatax(XYSHF_DIS);
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_CFG_NOAXIMSK register
			-- -------------------------------------------------------------
			elsif debug and r.axi.waddr = W_DBG_CFG_NOAXIMSK then -- (s202) see (s203)
				v.debug.noaxirnd := r.axi.wdatax(AXIMSK_DIS);
				-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
				-- to happen again
				v.axi.awready := '1';
				v.axi.wready := '1';
				v.axi.arready := '1';
				-- drive write-response to initiator
				v.axi.bvalid := '1';
			-- -------------------------------------------------------------
			-- decoding write of W_DBG_CFG_NOMEMSHUF register
			-- -------------------------------------------------------------
			elsif debug and shuffle and -- statically resolved by synthesizer
				 (r.axi.waddr = W_DBG_CFG_NOMEMSHUF) -- (s221)
			then
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				if (not v_wlock) or debug then -- (s166), see (s161)
					v.ctrl.doshuffle := not r.axi.wdatax(MEMSHF_DIS);
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '0';
				else
					-- raise error flag (illicite register write)
					v.ctrl.ierrid(STATUS_ERR_WREG_FBD) := '1';
				end if;
			else
				-- unknown target address
				-- (simply ignore & acknowledge everything)
				v.axi.wready := '1';
				v.axi.awready := '1';
				v.axi.arready := '1';
				v.axi.bvalid := '1';
				-- raise error flag (illicite register access)
				v.ctrl.ierrid(STATUS_ERR_UNKNOWN_REG) := '1';
			end if;
		end if; -- awpending = dwpending = 1 (one data beat)

		-- detection of writing one new limb of a large number to be transferred
		-- into ecc_fp_dram
		-- (one large number among: p, a, b, q, [XY]R[01], k0, k1 when in production
		-- mode (= not debug), anyone of the 32 large numbers in ecc_fp_dram
		-- otherwise)
		if r.write.new32 = '1' then
			v.write.doshift := '1';
		end if;

		-- --------------------------------
		-- on-the-fly masking of the scalar  (part 1 on 2)  producing random masks
		-- --------------------------------

		-- a random mask is made available as soon as r.write.rnd.kmaskfull = 1,
		-- see (s65) below (which hence acts as a strobe signal for the random
		-- word r.write.rnd.irn) and .kmaskfull will stay high until it is
		-- deasserted back by (s66), at the time the process of writing both
		-- the value to be masked and the mask itself is complete.
		-- Restoring .kmaskfull to 0 will have the shifting of IRN data into
		-- r.write.rnd.irn to be resumed thx to (s67)
		
		-- handshake with ecc_trng
		if r.write.rnd.trngrdy = '1' and trngvalid = '1' then
			v.write.rnd.trngrdy := '0';
			v.write.rnd.irn := trngdata;
			v.write.rnd.irnempty := '0';
			v.write.rnd.bitsirn := to_unsigned(ww - 1, log2(ww - 1));
		end if;

		-- (s203), bypass by debug feature, see (s202) register W_DBG_CFG_NOAXIMSK
		if r.debug.noaxirnd = '1' then
			v.write.rnd.irn := (others => '0');
		end if;

		-- continuously gather random bits for both linear and arithmetic masking
		-- of the scalar
		if r.ctrl.wk = '1' then
			-- assert doshift signal whenever source shift-reg is not empty and
			-- destination shift-reg is not full
			if r.write.rnd.irnempty = '0' and r.write.rnd.kmaskfull = '0' -- (s67)
				--and r.write.rnd.shiftdone = '0' -- (s218), see (s217)
			then
				v.write.rnd.doshift := '1';
			end if;
			if r.write.rnd.doshift = '1' then
				if r.write.rnd.trailingzeros = '0' then
					-- shift-empty .irn
					v.write.rnd.irn(ww - 2 downto 0) := r.write.rnd.irn(ww - 1 downto 1);
					-- shift-fill .kmask
					if r.ctrl.doblinding = '1' and
						r.write.rnd.bitstotal = (r.write.rnd.bitstotal'range => '0')
					then
						-- when the blinding is activated, the last random bit (of the
						-- phase defined by .trailingzeros = 0) must be removed and
						-- replaced with a 0 (to avoid overflow when the mask will be
						-- arithmetically added to the scalar)
						v.write.rnd.kmask :=
							'0' & r.write.rnd.kmask(ww - 1 downto 1);
					elsif r.ctrl.doblinding = '0' or
						r.write.rnd.bitstotal /= (r.write.rnd.bitstotal'range => '0')
					then
						v.write.rnd.kmask :=
							r.write.rnd.irn(0) & r.write.rnd.kmask(ww - 1 downto 1);
					end if;
				elsif r.write.rnd.trailingzeros = '1' then
					-- only shift .kmask in this case and with a 0 not a random
					v.write.rnd.kmask := '0' & r.write.rnd.kmask(ww - 1 downto 1);
				end if;
				-- decrement counters
				v.write.rnd.bitsirn := r.write.rnd.bitsirn - 1;
				v.write.rnd.bitsww := r.write.rnd.bitsww - 1;
				if r.write.rnd.trailingzeros = '0' then
					v.write.rnd.bitstotal := r.write.rnd.bitstotal - 1;
				end if;
				-- detect and handle completion of an ww-bit shifts cycle
				if r.write.rnd.bitsirn = (r.write.rnd.bitsirn'range => '0') then
					v.write.rnd.doshift := '0';
					v.write.rnd.irnempty := '1';
					-- request another ww random word from ecc_trng
					v.write.rnd.trngrdy := '1';
				end if;
				-- detect and handle completion of an 'ww'-bit shifts cycle
				if r.write.rnd.bitsww = (r.write.rnd.bitsww'range => '0') then
					v.write.rnd.doshift := '0';
					v.write.rnd.kmaskfull := '1'; -- (s65) used as an available-mask flag
				end if;
				-- detect and handle completion of the total
				if r.write.rnd.bitstotal = (r.write.rnd.bitstotal'range => '0') then
					v.write.rnd.trailingzeros := '1'; -- (s214), will be reset by (s215)
					if r.write.rnd.trailingzeros = '1' then
						v.write.rnd.doshift := '0';
						--v.write.rnd.shiftdone := '1'; -- (s219), will be reset by (s217)
					end if;
				end if;
			end if;
		end if;

		-- --------------
		-- shift-register during write of large numbers (from AXI to ecc_fp_dram)
		-- --------------
		v.ctrl.pendownsh := '0' & r.ctrl.pendownsh(3 downto 1);
		if r.write.doshift = '1' then
			-- emptying r.axi.wdatax
			v.axi.wdatax := '0' & r.axi.wdatax(C_S_AXI_DATA_WIDTH - 1 downto 1);
			-- filling r.write.shdataww (from r.axi.wdatax)
			if r.write.trailingzeros(0) = '1' or r.write.trailingzeros(1) = '1' then
				v.write.shdataww := '0' & r.write.shdataww(ww - 1 downto 1);
			else
				-- (s22)
				v.write.shdataww := r.axi.wdatax(0) & r.write.shdataww(ww-1 downto 1);
			end if;
			-- detecting if the current LSbit is non-null
			if r.ctrl.wk = '1' then
				if r.axi.wdatax(0) = '1' then
					v.ctrl.k_is_null := '0';
				end if;
			end if;
			-- decrement counters
			v.write.bitsww := r.write.bitsww - 1;
			v.write.bitstotal := r.write.bitstotal - 1;
			if r.write.trailingzeros = "00" then
			--if r.write.trailingzeros = '0' then
			--if r.write.trailingzeros(0) = '0' and r.write.trailingzeros(1) = '0' then
				v.write.bitsaxi := r.write.bitsaxi - 1;
			end if;
			-- detect and handle completion of a 'ww'-bit shifts cycle
			if r.write.bitsww(log2(ww - 1) - 1) = '0'
			  and v.write.bitsww(log2(ww - 1) - 1) = '1'
			then
				v.write.bitsww := to_unsigned(ww - 1, log2(ww - 1));
				if r.ctrl.wk = '0' then
					v.write.fpwe0 := '1';
				elsif r.ctrl.wk = '1' then
					v.write.rnd.avail4mask := '1'; -- stays asserted 1 cycle only
				end if;
			end if;
			-- -----------------------------------------------------------------
			-- detect and handle completion of a cycle amounting to the bitwidth
			-- of one AXI data transfer (32 or 64 bits)
			-- -----------------------------------------------------------------
			if r.write.bitsaxi(axiw - 1) = '0' and v.write.bitsaxi(axiw - 1) = '1'
			then
				-- we authorize the reception of a new 32-bit data again from AXI bus
				-- (note that AWREADY has already been reasserted when handling the
				-- 32-bit write-data beat from the AXI fabric, see (s3) above)
				v.axi.wready := '1'; -- (s2)
				-- stop shifting r.axi.wdatax into r.write.shdataww
				v.write.doshift := '0';
				-- write-response has already been presented to initiator upon
				-- reception of the 32 (or 64) bit data word on the AXI interface
				-- (see (s4) above)
				v.write.bitsaxi := to_unsigned(C_S_AXI_DATA_WIDTH - 1, axiw);
				-- (s135) is deassertion of (s134), and will be possibly bypassed
				-- by (s136), (s137)
				v.write.busy := '0'; -- (s135)
			end if;
			-- -------------------------------------------------------------------
			-- detect and handle completion of a cycle amounting to the total data
			-- size of one large number
			-- -------------------------------------------------------------------
			if r.write.bitstotal(log2(nn) - 1) = '0' and
			   v.write.bitstotal(log2(nn) - 1) = '1'
			then
				-- all nn bits of the large number have been read from AXI interface
				-- & shifted into r.write.shdataww. However we still need to push
				-- a certain number of zeros (depending on the value of nn) to account
				-- for the fact that nn is not necessarily a multiple of ww bit,
				-- and also that we must guarantee that all large numbers in ecc_fp_dram
				-- have their 4 most-significant bits to 0:
				--   2 of these are for the Montgomery reduction technique, which
				--                      is based on a field numbers' representation
				--                      in which they can span the [0...2p[ interval
				--                      (not simply [0;p[ as for ordinary modulo-p
				--                      arithmetic)
				--   1 of these is because we need to form the number R = 2**(nn + 2)
				--   1 of these is for sign (two's complement representation)
				if r.write.trailingzeros(1) = '1' or
					(r.write.trailingzeros(0) = '1'
					  and (r.ctrl.doblinding = '0' or r.ctrl.wk = '0'))
				--if r.write.trailingzeros = '1' then
				then
					v.ctrl.state := idle;
					v.write.doshift := '0';
					-- in this case deassertion of r.write.busy by (s135) above was
					-- legitimate (we don't assert it with a bypass), we keep the
					-- statement below in comment for the sake of readability
					-- v.write.busy := '0';
					if r.ctrl.pen = '1' then
						-- so that Montgomery multipliers stop sampling words of
						-- large number 'p'
						v.ctrl.pendownsh(3) := '1';
					end if;
					if r.ctrl.newp = '1' and r.ctrl.mtypending = '0' then -- (s11)
						v.ctrl.agocstmty := '1'; -- reset by (s1) after ecc_scalar's ACK
						v.write.busy := '0';
					end if;
					-- (s178), see (s177)
					v_fpaddr0_msb :=
						r.fpaddr0(log2(n - 1) + FP_ADDR_MSB - 1 downto log2(n - 1));
					if v_fpaddr0_msb = CST_ADDR_P then
						v.ctrl.p_set := '1'; -- (s112)
					elsif v_fpaddr0_msb = CST_ADDR_A then
						v.ctrl.a_set := '1'; -- (s113), see (s181)
						-- since Montgomery constants have been computed & are available,
						-- transmission of parameter 'a' triggers the execution of the
						-- (tiny) routine that will switch it into its Montgomery repre-
						-- sentation
						if r.ctrl.p_set_and_mty = '1' -- and r.ctrl.p_set = '1' -- useless
						then
							-- r.ctrl.agomtya will be reset by (s105) after ecc_scalar's ACK
							v.ctrl.agomtya := '1'; -- (s103)
							v.ctrl.newa := '0';
							v.write.busy := '0';
						-- else
						-- 	-- r.ctrl.a_set_and_mty still 0
						end if;
					elsif v_fpaddr0_msb = CST_ADDR_B then
						v.ctrl.b_set := '1';
					elsif v_fpaddr0_msb = CST_ADDR_Q then
						v.ctrl.q_set := '1';
					--elsif v_fpaddr0_msb = CST_ADDR_K then
					--	v.ctrl.k_set := '1'; -- error, see (s123) below
					elsif v_fpaddr0_msb = CST_ADDR_XR1 then
						v.ctrl.x_set := '1';
					elsif v_fpaddr0_msb = CST_ADDR_YR1 then
						v.ctrl.y_set := '1';
					end if;
					-- (s123) we can't use r.fpaddr0 to detect that scalar k is the large
					-- nb currently written (because in that case r.fpaddr0 might as well
					-- contain the address of the mask for k), so we use a special flag
					-- (r.ctrl.k_is_being_set) that was asserted by (s122)
					if r.ctrl.k_is_being_set = '1' then
						v.ctrl.k_set := '1';
						v.ctrl.k_is_being_set := '0';
					end if;
					-- authorize the reception of a new 32-bit data again from AXI
					-- fabric (note that AWREADY has already been reasserted when
					-- sampling the 32-bit word from the AXI interface, see (s3) above)
					v.axi.wready := '1'; -- (s172) bypassed by (s48) & (s193) below
					v.write.trailingzeros := "00";
					v.write.active := '0'; -- (s117), reset of (s116)
					v.write.busy := '0';
				elsif r.write.trailingzeros(0) = '1' and
					r.ctrl.doblinding = '1' and r.ctrl.wk = '1'
				--elsif r.write.trailingzeros = '0'
				then
					--v.write.trailingzeros := '1';
					v.write.trailingzeros := "10";
					-- we need to determine the nb of extra 0 bits following the most
					-- significant bits of the large nb that software is currently
					-- pushing to us
					--v.write.bitstotal := resize(r.ctrl.blindbits - 1, log2(nn));
					v.write.bitstotal := resize(r.ctrl.nn_extrabits, log2(nn));
					v.axi.wready := '0'; -- (s48)
					v.write.doshift := '1';
					-- in this case deassertion of r.write.busy by (s135) must not occur
					v.write.busy := '1'; -- (s136), bypass of (s135)
				elsif r.write.trailingzeros = "00" then
					-- set r.write.trailingzeros (there are always trailing zeros to add)
					v.write.trailingzeros := "01";
					-- (s43), see (s42) for computation of r.nndyn.nbtrailzeros signal
					-- TODO: set a multicycle of 16 on path:
					--     r.nndyn.nbtrailzeros -> r.write.bitstotal
					-- The idea here is to reuse register .bitstotal in order to shift
					-- the required number of trailing zeros into .shdataww. Next time
					-- we hit down 0 for .bitstotal, we'll know the job is over for
					-- the whole large number as .trailingzeros this time will be high
					-- (note that there are always trailing zeros to account for
					-- since the large number transmitted by user-software is nn-bit
					-- long while the large numbers in ecc_fp_dram are (nn+4)-bit long
					-- Note: in case of blinding the trick is now using an extra bit
					-- for register r.write.trailingzeros, to allow enough extra 0 bits
					-- to span the entirety of the scalar once blinded.
					if r.ctrl.wk = '1' and r.ctrl.doblinding = '1' then
						-- it is the scalar that software driver is currently pushing to us
						-- and blinding is currently activated
						-- using .blindbits to set next value of .bitstotal (instead of
						-- .blindbits - 1) will ensure that we actually add .blindbits
						-- null bits after the large number (as counting from .blindbits
						-- downto 0 represents a number of .blindbits + 1 write beats)
						-- note on (s208), line below: r.ctrl.blindbits cannot be equal
						-- to 0 nor to 1 (this is from (s209)) so the result is at least 1
						v.write.bitstotal := resize(r.ctrl.blindbits - 1, -- (s208)
							log2(nn));
					elsif r.ctrl.wk = '0' or r.ctrl.doblinding = '0' then
						-- it is either a large number other than the scalar the the
						-- software is currently pushing to us OR it is the scalar indeed
						-- BUT blinding is not currently activated (and in this case the
						-- scalar can be treated as any other large number regarding the
						-- nb of extra bits to add)
						if nn_dynamic then -- statically resolved by synthesizer
							v.write.bitstotal := resize(r.nndyn.nbtrailzeros, log2(nn));
						else -- the 4 tests below will be statically resolved by synthesizer
							if (nn mod ww) = 0 then
								v.write.bitstotal := to_unsigned(ww - 1, log2(nn));
							elsif (nn mod ww) < ww - 4 then
								v.write.bitstotal := to_unsigned(ww - (nn mod ww) - 1, log2(nn));
							elsif (nn mod ww) = ww - 4 then
								v.write.bitstotal := to_unsigned(3, log2(nn));
							else -- means nn mod ww > ww - 4 strictly (ww-3, ww-2 or ww-1)
								v.write.bitstotal := to_unsigned(2*ww-(nn mod ww)-1, log2(nn));
							end if;
						end if;
					end if;
					v.axi.wready := '0'; -- (s193)
					v.write.doshift := '1';
					-- in this case deassertion of r.write.busy by (s135) must not occur
					v.write.busy := '1'; -- (s137), bypass of (s135)
				end if;
			end if; -- bitstotal = 0
			-- a few neccessary bypasses - in case we are writing the scalar
			-- and a new ww-bit limb has just been formed from it
			if v.write.rnd.avail4mask = '1' then -- note v (comb. signal, not reg.)
				v.write.rnd.doshiftbk := v.write.doshift; -- (s52) note v for r-value
				v.write.doshift := '0';
				v.write.rnd.wreadybk := v.axi.wready; -- (s53) note v for r-value
				v.axi.wready := '0';
				-- in this case deassertion of r.write.busy by (s135) above was
				-- legitimate (we don't assert it with a bypass), we keep the
				-- statement below in comment for the sake of readability
				-- v.write.busy := '0';
			end if;
		end if; -- doshift = 1

		-- --------------------------------
		-- on-the-fly masking of the scalar  (part 2 on 2)  actual masking + write
		-- --------------------------------

		if r.write.rnd.avail4mask = '1' then
			v.write.rnd.wait4rnd := '1';
			v.write.rnd.kmasked := r.write.shdataww;
		end if;

		-- small shift register to control the short 2-cycles sequence
		-- to write the masked scalar and the masking value in a row
		if r.write.rnd.write_mask_sh(0) = '1' or r.write.rnd.write_mask_sh(1) = '1'
		then
			v.write.rnd.write_mask_sh := r.write.rnd.write_mask_sh(0) & '0';
		end if;

		-- we'll stay in state .wait4rnd = 1 until a random ww-bit word
		-- becomes available (that is .kmaskfull = 1)
		if r.write.rnd.wait4rnd = '1' and r.write.rnd.kmaskfull = '1' and
			r.write.rnd.write_mask_sh = "00" -- (s62)
		then
			if r.ctrl.doblinding = '1' then
				-- arithmetic masking
				v_write_rnd_kmasked :=
					  resize(unsigned(r.write.rnd.kmasked), ww + 1)
					+ resize(unsigned(r.write.rnd.kmask), ww + 1);
				v_write_rnd_kmasked := v_write_rnd_kmasked
					+ r.write.rnd.carry;
				-- v_write_rnd_kmasked merely serves as a combinational intermediate
				-- here, the point being to latch registers .kmasked and .carry
				v.write.rnd.kmasked :=
					std_logic_vector(v_write_rnd_kmasked(ww - 1 downto 0));
				if v_write_rnd_kmasked(ww) = '0' then
					v.write.rnd.carry := 0;
				elsif v_write_rnd_kmasked(ww) = '1' then
					v.write.rnd.carry := 1;
				end if;
			elsif r.ctrl.doblinding = '0' then
				-- linear masking (xor)
				v.write.rnd.kmasked := r.write.rnd.kmasked xor r.write.rnd.kmask;
			end if;
			-- (s63) is to inhibit condition test (s62)
			v.write.rnd.write_mask_sh(0) := '1'; -- (s63)
			v.write.fpwe0 := '1';
			if r.write.rnd.firstwwmask = '1' then
				v.write.rnd.firstwwmask := '0';
				v.write.rnd.masklsb := r.write.rnd.kmask(0);
			end if;
		end if;

		-- increment of the address in ecc_fp_dram where data are written to
		-- each time one is actually written
		if r.write.fpwe0 = '1' then
			v.fpaddr0 := std_logic_vector(unsigned(r.fpaddr0) + 1); -- (s60)
		end if;

		if r.write.rnd.write_mask_sh(0) = '1' then
			-- post the masked-scalar write in ecc_fp_dram by asserting .fpwe0
			v.write.fpwe0 := '1';
			v.fpaddr0 := r.write.rnd.maskaddr;
			v.write.rnd.fpaddr_bkup := -- (s61) bypass of (s60) don't switch order
				std_logic_vector(unsigned(r.fpaddr0) + 1);
		end if;

		if r.write.rnd.write_mask_sh(1) = '1' then
			v.fpaddr0 := -- (s64) bypass of (s60) don't switch order
				r.write.rnd.fpaddr_bkup;
			v.write.rnd.maskaddr :=
				std_logic_vector(unsigned(r.write.rnd.maskaddr) + 1);
			v.write.rnd.wait4rnd := '0';
			v.write.rnd.kmaskfull := '0'; -- (s66), see (s65)
			-- restore both registers r.write.doshift & r.axi.wready,
			-- see (s52) and (s53)
			v.write.doshift := r.write.rnd.doshiftbk;
			v.axi.wready := r.write.rnd.wreadybk;
			v.write.rnd.bitsww := to_unsigned(ww - 1, log2(ww - 1));
			if r.write.rnd.dowecnt = '1' then
				v.write.rnd.wecnt := r.write.rnd.wecnt - 1;
				if r.write.rnd.wecnt = (r.write.rnd.wecnt'range => '0') then
					v.write.rnd.dowecnt := '0';
					v.write.rnd.realign := '1';
				end if;
			end if;
		end if;

		-- if blinding is active (see (s73)) we must intercept the w + 1 address
		-- increment & re-align it on n - see (s72)
		if r.ctrl.wk = '1' and r.ctrl.doblinding = '1'
			and r.write.rnd.realign = '1'
		then
			if r.write.rnd.write_mask_sh(0) = '1' then
				-- increment base (upper) part of .fpaddr_bkup
				v.write.rnd.fpaddr_bkup(FP_ADDR - 1 downto log2(w - 1)) :=
					std_logic_vector(unsigned(
						r.write.rnd.fpaddr_bkup(FP_ADDR - 1 downto log2(w - 1))) + 1);
				-- and realign its lower part
				v.write.rnd.fpaddr_bkup(log2(w - 1) - 1 downto 0) := (others => '0');
			elsif r.write.rnd.write_mask_sh(1) = '1' then
				v.write.rnd.realign := '0';
				-- increment base (upper) part of .maskaddr
				v.write.rnd.maskaddr(FP_ADDR - 1 downto log2(w - 1)) :=
					std_logic_vector(unsigned(
						r.write.rnd.maskaddr(FP_ADDR - 1 downto log2(w - 1))) + 1);
				-- and realign its lower part
				v.write.rnd.maskaddr(log2(w - 1) - 1 downto 0) := (others => '0');
			end if;
		end if;

		-- (s185), see (s184)
		if r.ctrl.penupsh(0) = '1' then
			v.ctrl.pen := '1';
		end if;
		if r.ctrl.pendownsh(0) = '1' then
			v.ctrl.pen := '0';
		end if;

		-- interrupt, once raised, lasts 4 cycles
		v.ctrl.irqsh := '0' & r.ctrl.irqsh(3 downto 1);
		if r.ctrl.irqsh(0) = '1' then
			v.ctrl.irq := '0';
		end if;

		-- irq generation upon rising edge of mtydone
		v.ctrl.mtydone_d := mtydone;
		if mtydone = '1' and r.ctrl.mtydone_d = '0' then
			v.ctrl.mtypending := '0'; -- (s107) bypassed by (s108)
			-- back from executing routine to compute Montgomery constants,
			-- we test if curve parameter 'a' has already been set by software,
			-- and if so we make ecc_scalar execute routine .aMontyL to switch
			-- 'a' in Montgomery domain
			if r.ctrl.a_set = '1' then
				v.ctrl.agomtya := '1'; -- (s104), will be reset by (s105)
				v.ctrl.mtyirq_postponed := '1'; -- (s106)
				-- we keep .mtypending asserted to maintain (s30) coherent
				v.ctrl.mtypending := '1'; -- (s108), bypass of (s107), see also (s109)
			else
				-- execution of routine .aMontyL was not part of .constMTYL routine
				-- post-processing (means SW has first written 'p', and then 'a')
				-- so we generate the IRQ now
				v.ctrl.irqsh(3) := '1';
				if r.ctrl.irqen = '1' then
					v.ctrl.irq := '1';
				end if;
			end if;
			v.ctrl.p_set_and_mty := '1'; -- (s110), see (s179) & (s180)
		end if;

		-- {deassertion of r.ctrl.agocstmty}/{assertion of r.ctrl.mtypending}
		-- once ecc_scalar has acknowledged 'agocstmty' request
		if r.ctrl.agocstmty = '1' and ardy = '1' then
			v.ctrl.agocstmty := '0'; -- (s1)
			v.ctrl.mtypending := '1';
			v.ctrl.newp := '0'; -- (s8)
		end if;

		-- deassertion of r.ctrl.amtypending once ecc_scalar has asserted amtydone
		-- (no IRQ generated here)
		v.ctrl.amtydone_d := amtydone;
		if amtydone = '1' and r.ctrl.amtydone_d = '0' then
			v.ctrl.amtypending := '0';
			-- (s109) we must also reset .mtypending in case it was kept asserted
			-- by (s108) (because execution of routine .aMontyL was part of the
			-- postprocessing of routine .constMTYL)
			v.ctrl.mtypending := '0';
			-- amtydone rising edge means routine .aMontyL was just executed,
			-- which means curve parameter 'a' is now in Montgomery representation
			-- so we set r.ctrl.a_set_and_mty
			v.ctrl.a_set_and_mty := '1'; -- (s111), see (s182) & (s183)
		end if;

		-- {deassertion of r.ctrl.agomtya}/{assertion of r.ctrl.amtypending}
		-- once ecc_scalar has acknowledged 'agomtya' request
		if r.ctrl.agomtya = '1' and ardy = '1' then
			v.ctrl.agomtya := '0'; -- (s105), see (s103) & (s104)
			v.ctrl.amtypending := '1';
			v.ctrl.newa := '0';
			-- if routine .aMontyL has been executed as part of a .constMTYL
			-- routine post-processing, then (s106) has asserted .mtyirq_postponed
			-- to tell us to generate possible IRQ afterwards
			if r.ctrl.mtyirq_postponed = '1' then
				v.ctrl.mtyirq_postponed := '0';
				v.ctrl.irqsh(3) := '1';
				if r.ctrl.irqen = '1' then
					v.ctrl.irq := '1';
				end if;
			end if;
		end if;

		-- irq generation upon rising edge of kpdone
		v.ctrl.kpdone_d := kpdone;
		if kpdone = '1' and r.ctrl.kpdone_d = '0' then
			v.ctrl.kppending := '0';
			v.ctrl.irqsh(3) := '1';
			if r.ctrl.irqen = '1' then
				v.ctrl.irq := '1';
			end if;
			-- r.ctrl.[kxy]_set are considered stale at the end of a [k]P computation
			v.ctrl.k_set := '0'; -- see (s114) & (s115)
			v.ctrl.x_set := '0';
			v.ctrl.y_set := '0';
			-- authorize SW to read the result
			v.ctrl.read_forbidden := '0';
		end if;

		-- -------------------------
		-- start of [k]P computation (handshake with ecc_scalar)
		-- -------------------------
		-- {deassertion of r.ctrl.agokp}/{assertion of r.ctrl.kppending}
		-- once ecc_scalar has acknowledged 'agokp' request
		if r.ctrl.agokp = '1' and ardy = '1' then
			v.ctrl.agokp := '0';
			v.ctrl.kppending := '1';
			v.ctrl.lockaxi := '0'; -- (s69) deassertion of (s68)
			if debug then -- statically resolved by synthesizer
				v.debug.trigger := '0';
				v.debug.counter := (others => '0');
			end if;
		end if;

		if debug then -- statically resolved by synthesizer
			if (r.ctrl.kppending = '1' or r.ctrl.poppending = '1' or
				r.ctrl.aoppending = '1') and dbghalted = '0'
			then
				v.debug.counter := r.debug.counter + 1;
			end if;
		end if;

		-- detect possible trigger counter matches
		if debug then -- statically resolved by synthesizer
			if r.debug.counter = unsigned(r.debug.trigdown) then
				v.debug.trigger := '0';
			end if;
			if r.debug.counter = unsigned(r.debug.trigup) then
				v.debug.trigger := '1';
			end if;
			if r.debug.trigactive = '0' then
				v.debug.trigger := '0';
			end if;
		end if;

		-- irq generation upon rising edge of popdone
		v.ctrl.popdone_d := popdone;
		if popdone = '1' and r.ctrl.popdone_d = '0' then
			v.ctrl.poppending := '0';
			v.ctrl.irqsh(3) := '1';
			if r.ctrl.irqen = '1' then
				v.ctrl.irq := '1';
			end if;
			-- authorize SW to read the result
			v.ctrl.read_forbidden := '0';
		end if;
		
		-- ------------------------------------
		-- start of one point-based computation (handshake with ecc_scalar)
		-- ------------------------------------
		-- {deassertion of r.ctrl.dopop}/{assertion of r.ctrl.poppending}
		-- once ecc_scalar has acknowledged 'dopop' request
		if r.ctrl.dopop = '1' and ardy = '1' then
			v.ctrl.dopop := '0';
			v.ctrl.poppending := '1';
			v.ctrl.lockaxi := '0'; -- (s90) deassertion of (s89)
			if debug then -- statically resolved by synthesizer
				v.debug.trigger := '0';
				v.debug.counter := (others => '0');
			end if;
		end if;

		-- irq generation upon rising edge of aopdone
		v.ctrl.aopdone_d := aopdone;
		if aopdone = '1' and r.ctrl.aopdone_d = '0' then
			v.ctrl.aoppending := '0';
			v.ctrl.irqsh(3) := '1';
			if r.ctrl.irqen = '1' then
				v.ctrl.irq := '1';
			end if;
			-- authorize SW to read the result
			v.ctrl.read_forbidden := '0';
		end if;

		-- ---------------------------------
		-- start of one Fp-based computation (handshake with ecc_scalar)
		-- ---------------------------------
		-- {deassertion of r.ctrl.doaop}/{assertion of r.ctrl.aoppending}
		-- once ecc_scalar has acknowledged 'doaop' request
		if r.ctrl.doaop = '1' and ardy = '1' then
			v.ctrl.doaop := '0';
			v.ctrl.aoppending := '1';
			v.ctrl.lockaxi := '0'; -- (s92) deassertion of (s91)
			if debug then -- statically resolved by synthesizer
				v.debug.trigger := '0';
				v.debug.counter := (others => '0');
			end if;
		end if;

		-- ----------------------------------------------------------
		--                     A X I   R e a d s
		-- ----------------------------------------------------------

		-- handshake over AXI address-read channel
		if s_axi_arvalid = '1' and r.axi.arready = '1' then
			-- by immediately deasserting r.axi.arready (which directly drives
			-- s_axi_arready) in (s143) below, we're telling AXI fabric that
			-- we're not ready to accept a new read address again, not until...
			--   - [in the case of a read targeting the DATA register] ...we have
			--     a 32-bit data available that has been gathered from different
			--     reads & shifts from ecc_fp_dram
			--   - [in the case of a read targeting any of the registers that
			--     does not require further processing and for which read payload
			--     can be directly driven back to initiator, like R_STATUS] ...the
			--     AXI fabric actually reads the content of the register on the
			--     data-read channel - that's the reason why we immediately assert
			--     r.axi.rvalid in this case (which directly drives s_axi_rvalid) -
			--     see all cases tagged (s5) down below.
			-- In both cases, s_axi_arready will be reasserted upon actual transfer
			-- of the 32-bit data on the AXI read-data channel, see (s6) below
			v.axi.arready := '0'; -- (s143)
			-- ----------------------------------
			-- decoding read of R_STATUS register
			-- ----------------------------------
			if (debug and s_axi_araddr(ADB + 2 downto 3) = R_STATUS)
				or ((not debug) and s_axi_araddr(ADB + 1 downto 3) =
					R_STATUS(ADB - 2 downto 0))
			then
				dw := (others => '0');
				if v_busy then -- (s160), see (s30)
					dw(STATUS_BUSY) := '1';
				else
					dw(STATUS_BUSY) := '0';
				end if;
				dw(STATUS_KP) := r.ctrl.kppending;
				dw(STATUS_MTY) :=
				     r.ctrl.mtypending or r.ctrl.agocstmty -- or r.ctrl.newp;
				  or r.ctrl.amtypending or r.ctrl.agomtya;
				dw(STATUS_POP) := r.ctrl.poppending;
				dw(STATUS_AOP) := r.ctrl.aoppending;
				dw(STATUS_R_OR_W) := r.write.busy or r.read.busy;
				dw(STATUS_INIT) := not initdone;
				dw(STATUS_ENOUGH_RND) := not r.write.rnd.enough_random;
				if nn_dynamic then -- statically resolved by synthesizer
					dw(STATUS_NNDYNACT) := r.nndyn.active;
				else
					dw(STATUS_NNDYNACT) := '0';
				end if;
				dw(STATUS_YES) := r.ctrl.yes; -- (s98), was set by (s96)
				dw(STATUS_R0_IS_NULL) := r.ctrl.r0_is_null;
				dw(STATUS_R1_IS_NULL) := r.ctrl.r1_is_null;
				dw(STATUS_ERR_MSB downto STATUS_ERR_LSB) := r.ctrl.ierrid;
				dw(STATUS_ERR_IN_PT_NOT_ON_CURVE) := aerr_inpt_not_on_curve;
				dw(STATUS_ERR_OUT_PT_NOT_ON_CURVE) := aerr_outpt_not_on_curve;
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------
			-- decoding read of R_READ_DATA register
			-- -------------------------------------
			elsif (debug and s_axi_araddr(ADB + 2 downto 3) = R_READ_DATA)
				or ((not debug) and s_axi_araddr(ADB + 1 downto 3) =
					R_READ_DATA(ADB - 2 downto 0))
			then
				-- actually there is nothing to do here: s_axi_rvalid will be asserted
				-- (along with data on the AXI read-data channel) once available data
				-- is collected from ecc_fp_dram.
				-- We just assert r.read.arpending so that the handshake logic for data
				-- read channel (see (s7) below) is now aware that the current read
				-- access is targeting the DATA register (and therefore can trigger
				-- a new 'ww'-bit word read from ecc_fp_dram as soon as the read has
				-- actually taken place on the data-read channel)
				-- r.read.arpending is used as a flag to differenciate AXI read acces-
				-- ses targeting the DATA register (r.read.arpending = 1) from AXI read
				-- accesses targeting other registers
				if r.ctrl.state = readln then
					v.read.arpending := '1';
				else
					v.axi.rvalid := '1'; -- (s5)
					v.axi.rdatax := (others => '1'); -- 0xFFF...FF
				end if;
			-- ----------------------------------------
			-- decoding read of R_CAPABILITIES register
			-- ----------------------------------------
			elsif (debug and s_axi_araddr(ADB + 2 downto 3) = R_CAPABILITIES)
				or ((not debug) and s_axi_araddr(ADB + 1 downto 3) =
					R_CAPABILITIES(ADB - 2 downto 0))
			then
				dw := (others => '0');
				-- debug versus prod
				if debug then -- statically resolved by synthesizer
					dw(CAP_DBG_N_PROD) := '1';
				else
					dw(CAP_DBG_N_PROD) := '0';
				end if;
				-- is shuffle implemented
				if shuffle then -- statically resolved by synthesizer
					dw(CAP_SHF) := '1';
				else
					dw(CAP_SHF) := '0';
				end if;
				-- is AXI interface 32 or 64 bit
				if C_S_AXI_DATA_WIDTH = 64 then
					dw(CAP_W64) := '1';
				elsif C_S_AXI_DATA_WIDTH = 32 then
					dw(CAP_W64) := '0';
				end if;
				-- is prime size modifiable
				if nn_dynamic then -- statically resolved by synthesizer
					dw(CAP_NNDYN) := '1';
				else
					dw(CAP_NNDYN) := '0';
				end if;
				-- maximal (or static) value of prime size
				dw(CAP_NNMAX_MSB downto CAP_NNMAX_LSB) := std_logic_vector(
					to_unsigned(nn, log2(nn))); -- (s171)
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- --------------------------------------
			-- decoding read of R_PRIME_SIZE register
			-- --------------------------------------
			elsif (debug and s_axi_araddr(ADB + 2 downto 3) = R_PRIME_SIZE)
				or ((not debug) and s_axi_araddr(ADB + 1 downto 3) =
					R_PRIME_SIZE(ADB - 2 downto 0))
			then
				dw --(PMSZ_VALNN_MSB downto PMSZ_VALNN_LSB)
					:= std_logic_vector(
					resize(r.nndyn.valnn, C_S_AXI_DATA_WIDTH));
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- --------------------------------------
			-- decoding read of R_HW_VERSION register
			-- --------------------------------------
			elsif (debug and s_axi_araddr(ADB + 2 downto 3) = R_HW_VERSION)
				or ((not debug) and s_axi_araddr(ADB + 1 downto 3) =
					R_HW_VERSION(ADB - 2 downto 0))
			then
				-- version number, we use the first 32 bits of git commit checksum
				dw := (others => '0');
				dw(31 downto 0) := x"0001" & x"0001"; -- version 1.1
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- ------------------------------
			-- below are DEBUG only registers
			-- ------------------------------
			-- (note that until now, the 'debug' boolean constant was only used
			-- for proper address decoding - now in the following registers,
			-- 'debug=TRUE' is used as a required condition for the hardware
			-- inference of each of them, meaning these registers only exist
			-- in debug mode - when not in debug mode, synthesizer will trim
			-- them off)
			-- -------------------------------------
			-- decoding read of R_DBG_CAPABILITIES_0
			-- -------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_CAPABILITIES_0
			then
				dw := (others => '0');
				dw(log2(ww) - 1 downto 0) :=
					std_logic_vector(to_unsigned(ww, log2(ww)));
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------
			-- decoding read of R_DBG_CAPABILITIES_1
			-- -------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_CAPABILITIES_1
			then
				dw := (others => '0');
				dw(log2(nbopcodes) - 1 downto 0) := -- (s147), see (s146)
					std_logic_vector(to_unsigned(nbopcodes, log2(nbopcodes)));
				dw(16 + log2(OPCODE_SZ) - 1 downto 16) := -- (s149), see (s148)
					std_logic_vector(to_unsigned(OPCODE_SZ, log2(OPCODE_SZ)));
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------
			-- decoding read of R_DBG_CAPABILITIES_2
			-- -------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_CAPABILITIES_2
			then
				dw := (others => '0');
				dw(log2(raw_ram_size) - 1 downto 0) := -- (s151), see (s150)
					std_logic_vector(to_unsigned(raw_ram_size, log2(raw_ram_size)));
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- --------------------------------------
			-- decoding read of R_DBG_STATUS register
			-- --------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_STATUS
			then
				dw := (others => '0');
				-- (s153), see (s152)
				-- TODO: add 1-bit bkptid valid
				dw(DBG_STATUS_HALTED) := dbghalted; -- 1 bit
				dw(DBG_STATUS_BKID_MSB downto DBG_STATUS_BKID_LSB) := -- 2 bits
					dbgbreakpointid;
				dw(DBG_STATUS_BK_HIT) := dbgbreakpointhit; -- 1bit
				dw(DBG_STATUS_PC_MSB downto DBG_STATUS_PC_LSB) := -- (s88), see (s87)
					std_logic_vector(resize(unsigned(dbgdecodepc),
					DBG_STATUS_PC_MSB - DBG_STATUS_PC_LSB + 1)); -- 12 bits
				dw(DBG_STATUS_NBIT_MSB downto DBG_STATUS_NBIT_LSB) := -- 12 bits
					dbgnbbits(DBG_STATUS_NBIT_MSB - DBG_STATUS_NBIT_LSB downto 0);
				dw(DBG_STATUS_STATE_MSB downto DBG_STATUS_STATE_LSB) := -- 4 bits
					dbgpgmstate;
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- ------------------------------------
			-- decoding read of R_DBG_TIME register
			-- ------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_TIME
			then
				v.axi.rdatax(31 downto 0) := std_logic_vector(r.debug.counter);
				v.axi.rvalid := '1'; -- (s5)
			-- ---------------------------------------
			-- decoding read of R_DBG_RAW_DUR register
			-- ---------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_RAWDUR
			then
				v.axi.rdatax(31 downto 0) := std_logic_vector(dbgtrngrawduration);
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------
			-- decoding read of R_DBG_FLAGS register
			-- -------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_FLAGS
			then
				dw := (others => '0');
				dw(FLAGS_P_NOT_SET) := not r.ctrl.p_set;
				dw(FLAGS_P_NOT_SET_MTY) := not r.ctrl.p_set_and_mty;
				dw(FLAGS_A_NOT_SET) := not r.ctrl.a_set;
				dw(FLAGS_A_NOT_SET_MTY) := not r.ctrl.a_set_and_mty;
				dw(FLAGS_B_NOT_SET) := not r.ctrl.b_set;
				dw(FLAGS_K_NOT_SET) := not r.ctrl.k_set;
				if nn_dynamic then
					dw(FLAGS_NNDYN_NOERR) := r.nndyn.valwerr;
				else
					dw(FLAGS_NNDYN_NOERR) := '0';
				end if;
				if r.ctrl.doblinding = '1' then
					dw(FLAGS_NOT_BLN_OR_Q_NOT_SET) := not r.ctrl.q_set;
				elsif r.ctrl.doblinding = '0' then
					dw(FLAGS_NOT_BLN_OR_Q_NOT_SET) := '0';
				end if;
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_TRNG_STATUS register
			-- -------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_TRNG_STATUS
			then
				v.axi.rdatax :=
				  std_logic_vector(
					  to_unsigned(0, C_S_AXI_DATA_WIDTH - 8 - log2(raw_ram_size - 1)))
				  & dbgtrngrawwaddr
				  & "0000"
				  & "000" & dbgtrngrawfull;
				v.axi.rvalid := '1'; -- (s5)
			-- -----------------------------------------
			-- decoding read of R_DBG_TRNG_DATA register
			-- -----------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_TRNG_DATA
			then
				if r.ctrl.state = readraw then
					--v.debug.trng.raw.arpending := '1';
					v.axi.rvalid := '1'; -- (s27) see (s26)
					v.axi.rdatax(C_S_AXI_DATA_WIDTH - 1 downto 1) := (others => '0');
					v.axi.rdatax(0) := dbgtrngrawdata;
					-- reading one raw bit requires only 1 AXI read access so we can
					-- get back to idle state
					v.ctrl.state := idle;
				else
					v.axi.rvalid := '1'; -- (s5)
					v.axi.rdatax := (others => '1'); -- 0xFFF...FF
				end if;
			-- ----------------------------------------
			-- decoding read of R_DBG_FP_RDATA register
			-- ----------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_FP_RDATA
			then
				v.axi.rdatax :=
					(C_S_AXI_DATA_WIDTH-1 downto ww => '0') & xrdata; -- (s50), see (s51)
				v.debug.readrdy := '0';
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_IRN_CNT_AXI register
			-- -------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_IRN_CNT_AXI
			then
				v.axi.rdatax(31 downto 0) :=
					std_logic_vector(resize(unsigned(trngaxiirncount), 32));
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_IRN_CNT_EFP register
			-- -------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_IRN_CNT_EFP
			then
				v.axi.rdatax(31 downto 0) :=
					std_logic_vector(resize(unsigned(trngefpirncount), 32));
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_IRN_CNT_CUR register
			-- -------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_IRN_CNT_CUR
			then
				v.axi.rdatax(31 downto 0) :=
					std_logic_vector(resize(unsigned(trngcurirncount), 32));
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_IRN_CNT_SHF register
			-- -------------------------------------------
			elsif debug and shuffle -- both statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_IRN_CNT_SHF
			then
				v.axi.rdatax(31 downto 0) :=
					std_logic_vector(resize(unsigned(trngshfirncount), 32));
				v.axi.rvalid := '1'; -- (s5)
			-- --------------------------------------------
			-- decoding read of R_DBG_FP_RDATA_RDY register
			-- --------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_FP_RDATA_RDY
			then
				--v.axi.rdatax(0) := r.debug.readrdy;
				--v.axi.rdatax(31 downto 1) := (others => '0');
				v.axi.rdatax(31 downto 0) :=
					(DBG_FP_RDATA_IS_RDY => r.debug.readrdy, others => '0');
				v.axi.rvalid := '1'; -- (s5)
			-- -----------------------------------------
			-- decoding read of R_DBG_EXP_FLAGS register
			-- -----------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_EXP_FLAGS
			then
				dw := (others => '0');
				dw(0) := r0z;
				dw(1) := r1z;
				dw(2) := kap;
				dw(3) := kapp;
				dw(4) := zu;
				dw(5) := zc;
				dw(6) := laststep;
				dw(7) := firstzdbl;
				dw(8) := firstzaddu;
				dw(9) := first2pz;
				dw(10) := first3pz;
				dw(11) := torsion2;
				dw(12) := pts_are_equal;
				dw(13) := pts_are_oppos;
				dw(14) := phimsb;
				dw(15) := kb0end;
				dw(31 downto 16) := std_logic_vector(resize(unsigned(dbgjoyebit), 16));
				v.axi.rdatax := dw;
				v.axi.rvalid := '1'; -- (s5)
			-- -------------------------------------------
			-- decoding read of R_DBG_DIAGNOSTICS register
			-- -------------------------------------------
			elsif debug -- statically resolved by synthesizer
			  and s_axi_araddr(ADB + 2 downto 3) = R_DBG_DIAGNOSTICS
			then
				dw(31 downto 0) :=
					std_logic_vector(resize(unsigned(dbgnbstarvrndxyshuf), 32));
				v.axi.rdatax(31 downto 0) := dw(31 downto 0);
				v.axi.rvalid := '1'; -- (s5)
			-- --------------------------------------------
			-- unknown target address, drive back dumb data (all 1's)
			-- --------------------------------------------
			else
				v.axi.rdatax := (others => '1'); -- 0xFFFFFFFF
				v.axi.rvalid := '1'; -- (s5)
				-- raise error flag (illicite register access)
				v.ctrl.ierrid(STATUS_ERR_UNKNOWN_REG) := '1';
			end if;
		end if;

		-- handshake over AXI data-read channel
		if r.axi.rvalid = '1' and s_axi_rready = '1' then
			v.axi.rvalid := '0';
			-- tell AXI fabric that our AXI address-read channel is ready
			-- to accept a new address again
			v.axi.arready := '1'; -- (s6)
			if r.read.arpending = '1' then -- (s7)
				v.read.arpending := '0';
				if r.read.lastwordx = '1' then
					v.ctrl.state := idle;
					v.read.lastwordx := '0';
					v.read.active := '0'; -- (s119), reset of (s118)
				end if;
			end if;
			-- pragma translate_off
			v.axi.rdatax := (others => 'X');
			-- pragma translate_on
		end if;

		--                      --------------------
		--                          state-machine
		--                      for read accesses to
		--                          large numbers
		--                      --------------------

		-- sample of data read back from ecc_fp_dram into r.read.shdataww
		-- & assertion of r.read.shdatawwcanbeemptied
		v.read.resh := r.read.fpre & r.read.resh(readlat downto 1);
		if r.read.resh(0) = '1' then
			v.read.shdataww := xrdata;
			v.read.shdatawwcanbeemptied := '1';
		end if;

		-- --------------
		-- shift-register during read of large numbers (from ecc_fp_dram to AXI)
		-- --------------
		if r.read.shdatawwcanbeemptied = '1' -- (s19)
			and r.read.rdataxcanbefilled = '1'
		then
			-- emptying r.read.shdataww
			v.read.shdataww := '0' & r.read.shdataww(ww - 1 downto 1);
			-- filling r.read.rdatax
			if r.read.lastwordx = '0' then -- (s17)
				v.read.rdatax :=
					r.read.shdataww(0) & r.read.rdatax(C_S_AXI_DATA_WIDTH - 1 downto 1);
			elsif r.read.lastwordx = '1' then
				v.read.rdatax := '0' & r.read.rdatax(C_S_AXI_DATA_WIDTH - 1 downto 1);
			end if;
			-- decrement counters
			v.read.bitsww := r.read.bitsww - 1;
			v.read.bitsaxi := r.read.bitsaxi - 1;
			v.read.bitstotal := r.read.bitstotal - 1;
			-- detect and handle completion of a 'ww'-bit shifts cycle
			if r.read.bitsww(log2(ww - 1) - 1) = '0'
			  and v.read.bitsww(log2(ww - 1) - 1) = '1' then
				if r.read.lastwordx = '0' then
					v.read.shdatawwcanbeemptied := '0'; -- (s15) bypassed by (s16)
					v.read.fpre0 := '1'; -- (s12) bypassed by (s13) & (s14)
				end if;
				v.read.bitsww := to_unsigned(ww - 1, log2(ww - 1));
			end if;
			-- detect and handle completion of a cycle amounting to the width of
			-- an AXI data transfer
			if r.read.bitsaxi(axiw - 1) = '0' and v.read.bitsaxi(axiw - 1) = '1'
			then
				v.read.bitsaxi := to_unsigned(C_S_AXI_DATA_WIDTH - 1, axiw);
				v.read.availx := '1';
				v.read.rdataxcanbefilled := '0'; -- (s20)
				-- (s139) is deassertion of (s138) or (s140), so that software knows
				-- it can now read R_READ_DATA
				v.read.busy := '0'; -- (s139)
			end if;
			-- detect and handle completion of a cycle amounting to total size
			-- of one large number
			if r.read.bitstotal(log2(nn) - 1) = '0' and
			   v.read.bitstotal(log2(nn) - 1) = '1'
			then
				v.read.lastwordx := '1'; -- (s18)
				if nn_dynamic then -- -- statically resolved by synthesizer
					v.read.bitstotal := resize(r.nndyn.nbtrailzeros, log2(nn));
				else
					if (nn mod ww) = 0 -- statically resolved by synthesizer
						and (nn mod C_S_AXI_DATA_WIDTH) = 0 -- idem
					then
						-- we must not re-engage reading from ecc_fp_dram in this case
						v.read.fpre0 := '0'; -- (s13) late bypass of (s12)
						-- both r.read.shdatawwcanbeemptied & r.read.rdataxcanbefilled
						-- have been deasserted (by (s15) & by (s20) resp.) so no need
						-- to create this path
					elsif (nn mod ww) = 0 then -- statically resolved by synthesizer
						-- we must not re-engage reading from ecc_fp_dram in this case
						v.read.fpre0 := '0'; -- (s14) late bypass of (s12)
						-- we reassert r.read.shdatawwcanbeemptied, and as r.read.lastwordx
						-- is about to be asserted (from (s18) just above) and as furthermore
						-- r.read.rdataxcanbefilled cannot be about to be deasserted by (s20)
						-- above (this is because nn is NOT a multiple of C_S_AXI_DATA_WIDTH)
						-- then (s17) will now fill r.read.rdatax with trailing zeros
						v.read.shdatawwcanbeemptied := '1'; -- (s16) bypass fo (s15)
					elsif (nn mod C_S_AXI_DATA_WIDTH) = 0 then -- stat. resolved by syn
						-- nothing to do: r.read.rdataxcanbefilled is already about to
						-- be deasserted (from (s20) above) as there is no trailing zeros
						-- in this case
						null;
					else
						-- nothing to do: NEITHER r.read.shdatawwcanbeemptied NOR
						-- r.read.rdataxcanbefilled can be about to be deasserted (the
						-- latter by (s20) above, the former by (s18) above) - this is
						-- because nn is neither a multiple of ww nor a multiple of
						-- C_S_AXI_DATA_WIDTH - so (s17) will now fill r.read.rdatax
						-- with trailing zeros (thx to r.read.lastwordx which is about to
						-- be asserted from (s18) just above)
						null;
					end if;
				end if; -- nn_dynamic
			end if;
		end if;

		-- transfer r.read.availx -> r.axi.rdatax w/ assertion of rvalid
		if r.read.arpending = '1' and r.read.availx = '1' and r.axi.rvalid = '0'
		then
			v.read.availx := '0';
			v.axi.rvalid := '1';
			v.axi.rdatax := r.read.rdatax;
			if r.read.lastwordx = '0' then
				v.read.rdataxcanbefilled := '1';
				v.read.busy := '1'; -- (s140), deasserted by (s139)
			end if;
		end if;

		-- increment of the address at which data are read from ecc_fp_dram
		-- at each read
		if r.read.fpre0 = '1' then
			v.fpaddr0 := std_logic_vector(unsigned(r.fpaddr0) + 1);
		end if;

		--                     ------------------------
		--                          state-machine
		--                      for dynamic modifs of
		--                      size 'nn' of prime  p
		--                     ------------------------

		-- the aim is to compute the value of a few registers, among which:
		--   r.nndyn.valnnm1: holds value of "dynamic nn" minus 1
		--   r.nndyn.valnnp2: holds value of "dynamic nn" plus 2
		--   r.nndyn.valw: holds value of "dynamic nn" + 2 divided by ww
		--                 & rounded to the upper integer value if necessary
		--   r.nndyn.valwm1: holds value of r.nndyn.valw - 1
		--   r.nndyn.val2wm1: hold value of (2 * r.nndyn.valw) - 1
		--   r.nndyn.nnrnd_mask
		-- these registers are forwarded to mm_ndsp blocks and ecc_fp
		-- TODO: multicycle constraints are possible on many paths below!
		-- (all the more many idle states are inserted at the end of the
		-- different computations to let signals nndyn_xxx propagate to
		-- their target DFF, see (s196) below)

		if nn_dynamic then -- statically resolved by synthesizer

			-- bitwidth of numbers used to compare value of nn transmitted by
			-- software and the maximum allowed in R_CAPABILITIES is not the
			-- the bitwidth of that maximum allowed in R_CAPABILITIES... it is the
			-- bitwidth of the maximum that this maximum in R_CAPABILITIES may
			-- have, that is (32 - CAP_NNMAX_LSB)
			-- This is because we must account for the possibilty that (malicious?)
			-- software files a value of nn greater that one given in R_CAPABILITIES
			-- register. Not only that, but software driver should be able to be
			-- compiled without any prejudice regarding the bitwidth of value in
			-- R_CAPABILITIES
			if r.nndyn.testnn = '1' then
				v_nndyn_testnn :=
					  to_unsigned(nn, 32 - CAP_NNMAX_LSB)
					- resize(r.nndyn.valnntest, 32 - CAP_NNMAX_LSB);
				if v_nndyn_testnn(31 - CAP_NNMAX_LSB) = '1' then -- nn < .valnn (NOK)
					v.ctrl.state := idle;
					v.nndyn.active := '0';
					-- raise error flag (illicite dynamic value for nn)
					v.ctrl.ierrid(STATUS_ERR_NNDYN) := '1';
				elsif v_nndyn_testnn(31 - CAP_NNMAX_LSB) = '0' then -- nn >= .valnn (OK)
					v.nndyn.start := '1'; -- asserted only 1 cycle, see (s124)
					v.nndyn.valnn := r.nndyn.valnntest;
					-- clear possible past error
					v.ctrl.ierrid(STATUS_ERR_NNDYN) := '0'; -- (s131)
					-- invalidates values of 'a' & 'p'
					v.ctrl.p_set := '0';
					v.ctrl.p_set_and_mty := '0';
					v.ctrl.a_set := '0';
					v.ctrl.a_set_and_mty := '0';
				end if;
			end if;

			-- computation of r.nndyn.valnnp1 ( = nn + 1)
			v.nndyn.valnnp1 := resize(r.nndyn.valnn, log2(nn + 1)) + 1;

			-- computation of r.nndyn.valnnm1 ( = nn - 1)
			v.nndyn.valnnm1 := r.nndyn.valnn - 1; -- (s34)

			-- computation of r.nndyn.valnnp2 ( = nn + 2)
			v.nndyn.valnnp2 := resize(r.nndyn.valnn, log2(nn + 2)) + 2; -- (s36)

			-- computation of r.nndyn.valnnp3 ( = nn + 3)
			v.nndyn.valnnp3 := resize(r.nndyn.valnn, log2(nn + 3)) + 3;

			-- computation of r.nndyn.valnnp4 ( = nn + 4)
			v.nndyn.valnnp4 := resize(r.nndyn.valnn, log2(nn + 4)) + 4; -- (s47)

			-- computation of r.nndyn.valnnm3 ( = nn - 3)
			v.nndyn.valnnm3 := r.nndyn.valnn - 3;

			v.nndyn.savnnp2p3p4 := r.nndyn.start;

			if r.nndyn.start = '1' then
				-- init the 2nd batch of operations
				v.nndyn.dodec1 := '1';
				-- init the 4th batch of operations
				v.nndyn.dodec3 := '1';
				v.nndyn.valwtmp3 := (others => '0');
				v.nndyn.dodec3b := '1';
				v.nndyn.dodec3done := '0';
				v.nndyn.tmp1 := '0' & r.nndyn.valnn;
				v.nndyn.tmp3 := '0' & r.nndyn.valnn;
				v.nndyn.tmp3b := '0' & r.nndyn.valnn;
				v.nndyn.savnnp2p3p4 := '1'; -- asserted only 1 cycle
				v.nndyn.dodec0done := '0';
				v.nndyn.dodec3done := '0';
				v.nndyn.burst01done := '0';
				v.nndyn.docnt32done := '0';
				v.nndyn.valnnp2dww_rdy := '0';
				v.nndyn.brlwmin_rdy:= '0';
			end if;

			-- computation of r.nndyn.valw
			if r.nndyn.savnnp2p3p4 = '1' then -- asserted only 1 cycle
				-- init the 1st batch of operations
				v.nndyn.tmp0 := '0' & r.nndyn.valnnp2;
				v.nndyn.tmp00 := (others => '0');
				v.nndyn.dodec0 := '1';
				-- init the 3rd batch of operations
				v.nndyn.tmp2 := '0' & r.nndyn.valnnp4;
				v.nndyn.dodec2 := '1';
				-- init the 5th batch of operations
				v.nndyn.valwtmp := (others => '0');
				v.nndyn.doburst01 := '1';
				v.nndyn.burst0or1 := '0'; -- we first erase large number "zero"
				v.nndyn.burst01cnt := to_unsigned(n - 1, log2(n - 1));
			end if;

			-- --------------------------------------------------------------------
			-- 1st batch of operations, based on value nn + 2
			-- --------------------------------------------------------------------

			if r.nndyn.dodec0 = '1' then
				-- subtract ww to value of .tmp0
				v.nndyn.tmp0 := r.nndyn.tmp0 - to_unsigned(ww, log2(nn + 2) + 1);
				v.nndyn.tmp00 := r.nndyn.tmp00 + 1;
				v.nndyn.tmp00prev := r.nndyn.tmp00; -- (s75)
				if r.nndyn.tmp0(log2(nn + 2)) = '1' then -- < 0
					-- (here we must ONLY test for STRICTLY negative, not zero)
					v.nndyn.dodec0 := '0';
					v.nndyn.doshcnt := '1';
					-- size of .tmpprev0 is log2(nn + 2) + 1, size of .shcnt
					-- is log2(ww - 1) so resize function in (s70) below will discard
					-- the upper bits of .tmpprev0. However at the time hardware
					-- latches .tmpprev0 into .shcnt, it is sure that .tmpprev0 holds
					-- a residue value mod ww, so these bits are necessarily 0 anyway
					v.nndyn.shcnt := resize(r.nndyn.tmpprev0, log2(ww - 1)); -- (s70)
					v.nndyn.masktmp := (others => '0');
					-- same remark applies here in (s37) for r.nndyn.shrcnt as for
					-- r.nndyn.shcnt in (s70) above
					v.nndyn.shrcnt := resize(r.nndyn.tmpprev0, log2(ww)); -- (s37)
					vtmp0 := -signed(r.nndyn.tmp0); -- signed, pos, size log2(nn+2)+1 bit
					vtmp1 := unsigned(vtmp0); -- unsigned, pos, of same size
					-- same remark applies here in (s71) for vtmp2 (and hence also
					-- for r.nndyn.shlcnt) as for r.nndyn.shcnt in (s70) above
					vtmp2 := resize(vtmp1, log2(ww)); -- (s71)
					v.nndyn.shlcnt := vtmp2;
					-- the latch of r.nndyn.valnnp2dww, which is the 4th register useful
					-- here (w/ .shcnt, .shrcnt & .shlcnt) is already done in (s75)
					-- (it will keep the value it was holding upon the last cycle where
					-- .dodec0 was high). This value will be compared afterwards w/
					-- (ceil[ceil[(nn + 4)/ww] / ndsp ] - 1 ) * ndsp, which value, held
					-- in r.nndyn.brlwmin, is computed by the 3rd batch of operations
					-- (see (s74) below)
					v.nndyn.valnnp2dww_rdy := '1';
					v.nndyn.valnnp2dww := r.nndyn.tmp00prev; -- (s75)
				end if;
			end if;

			v.nndyn.tmpprev0 := r.nndyn.tmp0;

			if r.nndyn.doshcnt = '1' then
				v.nndyn.masktmp := r.nndyn.masktmp(ww - 2 downto 0) & '1';
				v.nndyn.shcnt := r.nndyn.shcnt - 1;
				if r.nndyn.shcnt(log2(ww - 1) - 1) = '0'
					and v.nndyn.shcnt(log2(ww - 1) - 1) = '1'
				then
					v.nndyn.doshcnt := '0';
					v.nndyn.mask := r.nndyn.masktmp;
					v.nndyn.dodec0done := '1';
				end if;
			end if;

			-- --------------------------------------------------------------------
			-- 2nd batch of operations, based on value of nn (s42)
			-- --------------------------------------------------------------------

			-- This batch aims at computing the signal r.nndyn.nbtrailzeros.
			-- This signal is used by (s43) to enforce proper representation of large
			-- numbers in ecc_fp_dram memory (meaning by this: with adequate most
			-- significant bits set to 0, as this depends on the value of nn)

			v.nndyn.tmpprev1 := r.nndyn.tmp1;

			if r.nndyn.dodec1 = '1' then
				-- subtract ww to value of .tmp1
				v.nndyn.tmp1 := r.nndyn.tmp1 - to_unsigned(ww, log2(nn) + 1);
				if r.nndyn.tmp1(log2(nn)) = '1' -- < 0
					--or r.nndyn.tmp1 = (r.nndyn.tmp1'range => '0') -- or = 0
					-- (here we must ONLY test for STRICTLY negative, not zero)
				then
					v.nndyn.dodec1 := '0';
					v.nndyn.nn_mod_ww := resize(r.nndyn.tmpprev1, log2(ww) + 1);
				end if;
			end if;

			-- computation of signal r.nndyn.nbtrailzeros based on value
			-- of .nn_mod_ww
			-- TODO: set a multicycle on following path:
			--       r.nndyn.nn_mod_ww -> r.nndyn.nbtrailzeros
			-- (s45) below is the (lazy) reason why we don't want to support ww < 4,
			-- see (s44)
			v_nn_mod_ww_sub :=
				r.nndyn.nn_mod_ww - to_unsigned(ww - 4, log2(ww) + 1); -- (s45)
			if r.nndyn.nn_mod_ww = (r.nndyn.nn_mod_ww'range => '0') then
				-- means nn mod ww = 0
				v.nndyn.nbtrailzeros := to_unsigned(ww - 1, log2(2*ww));
			elsif v_nn_mod_ww_sub(log2(ww)) = '1' then
				-- means nn mod ww < ww - 4 (strictly)
				v.nndyn.nbtrailzeros := to_unsigned(ww - 1, log2(2*ww))
					- resize(r.nndyn.nn_mod_ww, log2(ww + 4));
			elsif v_nn_mod_ww_sub = (v_nn_mod_ww_sub'range => '0') then
				-- means nn mod ww = ww - 4
				v.nndyn.nbtrailzeros := to_unsigned(3, log2(2*ww));
			else
				-- means nn mod ww > ww - 4 strictly (either ww - 3, ww - 2 or ww - 1)
				v.nndyn.nbtrailzeros := to_unsigned(2*ww - 1, log2(2*ww))
					- resize(r.nndyn.nn_mod_ww, log2(2*ww));
			end if;

			-- --------------------------------------------------------------------
			-- 3rd batch of operations, based on value nn + 4
			-- --------------------------------------------------------------------

			if r.nndyn.dodec2 = '1' then
				-- subtract ww to value of .tmp2
				v.nndyn.tmp2 := r.nndyn.tmp2 - to_unsigned(ww, log2(nn + 4) + 1);
				-- increment .valw
				v.nndyn.valwtmp := r.nndyn.valwtmp + 1;
				if r.nndyn.tmp2(log2(nn + 4)) = '1' -- < 0
					or r.nndyn.tmp2 = (r.nndyn.tmp2'range => '0') -- or = 0
					-- (here we must test for either negative OR ZERO)
				then
					v.nndyn.dodec2 := '0';
					v.nndyn.valw := r.nndyn.valwtmp;
					-- the latch of r.nndyn.brlwmim, which is the second register useful
					-- here, is already done in (s74) (it will keep the value it was
					-- holding during the last cycle where .dodec2 was high). This value
					-- will be compared afterwards w/ floor[(nn + 2)/ww], the value of
					-- which, held in r.nnynd.valnnp2dww, is computed by the 1st batch
					-- of operations (see (s75) above)
					v.nndyn.dodec22 := '1';
					v.nndyn.tmp22a := '0' & r.nndyn.valwtmp;
					v.nndyn.tmp22b := (others => '0');
				end if;
			end if;

			-- TODO: set a multicycle constraint on path:
			--       r.nndyn.valw -> r.nndyn.valwerr (but not on .ierrid)
			-- w = 1 is forbidden (same as in static case)
			if r.nndyn.valw = to_unsigned(1, log2(w)) then
				v.nndyn.valwerr := '1';
				v.ctrl.ierrid(STATUS_ERR_NNDYN) := '1';
			else
				v.nndyn.valwerr := '0';
				-- no need to reset a possible past error in r.ctrl.ierrid, it was
				-- done by (s131) when starting the nn_dynamic related computations
				-- (just upon validating the first test nn < max)
			end if;

			-- compute r.nndyn.brlwmin = (ceil[ceil[(nn+4)/ww]/ndsp] - 1 ) * ndsp
			if r.nndyn.dodec22 = '1' then
				v.nndyn.tmp22a := r.nndyn.tmp22a - to_unsigned(ndsp, log2(w) + 1);
				v.nndyn.tmp22b := r.nndyn.tmp22b + to_unsigned(ndsp, log2(w) + 1);
				v.nndyn.tmp22bprev := r.nndyn.tmp22b;
				if r.nndyn.tmp22a(log2(w)) = '1' -- < 0
					or r.nndyn.tmp22a = (r.nndyn.tmp22a'range => '0') -- or = 0
					-- (here we must test for either negative OR ZERO)
				then
					v.nndyn.dodec22 := '0';
					v.nndyn.brlwmin := r.nndyn.tmp22bprev; -- (s74)
					v.nndyn.brlwmin_rdy := '1';
				end if;
			end if;

			-- comparison between r.nndyn.valnnp2dww & r.nndyn.brlwmin
			if r.nndyn.valnnp2dww_rdy = '1' and r.nndyn.brlwmin_rdy = '1' then
				vtmp3 := "00" & r.nndyn.valnnp2dww; -- log2(w) + 2 bits
				vtmp4 := '0' & r.nndyn.brlwmin; -- log2(w) + 2 bits
				vtmp5 := vtmp3 - vtmp4;
				-- r.nndyn.exception asserted iff .valnnp2dww < .brlwmin
				v.nndyn.exception := vtmp5(log2(w) + 1);
			end if;

			-- --------------------------------------------------------------------
			-- 4th batch of operations (for NNRND instruction)
			-- --------------------------------------------------------------------

			if r.nndyn.dodec3 = '1' then
				-- subtract ww to value of .tmp3
				v.nndyn.tmp3 := r.nndyn.tmp3 - to_unsigned(ww, log2(nn) + 1);
				-- increment .valwtmp3
				v.nndyn.valwtmp3 := r.nndyn.valwtmp3 + 1;
				if r.nndyn.tmp3(log2(nn)) = '1' -- < 0
					or r.nndyn.tmp3 = (r.nndyn.tmp3'range => '0') -- or = 0
					-- (here we must test for either negative OR ZERO)
				then
					v.nndyn.dodec3 := '0';
					v.nndyn.valw3 := r.nndyn.valwtmp3;
				end if;
			end if;

			v.nndyn.tmpprev3b := r.nndyn.tmp3b;

			if r.nndyn.dodec3b = '1' then
				-- subtract ww to value of .tmp3b
				v.nndyn.tmp3b := r.nndyn.tmp3b - to_unsigned(ww, log2(nn) + 1);
				if r.nndyn.tmp3b(log2(nn)) = '1' -- < 0
					or r.nndyn.tmp3b = (r.nndyn.tmp3b'range => '0') -- or = 0
					-- (here we must test for either negative OR ZERO)
				then
					v.nndyn.dodec3b := '0';
					v.nndyn.doshcnt3b := '1';
					v.nndyn.shcnt3b := resize(r.nndyn.tmpprev3b, log2(ww));
					v.nndyn.masktmp3b := (others => '0');
				end if;
			end if;

			if r.nndyn.doshcnt3b = '1' then
				v.nndyn.masktmp3b := r.nndyn.masktmp3b(ww - 2 downto 0) & '1';
				v.nndyn.shcnt3b := r.nndyn.shcnt3b - 1;
				if r.nndyn.shcnt3b(log2(ww) - 1) = '0'
					and v.nndyn.shcnt3b(log2(ww) - 1) = '1'
				then
					v.nndyn.doshcnt3b := '0';
					v.nndyn.nnrnd_mask := r.nndyn.masktmp3b;
					v.nndyn.dodec3done := '1';
				end if;
			end if;

			if r.nndyn.dodec0done = '1' and r.nndyn.dodec3done = '1'
				and r.nndyn.burst01done = '1'
			then
				v.nndyn.docnt32 := '1';
				v.nndyn.cnt32 := (others => '1'); -- decimal 31
				v.nndyn.dodec0done := '0';
				v.nndyn.dodec3done := '0';
				v.nndyn.burst01done := '0';
			end if;

			-- --------------------------------------------------------------------
			-- 5th batch of operations (based on value nn + 3)
			-- --------------------------------------------------------------------

			if r.nndyn.doburst01 = '1' then
				v.write.fpwe0 := '1'; -- (s222), will be deasserted by (s223)
				-- we "recycle" the .shdataww register
				v.write.shdataww := (others => '0');
				if r.nndyn.burst0or1 = '0' then
					v.fpaddr0 := std_logic_vector(
						to_unsigned(LARGE_NB_ZERO_ADDR, FP_ADDR_MSB)
					) & std_logic_vector(r.nndyn.burst01cnt);
				elsif r.nndyn.burst0or1 = '1' then
					v.fpaddr0 := std_logic_vector(
						to_unsigned(LARGE_NB_ONE_ADDR, FP_ADDR_MSB)
					) & std_logic_vector(r.nndyn.burst01cnt);
				end if;
				v.nndyn.burst01cnt := r.nndyn.burst01cnt - 1;
				if r.nndyn.burst01cnt = (r.nndyn.burst01cnt'range => '0') then
					v.nndyn.burst0or1 := not r.nndyn.burst0or1;
					if r.nndyn.burst0or1 = '1' then
						v.nndyn.doburst01 := '0';
						v.nndyn.dosingle1 := '1';
						v.write.shdataww := (0 => '1', others => '0');
					end if;
				end if;
			end if;

			if r.nndyn.dosingle1 = '1' then
				v.nndyn.dosingle1 := '0';
				v.write.fpwe0 := '0'; -- (s223), deassertion of (s222)
				v.nndyn.burst01done := '1';
			end if;

			-- --------------------------------------------------------------------
			-- (s196)
			-- 6th batch of operations: wait a few cycles so as to let nndyn_xxx
			-- signals propagate to their target DFF
			-- --------------------------------------------------------------------

			-- counting 32 cycles so that register outputs have time to propagate
			-- to mm_ndsp blocks & ecc_fp
			if r.nndyn.docnt32 = '1' then
				v.nndyn.cnt32 := r.nndyn.cnt32 - 1;
				if r.nndyn.cnt32(4) = '0' and v.nndyn.cnt32(4) = '1' then
					v.nndyn.docnt32 := '0';
					v.nndyn.docnt32done := '1';
				end if;
			end if;

			-- end of "nndyn" operations
			if r.nndyn.docnt32done = '1' then
				v.nndyn.docnt32done := '0';
				v.ctrl.state := idle;
				v.nndyn.active := '0'; -- release BUSY bit in R_STATUS, see (s30)
			end if;

		end if; -- nn_dynamic

		-- synchronous (active low) reset
		if s_axi_aresetn = '0' then
			v.ctrl.state := idle;
			v.axi.awpending := '0';
			v.axi.dwpending := '0';
			v.axi.awready := '1';
			v.axi.wready := '1';
			v.axi.bvalid := '0';
			v.axi.rvalid := '0';
			v.axi.arready := '1';
			v.write.doshift := '0';
			v.write.new32 := '0';
			v.write.fpwe0 := '0';
			v.write.fpwe := '0';
			v.write.trailingzeros := "00";
			-- at least one of the two registers r.read.shdatawwcanbeemptied &
			-- r.read.rdataxcanbefilled (but not the two) needs to be reset
			-- so that (s19) does not create erronous behaviour
			--v.read.rdataxcanbefilled := '1';
			v.read.shdatawwcanbeemptied := '0';
			v.read.fpre0 := '0';
			v.read.resh := (others => '0');
			v.read.arpending := '0';
			v.read.availx := '0';
			v.read.lastwordx := '0';
			v.read.active := '0';
			v.read.busy := '0';
			v.read.trngreading := '0';
			v.ctrl.newp := '0';
			v.ctrl.newa := '0';
			v.ctrl.wk := '0';
			-- no need to reset r.ctrl.k_is_null
			v.ctrl.agocstmty := '0';
			v.ctrl.agomtya := '0';
			v.ctrl.agokp := '0';
			v.ctrl.mtypending := '0';
			v.ctrl.amtypending := '0';
			v.ctrl.mtyirq_postponed := '0';
			v.ctrl.kppending := '0';
			v.ctrl.lockaxi := '0';
			v.ctrl.doblinding := '0';
			v.ctrl.savedoblinding := '0';
			v.ctrl.doblindcheck := '0';
    	-- no need to reset r.ctrl.blindbits
			v.ctrl.pen := '0';
			v.ctrl.pendownsh := "0000";
			v.ctrl.penupsh := "00";
			v.ctrl.irq := '0';
			v.ctrl.irqen := '0';
			v.ctrl.kpdone_d := '0';
			v.ctrl.mtydone_d := '0';
			v.ctrl.amtydone_d := '0';
			v.ctrl.dopop := '0';
			v.ctrl.doaop := '0';
			v.ctrl.poppending := '0';
			v.ctrl.aoppending := '0';
			v.ctrl.ierrid := (others => '0');
			-- no need to reset v.ctrl.aerr_inpt_ack
			-- no need to reset v.ctrl.aerr_outpt_ack
			-- no need to reset r.ctrl.ierrid
			v.ctrl.yes := '0';
			v.ctrl.p_set := '0';
			v.ctrl.p_set_and_mty := '0';
			v.ctrl.a_set := '0';
			v.ctrl.a_set_and_mty := '0';
			v.ctrl.b_set := '0';
			v.ctrl.q_set := '0';
			v.ctrl.k_set := '0';
			v.ctrl.k_is_being_set := '0';
			v.ctrl.x_set := '0';
			v.ctrl.y_set := '0';
			v.ctrl.r0_is_null := '0';
			v.ctrl.r1_is_null := '0';
			v.ctrl.read_forbidden := '1'; -- upon reset, no read access to ecc_fp_dram
			v.ctrl.do_ksz_test := '0';
			v.ctrl.small_k_sz_en := '0';
			v.ctrl.small_k_sz_is_on := '0';
			v.ctrl.swrst := '0'; -- no need to reset r.ctrl.swrst_cnt
			v.ctrl.doblindsh := (others => '0');
			if shuffle then -- statically resolved by synthesizer
				if debug then -- statically resolved by synthesizer
					-- if in DEBUG mode, shuffle is disactivated by default
					v.ctrl.doshuffle := '0';
				else
					-- if in production mode, shuffle is enabled by default
					-- (and it can't be deactivated as W_DBG_CFG_NOMEMSHUF
					-- register does not even exist, see (s221))
					v.ctrl.doshuffle := '1';
				end if;
			end if;
			v.write.rnd.irnempty := '1';
			v.write.rnd.trngrdy := '1';
			v.write.rnd.kmaskfull := '0';
			v.write.rnd.doshift := '0';
			v.write.rnd.avail4mask := '0';
			-- (s216), no need to reset r.write.rnd.trailingzeros, see (s215)
			-- -- (s220), no need to reset r.write.rnd.shiftdone, see (s217)
			v.write.rnd.wait4rnd := '0';
			v.write.rnd.write_mask_sh := "00";
			v.write.rnd.enough_random := '0'; -- probably useless
			v.write.rnd.realign := '0';
			v.write.active := '0';
			v.write.busy := '0';
			-- no need to reset r.write.rnd.masklsb nor .firstwwmask
			-- dynamic prime size feature
			if nn_dynamic then
				-- the idea here is that when nn_dynamic = TRUE, all r.nndyn.xxx
				-- registered signals are given a reset value corresponding to the
				-- value of nn given statically in ecc_customize.vhd (which constitutes
				-- a maximal value for dynamic nn parameter).
				-- Alternatively, to save routing ressources, we could remove the
				-- following assignments and specify user/software to write the
				-- value of nn (through the AXI interface, see (s41) above) before
				-- asking the IP to perform any scalar multiplication.
				-- Yes, TODO: remove these useless resets and document for software
				-- to write register W_PRIME_SIZE after reset
				v.nndyn.valnn := to_unsigned(nn, log2(nn));
				v.nndyn.valnnm1 := to_unsigned(nn - 1, log2(nn));
				v.nndyn.valw := to_unsigned(w, log2(w));
				--v.nndyn.valwm1 := to_unsigned(w - 1, log2(w));
				v.nndyn.mask := std_logic_vector (
					resize(unsigned(to_signed(-1, (nn + 2) mod ww)), ww) );
					-- it is important to cast the result of to_signed in unsigned
					-- so as to have resize() adding 0s on MSbits instead of 1s
				v.nndyn.shrcnt := to_unsigned((nn + 2) mod ww, log2(ww));
				v.nndyn.shlcnt := to_unsigned(ww - ((nn + 2) mod ww), log2(ww));
				--v.nndyn.tmp := to_unsigned(ww - ((nn + 2) mod ww), log2(nn + 2) + 1);
				v.nndyn.dodec0 := '0';
				v.nndyn.dodec1 := '0';
				v.nndyn.dodec0done := '0';
				v.nndyn.dodec3done := '0';
				v.nndyn.nn_mod_ww := to_unsigned(nn mod ww, log2(ww) + 1);
				v.nndyn.nnrnd_mask := std_logic_vector (
					resize(unsigned(to_signed(-1, nn mod ww)), ww) );
				v.nndyn.valw3 := to_unsigned(div(nn, ww), log2(w));
				v.nndyn.valwerr := '0';
				v.nndyn.valnnp1 := to_unsigned(nn + 1, log2(nn + 1));
				v.nndyn.valnnm3 := to_unsigned(nn - 3, log2(nn));
				v.nndyn.doshcnt := '0';
				v.nndyn.dodec3b := '0';
				v.nndyn.doshcnt3b := '0';
				v.nndyn.dodec3 := '0';
				v.nndyn.docnt32 := '0';
				v.nndyn.dodec2 := '0';
				v.nndyn.dodec22 := '0';
				v.nndyn.docnt32done := '0';
				v.nndyn.doburst01 := '0';
			else -- nn_dynamic = FALSE
				v.nndyn.valnn := to_unsigned(nn, log2(nn));
				v.nndyn.valnnm1 := to_unsigned(nn - 1, log2(nn));
				v.nndyn.valw := to_unsigned(w, log2(w));
				--v.nndyn.valwm1 := to_unsigned(w - 1, log2(w));
				v.nndyn.mask := std_logic_vector (
					resize(unsigned(to_signed(-1, (nn + 2) mod ww)), ww) );
					-- it is important to cast the result of to_signed in unsigned
					-- so as to have resize() adding 0's on MSbits instead of 1's
				v.nndyn.shrcnt := to_unsigned((nn + 2) mod ww, log2(ww));
				v.nndyn.shlcnt := to_unsigned(ww - ((nn + 2) mod ww), log2(ww));
				--v.nndyn.tmp := to_unsigned(ww - ((nn + 2) mod ww), log2(nn + 2) + 1);
				v.nndyn.dodec0 := '0';
				v.nndyn.dodec1 := '0';
				v.nndyn.dodec0done := '0';
				v.nndyn.dodec3done := '0';
				v.nndyn.nn_mod_ww := to_unsigned(nn mod ww, log2(ww) + 1);
				v.nndyn.nnrnd_mask := std_logic_vector (
					resize(unsigned(to_signed(-1, nn mod ww)), ww) );
				v.nndyn.valw3 := to_unsigned(div(nn, ww), log2(w));
				v.nndyn.valwerr := '0';
				v.nndyn.valnnp1 := to_unsigned(nn + 1, log2(nn + 1));
				v.nndyn.valnnm3 := to_unsigned(nn - 3, log2(nn));
			end if;
			v.nndyn.active := '0';
			-- debug feature
			if debug then
				v.debug.iwe := '0';
				v.debug.trigger := '0';
				v.debug.trigactive := '0';
				for i in 0 to 3 loop
					v.debug.breakpoints(i).act := '0';
				end loop;
				v.debug.dosomeopcodes := '0';
				v.debug.resume := '0';
				v.debug.nbopcodes := (others => '0');
				v.debug.trng.using := '1';
				--TODO: add reset of dbgtrngxxx etc...
				v.debug.trng.ta := to_unsigned(trngta, 20); -- defined in ecc_customize
				v.debug.trng.completebypass := '0';
				--no need to reset r.debug.trng.completebypassbit
				v.debug.trng.vonneuman := '1';
				-- by default, es_trng_byte will stay only 1 clock cyle into
				-- idle state (see es_trng_byte.vhd)
				v.debug.trng.idletime := (r.debug.trng.idletime'range => '0');
				v.debug.trng.ppdeact := '0';
				-- no need to reset r.debug.i[rw]datacnt
				v.debug.halt := '0';
				-- no need to reset r.debug.readsh
				v.debug.readrdy := '0';
				v.debug.noxyshuf := '1'; -- in debug mode, we start wo/ XY-shuffling
				v.debug.noaxirnd := '1'; -- in debug mode, we start wo/ AXI rnd masking
			else
				v.debug.trng.using := '1'; -- present also when debug=FALSE, see (s38)
			end if;
		end if; -- if s_axi_aresetn (synchronous reset)

		rin <= v;
	end process comb;

	-- registers, clocked by s_axi_aclk
	regs : process(s_axi_aclk)
	begin
		if s_axi_aclk'event and s_axi_aclk = '1' then
			r <= rin;
		end if;
	end process regs;

	-- --------------------
	-- drive output signals
	-- --------------------

	-- software reset
	swrst <= r.ctrl.swrst;

	-- to ecc_scalar
	agokp <= r.ctrl.agokp;
	agocstmty <= r.ctrl.agocstmty;
	agomtya <= r.ctrl.agomtya;
	doblinding <= r.ctrl.doblinding;
	blindbits <= std_logic_vector(r.ctrl.blindbits);
	doshuffle <= r.ctrl.doshuffle;
	k_is_null <= r.ctrl.k_is_null;
	dopop <= r.ctrl.dopop;
	popid <= r.ctrl.popid;
	doaop <= r.ctrl.doaop;
	aopid <= r.ctrl.aopid;
	ar0zo <= r.ctrl.r0_is_null;
	ar1zo <= r.ctrl.r1_is_null;
	aerr_inpt_ack <= r.ctrl.aerr_inpt_ack;
	aerr_outpt_ack <= r.ctrl.aerr_outpt_ack;
	small_k_sz_en <= r.ctrl.small_k_sz_en;
	small_k_sz_en_en <= r.ctrl.small_k_sz_en_en;
	small_k_sz <= r.ctrl.small_k_sz;

	-- to ecc_curve
	masklsb <= r.write.rnd.masklsb;

	-- to ecc_fp
	xwe <= r.write.fpwe;
	xaddr <= r.fpaddr;
	-- if writing into ecc_fp_dram using the debug interface was not
	-- a debug feature, we could set a multicycle constraint on
	-- path dbghalted -> xwdata (but it is a debug feature so perf
	-- is not really an issue)
	xwdata <= r.debug.fpwdata when (debug and dbghalted = '1' and
						                      r.debug.shwon(0) = '1')
	          else r.write.fpwdata;
	xre <= r.read.fpre;

	-- to external AXI interface
	s_axi_awready <= r.axi.awready;
	s_axi_wready <= r.axi.wready;
	s_axi_bresp <= CST_AXI_RESP_OKAY;
	s_axi_bvalid <= r.axi.bvalid;
	s_axi_arready <= r.axi.arready;
	s_axi_rdata <= r.axi.rdatax;
	s_axi_rresp <= CST_AXI_RESP_OKAY;
	s_axi_rvalid <= r.axi.rvalid;

	-- interrupt
	irq <= r.ctrl.irq;

	-- to mm_ndsp's
	pen <= r.ctrl.pen; -- (s9)

	n0: if nn_dynamic generate -- statically resolved by synthesizer
		nndyn_mask <= r.nndyn.mask;
		nndyn_shrcnt <= r.nndyn.shrcnt;
		nndyn_shlcnt <= r.nndyn.shlcnt;
		-- to mm_ndsp's & ecc_fp
		nndyn_w <= r.nndyn.valw;
		nndyn_wm1_s <= resize(r.nndyn.valw - 1, log2(w - 1));
		nndyn_wm2_s <= resize(r.nndyn.valw - 2, log2(w - 1));
		nndyn_2wm1_s <= resize((r.nndyn.valw & '0') - 1, log2(2*w - 1));
		nndyn_wm1 <= nndyn_wm1_s;
		nndyn_wm2 <= nndyn_wm2_s;
		nndyn_2wm1 <= nndyn_2wm1_s;
		nndyn_mask_is_zero_s <=
			'1' when r.nndyn.mask = (r.nndyn.mask'range => '0')
			else '0';
		nndyn_mask_is_all1_but_msb_s <=
			'1' when (r.nndyn.mask(r.nndyn.mask'LENGTH-1) = '0'
			     and ( r.nndyn.mask(r.nndyn.mask'LENGTH - 2 downto 0)
				      = (r.nndyn.mask'LENGTH - 2 downto 0 => '1') ) )
			else '0';
		nndyn_mask_wm2_s <= '1' when nndyn_mask_is_all1_but_msb_s = '1' else '0';
		nndyn_mask_wm2 <= nndyn_mask_wm2_s;
		nndyn_wmin_s <= resize(nndyn_wm2_s, log2(2*w - 1))
			when nndyn_mask_is_all1_but_msb_s = '1'
			else resize(nndyn_wm1_s, log2(2*w - 1));
		nndyn_wmin <= nndyn_wmin_s;
		nndyn_wmin_excp_val <= resize(r.nndyn.brlwmin, log2(2*w - 1));
		nndyn_wmin_excp <= r.nndyn.exception;
		nndyn_nnrnd_mask <= r.nndyn.nnrnd_mask;
		nndyn_nnrnd_zerowm1_s <=
			'1' when r.nndyn.valw /= r.nndyn.valw3
			else '0';
		nndyn_nnrnd_zerowm1 <= nndyn_nnrnd_zerowm1_s;
		nndyn_nnp1_s <= r.nndyn.valnnp1;
		nndyn_nnp1 <= nndyn_nnp1_s;
		nndyn_nnm3_s <= r.nndyn.valnnm3;
		nndyn_nnm3 <= nndyn_nnm3_s;
	end generate;

	nn0: if not nn_dynamic generate -- statically resolved by synthesizer
		-- in this case (nn_dynamic = FALSE) all signal values are statically
		-- computed and synthesizer will prune all the nndyn_xxx signals by
		-- tying them either to high/Vcc or low/gnd logic level
		nndyn_mask_s <= std_logic_vector (
			resize(unsigned(to_signed(-1, (nn + 2) mod ww)), ww) );
			-- it is important to cast the result of to_signed in unsigned
			-- so as to have resize() adding 0's on MSbits instead of 1's
		nndyn_mask <= nndyn_mask_s;
		nndyn_shrcnt <= to_unsigned((nn + 2) mod ww, log2(ww));
		nndyn_shlcnt <= to_unsigned(ww - ((nn + 2) mod ww), log2(ww));
		-- to mm_ndsp's & ecc_fp
		nndyn_w <= to_unsigned(w, log2(w));
		nndyn_wm1_s <= to_unsigned(w - 1, log2(w - 1));
		nndyn_wm2_s <= to_unsigned(w - 2, log2(w - 1));
		nndyn_2wm1_s <= to_unsigned(2*w - 1, log2(2*w - 1));
		nndyn_wm1 <= nndyn_wm1_s;
		nndyn_wm2 <= nndyn_wm2_s;
		nndyn_2wm1 <= nndyn_2wm1_s;
		nndyn_mask_is_zero_s <=
			'1' when nndyn_mask_s = (nndyn_mask_s'range => '0')
			else '0';
		nndyn_mask_is_all1_but_msb_s <=
			'1' when (nndyn_mask_s(nndyn_mask_s'LENGTH - 1) = '0'
			     and ( nndyn_mask_s(nndyn_mask_s'LENGTH - 2 downto 0)
			        = (nndyn_mask_s'LENGTH - 2 downto 0 => '1') ) )
			else '0';
		nndyn_mask_wm2 <= '1' when nndyn_mask_is_all1_but_msb_s = '1' else '0';
		nndyn_wmin <= resize(nndyn_wm2_s, log2(2*w - 1))
			when nndyn_mask_is_all1_but_msb_s = '1'
			else resize(nndyn_wm1_s, log2(2*w - 1));
		nndyn_wmin_excp_val <= to_unsigned((div(w,ndsp)-1) * ndsp, log2(2*w - 1));
		nndyn_wmin_excp <= '1'
			when ( (div(w, ndsp) - 1) * ndsp ) > ( (nn + 2) / ww )
			else '0';
		nndyn_nnrnd_mask <= std_logic_vector (
			resize(unsigned(to_signed(-1, nn mod ww)), ww) );
		nndyn_nnrnd_zerowm1 <=
			'1' when ((nn + 4) mod ww) /= (nn mod ww)
			else '0';
		nndyn_nnp1_s <= to_unsigned(nn + 1, log2(nn + 1));
		nndyn_nnp1 <= nndyn_nnp1_s;
		nndyn_nnm3_s <= to_unsigned(nn - 3, log2(nn));
		nndyn_nnm3 <= nndyn_nnm3_s;
	end generate;

	-- general busy signal
	kppending <= r.ctrl.kppending;

	-- interface with ecc_trng
	trngrdy <= r.write.rnd.trngrdy;

	-- debug features (to ecc_curve_iram)
	dbgiaddr <= r.debug.iaddr;
	dbgiwdata <= r.debug.iwdata;
	dbgiwe <= r.debug.iwe;
	dbgtrigger <= r.debug.trigger;

	-- debug features (to ecc_curve)
	dbgbreakpoints <= r.debug.breakpoints;
	dbgnbopcodes <= r.debug.nbopcodes;
	dbgdosomeopcodes <= r.debug.dosomeopcodes;
	dbgresume <= r.debug.resume;
	dbghalt <= r.debug.halt;
	dbgnoxyshuf <= r.debug.noxyshuf;

	-- debug features (to trng)
	dbgtrnguse <= r.debug.trng.using; -- (s38)
	dbgtrngta <= r.debug.trng.ta;
	dbgtrngrawreset <= r.debug.trng.rawreset;
	dbgtrngirnreset <= r.debug.trng.irnreset;
	dbgtrngrawraddr <= r.debug.trng.raw.raddr;
	dbgtrngppdeact <= r.debug.trng.ppdeact;
	dbgtrngcompletebypass <= r.debug.trng.completebypass;
	dbgtrngcompletebypassbit <= r.debug.trng.completebypassbit;
	dbgtrngvonneuman <= '1' when not debug -- statically resolved at synthesis
	                    else r.debug.trng.vonneuman;
	dbgtrngidletime <= r.debug.trng.idletime;

	-- pragma translate_off
	-- Simulation process to log on simulator console the random value used by
	-- ecc_axi (which it got from ecc_trng) to mask the scalar k on-the-fly
	-- before writing it to ecc_fp_dram (reminder: the masking is either
	-- additive - if blinding has been set by user -, or boolean otherwise).
	process(s_axi_aclk, s_axi_aresetn)
		variable bdx, bdx0 : integer;
		variable v_k : std_logic_vector(2*nn - 1 downto 0);
	begin
		if s_axi_aclk'event and s_axi_aclk = '1' then
			r_ctrl_wk <= r.ctrl.wk;
			if s_axi_aresetn = '0' then
				r_ctrl_wk <= '0';
				r_k_seq <= '0';
				rkw <= 0;
				rkx <= 0;
				r_k <= (others => '0');
				r_mask <= (others => '0');
				r_k_masked <= (others => '0');
				rkx_on <= '0';
			else
				r_ctrl_wk <= r.ctrl.wk;
				if r.ctrl.wk = '1' and r_ctrl_wk = '0' then
					-- r.ctrl.wk rising event: software has started a new sequence
					-- to write the scalar k in ecc_fp_dram
					r_k_seq <= '0';
					rkw <= 0;
					rkx <= 0;
					r_k <= (others => '0');
					r_mask <= (others => '0');
					r_k_masked <= (others => '0');
					rkx_on <= '1';
				elsif r.ctrl.wk = '0' and r_ctrl_wk = '1' then
					-- r.ctrl.wk falling event: software has finished the scalar
					-- write sequence, hence we can display the simu informations
					-- on console: the scalar k (before the masking), the mask, and
					-- then the masked scalar
					-- (first determine the highest non-null bit of r_k_masked: this
					-- is the most meaningful bit for the 3 bit vectors to display)
					bdx0 := to_integer(r.nndyn.valnn) - 1;
					bdx := bdx0 + to_integer(r.ctrl.blindbits);
					echo("ECC_AXI: k (as set by software) = 0x");
					if r.ctrl.doblinding = '1' then
						if (bdx > bdx0) then
							hex_echol(std_logic_vector(to_unsigned(0, bdx - bdx0))
								& r_k(bdx0 downto 0));
						else
							hex_echol(r_k(bdx0 downto 0));
						end if;
						echo("ECC_AXI: mask of k (additive)   = 0x");
						hex_echol(r_mask(bdx downto 0));
						echo("ECC_AXI: masked value of k      = 0x");
						hex_echol(r_k_masked(bdx downto 0));
					elsif r.ctrl.doblinding = '0' then
						hex_echol(r_k(bdx0 downto 0));
						echo("ECC_AXI: mask of k (boolean)    = 0x");
						hex_echol(r_mask(bdx0 downto 0));
						echo("ECC_AXI: masked value of k      = 0x");
						hex_echol(r_k_masked(bdx0 downto 0));
					end if;
				else
					if s_axi_awvalid = '1' and r.axi.awready = '1' then
						if s_axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 3) /=
							std_logic_vector(to_unsigned(1, C_S_AXI_ADDR_WIDTH - 3))
						then
							rkx_on <= '0';
						end if;
					end if;
					if r.ctrl.wk = '1' then
						-- construct r_k by directly intercepting the AXI writes
						-- made by software
						if s_axi_wvalid = '1' and r.axi.wready = '1' and rkx_on = '1' then
							-- a new data-beat is currently happening on the Data-Write
							-- AXI channel
							r_k((C_S_AXI_DATA_WIDTH*(rkx+1))-1 downto C_S_AXI_DATA_WIDTH*rkx)
								<= s_axi_wdata;
							rkx <= rkx + 1;
						end if;
						-- construct r_mask & r_k_masked by intercepting the writes
						-- made by ecc_axi in ecc_fp_dram
						if r.write.fpwe = '1' then
							if r_k_seq = '0' then
								r_k_masked( (ww*(rkw+1)) - 1 downto ww*rkw)
									<= r.write.fpwdata;
								r_k_seq <= '1';
							elsif r_k_seq = '1' then
								r_mask( (ww*(rkw+1)) - 1 downto ww*rkw)
									<= r.write.fpwdata;
								r_k_seq <= '0';
								rkw <= rkw + 1;
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	-- pragma translate_on

end architecture rtl;
