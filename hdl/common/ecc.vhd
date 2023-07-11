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
use work.mm_ndsp_pkg.all;
use work.ecc_trng_pkg.all;
use work.ecc_shuffle_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity ecc is
	generic(
		-- width of AXI data bus
		constant C_S_AXI_DATA_WIDTH : integer := axi32or64; -- in ecc_customize
		-- width of AXI address bus
		constant C_S_AXI_ADDR_WIDTH : integer := AXIAW -- in ecc_pkg
	);
	port(
		-- AXI clock
		s_axi_aclk : in std_logic;
		-- AXI reset (expected active low, async asserted, sync deasserted) 
		s_axi_aresetn : in std_logic;
		-- AXI write-address channel
		s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1  downto 0);
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
		-- clock for Montgomery multipliers in the async case
		clkmm : in std_logic;
		-- interrupt
		irq : out std_logic;
		irqo : out std_logic;
		-- busy signal for [k]P computation
		busy : out std_logic;
		-- debug feature (off-chip trigger)
		dbgtrigger : out std_logic;
		dbghalted : out std_logic
	);
end entity ecc;

architecture struct of ecc is

	-- following attributes are Xilinx specific but they should not do any harm
	-- on other platforms
	attribute X_INTERFACE_INFO : string;
	attribute X_INTERFACE_PARAMETER : string;
	attribute X_INTERFACE_INFO of irq : signal is
		"xilinx.com:signal:interrupt:1.0 irq INTERRUPT";
	attribute X_INTERFACE_PARAMETER of irq : signal is "SENSITIVITY EDGE_RISING";

	-- AXI-lite interface
	component ecc_axi is
		generic(
			-- Width of S_AXI data bus
			C_S_AXI_DATA_WIDTH  : integer := axi32or64; -- in ecc_customize
			-- Width of S_AXI address bus
			C_S_AXI_ADDR_WIDTH  : integer := AXIAW); -- in ecc_pkg
		port (
			-- AXI clock & reset
			s_axi_aclk : in  std_logic;
			s_axi_aresetn : in std_logic;
			-- AXI write-address channel
			s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			s_axi_awprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_awvalid : in std_logic;
			s_axi_awready : out std_logic;
			-- AXI write-data channel
			s_axi_wdata : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			s_axi_wstrb : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
			s_axi_wvalid : in std_logic;
			s_axi_wready : out std_logic;
			-- AXI write-response channel
			s_axi_bresp : out std_logic_vector(1 downto 0);
			s_axi_bvalid : out std_logic;
			s_axi_bready : in std_logic;
			-- AXI read-address channel
			s_axi_araddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			s_axi_arprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_arvalid : in std_logic;
			s_axi_arready : out std_logic;
			-- AXI read-data channel
			s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
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
			tokenact : out std_logic;
			zremaskact : out std_logic;
			zremaskbits : out unsigned(log2(nn - 1) - 1 downto 0);
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
			--   token
			gentoken : out std_logic;
			tokendone : in std_logic;
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
			trngaxiirncount : in std_logic_vector(log2(irn_fifo_size_axi)-1 downto 0);
			trngefpirncount : in std_logic_vector(log2(irn_fifo_size_fp)-1 downto 0);
			trngcurirncount : in std_logic_vector(log2(irn_fifo_size_curve)-1 downto 0);
			trngshfirncount : in std_logic_vector(log2(irn_fifo_size_sh)-1 downto 0);
			-- broadcast interface to Montgomery multipliers
			pen : out std_logic;
			nndyn_mask : out std_logic_vector(ww - 1 downto 0);
			nndyn_shrcnt : out unsigned(log2(ww) - 1 downto 0);
			nndyn_shlcnt : out unsigned(log2(ww) - 1 downto 0);
			nndyn_w : out unsigned(log2(w) - 1 downto 0);
			nndyn_wm1 : out unsigned(log2(w - 1) - 1 downto 0);
			nndyn_wm2 : out unsigned(log2(w - 1) - 1 downto 0);
			nndyn_2wm1 : out unsigned(log2((2*w) - 1) - 1 downto 0);
			nndyn_wmin : out unsigned(log2((2*w) - 1) - 1 downto 0);
			nndyn_wmin_excp_val : out unsigned(log2(2*w - 1) - 1 downto 0);
			nndyn_wmin_excp : out std_logic;
			nndyn_mask_wm2 : out std_logic;
			nndyn_nnp1 : out unsigned(log2(nn + 1) - 1 downto 0);
			nndyn_nnm3 : out unsigned(log2(nn) - 1 downto 0);
			-- busy signal for [k]P computation
			kppending : out std_logic;
			-- software reset (to other components of the IP)
			swrst : out std_logic;
			-- debug features (interface with ecc_scalar shared w/ ecc_curve)
			dbgpgmstate : in std_logic_vector(3 downto 0);
			dbgnbbits : in std_logic_vector(15 downto 0);
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
			-- handshake signals between entropy server ecc_trng
			-- and the different clients (for debug diagnostics)
			dbgtrngaxirdy : in std_logic;
			dbgtrngaxivalid : in std_logic;
			dbgtrngfprdy : in std_logic;
			dbgtrngfpvalid : in std_logic;
			dbgtrngcrvrdy : in std_logic;
			dbgtrngcrvvalid : in std_logic;
			dbgtrngshrdy : in std_logic;
			dbgtrngshvalid : in std_logic;
			-- debug feature (off-chip trigger)
			dbgtrigger : out std_logic
		);
	end component ecc_axi;

	-- unit handling control of overall [k]P computation
	component ecc_scalar is
		port (
			clk : in  std_logic;
			rstn : in  std_logic; -- synchronous reset
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
			agokp : in  std_logic;
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
			--   arithmetic computations
			doaop : in std_logic;
			aopid : in std_logic_vector(2 downto 0); -- id defined in ecc_pkg
			aopdone : out std_logic;
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
			compaop : out std_logic;
			token_generating : out std_logic;
			-- interface with ecc_fp_dram_sh_* (used only in the 'shuffle' case)
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
	end component ecc_scalar;

	-- unit handling execution of microcore routines
	component ecc_curve is
		port(
			clk : in std_logic;
			rstn : in  std_logic; -- deassertion ('1') assumed to be synchr. w/ clk
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
			firstzdbl : in std_logic;
			firstzaddu : in std_logic;
			iterate_shuffle_valid : in std_logic;
			iterate_shuffle_rdy : out std_logic;
			iterate_shuffle_force : in std_logic;
			first2pz : out std_logic;
			first3pz : in std_logic;
			torsion2 : out std_logic;
			xmxz : out std_logic;
			ymyz : out std_logic;
			kap : out std_logic;
			kapp : out std_logic;
			zu : in std_logic;
			zc : in std_logic;
			r0z : in std_logic;
			r1z : in std_logic;
			pts_are_equal : in std_logic;
			pts_are_oppos : in std_logic;
			phimsb : out std_logic;
			kb0end : out std_logic;
			ptadd : in std_logic;
			-- interface with ecc_curve_iram
			ire : out std_logic;
			iraddr : out std_logic_vector (IRAM_ADDR_SZ - 1 downto 0);
			irdata : in  std_logic_vector (OPCODE_SZ - 1 downto 0);
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
			dbgnoxyshuf : in std_logic;
			dbghalted : out std_logic;
			dbgdecodepc : out std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
			dbgbreakpointid : out std_logic_vector(1 downto 0);
			dbgbreakpointhit : out std_logic;
			-- debug features (interface with ecc_scalar shared w/ ecc_axi)
			dbgpgmstate : in std_logic_vector(3 downto 0);
			dbgnbbits : in std_logic_vector(15 downto 0)
			-- pragma translate_off
			; pc : out std_logic_vector (IRAM_ADDR_SZ - 1 downto 0);
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
	end component ecc_curve;

	-- double-clock simple dual-port RAM formated as 512 words (opcodes)
	-- of 32-bit each, accessed in read-only mode by 'ecc_curve'
	-- width of both address & data buses is independent of nn 
	component ecc_curve_iram is
		generic(
			rdlat : positive range 1 to 2 := 2);
		port(
			-- port A: write-only interface to AXI-lite interface
			clka : in std_logic;
			wea : in std_logic;
			addra : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
			dia : in std_logic_vector (OPCODE_SZ - 1 downto 0);
			-- port B: read-only interface to ecc_curve
			clkb : in std_logic;
			reb : in std_logic;
			addrb : in std_logic_vector (IRAM_ADDR_SZ - 1 downto 0);
			dob : out std_logic_vector (OPCODE_SZ - 1 downto 0)
		);
	end component ecc_curve_iram;

	-- unit handling execution of instructions/opcodes
	--  - receives instructions/opcodes from ecc_curve
	--  - performs operand data read from ecc_fp_dram
	--  - transmits operand data to Montgomery multipliers and perform
	--    other arithmetic operations
	--  - performs result data write back into ecc_fp_dram
	component ecc_fp is
		port (
			clk : in std_logic;
			rstn : in  std_logic; -- deassertion ('1') assumed synchronous to clk
			swrst : in std_logic;
			-- interface with ecc_curve
			opi : in opi_type;
			opo : out opo_type;
			-- interface with multipliers
			mmi : out mmi_type;
			mmo : in mmo_type;
			-- interface with ecc_fp_dram
			fpre : out std_logic;
			fpraddr : out std_logic_vector(FP_ADDR - 1 downto 0);
			fprdata : in std_logic_vector(ww - 1 downto 0);
			fpwe : out std_logic;
			fpwaddr : out std_logic_vector(FP_ADDR - 1 downto 0);
			fpwdata : out std_logic_vector(ww - 1 downto 0);
			-- interface with ecc_axi
			--   (to have the AXI-lite interface access ecc_fp_dram)
			xwe : in std_logic;
			xaddr : in std_logic_vector(FP_ADDR - 1 downto 0);
			xwdata : in std_logic_vector(ww - 1 downto 0);
			xre : in std_logic;
			xrdata : out std_logic_vector(ww - 1 downto 0);
			nndyn_nnrnd_mask : in std_logic_vector(ww - 1 downto 0);
			nndyn_nnrnd_zerowm1 : in std_logic;
			nndyn_wm1 : in unsigned(log2(w - 1) - 1 downto 0);
			nndyn_2wm1 : in unsigned(log2((2*w) - 1) - 1 downto 0);
			-- pragma translate_off
			nndyn_w : in unsigned(log2(w) - 1 downto 0);
			-- pragma translate_on
			-- interface with ecc_trng
			trngdata : in std_logic_vector(ww - 1 downto 0);
			trngvalid : in std_logic;
			trngrdy : out std_logic;
			-- interface with ecc_scalar
			initkp : in std_logic;
			compkp : in std_logic;
			compcstmty : in std_logic;
			comppop : in std_logic;
			compaop : in std_logic;
			token_generating : in std_logic;
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
			-- interface with ecc_fp_dram (simu only)
			fpdram : in fp_dram_type;
			fprwmask : in std_logic_vector(FP_ADDR - 1 downto 0);
			vtophys : in virt_to_phys_table_type
			-- pragma translate_on
		);
	end component ecc_fp;

	-- True random number generator w/ embedded post-processing
	component ecc_trng is
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- interface with ecc_scalar
			irn_reset : in std_logic;
			-- interface with entropy client ecc_axi
			rdy0 : in std_logic;
			valid0 : out std_logic;
			data0 : out std_logic_vector(ww - 1 downto 0);
			irncount0 : out std_logic_vector(log2(irn_fifo_size_axi) - 1 downto 0);
			-- interface with entropy client ecc_fp
			rdy1 : in std_logic;
			valid1 : out std_logic;
			data1 : out std_logic_vector(ww - 1 downto 0);
			irncount1 : out std_logic_vector(log2(irn_fifo_size_fp) - 1 downto 0);
			-- interface with entropy client ecc_curve
			rdy2 : in std_logic;
			valid2 : out std_logic;
			data2 : out std_logic_vector(1 downto 0);
			irncount2 : out std_logic_vector(log2(irn_fifo_size_curve) - 1 downto 0);
			-- interface with entropy client ecc_fp_dram_sh_*
			rdy3 : in std_logic;
			valid3 : out std_logic;
			data3 : out std_logic_vector(irn_width_sh - 1 downto 0);
			irncount3 : out std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
			-- interface with ecc_axi (only usable in debug mode)
			dbgtrngta : in unsigned(19 downto 0);
			dbgtrngrawreset : in std_logic;
			dbgtrngrawfull : out std_logic;
			dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawdata : out std_logic;
			dbgtrngppdeact : in std_logic;
			dbgtrngcompletebypass : in std_logic;
			dbgtrngcompletebypassbit : in std_logic;
			dbgtrngrawduration : out unsigned(31 downto 0);
			dbgtrngvonneuman : in std_logic;
			dbgtrngidletime : in unsigned(3 downto 0)
		);
	end component ecc_trng;

	-- synchronous simple-dual RAM formated as 512 words of 17-bit each
	-- functionally divided into 64 contiguous segments of 16 words each
	-- (each of these segments representing a number of the finite field
	-- underlying to the elliptic curve)
	component ecc_fp_dram is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			-- port A: write-only interface to ecc_fp
			-- (actually for write-access from AXI-lite interface)
			wea : in std_logic;
			addra : in std_logic_vector (FP_ADDR - 1 downto 0);
			dia : in std_logic_vector (ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector (FP_ADDR - 1 downto 0);
			dob : out std_logic_vector (ww - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type
			-- pragma translate_on
		);
	end component ecc_fp_dram;

	-- shuffled version of ecc_fp_dram (linear masking version)
	component ecc_fp_dram_sh_linear is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- port A: write-only interface from ecc_fp
			-- (actually for write-access from AXI-lite interface)
			wea : in std_logic;
			addra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(ww - 1 downto 0);
			-- interface with ecc_scalar
			permute : in std_logic;
			permuterdy : out std_logic;
			permuteundo : in std_logic;
			-- interface with ecc_trng
			trngvalid : in std_logic;
			trngrdy : out std_logic;
			trngdata : in std_logic_vector(irn_width_sh - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type;
			fprwmask : out std_logic_vector(FP_ADDR - 1 downto 0)
			-- pragma translate_on
		);
	end component ecc_fp_dram_sh_linear;

	-- shuffled version of ecc_fp_dram (version: Fisher-Yates permutation applied
	-- on a coarse scale, that is on large numbers only)
	component ecc_fp_dram_sh_fishy_nb is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- port A: write-only interface from ecc_fp
			-- (actually for write-access from AXI-lite interface)
			wea : in std_logic;
			addra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(ww - 1 downto 0);
			-- interface with ecc_axi
			nndyn_wm1 : in unsigned(log2(w - 1) - 1 downto 0);
			-- interface with ecc_scalar
			permute : in std_logic;
			permuterdy : out std_logic;
			-- interface with ecc_trng
			trngvalid : in std_logic;
			trngrdy : out std_logic;
			trngdata : in std_logic_vector(irn_width_sh - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type;
			vtophys : out virt_to_phys_table_type
			-- pragma translate_on
		);
	end component ecc_fp_dram_sh_fishy_nb;

	-- shuffled version of ecc_fp_dram (version: Fisher-Yates permutation applied
	-- on a fine scale, that is not only on large numbers but on their inside
	-- ww-bit limbs)
	component ecc_fp_dram_sh_fishy is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- port A: write-only interface from ecc_fp
			-- (actually for write-access from AXI-lite interface)
			wea : in std_logic;
			addra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(ww - 1 downto 0);
			-- interface with ecc_scalar
			permute : in std_logic;
			permuterdy : out std_logic;
			-- interface with ecc_trng
			trngvalid : in std_logic;
			trngrdy : out std_logic;
			trngdata : in std_logic_vector(irn_width_sh - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type;
			vtophys : out virt_to_phys_table_type
			-- pragma translate_on
		);
	end component ecc_fp_dram_sh_fishy;

	-- Montgomery multiplier
	component mm_ndsp is
		port(
			clkmm : in std_logic;
			clk : in std_logic;
			rstn : in std_logic; -- deassertion ('1') assumed to be synchronous w/ clk
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
			-- interface with ecc_curve
			ppen : in std_logic;
			-- output data
			z : out std_logic_vector(ww - 1 downto 0);
			zren : in std_logic;
			irq : out std_logic;
			go_ack : out std_logic;
			irq_ack : in std_logic
		);
	end component mm_ndsp;

	-- signals between ecc_axi & ecc_scalar
	signal doblinding : std_logic;
	signal blindbits : std_logic_vector(log2(nn) - 1 downto 0);
	signal doshuffle : std_logic;
	signal k_is_null : std_logic;
	signal small_k_sz_en : std_logic;
	signal small_k_sz_en_en : std_logic;
	signal small_k_sz : unsigned(log2(nn) - 1 downto 0);
	signal small_k_sz_en_ack : std_logic;
	signal small_k_sz_kpdone : std_logic;
	signal tokenact : std_logic;
	signal zremaskact : std_logic;
	signal zremaskbits : unsigned(log2(nn - 1) - 1 downto 0);
	signal ardy : std_logic;
	signal aerr_inpt_not_on_curve : std_logic;
	signal aerr_outpt_not_on_curve : std_logic;
	signal aerr_inpt_ack : std_logic;
	signal aerr_outpt_ack : std_logic;
	signal agokp, agocstmty : std_logic;
	signal initdone : std_logic;
	signal kpdone, mtydone : std_logic;
	signal agomtya : std_logic;
	signal amtydone : std_logic;
	signal nndyn_nnp1 : unsigned(log2(nn + 1) - 1 downto 0);
	signal nndyn_nnm3 : unsigned(log2(nn) - 1 downto 0);
	signal dopop : std_logic;
	signal popid : std_logic_vector(2 downto 0);
	signal popdone : std_logic;
	signal yes, yesen : std_logic;
	signal doaop : std_logic;
	signal aopid : std_logic_vector(2 downto 0);
	signal aopdone : std_logic;
	signal gentoken : std_logic;
	signal tokendone : std_logic;
	signal ar01zien : std_logic;
	signal ar0zi : std_logic;
	signal ar1zi : std_logic;
	signal ar0zo : std_logic;
	signal ar1zo : std_logic;
	-- signals between ecc_axi & ecc_curve
	signal masklsb : std_logic;
	-- signals from ecc_axi to top-level
	signal irq_s : std_logic;
	-- signals between ecc_axi & mm_ndsp(s)
	signal pen : std_logic;
	signal nndyn_mask : std_logic_vector(ww - 1 downto 0);
	signal nndyn_shrcnt : unsigned(log2(ww) - 1 downto 0);
	signal nndyn_shlcnt : unsigned(log2(ww) - 1 downto 0);
	signal nndyn_w : unsigned(log2(w) - 1 downto 0);
	signal nndyn_wm1 : unsigned(log2(w - 1) - 1 downto 0);
	signal nndyn_wm2 : unsigned(log2(w - 1) - 1 downto 0);
	signal nndyn_2wm1 : unsigned(log2((2*w) - 1) - 1 downto 0);
	signal nndyn_wmin : unsigned(log2((2*w) - 1) - 1 downto 0);
	signal nndyn_wmin_excp_val : unsigned(log2(2*w - 1) - 1 downto 0);
	signal nndyn_wmin_excp : std_logic;
	signal nndyn_mask_wm2 : std_logic;
	-- signals between ecc_curve & mm_ndsp(s)
	signal ppen : std_logic;
	-- signals between ecc_scalar & ecc_curve
	signal initkp : std_logic; -- also between ecc_scalar & ecc_fp
	signal frdy, fgo, ferr : std_logic;
	signal faddr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal zero : std_logic;
	signal laststep : std_logic;
	signal firstzdbl : std_logic;
	signal firstzaddu : std_logic;
	signal iterate_shuffle_valid : std_logic;
	signal iterate_shuffle_rdy : std_logic;
	signal iterate_shuffle_force : std_logic;
	signal first2pz : std_logic;
	signal first3pz : std_logic;
	signal torsion2 : std_logic;
	signal xmxz, ymyz : std_logic;
	signal kap, kapp : std_logic;
	signal zu, zc : std_logic;
	signal r0z, r1z : std_logic;
	signal pts_are_equal : std_logic;
	signal pts_are_oppos : std_logic;
	signal phimsb : std_logic;
	signal kb0end : std_logic;
	signal ptadd : std_logic;
	-- signals between ecc_curve & ecc_curve_iram
	signal ire : std_logic;
	signal iraddr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal irdata : std_logic_vector(OPCODE_SZ - 1 downto 0);
	-- signals between ecc_curve & ecc_fp
	signal opi : opi_type;
	signal opo : opo_type;
	-- pragma translate_off
	signal pc : std_logic_vector (IRAM_ADDR_SZ - 1 downto 0);
	signal b : std_logic;
	signal bz : std_logic;
	signal bsn : std_logic;
	signal bodd : std_logic;
	signal call : std_logic;
	signal callsn : std_logic;
	signal ret : std_logic;
	signal retpc : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal nop : std_logic;
	signal imma : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal xr0addr : std_logic_vector(1 downto 0);
	signal yr0addr : std_logic_vector(1 downto 0);
	signal xr1addr : std_logic_vector(1 downto 0);
	signal yr1addr : std_logic_vector(1 downto 0);
	signal stop : std_logic;
	signal patching : std_logic;
	signal patchid : integer;
	-- pragma translate_on
	-- signals between ecc_fp & Montgomery-multpliers
	signal mmi : mmi_type;
	signal mmo : mmo_type;
	-- signals between ecc_axi & ecc_fp
	signal nndyn_nnrnd_mask : std_logic_vector(ww - 1 downto 0);
	signal nndyn_nnrnd_zerowm1 : std_logic;
	-- signals between ecc_axi and ecc_fp_dram
	signal xwe, xre : std_logic;
	signal xaddr : std_logic_vector(FP_ADDR - 1 downto 0);
	signal xwdata : std_logic_vector(ww - 1 downto 0);
	signal xrdata : std_logic_vector(ww - 1 downto 0);
	-- signals between ecc_fp & ecc_fp_dram
	signal fpre : std_logic;
	signal fpraddr : std_logic_vector(FP_ADDR - 1 downto 0);
	signal fprdata : std_logic_vector(ww - 1 downto 0);
	signal fpwe : std_logic;
	signal fpwaddr : std_logic_vector(FP_ADDR - 1 downto 0);
	signal fpwdata : std_logic_vector(ww - 1 downto 0);
	-- signals between ecc_scalar & ecc_fp (also driven to ecc_curve)
	signal compkp : std_logic;
	signal compcstmty : std_logic;
	signal comppop : std_logic;
	signal compaop : std_logic;
	signal token_generating : std_logic;
	-- signals between ecc_fp_scalar & ecc_fp_dram_sh
	-- (used only when shuffle_type /= none)
	signal permute : std_logic;
	signal permuterdy : std_logic;
	signal permuteundo : std_logic;
	-- signals between ecc_trng & entropy user ecc_axi
	signal trng_rdy_axi : std_logic;
	signal trng_valid_axi : std_logic;
	signal trng_data_axi : std_logic_vector(ww - 1 downto 0);
	signal trngaxiirncount : std_logic_vector(log2(irn_fifo_size_axi) - 1 downto 0);
	signal trngefpirncount : std_logic_vector(log2(irn_fifo_size_fp) - 1 downto 0);
	signal trngcurirncount : std_logic_vector(log2(irn_fifo_size_curve) - 1 downto 0);
	signal trngshfirncount : std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
	-- signals between ecc_trng & entropy user ecc_fp
	signal trng_rdy_fp : std_logic;
	signal trng_valid_fp : std_logic;
	signal trng_data_fp : std_logic_vector(ww - 1 downto 0);
	-- signals between ecc_trng & entropy user ecc_curve
	signal trng_rdy_curve : std_logic;
	signal trng_valid_curve : std_logic;
	signal trng_data_curve : std_logic_vector(1 downto 0);
	-- signals between ecc_trng & entropy user ecc_fp_dram_sh
	signal trng_rdy_sh : std_logic;
	signal trng_valid_sh : std_logic;
	signal trng_data_sh : std_logic_vector(irn_width_sh - 1 downto 0);
	-- debug features (signals between ecc_axi & ecc_scalar)
	signal dbgpgmstate : std_logic_vector(3 downto 0);
	signal dbgnbbits : std_logic_vector(15 downto 0);
	signal dbgnbstarvrndxyshuf : std_logic_vector(15 downto 0);
	signal dbghalted_s : std_logic;
	-- debug features (signals between ecc_axi & ecc_curve_iram)
	signal dbgiaddr : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal dbgiwdata : std_logic_vector(OPCODE_SZ - 1 downto 0);
	signal dbgiwe : std_logic;
	-- debug features (signals between ecc_axi & ecc_curve)
	signal dbgbreakpoints : breakpoints_type;
	signal dbgnbopcodes : std_logic_vector(15 downto 0);
	signal dbgdosomeopcodes : std_logic;
	signal dbgresume : std_logic;
	signal dbghalt : std_logic;
	signal dbgnoxyshuf : std_logic;
	signal dbgdecodepc : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	signal dbgbreakpointid : std_logic_vector(1 downto 0);
	signal dbgbreakpointhit : std_logic;
	-- debug features (signals between ecc_axi & ecc_fp)
	signal dbgtrnguse : std_logic;
	-- debug features (signals between ecc_axi & ecc_trng)
	signal dbgtrngta : unsigned(19 downto 0);
	signal dbgtrngrawreset : std_logic;
	signal dbgtrngirnreset : std_logic;
	signal dbgtrngrawfull : std_logic;
	signal dbgtrngrawwaddr : std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
	signal dbgtrngrawraddr : std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
	signal dbgtrngrawdata : std_logic;
	signal dbgtrngppdeact : std_logic;
	signal dbgtrngcompletebypass, dbgtrngcompletebypassbit : std_logic;
	signal dbgtrngrawduration : unsigned(31 downto 0);
	signal dbgtrngvonneuman : std_logic;
	signal dbgtrngidletime : unsigned(3 downto 0);

	-- pragma translate_off
	-- signals between ecc_scalar & ecc_fp (simu only)
	signal logr0r1 : std_logic;
	signal logr0r1step : natural;
	signal logfinalresult : std_logic;
	signal simbit : natural;
	-- signals between ecc_fp & ecc_fp_dram[_sh] (simu only)
	signal fpdram : fp_dram_type;
	signal fprwmask : std_logic_vector(FP_ADDR - 1 downto 0);
	signal vtophys : virt_to_phys_table_type;
	-- pragma translate_on

	signal rstn_resync0 : std_logic;
	signal rstn_resync1 : std_logic;
	signal s_axi_aresetn_rsh : std_logic_vector(2 downto 0);
	alias s_axi_aresetn_resync : std_logic is s_axi_aresetn_rsh(0);

	-- software reset (to other components of the IP)
	signal swrst : std_logic;

begin

	assert (axi32or64 = 32 or axi32or64 = 64)
		report "Wrong value of parameter axi32or64 in ecc_customize.vhd "
		     & "(must be 32 or 64)."
			severity FAILURE;

	-- This is to ensure that 'shuffle_type' = 'none' only if at the
	-- same time 'shuffle' = FALSE.
	assert ((shuffle and shuffle_type /= none) or (not shuffle))
		report "Static configuration of the shuffle countermeasure is inconsistent "
		     & "in ecc_customize.vhd: either 'shuffle'=FALSE and then it makes "
				 & "sense (though not mandatory) to set 'shuffle_type' to 'none'; or "
				 & "'shuffle'=TRUE but then you must set a value for 'shuffle_type' "
				 & "that is different from 'none'."
			severity FAILURE;

	-- force resynchronization of input reset s_axi_aresetn in the
	-- s_axi_aclk clock domain
	process(s_axi_aclk, s_axi_aresetn)
	begin
		if (s_axi_aresetn = '0') then
			s_axi_aresetn_rsh <= (others => '0');
		elsif s_axi_aclk'event and s_axi_aclk = '1' then
			s_axi_aresetn_rsh(s_axi_aresetn_rsh'length - 1 downto 0) <=
				'1' & s_axi_aresetn_rsh(s_axi_aresetn_rsh'length - 1 downto 1);
		end if;
	end process;

	-- AXI-lite interface
	a0: ecc_axi
		generic map(
			C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
			C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH)
		port map(
			-- AXI clock & reset
			s_axi_aclk => s_axi_aclk,
			s_axi_aresetn => s_axi_aresetn_resync,
			-- AXI write-address channel
			s_axi_awaddr => s_axi_awaddr,
			s_axi_awprot => s_axi_awprot,
			s_axi_awvalid => s_axi_awvalid,
			s_axi_awready => s_axi_awready,
			-- AXI write-data channel
			s_axi_wdata => s_axi_wdata,
			s_axi_wstrb => s_axi_wstrb,
			s_axi_wvalid => s_axi_wvalid,
			s_axi_wready => s_axi_wready,
			-- AXI write-response channel
			s_axi_bresp => s_axi_bresp,
			s_axi_bvalid => s_axi_bvalid,
			s_axi_bready => s_axi_bready,
			-- AXI read-address channel
			s_axi_araddr => s_axi_araddr,
			s_axi_arprot => s_axi_arprot,
			s_axi_arvalid => s_axi_arvalid,
			s_axi_arready => s_axi_arready,
			-- AXI read-data channel
			s_axi_rdata => s_axi_rdata,
			s_axi_rresp => s_axi_rresp,
			s_axi_rvalid => s_axi_rvalid,
			s_axi_rready => s_axi_rready,
			-- interrupt
			irq => irq_s,
			-- interface with ecc_scalar
			--   general
			initdone => initdone,
			ardy => ardy,
			aerr_inpt_not_on_curve => aerr_inpt_not_on_curve,
			aerr_outpt_not_on_curve => aerr_outpt_not_on_curve,
			aerr_inpt_ack => aerr_inpt_ack,
			aerr_outpt_ack => aerr_outpt_ack,
			ar01zien => ar01zien,
			ar0zi => ar0zi,
			ar1zi => ar1zi,
			ar0zo => ar0zo,
			ar1zo => ar1zo,
			--   [k]P computation
			agokp => agokp,
			kpdone => kpdone,
			doblinding => doblinding,
			blindbits => blindbits,
			doshuffle => doshuffle,
			k_is_null => k_is_null,
			small_k_sz_en => small_k_sz_en,
			small_k_sz_en_en => small_k_sz_en_en,
			small_k_sz => small_k_sz,
			small_k_sz_en_ack => small_k_sz_en_ack,
			small_k_sz_kpdone => small_k_sz_kpdone,
			tokenact => tokenact,
			zremaskact => zremaskact,
			zremaskbits => zremaskbits,
			--   Montgomery constants computation
			agocstmty => agocstmty,
			mtydone => mtydone,
			--   constant 'a' Montgomery transform
			agomtya => agomtya,
			amtydone => amtydone,
			--   other point-based computations
			dopop => dopop,
			popid => popid,
			popdone => popdone,
			yes => yes,
			yesen => yesen,
			--   arihtmetic computations
			doaop => doaop,
			aopid => aopid,
			aopdone => aopdone,
			--   token
			gentoken => gentoken,
			tokendone => tokendone,
			-- interface with ecc_curve
			masklsb => masklsb,
			-- interface with ecc_fp (access to ecc_fp_dram)
			xwe => xwe,
			xaddr => xaddr,
			xwdata => xwdata,
			xre => xre,
			xrdata => xrdata,
			nndyn_nnrnd_mask => nndyn_nnrnd_mask,
			nndyn_nnrnd_zerowm1 => nndyn_nnrnd_zerowm1,
			-- interface with ecc_trng
			trngvalid => trng_valid_axi,
			trngrdy => trng_rdy_axi,
			trngdata => trng_data_axi,
			trngaxiirncount => trngaxiirncount,
			trngefpirncount => trngefpirncount,
			trngcurirncount => trngcurirncount,
			trngshfirncount => trngshfirncount,
			-- broadcast interface to Montgomery multipliers
			pen => pen,
			nndyn_mask => nndyn_mask,
			nndyn_shrcnt => nndyn_shrcnt,
			nndyn_shlcnt => nndyn_shlcnt,
			nndyn_w => nndyn_w,
			nndyn_wm1 => nndyn_wm1,
			nndyn_wm2 => nndyn_wm2,
			nndyn_2wm1 => nndyn_2wm1,
			nndyn_wmin => nndyn_wmin,
			nndyn_wmin_excp_val => nndyn_wmin_excp_val,
			nndyn_wmin_excp => nndyn_wmin_excp,
			nndyn_mask_wm2 => nndyn_mask_wm2,
			nndyn_nnp1 => nndyn_nnp1,
			nndyn_nnm3 => nndyn_nnm3,
			-- general busy signal
			kppending => busy,
			-- software reset (to other components of the IP)
			swrst => swrst,
			-- debug features (interface with ecc_scalar)
			dbgpgmstate => dbgpgmstate,
			dbgnbbits => dbgnbbits,
			dbgnbstarvrndxyshuf => dbgnbstarvrndxyshuf,
			-- debug features (interface with ecc_curve)
			dbgbreakpoints => dbgbreakpoints,
			dbgnbopcodes => dbgnbopcodes,
			dbgdosomeopcodes => dbgdosomeopcodes,
			dbgresume => dbgresume,
			dbghalt => dbghalt,
			dbgnoxyshuf => dbgnoxyshuf,
			dbghalted => dbghalted_s,
			dbgdecodepc => dbgdecodepc,
			dbgbreakpointid => dbgbreakpointid,
			dbgbreakpointhit => dbgbreakpointhit,
			-- debug features (interface with ecc_curve_iram)
			dbgiaddr => dbgiaddr,
			dbgiwdata => dbgiwdata,
			dbgiwe => dbgiwe,
			-- debug features (interface with ecc_fp)
			dbgtrnguse => dbgtrnguse,
			-- debug features (interface with ecc_trng)
			dbgtrngta => dbgtrngta,
			dbgtrngrawreset => dbgtrngrawreset,
			dbgtrngirnreset => dbgtrngirnreset,
			dbgtrngrawfull => dbgtrngrawfull,
			dbgtrngrawwaddr => dbgtrngrawwaddr,
			dbgtrngrawraddr => dbgtrngrawraddr,
			dbgtrngrawdata => dbgtrngrawdata,
			dbgtrngppdeact => dbgtrngppdeact,
			dbgtrngcompletebypass => dbgtrngcompletebypass,
			dbgtrngcompletebypassbit => dbgtrngcompletebypassbit,
			dbgtrngrawduration => dbgtrngrawduration,
			dbgtrngvonneuman => dbgtrngvonneuman,
			dbgtrngidletime => dbgtrngidletime,
			-- handshake signals between entropy server ecc_trng
			-- and the different clients (for debug diagnostics)
			dbgtrngaxirdy => trng_rdy_axi,
			dbgtrngaxivalid => trng_valid_axi,
			dbgtrngfprdy => trng_rdy_fp,
			dbgtrngfpvalid => trng_valid_fp,
			dbgtrngcrvrdy => trng_rdy_curve,
			dbgtrngcrvvalid => trng_valid_curve,
			dbgtrngshrdy => trng_rdy_sh,
			dbgtrngshvalid => trng_valid_sh,
			-- debug feature (off-chip trigger)
			dbgtrigger => dbgtrigger
		); -- ecc_axi

	-- drive output irq
	irq <= irq_s;
	irqo <= irq_s;

	-- scalar arithmetic block
	s0: ecc_scalar
		port map(
			clk => s_axi_aclk,
			rstn => s_axi_aresetn_resync,
			swrst => swrst,
			-- interface with ecc_axi
			--   general
			initdone => initdone,
			ardy => ardy,
			aerr_inpt_not_on_curve => aerr_inpt_not_on_curve,
			aerr_outpt_not_on_curve => aerr_outpt_not_on_curve,
			aerr_inpt_ack => aerr_inpt_ack,
			aerr_outpt_ack => aerr_outpt_ack,
			ar01zien => ar01zien,
			ar0zi => ar0zi,
			ar1zi => ar1zi,
			ar0zo => ar0zo,
			ar1zo => ar1zo,
			nndyn_nnp1 => nndyn_nnp1,
			nndyn_nnm3 => nndyn_nnm3,
			--   [k]P computation
			agokp => agokp,
			kpdone => kpdone,
			doblinding => doblinding,
			blindbits => blindbits,
			doshuffle => doshuffle,
			k_is_null => k_is_null,
			small_k_sz_en => small_k_sz_en,
			small_k_sz_en_en => small_k_sz_en_en,
			small_k_sz => small_k_sz,
			small_k_sz_en_ack => small_k_sz_en_ack,
			small_k_sz_kpdone => small_k_sz_kpdone,
			tokenact => tokenact,
			zremaskact => zremaskact,
			zremaskbits => zremaskbits,
			--   Montgomery constants computation
			agocstmty => agocstmty,
			mtydone => mtydone,
			--   constant 'a' Montgomery transform
			agomtya => agomtya,
			amtydone => amtydone,
			--   other point-based computations
			dopop => dopop,
			popid => popid,
			popdone => popdone,
			yes => yes,
			yesen => yesen,
			--   arihtmetic computations
			doaop => doaop,
			aopid => aopid,
			aopdone => aopdone,
			--   token
			gentoken => gentoken,
			tokendone => tokendone,
			-- interface with ecc_curve
			initkp => initkp,
			frdy => frdy,
			fgo => fgo,
			faddr => faddr,
			ferr => ferr,
			zero => zero,
			laststep => laststep,
			firstzdbl => firstzdbl,
			firstzaddu => firstzaddu,
			iterate_shuffle_valid => iterate_shuffle_valid,
			iterate_shuffle_rdy => iterate_shuffle_rdy,
			iterate_shuffle_force => iterate_shuffle_force,
			first2pz => first2pz,
			first3pz => first3pz,
			torsion2 => torsion2,
			xmxz => xmxz,
			ymyz => ymyz,
			kap => kap,
			kapp => kapp,
			zu => zu,
			zc => zc,
			r0z => r0z,
			r1z => r1z,
			pts_are_equal => pts_are_equal,
			pts_are_oppos => pts_are_oppos,
			phimsb => phimsb,
			kb0end => kb0end,
			ptadd => ptadd,
			-- interface with ecc_fp
			compkp => compkp, -- also driven to ecc_curve
			compcstmty => compcstmty,
			comppop => comppop, -- also driven to ecc_curve
			compaop => compaop, -- also driven to ecc_curve
			token_generating => token_generating,
			-- interface with ecc_fp_dram_sh (used only when shuffle_type /= none)
			permute => permute,
			permuterdy => permuterdy,
			permuteundo => permuteundo,
			-- debug features (interface with ecc_axi)
			dbgpgmstate => dbgpgmstate,
			dbgnbbits => dbgnbbits,
			dbgnbstarvrndxyshuf => dbgnbstarvrndxyshuf
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			, logr0r1 => logr0r1,
			logr0r1step => logr0r1step,
			logfinalresult => logfinalresult,
			simbit => simbit
			-- pragma translate_on
		); -- ecc_scalar

	-- curve arithmetic programs/routines execution unit
	c0: ecc_curve
		port map(
			clk => s_axi_aclk,
			rstn => s_axi_aresetn_resync,
			swrst => swrst,
			-- interface with ecc_axi
			masklsb => masklsb,
			doblinding => doblinding,
			-- interface with ecc_scalar
			frdy => frdy,
			fgo => fgo,
			faddr => faddr,
			initkp => initkp,
			ferr => ferr,
			zero => zero,
			laststep => laststep,
			firstzdbl => firstzdbl,
			firstzaddu => firstzaddu,
			iterate_shuffle_valid => iterate_shuffle_valid,
			iterate_shuffle_rdy => iterate_shuffle_rdy,
			iterate_shuffle_force => iterate_shuffle_force,
			first2pz => first2pz,
			first3pz => first3pz,
			torsion2 => torsion2,
			xmxz => xmxz,
			ymyz => ymyz,
			kap => kap,
			kapp => kapp,
			zu => zu,
			zc => zc,
			r0z => r0z,
			r1z => r1z,
			pts_are_equal => pts_are_equal,
			pts_are_oppos => pts_are_oppos,
			phimsb => phimsb,
			kb0end => kb0end,
			ptadd => ptadd,
			-- interface with ecc_curve_iram
			ire => ire,
			iraddr => iraddr,
			irdata => irdata,
			-- interface with ecc_fp
			opi => opi,
			opo => opo,
			-- interface with mm_ndsp(s)
			ppen => ppen,
			-- interface with ecc_trng
			trng_rdy => trng_rdy_curve,
			trng_valid => trng_valid_curve,
			trng_data => trng_data_curve,
			-- debug features (interface with ecc_axi)
			dbgbreakpoints => dbgbreakpoints,
			dbgnbopcodes => dbgnbopcodes,
			dbgdosomeopcodes => dbgdosomeopcodes,
			dbgresume => dbgresume,
			dbghalt => dbghalt,
			dbgnoxyshuf => dbgnoxyshuf,
			dbghalted => dbghalted_s,
			dbgdecodepc => dbgdecodepc,
			dbgbreakpointid => dbgbreakpointid,
			dbgbreakpointhit => dbgbreakpointhit,
			-- debug features (interface with ecc_scalar)
			dbgpgmstate => dbgpgmstate,
			dbgnbbits => dbgnbbits
			-- pragma translate_off
			,pc => pc,
			b => b,
			bz => bz,
			bsn => bsn,
			bodd => bodd,
			call => call,
			callsn => callsn,
			ret => ret,
			retpc => retpc,
			nop => nop,
			imma => imma,
			xr0addr => xr0addr,
			yr0addr => yr0addr,
			xr1addr => xr1addr,
			yr1addr => yr1addr,
			stop => stop,
			patching => patching,
			patchid => patchid
			-- pragma translate_on
		); -- ecc_curve

	-- static memory storing programs
	-- (the ones executed by ecc_curve)
	i0: ecc_curve_iram
		generic map(
			rdlat => sramlat)
		port map(
			-- port A: write-only interface to AXI-lite interface
			clka => s_axi_aclk,
			wea => dbgiwe,
			addra => dbgiaddr,
			dia => dbgiwdata,
			-- port B: read-only interface to ecc_curve
			clkb => s_axi_aclk,
			reb => ire,
			addrb => iraddr,
			dob => irdata
		); -- ecc_curve_iram

	-- prime field arithmetic (unit controlling arithmetic operations
	-- submitted by ecc_curve while executing programs/routines)
	f0: ecc_fp
		port map(
			clk => s_axi_aclk,
			rstn => s_axi_aresetn_resync,
			swrst => swrst,
			-- interface with ecc_curve
			opi => opi,
			opo => opo,
			-- interface with multipliers
			mmi => mmi,
			mmo => mmo,
			-- interface with ecc_fp_dram
			fpre => fpre,
			fpraddr => fpraddr,
			fprdata => fprdata,
			fpwe => fpwe,
			fpwaddr => fpwaddr,
			fpwdata => fpwdata,
			-- interface with AXI-lite
			xwe => xwe,
			xaddr => xaddr,
			xwdata => xwdata,
			xre => xre,
			xrdata => xrdata,
			nndyn_nnrnd_mask => nndyn_nnrnd_mask,
			nndyn_nnrnd_zerowm1 => nndyn_nnrnd_zerowm1,
			nndyn_wm1 => nndyn_wm1,
			nndyn_2wm1 => nndyn_2wm1,
			-- pragma translate_off
			nndyn_w => nndyn_w,
			-- pragma translate_on
			-- interface with ecc_trng
			trngvalid => trng_valid_fp,
			trngrdy => trng_rdy_fp,
			trngdata => trng_data_fp,
			-- interface with ecc_scalar
			initkp => initkp,
			compkp => compkp,
			compcstmty => compcstmty,
			comppop => comppop,
			compaop => compaop,
			token_generating => token_generating,
			-- debug feature (interface with ecc_axi)
			dbgtrnguse => dbgtrnguse,
			-- debug feature (ecc_scalar)
			dbghalted => dbghalted_s
			-- pragma translate_off
			-- interface with ecc_scalar (simu only)
			, logr0r1 => logr0r1,
			logr0r1step => logr0r1step,
			logfinalresult => logfinalresult,
			simbit => simbit,
			-- interface with ecc_curve (simu only)
			pc => pc,
			b => b,
			bz => bz,
			bsn => bsn,
			bodd => bodd,
			call => call,
			callsn => callsn,
			ret => ret,
			retpc => retpc,
			nop => nop,
			imma => imma,
			kap => kap,
			kapp => kapp,
			xr0addr => xr0addr,
			yr0addr => yr0addr,
			xr1addr => xr1addr,
			yr1addr => yr1addr,
			r0z => r0z,
			r1z => r1z,
			stop => stop,
			patching => patching,
			patchid => patchid,
			-- interface with ecc_fp_dram or ecc_fp_dram_sh (simu only)
			fpdram => fpdram,
			fprwmask => fprwmask,
			vtophys => vtophys
			-- pragma translate_on
		); -- ecc_fp

	-- TRNG
	t0: ecc_trng
		port map(
			clk => s_axi_aclk,
			rstn => s_axi_aresetn_resync,
			swrst => swrst,
			-- interface with ecc_scalar
			irn_reset => dbgtrngirnreset,
			-- interface with entropy client ecc_axi
			rdy0 => trng_rdy_axi,
			valid0 => trng_valid_axi,
			data0 => trng_data_axi,
			irncount0 => trngaxiirncount,
			-- interface with entropy client ecc_fp
			rdy1 => trng_rdy_fp,
			valid1 => trng_valid_fp,
			data1 => trng_data_fp,
			irncount1 => trngefpirncount,
			-- interface with entropy client ecc_curve
			rdy2 => trng_rdy_curve,
			valid2 => trng_valid_curve,
			data2 => trng_data_curve,
			irncount2 => trngcurirncount,
			-- interface with entropy client ecc_fp_dram_sh
			rdy3 => trng_rdy_sh,
			valid3 => trng_valid_sh,
			data3 => trng_data_sh,
			irncount3 => trngshfirncount,
			-- interface with ecc_axi (only usable in debug mode)
			dbgtrngta => dbgtrngta,
			dbgtrngrawreset => dbgtrngrawreset,
			dbgtrngrawfull => dbgtrngrawfull,
			dbgtrngrawwaddr => dbgtrngrawwaddr,
			dbgtrngrawraddr => dbgtrngrawraddr,
			dbgtrngrawdata => dbgtrngrawdata,
			dbgtrngppdeact => dbgtrngppdeact,
			dbgtrngcompletebypass => dbgtrngcompletebypass,
			dbgtrngcompletebypassbit => dbgtrngcompletebypassbit,
			dbgtrngrawduration => dbgtrngrawduration,
			dbgtrngvonneuman => dbgtrngvonneuman,
			dbgtrngidletime => dbgtrngidletime
		); -- ecc_trng

	-- static-memory storing temporary variables read-&-written
	-- by instructions of programs executed by ecc_curve
	d0 : if shuffle_type = none generate
		d0: ecc_fp_dram
			generic map(
				rdlat => sramlat)
			port map(
				clk => s_axi_aclk,
				-- port A: write-only interface to ecc_fp
				-- (actually for write-access from AXI-lite interface)
				wea => fpwe,
				addra => fpwaddr,
				dia => fpwdata,
				-- port B: read-only interface to ecc_fp
				reb => fpre,
				addrb => fpraddr,
				dob => fprdata
				-- pragma translate_off
				-- interface with ecc_fp (simu only)
				, fpdram => fpdram
				-- pragma translate_on
			); -- ecc_fp_dram
	end generate;

	-- same feature as ecc_fp_dram for the address
	-- shuffling countermeasure
	ds0: if shuffle_type /= none generate

		ds0: if shuffle_type = linear generate
			ds0: ecc_fp_dram_sh_linear
				generic map(
					rdlat => sramlat)
				port map(
					clk => s_axi_aclk,
					rstn => s_axi_aresetn_resync,
					swrst => swrst,
					-- port A: write-only interface to ecc_fp
					-- (actually for write-access from AXI-lite interface)
					wea => fpwe,
					addra => fpwaddr,
					dia => fpwdata,
					-- port B: read-only interface to ecc_fp
					reb => fpre,
					addrb => fpraddr,
					dob => fprdata,
					-- interface with ecc_scalar
					permute => permute,
					permuterdy => permuterdy,
					permuteundo => permuteundo,
					-- interface with ecc_trng
					trngvalid => trng_valid_sh,
					trngrdy => trng_rdy_sh,
					trngdata => trng_data_sh
					-- pragma translate_off
					-- interface with ecc_fp (simu only)
					, fpdram => fpdram,
					fprwmask => fprwmask
					-- pragma translate_on
				); -- ecc_fp_dram_sh_linear
		end generate;

		ds1: if shuffle_type = permute_lgnb generate
			ds1: ecc_fp_dram_sh_fishy_nb
				generic map(
					rdlat => sramlat)
				port map(
					clk => s_axi_aclk,
					rstn => s_axi_aresetn_resync,
					swrst => swrst,
					-- port A: write-only interface to ecc_fp
					-- (actually for write-access from AXI-lite interface)
					wea => fpwe,
					addra => fpwaddr,
					dia => fpwdata,
					-- port B: read-only interface to ecc_fp
					reb => fpre,
					addrb => fpraddr,
					dob => fprdata,
					-- interface with ecc_axi
					nndyn_wm1 => nndyn_wm1,
					-- interface with ecc_scalar
					permute => permute,
					permuterdy => permuterdy,
					-- interface with ecc_trng
					trngvalid => trng_valid_sh,
					trngrdy => trng_rdy_sh,
					trngdata => trng_data_sh
					-- pragma translate_off
					-- interface with ecc_fp (simu only)
					, fpdram => fpdram,
					vtophys => vtophys
					-- pragma translate_on
				); -- ecc_fp_dram_sh_fishy_nb
		end generate;

		ds2: if shuffle_type = permute_limbs generate
			ds2: ecc_fp_dram_sh_fishy
				generic map(
					rdlat => sramlat)
				port map(
					clk => s_axi_aclk,
					rstn => s_axi_aresetn_resync,
					swrst => swrst,
					-- port A: write-only interface to ecc_fp
					-- (actually for write-access from AXI-lite interface)
					wea => fpwe,
					addra => fpwaddr,
					dia => fpwdata,
					-- port B: read-only interface to ecc_fp
					reb => fpre,
					addrb => fpraddr,
					dob => fprdata,
					-- interface with ecc_scalar
					permute => permute,
					permuterdy => permuterdy,
					-- interface with ecc_trng
					trngvalid => trng_valid_sh,
					trngrdy => trng_rdy_sh,
					trngdata => trng_data_sh
					-- pragma translate_off
					-- interface with ecc_fp (simu only)
					, fpdram => fpdram,
					vtophys => vtophys
					-- pragma translate_on
				); -- ecc_fp_dram_sh_fishy
		end generate;

	end generate;

	ds0_n: if shuffle_type = none generate
		trng_rdy_sh <= '0';
	end generate;

	-- Montgomery-multipliers instanciation loop
	mm: for i in 0 to nbmult - 1 generate
		mmmi: mm_ndsp
			port map(
				clkmm => clkmm,
				clk => s_axi_aclk,
				rstn => s_axi_aresetn_resync,
				swrst => swrst,
				go => mmi(i).go,
				rdy => mmo(i).rdy,
				-- input data
				xyin => mmi(i).xy,
				xen => mmi(i).xen,
				yen => mmi(i).yen,
				fpwdata => fpwdata,
				fpwe => fpwe,
				pen => pen,
				nndyn_mask => nndyn_mask,
				nndyn_shrcnt => nndyn_shrcnt,
				nndyn_shlcnt => nndyn_shlcnt,
				nndyn_w => nndyn_w,
				nndyn_wm1 => nndyn_wm1,
				nndyn_wm2 => nndyn_wm2,
				nndyn_2wm1 => nndyn_2wm1,
				nndyn_wmin => nndyn_wmin,
				nndyn_wmin_excp_val => nndyn_wmin_excp_val,
				nndyn_wmin_excp => nndyn_wmin_excp,
				nndyn_mask_wm2 => nndyn_mask_wm2,
				-- interface with ecc_curve
				ppen => ppen,
				-- output data
				z => mmo(i).z,
				zren => mmi(i).zren,
				irq => mmo(i).irq,
				go_ack => mmo(i).go_ack,
				irq_ack => mmi(i).irq_ack
			); -- mm_ndsp
	end generate;

	dbghalted <= dbghalted_s;

	-- pragma translate_off
	process
	begin
		-- 1st console log line (general settings)
		echo("ECC: nn = ");
		echo(integer'image(nn));
		echo(" (nn_dynamic ");
		if nn_dynamic then
			echo("ON)");
		else
			echo("OFF)");
		end if;
		echo(", ww = ");
		echo(integer'image(ww));
		echo(", w = ");
		echo(integer'image(w));
		echo(" (n = ");
		echo(integer'image(n));
		echo("), ndsp = ");
		echo(integer'image(ndsp));
		echo(", sram lat = ");
		echo(integer'image(sramlat));
		echo(", async = ");
		if async then
			echo("TRUE");
		else
			echo("FALSE");
		end if;
		if shuffle_type /= none then
			echo(", shuffle AVAIL (");
			if shuffle_type = linear then
				echo("linear address masking)");
			elsif shuffle_type = permute_lgnb then
				echo("permutation of large numbers)");
			elsif shuffle_type = permute_limbs then
				echo("permutation of large numbers' internal limbs)");
			end if;
			if shuffle then
				echo(" and ON");
			else
				echo(" but OFF at reset");
			end if;
		else
			echo(", no shuffle avail");
		end if;
		echo(", debug ");
		if debug then
			echo("ON");
		else
			echo("OFF");
		end if;
		if (simkb > 0) then
			echo(", simu only ");
			echo(integer'image(simkb));
			echol(" bits of k");
		else
			echol("");
		end if;
		-- 2nd console log line (ecc_curve_iram & ecc_fp settings)
		echo("ECC: microcode memory size: ");
		echo(integer'image(ge_pow_of_2(nbopcodes)));
		echo(" opcodes of ");
		echo(integer'image(OPCODE_SZ));
		echo("-bit, data memory: ");
		echo(integer'image(ge_pow_of_2(nblargenb)));
		echol(" large-numbers");
		-- 3rd console log line (TRNG fifos)
		echo("ECC: trng fifo sizes: raw=");
		echo(integer'image(raw_ram_size));
		echo("-bit, irn axi=");
		echo(integer'image(irn_fifo_size_axi));
		echo(" words of ");
		echo(integer'image(ww));
		echo("-bit, irn fp=");
		echo(integer'image(irn_fifo_size_fp));
		echo(" words of ");
		echo(integer'image(ww));
		echo("-bit, irn curve=");
		echo(integer'image(irn_fifo_size_curve));
		echo(" words of ");
		echo(integer'image(2));
		echo("-bit, irn sh=");
		echo(integer'image(irn_fifo_size_sh));
		echo(" words of ");
		echo(integer'image((irn_width_sh)));
		echol("-bit");
		wait;
	end process;
	-- pragma translate_on

end architecture struct;
