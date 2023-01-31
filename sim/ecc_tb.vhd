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

use work.ecc_custom.all; -- for 'nn' & 'nn_dynamic'
use work.ecc_utils.all; -- for div()
use work.ecc_pkg.all;

use std.textio.all;

entity ecc_tb is
end entity ecc_tb;

architecture sim of ecc_tb is

	-- DuT component declaration
	component ecc is
		generic(
			-- Width of S_AXI data bus
			C_S_AXI_DATA_WIDTH : integer := 32;
			-- Width of S_AXI address bus
			C_S_AXI_ADDR_WIDTH : integer := 8
			);
		port(
			-- AXI clock & reset
			s_axi_aclk : in  std_logic;
			s_axi_aresetn : in std_logic; -- asyn asserted, syn deasserted, active low
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
			--  AXI read-data channel
			s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			s_axi_rresp : out std_logic_vector(1 downto 0);
			s_axi_rvalid : out std_logic;
			s_axi_rready : in std_logic;
			-- clock for Montgomery multipliers in the async case
			clkmm : in std_logic;
			-- interrupt
			irq : out std_logic;
			irqo : out std_logic;
			-- general busy signal
			busy : out std_logic;
			-- debug feature (off-chip trigger)
			dbgtrigger : out std_logic;
			dbghalted : out std_logic
		);
	end component ecc;

	-- AXI clock & reset
	signal s_axi_aclk, s_axi_aresetn : std_logic;
	-- AXI write-address channel
	signal s_axi_awaddr : std_logic_vector(7 downto 0);
	signal s_axi_awprot : std_logic_vector(2 downto 0); -- ignored
	signal s_axi_awvalid : std_logic;
	signal s_axi_awready : std_logic;
	-- AXI write-data channel
	signal s_axi_wdata : std_logic_vector(AXIDW - 1 downto 0);
	signal s_axi_wstrb : std_logic_vector((AXIDW/8)-1 downto 0);
	signal s_axi_wvalid : std_logic;
	signal s_axi_wready : std_logic;
	-- AXI write-response channel
	signal s_axi_bresp : std_logic_vector(1 downto 0);
	signal s_axi_bvalid : std_logic;
	signal s_axi_bready : std_logic;
	-- AXI read-address channel
	signal s_axi_araddr : std_logic_vector(7 downto 0);
	signal s_axi_arprot : std_logic_vector(2 downto 0); -- ignored
	signal s_axi_arvalid : std_logic;
	signal s_axi_arready : std_logic;
	-- AXI read-data channel
	signal s_axi_rdata : std_logic_vector(31 downto 0);
	signal s_axi_rresp : std_logic_vector(1 downto 0);
	signal s_axi_rvalid : std_logic;
	signal s_axi_rready : std_logic;

	signal clkmm : std_logic;

	-- 512 bit is assumed to be the maximum value of nn that might be
	-- simulated, therefore all curve parameters, whatever their size
	-- (all smaller than 512) are encoded as 512-bit large numbers
	-- ('std_logic512' is defined in ecc_pkg.vhd pacakge)
	type curve_param_type is array(integer range 0 to 3) of std_logic512;

	-- BRAINPOOL512R1 curve parameters (nn = 512) ---------------------------
	constant BIG_P_BPOOL512R1 : std_logic512 :=
		x"aadd9db8dbe9c48b3fd4e6ae33c9fc07cb308db3b3c9d20ed6639cca70330871"
	& x"7d4d9b009bc66842aecda12ae6a380e62881ff2f2d82c68528aa6056583a48f3";
	constant BIG_A_BPOOL512R1 : std_logic512 :=
		x"7830a3318b603b89e2327145ac234cc594cbdd8d3df91610a83441caea9863bc"
	& x"2ded5d5aa8253aa10a2ef1c98b9ac8b57f1117a72bf2c7b9e7c1ac4d77fc94ca";
	constant BIG_B_BPOOL512R1 : std_logic512 :=
		x"3df91610a83441caea9863bc2ded5d5aa8253aa10a2ef1c98b9ac8b57f1117a7"
	& x"2bf2c7b9e7c1ac4d77fc94cadc083e67984050b75ebae5dd2809bd638016f723";
	constant BIG_Q_BPOOL512R1 : std_logic512 :=
		x"aadd9db8dbe9c48b3fd4e6ae33c9fc07cb308db3b3c9d20ed6639cca70330870"
	& x"553e5c414ca92619418661197fac10471db1d381085ddaddb58796829ca90069";
	constant BIG_XP_BPOOL512R1 : std_logic512 :=
		x"81aee4bdd82ed9645a21322e9c4c6a9385ed9f70b5d916c1b43b62eef4d0098e"
	& x"ff3b1f78e2d0d48d50d1687b93b97d5f7c6d5047406a5e688b352209bcb9f822";
	constant BIG_YP_BPOOL512R1 : std_logic512 :=
		x"7dde385d566332ecc0eabfa9cf7822fdf209f70024a57b1aa000c55b881f8111"
	& x"b2dcde494a5f485e5bca4bd88a2763aed1ca2b2fa8f0540678cd1e0f3ad80892";
	constant CURVE_PARAM_512 : curve_param_type :=
		(0 => BIG_P_BPOOL512R1,
		 1 => BIG_A_BPOOL512R1,
		 2 => BIG_B_BPOOL512R1,
		 3 => BIG_Q_BPOOL512R1);
	-- end of BRAINPOOL512R1 curve parameters -------------------------------

	-- BRAINPOOL384R1 curve parameters (nn = 384) ---------------------------
	constant BIG_P_BPOOL384R1 : std_logic512 :=
		x"000000000000000000000000000000008cb91e82a3386d280f5d6f7e50e641df"
	& x"152f7109ed5456b412b1da197fb71123acd3a729901d1a71874700133107ec53";
	constant BIG_A_BPOOL384R1 : std_logic512 :=
		x"000000000000000000000000000000007bc382c63d8c150c3c72080ace05afa0"
	& x"c2bea28e4fb22787139165efba91f90f8aa5814a503ad4eb04a8c7dd22ce2826";
	constant BIG_B_BPOOL384R1 : std_logic512 :=
		x"0000000000000000000000000000000004a8c7dd22ce28268b39b55416f0447c"
	& x"2fb77de107dcd2a62e880ea53eeb62d57cb4390295dbc9943ab78696fa504c11";
	constant BIG_Q_BPOOL384R1 : std_logic512 :=
		x"000000000000000000000000000000008cb91e82a3386d280f5d6f7e50e641df"
	& x"152f7109ed5456b31f166e6cac0425a7cf3ab6af6b7fc3103b883202e9046565";
	constant BIG_XP_BPOOL384R1 : std_logic512 :=
		x"000000000000000000000000000000001d1c64f068cf45ffa2a63a81b7c13f6b"
	& x"8847a3e77ef14fe3db7fcafe0cbd10e8e826e03436d646aaef87b2e247d4af1e";
	constant BIG_YP_BPOOL384R1 : std_logic512 :=
		x"000000000000000000000000000000008abe1d7520f9c2a45cb1eb8e95cfd552"
	& x"62b70b29feec5864e19c054ff99129280e4646217791811142820341263c5315";
	constant CURVE_PARAM_384 : curve_param_type :=
		(0 => BIG_P_BPOOL384R1,
		 1 => BIG_A_BPOOL384R1,
		 2 => BIG_B_BPOOL384R1,
		 3 => BIG_Q_BPOOL384R1);
	-- end of BRAINPOOL384R1 curve parameters -------------------------------

	-- BRAINPOOL320R1 curve parameters (nn = 320 )---------------------------
	constant BIG_P_BPOOL320R1 : std_logic512 :=
		x"000000000000000000000000000000000000000000000000d35e472036bc4fb7"
	& x"e13c785ed201e065f98fcfa6f6f40def4f92b9ec7893ec28fcd412b1f1b32e27";
	constant BIG_A_BPOOL320R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000003ee30b568fbab0f8"
	& x"83ccebd46d3f3bb8a2a73513f5eb79da66190eb085ffa9f492f375a97d860eb4";
	constant BIG_B_BPOOL320R1 : std_logic512 :=
		x"000000000000000000000000000000000000000000000000520883949dfdbc42"
	& x"d3ad198640688a6fe13f41349554b49acc31dccd884539816f5eb4ac8fb1f1a6";
	constant BIG_Q_BPOOL320R1 : std_logic512 :=
		x"000000000000000000000000000000000000000000000000d35e472036bc4fb7"
	& x"e13c785ed201e065f98fcfa5b68f12a32d482ec7ee8658e98691555b44c59311";
	constant BIG_XP_BPOOL320R1 : std_logic512 :=
		x"00000000000000000000000000000000000000000000000043bd7e9afb53d8b8"
	& x"5289bcc48ee5bfe6f20137d10a087eb6e7871e2a10a599c710af8d0d39e20611";
	constant BIG_YP_BPOOL320R1 : std_logic512 :=
		x"00000000000000000000000000000000000000000000000014fdd05545ec1cc8"
	& x"ab4093247f77275e0743ffed117182eaa9c77877aaac6ac7d35245d1692e8ee1";
	constant CURVE_PARAM_320 : curve_param_type :=
		(0 => BIG_P_BPOOL320R1,
		 1 => BIG_A_BPOOL320R1,
		 2 => BIG_B_BPOOL320R1,
		 3 => BIG_Q_BPOOL320R1);
	-- end of BRAINPOOL320R1 curve parameters -------------------------------

	-- FRP256v1 curve parameters (nn = 256) ---------------------------------
	constant BIG_P_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"f1fd178c0b3ad58f10126de8ce42435b3961adbcabc8ca6de8fcf353d86e9c03";
	constant BIG_A_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"f1fd178c0b3ad58f10126de8ce42435b3961adbcabc8ca6de8fcf353d86e9c00";
	constant BIG_B_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"ee353fca5428a9300d4aba754a44c00fdfec0c9ae4b1a1803075ed967b7bb73f";
	constant BIG_Q_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"f1fd178c0b3ad58f10126de8ce42435b53dc67e140d2bf941ffdd459c6d655e1";
	constant BIG_XP_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"b6b3d4c356c139eb31183d4749d423958c27d2dcaf98b70164c97a2dd98f5cff";
	constant BIG_YP_FRP256v1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"6142e0f7c8b204911f9271f0f3ecef8c2701c307e8e4c9e183115a1554062cfb";
	constant CURVE_PARAM_256 : curve_param_type :=
		(0 => BIG_P_FRP256v1,
		 1 => BIG_A_FRP256v1,
		 2 => BIG_B_FRP256v1,
		 3 => BIG_Q_FRP256v1);
	-- end of FRP256v1 curve parameters -------------------------------------

	-- BRAINPOOL224R1 curve parameters (nn = 224) ---------------------------
	constant BIG_P_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"00000000d7c134aa264366862a18302575d1d787b09f075797da89f57ec8c0ff";
	constant BIG_A_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000068a5e62ca9ce6c1c299803a6c1530b514e182ad8b0042a59cad29f43";
	constant BIG_B_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000002580f63ccfe44138870713b1a92369e33e2135d266dbb372386c400b";
	constant BIG_Q_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"00000000d7c134aa264366862a18302575d0fb98d116bc4b6ddebca3a5a7939f";
	constant BIG_XP_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000d9029ad2c7e5cf4340823b2a87dc68c9e4ce3174c1e6efdee12c07d";
	constant BIG_YP_BPOOL224R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000058aa56f772c0726f24c6b89e4ecdac24354b9e99caa3f6d3761402cd";
	constant CURVE_PARAM_224 : curve_param_type :=
		(0 => BIG_P_BPOOL224R1,
		 1 => BIG_A_BPOOL224R1,
		 2 => BIG_B_BPOOL224R1,
		 3 => BIG_Q_BPOOL224R1);
	-- end of BRAINPOOL224R1 curve parameters -------------------------------

	-- BRAINPOOL192R1 curve parameters (nn = 192) ---------------------------
constant BIG_P_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000c302f41d932a36cda7a3463093d18db78fce476de1a86297";
	constant BIG_A_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"00000000000000006a91174076b1e0e19c39c031fe8685c1cae040e5c69a28ef";
	constant BIG_B_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000469a28ef7c28cca3dc721d044f4496bcca7ef4146fbf25c9";
	constant BIG_Q_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000c302f41d932a36cda7a3462f9e9e916b5be8f1029ac4acc1";
	constant BIG_XP_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000c0a0647eaab6a48753b033c56cb0f0900a2f5c4853375fd6";
	constant BIG_YP_BPOOL192R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000000000014b690866abd5bb88b5f4828c1490002e6773fa2fa299b8f";
	constant CURVE_PARAM_192 : curve_param_type :=
		(0 => BIG_P_BPOOL192R1,
		 1 => BIG_A_BPOOL192R1,
		 2 => BIG_B_BPOOL192R1,
		 3 => BIG_Q_BPOOL192R1);
	-- end of BRAINPOOL192R1 curve parameters -------------------------------

	-- BRAINPOOL160R1 curve parameters (nn = 160) ---------------------------
	constant BIG_P_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000000000000000000e95e4a5f737059dc60dfc7ad95b3d8139515620f";
	constant BIG_A_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000000000000000000340e7be2a280eb74e2be61bada745d97e8f7c300";
	constant BIG_B_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000000000001e589a8595423412134faa2dbdec95c8d8675e58";
	constant BIG_Q_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000000000000000000e95e4a5f737059dc60df5991d45029409e60fc09";
	constant BIG_XP_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"000000000000000000000000bed5af16ea3f6a4f62938c4631eb5af7bdbcdbc3";
	constant BIG_YP_BPOOL160R1 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000000000001667cb477a1a8ec338f94741669c976316da6321";
	constant CURVE_PARAM_160 : curve_param_type :=
		(0 => BIG_P_BPOOL160R1,
		 1 => BIG_A_BPOOL160R1,
		 2 => BIG_B_BPOOL160R1,
		 3 => BIG_Q_BPOOL160R1);
	-- another point (= [12]P with P = (BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1))
	constant BIG_X160_12P : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000000000006248702007211c3aaff765138ab609014e3d9614";
	constant BIG_Y160_12P : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"00000000000000000000000069298b399fcf1a982e90e5c3fe039f179fdb406a";
	-- end of BRAINPOOL160R1 curve parameters -------------------------------

	-- some scalars ---------------------------------------------------------
	constant SCALAR_K512 : std_logic512 :=
		x"a247dd445f93b085b804f0748493d353a8f51b1922b8ba68df6ce35b00364c0a"
	& x"ea25b7d854721594219a259bf66bbca76d7adb6d23262cbdfa51e13602e2113a";
	constant SCALAR_K384 : std_logic512 :=
		x"0000000000000000000000000000000071b91e82a3386d280f5d6f7e50e641df"
	& x"152f7109ed5456b31f166e6cac0425a7cf3ab6af6b7fc3103b883202e9046565";
	constant SCALAR_K320 : std_logic512 :=
		x"00000000000000000000000000000000000000000000000071f60ecf6f4a75b0"
	& x"8022b5cc85deb00b060eb483a06ab83d48a4980f4f8c9f0bdbe646586b834660";
	constant SCALAR_K256 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"f1adb2506355162d0de14468748fb171f730bd40f6595fe1732651df00589fcf";
	constant SCALAR_K224 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"00000000eee115c13ee411dfd929705cd83876727fa9c22d315abbc6bcd34576";
	constant SCALAR_K192 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000e0ed258a2778c759153d6243591938cc0ce6ac65af6ecd3b";
	constant SCALAR_K160 : std_logic512 :=
		x"0000000000000000000000000000000000000000000000000000000000000000"
	& x"0000000000000000000000005e98fab1e81df9fc17d528542f81c358dc7f91e6";
	-------------------------------------------------------------------------

	type curve_param_addr_type is
		array(integer range 0 to 3) of integer;
	constant CURVE_PARAM_ADDR : curve_param_addr_type :=
		(0 => LARGE_NB_P_ADDR,
		 1 => LARGE_NB_A_ADDR,
		 2 => LARGE_NB_B_ADDR,
		 3 => LARGE_NB_Q_ADDR);

	signal nn_s : integer range 1 to nn;

begin

	-- emulate AXI reset
	process
	begin
		s_axi_aresetn <= '0';
		wait for 333 ns;
		s_axi_aresetn <= '1';
		wait;
	end process;

	-- emulate AXI clock (100 MHz)
	process
	begin
		s_axi_aclk <= '0';
		wait for 5 ns;
		s_axi_aclk <= '1';
		wait for 5 ns;
	end process;

	-- emulate clkmm clock (250 MHz)
	process
	begin
		clkmm <= '0';
		wait for 2 ns;
		clkmm <= '1';
		wait for 2 ns;
	end process;

	-- DuT instance
	e0: ecc
		generic map(
			C_S_AXI_DATA_WIDTH => AXIDW,
			C_S_AXI_ADDR_WIDTH => 8)
		port map(
			-- AXI clock & reset
			s_axi_aclk => s_axi_aclk,
			s_axi_aresetn => s_axi_aresetn,
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
			--  AXI read-data channel
			s_axi_rdata => s_axi_rdata,
			s_axi_rresp => s_axi_rresp,
			s_axi_rvalid => s_axi_rvalid,
			s_axi_rready => s_axi_rready,
			-- clock for Montgomery multipliers in the async case
			clkmm => clkmm,
			-- interrupt
			irq => open,
			irqo => open,
			-- general busy signal
			busy => open,
			-- debug feature (off-chip trigger)
			dbgtrigger => open,
			dbghalted => open
		);

	-- emulation of stimuli signals
	process
		variable v_debug_reg : std_logic_vector(31 downto 0);
		-- -------------------------------------------------------------
		-- emulate SW polling the R_STATUS register until it shows ready
		-- -------------------------------------------------------------
		procedure poll_until_ready is
		begin
			loop
				wait until s_axi_aclk'event and s_axi_aclk = '1';
				-- read R_STATUS register
				s_axi_araddr <= R_STATUS & "000";
				s_axi_arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
				s_axi_araddr <= "XXXXXXXX";
				s_axi_arvalid <= '0';
				s_axi_rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
				s_axi_rready <= '0';
				if s_axi_rdata(STATUS_BUSY) = '0' then
					-- means bit 'busy' is deasserted
					exit;
				end if;
			end loop;
		end procedure;
		-- -------------------------------------------------
		-- emulate SW writing prime size (nn)
		--   (option nn_dynamic = TRUE in ecc_customize.vhd)
		-- -------------------------------------------------
		procedure set_nn(valnn : positive) is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write PRIME_SIZE register
			s_axi_awaddr <= W_PRIME_SIZE & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(valnn, AXIDW));
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -----------------------------------
		-- emulate SW writing one large number (except the scalar)
		-- -----------------------------------
		procedure write_big(valnn : positive;
			addr : in natural range 0 to nblargenb - 1; val : in std_logic_vector)
		is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			poll_until_ready;
			-- write W_CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= (others => 'X'); s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_WRITE_NB) := '1';
			dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
				:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			-- now perform the proper nb of writes of the W_WRITE_DATA register
			for i in 0 to div(valnn,AXIDW) - 1 loop
				poll_until_ready;
				s_axi_awaddr <= W_WRITE_DATA & "000"; s_axi_awvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
				s_axi_awaddr <= (others => 'X'); s_axi_awvalid <= '0';
				s_axi_wdata <= val((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
				s_axi_wvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
				s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			end loop;
		end procedure;
		-- -------------------------------------------------
		-- emulate SW writing the large number of the scalar
		-- -------------------------------------------------
		procedure write_scalar(valnn : positive; val : in std_logic_vector)
		is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_WRITE_NB) := '1';
			dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB) := CST_ADDR_K;
			dw(CTRL_WRITE_K) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			-- now perform the proper nb of writes of the DATA register
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			for i in 0 to div(valnn,AXIDW) - 1 loop
				for j in 0 to 63 loop
					wait until s_axi_aclk'event and s_axi_aclk = '1';
				end loop;
				s_axi_awaddr <= W_WRITE_DATA & "000"; s_axi_awvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
				s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
				s_axi_wdata <= val((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
				s_axi_wvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
				s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end loop;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------
		-- emulate SW configuring blinding
		-- -------------------------------
		procedure configure_blinding(blind : in boolean; blindbits : in natural) is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write W_BLINDING register
			s_axi_awaddr <= W_BLINDING & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			if blind then dw(BLD_EN) := '1'; end if;
			assert (blindbits <= nn)
				report "nb of blinding bits to large"
					severity FAILURE;
			dw(BLD_BITS_MSB downto BLD_BITS_LSB) := std_logic_vector(
				to_unsigned(blindbits, log2(nn)));
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------
		-- emulate SW configuring shuffle
		-- ------------------------------
		procedure configure_shuffle(sh : in boolean) is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			s_axi_awaddr <= W_SHUFFLE & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			if sh then dw(SHF_EN) := '1'; end if;
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------
		-- emulate SW configuring IRQ
		-- --------------------------
		procedure configure_irq(irq : in boolean) is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			s_axi_awaddr <= W_IRQ & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			if irq then dw(IRQ_EN) := '1'; end if;
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------------------------
		-- emulate SW issuing command 'do [k]P-computation'
		-- ------------------------------------------------
		procedure run_kp is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_KP) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------
		-- emulate SW issuing command 'do point-addition'
		-- ----------------------------------------------
		procedure run_point_add is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_ADD) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------
		-- emulate SW issuing command 'do point-doubling'
		-- ----------------------------------------------
		procedure run_point_double is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_DBL) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------------------------
		-- emulate SW issuing command 'do point-negate'
		-- --------------------------------------------
		procedure run_point_negate is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_NEG) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------------------
		-- emulate SW issuing command 'do P == Q test'
		-- -------------------------------------------
		procedure run_point_test_equal is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_EQU) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------------------------
		-- emulate SW issuing command 'do P == -Q test'
		-- --------------------------------------------
		procedure run_point_test_opp is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_OPP) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ---------------------------------------------------
		-- emulate SW issuing command 'is point on curve test'
		-- ---------------------------------------------------
		procedure run_point_test_oncurve is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_PT_CHK) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ---------------------------------------
		-- emulate SW setting all curve parameters
		-- ---------------------------------------
		procedure set_curve(size: in positive; curve: curve_param_type) is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			--wait until s_axi_aclk'event and s_axi_aclk = '1';
			for i in 0 to 3 loop
				poll_until_ready;
				write_big(size, CURVE_PARAM_ADDR(i), curve(i));
			end loop;
			--wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -----------------------------------
		-- emulate SW reading one large number
		-- -----------------------------------
		procedure read_big(valnn: in positive;
			addr : in natural range 0 to nblargenb - 1; bignb: inout std_logic_vector)
		is
			variable tup, xup : integer;
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write CTRL register
			s_axi_awaddr <= W_CTRL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(CTRL_READ_NB) := '1';
			dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
				:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			-- now perform the exact required nb of reads of the DATA register
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			for i in 0 to div(valnn,AXIDW) - 1 loop
				s_axi_araddr <= R_READ_DATA & "000"; s_axi_arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
				s_axi_araddr <= "XXXXXXXX"; s_axi_arvalid <= '0'; s_axi_rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
				if ((i+1) * AXIDW) > bignb'length then
					tup := bignb'length - 1;
					xup := bignb'length mod AXIDW - 1;
					assert FALSE
						report "ecc_tb: error while reading back big number"
							severity WARNING;
				else
					tup := ((i+1) * AXIDW) - 1;
					xup := AXIDW - 1;
				end if;
				bignb(tup downto i * AXIDW) := s_axi_rdata(xup downto 0);
				s_axi_rready <= '0';
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end loop;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------------------------
		-- emulate SW reading [k]P result's coordinates
		-- --------------------------------------------
		procedure read_and_display_kp_result(valnn: in positive) is
			variable kpx : std_logic512 := (others => '0');
			variable kpy : std_logic512 := (others => '0');
			variable xmsb, ymsb : integer;
		begin
			kpx := (others => '0');
			kpy := (others => '0');
			read_big(valnn, LARGE_NB_XR1_ADDR, kpx);
			read_big(valnn, LARGE_NB_YR1_ADDR, kpy);
			xmsb := kpx'high;
			for i in kpx'high downto 0 loop
				if kpx(i) /= '0' then
					exit;
				end if;
				xmsb := xmsb - 1;
			end loop;
			if xmsb <= 0 then
				echol("ECC_TB: found no high bit in [k]P.x");
				xmsb := valnn;
			end if;
			ymsb := kpy'high;
			for i in kpy'high downto 0 loop
				if kpy(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			if ymsb <= 0 then
				echol("ECC_TB: found no high bit in [k]P.y");
				ymsb := valnn;
			end if;
			echo("ECC_TB: read-back on AXI interface: [k]P.x = 0x");
			hex_echol(kpx(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: [k]P.y = 0x");
			hex_echol(kpy(max(xmsb, ymsb) downto 0));
		end procedure;
		-- -------------------------------------------
		-- emulate SW checking if R0 is the null point
		-- -------------------------------------------
		procedure check_if_r0_null(isnull : out boolean) is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read R_STATUS register
			s_axi_araddr <= R_STATUS & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			-- decode content of R_STATUS register
			if s_axi_rdata(STATUS_R0_IS_NULL) = '1' then
				isnull := TRUE;
			elsif s_axi_rdata(STATUS_R0_IS_NULL) = '0' then
				isnull := FALSE;
			else
				report "invalid state for R0 point"
					severity FAILURE;
			end if;
		end procedure;
		-- -------------------------------------------
		-- emulate SW checking if R1 is the null point
		-- -------------------------------------------
		procedure check_if_r1_null(isnull : out boolean) is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read R_STATUS register
			s_axi_araddr <= R_STATUS & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			-- decode content of R_STATUS register
			if s_axi_rdata(STATUS_R1_IS_NULL) = '1' then
				isnull := TRUE;
			elsif s_axi_rdata(STATUS_R1_IS_NULL) = '0' then
				isnull := FALSE;
			else
				report "invalid state for R1 point"
					severity FAILURE;
			end if;
		end procedure;
		-- ---------------------------------------------------------------------------------
		-- emulate SW checking if R0/R1 is the null point & display it on simulation console
		-- ---------------------------------------------------------------------------------
		procedure check_and_display_if_r0_r1_null is
			variable vz0, vz1 : boolean;
			variable vz : std_logic_vector(1 downto 0);
		begin
			check_if_r0_null(vz0);
			if vz0 then
				vz(0) := '1';
			else
				vz(0) := '0';
			end if;
			check_if_r1_null(vz1);
			if vz1 then
				vz(1) := '1';
			else
				vz(1) := '0';
			end if;
			case vz is
				when "00" => echol("ECC_TB: (R0,R1) = (not0, not0)");
				when "01" => echol("ECC_TB: (R0,R1) = (0, not0)");
				when "10" => echol("ECC_TB: (R0,R1) = (not0, 0)");
				when "11" => echol("ECC_TB: (R0,R1) = (0, 0)");
				when others =>
					echol(string'("ECC_TB: undefined state for R0 or R1" &
					      " in R_STATUS register"));
			end case;
		end procedure;
		-- --------------------------------------------------------------
		-- emulate SW getting answer to a test it's asked on R0 and/or R1
		-- --------------------------------------------------------------
		procedure check_test_answer(
			yes_or_no : out boolean; answer_right : out boolean) is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read R_STATUS register
			s_axi_araddr <= R_STATUS & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			if s_axi_rdata(STATUS_YES) = '1' then
				yes_or_no := TRUE;
			else
				yes_or_no := FALSE;
			end if;
			answer_right := TRUE;
		end procedure;
		-- ----------------------------------
		-- same thing with display on console
		-- ----------------------------------
		procedure read_and_display_pttest_result(valnn: in positive) is
			variable yes_or_no, answer_right : boolean;
		begin
			check_test_answer(yes_or_no, answer_right);
			if answer_right then
				if yes_or_no then
					echol("ECC_TB: answer is YES");
				else
					echol("ECC_TB: answer is NO");
				end if;
			else
				echol("ECC_TB: no answer :/");
			end if;
		end procedure;
		-- -----------------------------------
		-- emulate SW acknowledging all errors
		-- -----------------------------------
		procedure ack_all_errors is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write W_ERR_ACK register
			s_axi_awaddr <= W_ERR_ACK & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= (others => 'X'); s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(31 downto STATUS_ERR_COMP) := (others => '1');
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------------------
		-- emulate SW checking if any error & display them on console
		-- ----------------------------------------------------------
		procedure display_errors is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read R_STATUS register
			s_axi_araddr <= R_STATUS & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			if s_axi_rdata(STATUS_ERR_COMP) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_COMP error");
			end if;
			if s_axi_rdata(STATUS_ERR_WREG_FBD) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_WREG_FBD error");
			end if;
			if s_axi_rdata(STATUS_ERR_KP_FBD) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_KP_FBD error");
			end if;
			if s_axi_rdata(STATUS_ERR_NNDYN) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_NNDYN error");
			end if;
			if s_axi_rdata(STATUS_ERR_POP_FBD) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_POP_FBD error");
			end if;
			if s_axi_rdata(STATUS_ERR_RDNB_FBD) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_RDNB_FBD error");
			end if;
			if s_axi_rdata(STATUS_ERR_BLN) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_BLN error");
			end if;
			if s_axi_rdata(STATUS_ERR_UNKNOWN_REG) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_UNKNOWN_REG error");
			end if;
			if s_axi_rdata(STATUS_ERR_IN_PT_NOT_ON_CURVE) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_IN_PT_NOT_ON_CURVE error");
			end if;
			if s_axi_rdata(STATUS_ERR_OUT_PT_NOT_ON_CURVE) = '1' then
				echol("ECC_TB: R_STATUS shows STATUS_ERR_OUT_PT_NOT_ON_CURVE error");
			end if;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------------------------------------------------------------------
		-- emulate SW reading result's coordinates after point-addition & display them on console
		-- --------------------------------------------------------------------------------------
		procedure read_and_display_ptadd_result(valnn: in positive) is
			variable pax : std_logic512 := (others => '0');
			variable pay : std_logic512 := (others => '0');
			variable xmsb, ymsb : integer;
			variable vz1 : boolean;
		begin
			check_if_r1_null(vz1);
			if vz1 then
				echol("ECC_TB: P+Q = 0");
			else
				pax := (others => '0');
				pay := (others => '0');
				read_big(valnn, LARGE_NB_XR1_ADDR, pax);
				read_big(valnn, LARGE_NB_YR1_ADDR, pay);
				xmsb := pax'high;
				for i in pax'high downto 0 loop
					if pax(i) /= '0' then
						exit;
					end if;
					xmsb := xmsb - 1;
				end loop;
				assert (xmsb > 0)
					report "X-coordinate of point-addition result seems to equal 0"
						severity WARNING;
				ymsb := pay'high;
				for i in pay'high downto 0 loop
					if pay(i) /= '0' then
						exit;
					end if;
					ymsb := ymsb - 1;
				end loop;
				assert (ymsb > 0)
					report "Y-coordinate of point-addition result seems to equal 0"
						severity WARNING;
				echo("ECC_TB: read-back on AXI interface: (P+Q).x = 0x");
				hex_echol(pax(max(xmsb, ymsb) downto 0));
				echo("ECC_TB: read-back on AXI interface: (P+Q).y = 0x");
				hex_echol(pay(max(xmsb, ymsb) downto 0));
			end if;
		end procedure;
		-- --------------------------------------------------------------------------------------
		-- emulate SW reading result's coordinates after point-doubling & display them on console
		-- --------------------------------------------------------------------------------------
		procedure read_and_display_ptdbl_result(valnn: in positive) is
			variable pax : std_logic512 := (others => '0');
			variable pay : std_logic512 := (others => '0');
			variable xmsb, ymsb : integer;
			variable vz1 : boolean;
		begin
			check_if_r1_null(vz1);
			if vz1 then
				echol("ECC_TB: [2]P = 0");
			else
				pax := (others => '0');
				pay := (others => '0');
				read_big(valnn, LARGE_NB_XR1_ADDR, pax);
				read_big(valnn, LARGE_NB_YR1_ADDR, pay);
				xmsb := pax'high;
				for i in pax'high downto 0 loop
					if pax(i) /= '0' then
						exit;
					end if;
					xmsb := xmsb - 1;
				end loop;
				assert (xmsb > 0)
					report "X-coordinate of point-doubling result seems to equal 0"
						severity WARNING;
				ymsb := pay'high;
				for i in pay'high downto 0 loop
					if pay(i) /= '0' then
						exit;
					end if;
					ymsb := ymsb - 1;
				end loop;
				assert (ymsb > 0)
					report "Y-coordinate of point-doubling result seems to equal 0"
						severity WARNING;
				echo("ECC_TB: read-back on AXI interface: [2]P.x = 0x");
				hex_echol(pax(max(xmsb, ymsb) downto 0));
				echo("ECC_TB: read-back on AXI interface: [2]P.y = 0x");
				hex_echol(pay(max(xmsb, ymsb) downto 0));
			end if;
		end procedure;
		-- ------------------------------------------------------------------------------------
		-- emulate SW reading result's coordinates after point-negate & display them on console
		-- ------------------------------------------------------------------------------------
		procedure read_and_display_ptneg_result(valnn: in positive) is
			variable pax : std_logic512 := (others => '0');
			variable pay : std_logic512 := (others => '0');
			variable xmsb, ymsb : integer;
			variable vz1 : boolean;
		begin
			check_if_r1_null(vz1);
			if vz1 then
				echol("ECC_TB: -P = 0");
			else
				pax := (others => '0');
				pay := (others => '0');
				read_big(valnn, LARGE_NB_XR1_ADDR, pax);
				read_big(valnn, LARGE_NB_YR1_ADDR, pay);
				xmsb := pax'high;
				for i in pax'high downto 0 loop
					if pax(i) /= '0' then
						exit;
					end if;
					xmsb := xmsb - 1;
				end loop;
				assert (xmsb > 0)
					report "X-coordinate of opposite-point result seems to equal 0"
						severity WARNING;
				ymsb := pay'high;
				for i in pay'high downto 0 loop
					if pay(i) /= '0' then
						exit;
					end if;
					ymsb := ymsb - 1;
				end loop;
				assert (ymsb > 0)
					report "Y-coordinate of opposite-point result seems to equal 0"
						severity WARNING;
				echo("ECC_TB: read-back on AXI interface: (-P).x = 0x");
				hex_echol(pax(max(xmsb, ymsb) downto 0));
				echo("ECC_TB: read-back on AXI interface: (-P).y = 0x");
				hex_echol(pay(max(xmsb, ymsb) downto 0));
			end if;
		end procedure;
		-- -----------------------------------------------
		-- emulate SW programing trigger-up & trigger-down (debug feature)
		-- -----------------------------------------------
		procedure set_trigger(up : in natural; down : in natural) is
		begin
			-- write DEBUG-TRIG-UP register
			s_axi_awaddr <= W_DBG_TRIG_UP & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(up, AXIDW)); s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			-- write DEBUG-TRIG-DOWN register
			s_axi_awaddr <= W_DBG_TRIG_DOWN & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(down, AXIDW)); s_axi_wvalid <='1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			-- write DEBUG-TRIG-ACTIVATE register
			s_axi_awaddr <= W_DBG_TRIG_ACT & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= x"00000001"; -- ACTIVATE trigger
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- --------------------------------------------------
		-- emulate SW modifying an opcode in microcode memory (debug feature)
		-- --------------------------------------------------
		procedure patch_opcode(
			addr : in std_logic_vector(8 downto 0); op : in std_logic_vector) is
		begin
			-- write DEBUG_OPCODE_ADDR register
			s_axi_awaddr <= W_DBG_OP_ADDR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata <= x"00000" & "000" & addr(8 downto 0);
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			-- write DEBUG_WRITE_OPCODE register
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			s_axi_awaddr <= W_DBG_WR_OPCODE & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata <= op;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------
		-- emulate SW setting a breakpoint (debug feature)
		-- -------------------------------
		procedure set_one_breakpoint(
			id: in natural; addr: in std_logic_vector(8 downto 0);
			state: in std_logic_vector(3 downto 0); nbbits: in natural) is
		begin
			-- write DEBUG_BREAKPOINT register
			s_axi_awaddr <= W_DBG_BKPT & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata(31 downto 28) <= state(3 downto 0);
			s_axi_wdata(27 downto 16) <= std_logic_vector(to_unsigned(nbbits, 12));
			s_axi_wdata(15 downto 13) <= "000";
			s_axi_wdata(12 downto 4) <= addr(8 downto 0);
			s_axi_wdata(3) <= '0';
			s_axi_wdata(2 downto 1) <= std_logic_vector(to_unsigned(id, 2));
			s_axi_wdata(0) <= '1';
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------------------
		-- emulate SW resuming execution of microcode (debug feature)
		-- ------------------------------------------
		procedure resume is
		begin
			-- write DEBUG_STEPS register (0x28)
			s_axi_awaddr <= W_DBG_STEPS & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= "0001" & x"0000000"; s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------------------------------------
		-- emulate SW polling R_STATUS register until it shows [k]P computation is done
		-- ----------------------------------------------------------------------------
		procedure poll_until_kp_done is
		begin
			loop
				-- read R_STATUS register
				s_axi_araddr <= R_STATUS & "000";
				s_axi_arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
				s_axi_araddr <= "XXXXXXXX";
				s_axi_arvalid <= '0';
				s_axi_rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
				s_axi_rready <= '0';
				if s_axi_rdata(STATUS_KP) = '0' and s_axi_rdata(STATUS_BUSY) = '0' then
					-- means both bits 'kppending' & 'busy' are deasserted
					exit;
				end if;
				-- wait a little bit between each polling read (say 1 us, like software)
				wait for 1 us;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end loop;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------------------------------------------------
		-- emulate SW polling R_DBG_STATUS register until it shows machine is halted (debug feature)
		-- -------------------------------------------------------------------------
		procedure poll_until_debug_halted is
			variable tmp : integer;
		begin
			loop
				-- read DEBUG_STATUS register
				s_axi_araddr <= R_DBG_STATUS & "000";
				s_axi_arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
				s_axi_araddr <= "XXXXXXXX";
				s_axi_arvalid <= '0';
				s_axi_rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
				s_axi_rready <= '0';
				if s_axi_rdata(0) = '1' then
					echo("IP halted: PC=0x");
					hex_echo(s_axi_rdata(12 downto 4));
					echo(" (bkpt #");
					tmp := to_integer(unsigned(s_axi_rdata(2 downto 1)));
					echo(integer'image(tmp));
					echo(", state = 0x");
					hex_echo(s_axi_rdata(31 downto 28));
					echo(", nbbits = ");
					tmp := to_integer(unsigned(s_axi_rdata(27 downto 16)));
					echo(integer'image(tmp));
					exit;
				end if;
				-- wait a little bit between each polling read (say 1 us, like software)
				wait for 1 us;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end loop;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -----------------------------------------
		-- emulate SW issuing a TRNG refresh command (debug feature)
		-- -----------------------------------------
		procedure trng_refresh is
		begin
			-- write DEBUG_TRNG_CTRL register
			s_axi_awaddr <= W_DBG_TRNGCTR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata(31 downto 1) <= (others => '0'); s_axi_wdata(0) <= '1';
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ---------------------------------------------------
		-- emulate SW setting TRNG to use Von Neuman debiasing (debug feature)
		-- ---------------------------------------------------
		procedure trng_use_von_neuman is
		begin
			-- write DEBUG_TRNG_CTRL register
			s_axi_awaddr <= W_DBG_TRNGCTR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata(31 downto 0) <= x"00000404"; -- idletime = 4
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------------------------------
		-- emulate SW setting TRNG not to use Von Neuman debiasing (debug feature)
		-- -------------------------------------------------------
		procedure trng_dont_use_von_neuman is
		begin
			-- write DEBUG_TRNG_CTRL register
			s_axi_awaddr <= W_DBG_TRNGCTR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata(31 downto 0) <= x"00000600"; -- idletime = 6
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ---------------------------------------------------------------------
		-- emulate SW polling R_DBG_TRNG_STATUS register until TRNG refresh done (debug feature)
		-- ---------------------------------------------------------------------
		procedure poll_until_debug_trng_refresh_done is
		begin
			loop
				-- read DEBUG_TRNG_STATUS register
				s_axi_araddr <= R_DBG_TRNG_STATUS & "000";
				s_axi_arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
				s_axi_araddr <= "XXXXXXXX";
				s_axi_arvalid <= '0';
				s_axi_rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
				s_axi_rready <= '0';
				if s_axi_rdata(0) = '1' then -- means bit TRNG_REFRESH_DONE asserted
					exit;
				end if;
				-- wait a little bit between each polling read (say 1 us, like software)
				wait for 1 us;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end loop;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------------------------------------------
		-- emulate SW reading one Internal random number from ecc_trng memory (debug feature)
		-- ------------------------------------------------------------------
		procedure read_trng_irn(addr : in natural) is
		begin
			-- write DEBUG_TRNG_CTRL register
			s_axi_awaddr <= W_DBG_TRNGCTR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(addr, 24))
			               & "000" & '1' & "0000";
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read DEBUG_TRNG_DATA register
			s_axi_araddr <= R_DBG_TRNG_DATA & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			wait for 1 us;
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------------
		-- emulate SW deactivating usage of TRNG (debug feature)
		-- -------------------------------------
		procedure bypass_trng is
		begin
			-- write DEBUG_TRNG_CTRL register
			s_axi_awaddr <= W_DBG_TRNGCTR & "000";
			s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX";
			s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(0, 23))
			               & '1' & x"00";
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X');
			s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- procedure to wait for 100 us
		procedure delay_and_sync(duration : in time) is
		begin
			wait for duration; wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -----------------------------------------------------------------------------------------
		-- emulate SW writing base-point's X & Y coordinates & scalar and give [k]P computation a go
		-- -----------------------------------------------------------------------------------------
		procedure scalar_mult(
			valnn : positive;
			scalar : in std_logic_vector;
			xx : in std_logic_vector;
			yy : in std_logic_vector) is
		begin
			-- write base-point's X & Y coordinates
			poll_until_ready;
			write_scalar(valnn, scalar);
			poll_until_ready;
			write_big(valnn, 6, xx);
			poll_until_ready;
			write_big(valnn, 7, yy);
			-- give [k]P computation a go
			poll_until_ready;
			run_kp;
		end procedure;
		-- -----------------------------------------
		-- emulate SW setting R0 to be the null point
		-- -----------------------------------------
		procedure set_r0_null is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write W_R0_NULL register
			s_axi_awaddr <= W_R0_NULL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(WR0_IS_NULL) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------
		-- emulate SW setting R0 NOT to be the null point
		-- ----------------------------------------------
		procedure set_r0_non_null is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write W_R0_NULL register
			s_axi_awaddr <= W_R0_NULL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(WR0_IS_NULL) := '0';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------------------
		-- emulate SW setting R1 to be the null point
		-- ------------------------------------------
		procedure set_r1_null is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write W_R1_NULL register
			s_axi_awaddr <= W_R1_NULL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(WR1_IS_NULL) := '1';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ----------------------------------------------
		-- emulate SW setting R1 NOT to be the null point
		-- ----------------------------------------------
		procedure set_r1_non_null is
			variable dw : std_logic_vector(AXIDW - 1 downto 0);
		begin
			-- write W_R1_NULL register
			s_axi_awaddr <= W_R1_NULL & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			dw := (others => '0');
			dw(WR1_IS_NULL) := '0';
			s_axi_wdata <= dw;
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- -------------------------------------------------------------------------------
		-- emulate SW writing coordinates of two points to add and giving computation a go
		-- -------------------------------------------------------------------------------
		procedure point_add(
			valnn : positive;
			x0 : in std_logic_vector; y0 : in std_logic_vector;
			x1 : in std_logic_vector; y1 : in std_logic_vector;
			z0 : in boolean; z1 : in boolean) is
		begin
			-- write two points' X & Y coordinates
			if not z0 then
				poll_until_ready;
				write_big(valnn, 4, x0);
				poll_until_ready;
				write_big(valnn, 5, y0);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			if not z1 then
				poll_until_ready;
				write_big(valnn, 6, x1);
				poll_until_ready;
				write_big(valnn, 7, y1);
				poll_until_ready;
				set_r1_non_null;
			else
				poll_until_ready;
				set_r1_null;
			end if;
			-- give P + Q computation a go
			poll_until_ready;
			run_point_add;
		end procedure;
		-- -------------------------------------------------------------------------------
		-- emulate SW writing coordinates of a point to double and giving computation a go
		-- -------------------------------------------------------------------------------
		procedure point_double(
			valnn : positive;
			x : in std_logic_vector; y : in std_logic_vector; z : in boolean) is
		begin
			-- write point's X & Y coordinates
			if not z then
				poll_until_ready;
				write_big(valnn, 4, x);
				poll_until_ready;
				write_big(valnn, 5, y);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			-- give [2]P computation a go
			poll_until_ready;
			run_point_double;
		end procedure;
		-- ------------------------------------------------------------------------------------
		-- emulate SW writing coordinates of a point to negate (-P) and giving computation a go
		-- ------------------------------------------------------------------------------------
		procedure point_negate(
			valnn : positive;
			x : in std_logic_vector; y : in std_logic_vector; z : in boolean) is
		begin
			-- write point's X & Y coordinates
			if not z then
				poll_until_ready;
				write_big(valnn, 4, x);
				poll_until_ready;
				write_big(valnn, 5, y);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			-- give -P computation a go
			poll_until_ready;
			run_point_negate;
		end procedure;
		-- -------------------------------------------------------------------------------------
		-- emulate SW writing coords of two points to compare (P==Q) and giving computation a go
		-- -------------------------------------------------------------------------------------
		procedure point_test_equal(
			valnn : positive;
			x0 : in std_logic_vector; y0 : in std_logic_vector;
			x1 : in std_logic_vector; y1 : in std_logic_vector;
			z0 : in boolean; z1 : in boolean) is
		begin
			-- write point's X & Y coordinates
			if not z0 then
				poll_until_ready;
				write_big(valnn, 4, x0);
				poll_until_ready;
				write_big(valnn, 5, y0);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			if not z1 then
				poll_until_ready;
				write_big(valnn, 6, x1);
				poll_until_ready;
				write_big(valnn, 7, y1);
				poll_until_ready;
				set_r1_non_null;
			else
				poll_until_ready;
				set_r1_null;
			end if;
			-- give P==Q test computation a go
			poll_until_ready;
			run_point_test_equal;
		end procedure;
		-- ------------------------------------------------------------------------------------------------------
		-- emulate SW writing coords of two points to test for opposite state (P==-Q) and giving computation a go
		-- ------------------------------------------------------------------------------------------------------
		procedure point_test_opp(
			valnn : positive;
			x0 : in std_logic_vector; y0 : in std_logic_vector;
			x1 : in std_logic_vector; y1 : in std_logic_vector;
			z0 : in boolean; z1 : in boolean) is
		begin
			-- write point's X & Y coordinates
			if not z0 then
				poll_until_ready;
				write_big(valnn, 4, x0);
				poll_until_ready;
				write_big(valnn, 5, y0);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			if not z1 then
				poll_until_ready;
				write_big(valnn, 6, x1);
				poll_until_ready;
				write_big(valnn, 7, y1);
				poll_until_ready;
				set_r1_non_null;
			else
				poll_until_ready;
				set_r1_null;
			end if;
			-- give P==-Q test computation a go
			poll_until_ready;
			run_point_test_opp;
		end procedure;
		-- -----------------------------------------------------------------------------------------------
		-- emulate SW writing coords of a point to test for being on the curve and giving computation a go
		-- -----------------------------------------------------------------------------------------------
		procedure point_test_oncurve(
			valnn : positive;
			x : in std_logic_vector; y : in std_logic_vector; z : in boolean) is
		begin
			-- write point's X & Y coordinates
			if not z then
				poll_until_ready;
				write_big(valnn, 4, x);
				poll_until_ready;
				write_big(valnn, 5, y);
				poll_until_ready;
				set_r0_non_null;
			else
				poll_until_ready;
				set_r0_null;
			end if;
			-- give 'is P on curve' test computation a go
			poll_until_ready;
			run_point_test_oncurve;
		end procedure;
		-- ---------------------------------------------------------------------------------
		-- emulate SW setting a one-shot [k]P computation with a scalar size smaller than nn
		-- ---------------------------------------------------------------------------------
		procedure set_small_k_size(valksz : positive) is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- write W_SMALL_SCALAR register
			s_axi_awaddr <= W_SMALL_SCALAR & "000"; s_axi_awvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_awready = '1';
			s_axi_awaddr <= "XXXXXXXX"; s_axi_awvalid <= '0';
			s_axi_wdata <= std_logic_vector(to_unsigned(valksz, AXIDW));
			s_axi_wvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_wready = '1';
			s_axi_wdata <= (others => 'X'); s_axi_wvalid <= '0';
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
		-- ------------------------------------------------------------
		-- emulate SW reading R_STATUS register & display it on console
		-- ------------------------------------------------------------
		procedure read_and_display_r_status is
		begin
			wait until s_axi_aclk'event and s_axi_aclk = '1';
			-- read R_STATUS register
			s_axi_araddr <= R_STATUS & "000";
			s_axi_arvalid <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_arready = '1';
			s_axi_araddr <= "XXXXXXXX";
			s_axi_arvalid <= '0';
			s_axi_rready <= '1';
			wait until s_axi_aclk'event and s_axi_aclk = '1' and s_axi_rvalid = '1';
			s_axi_rready <= '0';
			echo("0x");
			hex_echol(s_axi_rdata);
			wait until s_axi_aclk'event and s_axi_aclk = '1';
		end procedure;
	begin

		-- *********************************************************************
		--                          i n i t   s t u f f
		-- *********************************************************************

		-- ------------------------------------------------------
		-- time 0
		-- ------------------------------------------------------
		s_axi_awvalid <= '0';
		s_axi_wvalid <= '0';
		s_axi_bready <= '1';
		s_axi_arvalid <= '0';
		s_axi_rready <= '1';

		-- ------------------------------------------------------
		-- wait for out-of-reset
		-- ------------------------------------------------------
		wait until s_axi_aresetn = '1';
		wait for 333 ns;
		wait until s_axi_aclk'event and s_axi_aclk = '1';

		echol("Waiting for init");

		-- ------------------------------------------------------
		-- wait until IP has done its (possible) init stuff
		-- ------------------------------------------------------
		poll_until_ready;
		
		echol("Init done");

		configure_shuffle(TRUE);
		configure_irq(TRUE);

		-- *********************************************************************
		--              B R A I N P O O L   1 6 0   R 1   C U R V E
		-- *********************************************************************
		if nn >= 160 then
			echol("");
			echol(" __   __   ___  ");
			echol("/_ | / /  / _ \ ");
			echol(" | |/ /_ | | | |");
			echol(" | | '_ \| | | |");
			echol(" | | (_) | |_| |");
			echol(" |_|\___/ \___/ ");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(160);
			nn_s <= 160;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready; -- or poll_until_ready

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(FALSE,             0);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(160, CURVE_PARAM_160);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime    k            x                  y
			--          size     |            |                  |
			--           |       |            |                  |
			--           V       V            V                  V
			scalar_mult(160,     SCALAR_K160, BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1);
			--           ^       ^
			--           |       |
			--          use      |
			--        random  shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(160);

			delay_and_sync(100 us); -- for sake of waveform readability

			-- P O I N T   A D D I T I O N   :   P + [12]P
			echol("ECC_TB: **** P + [12]P");
			-- send points' coordinates
			point_add(160, BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
										 BIG_X160_12P,      BIG_Y160_12P,    FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display coordinates of P + Q point result
			read_and_display_ptadd_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- P O I N T   D O U B L I N G   :   [2]P
			echol("ECC_TB: **** [2]Q  with Q = [12]P");
			-- send point coordinates
			point_double(160, BIG_X160_12P, BIG_Y160_12P, FALSE);
			-- poll until IP has completed point-doubling and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display coordinates of [2]P point result
			read_and_display_ptdbl_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- P O I N T   D O U B L I N G   :   [2]0
			echol("ECC_TB: **** [2]0");
			-- send point coordinates
			point_double(160, BIG_X160_12P, BIG_Y160_12P, TRUE);
			-- poll until IP has completed point-doubling and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display coordinates of [2]P point result
			read_and_display_ptdbl_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- P O I N T   O P P O S I T E   :   -P
			echol("ECC_TB: **** -Q  with Q = [12]P");
			-- send point coordinates
			point_negate(160, BIG_X160_12P, BIG_Y160_12P, FALSE);
			-- poll until IP has completed opposite-point computation and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display coordinates of -P point result
			read_and_display_ptneg_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- P O I N T   O P P O S I T E   :   -0
			echol("ECC_TB: **** -0");
			-- send point coordinates
			point_negate(160, BIG_X160_12P, BIG_Y160_12P, TRUE);
			-- poll until IP has completed opposite-point computation and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display coordinates of -P point result
			read_and_display_ptneg_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- A R E   P O I N T   E Q U A L   :   P == Q
			echol("ECC_TB: **** P == Q  with Q = [12]P");
			-- send points' coordinates
			point_test_equal(160, BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
														BIG_X160_12P,      BIG_Y160_12P, FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display test result
			read_and_display_pttest_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			-- A R E   P O I N T   E Q U A L   :   P == P
			echol("ECC_TB: **** P == P");
			-- send points' coordinates
			point_test_equal(160, BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
														BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1, FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready;
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null;
			-- get and display test result
			read_and_display_pttest_result(160);
			-- for sake of waveform readability
			delay_and_sync(100 us);

			echol("");

		end if; -- nn >= 160

		-- *********************************************************************
		--              B R A I N P O O L   1 9 2   R 1   C U R V E
		-- *********************************************************************
		if nn >= 192 then
			echol(" __  ___ ___  ");
			echol("/_ |/ _ \__ \ ");
			echol(" | | (_) | ) |");
			echol(" | |\__, |/ / ");
			echol(" | |  / // /_ ");
			echol(" |_| /_/|____|");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(192);
			nn_s <= 192;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready; -- or poll_until_ready

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(TRUE,              19);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(192, CURVE_PARAM_192);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                  y
			--          size         |            |                  |
			--           |           |            |                  |
			--           V           V            V                  V
			scalar_mult(192,         SCALAR_K192, BIG_XP_BPOOL192r1, BIG_YP_BPOOL192r1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(192);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 192

		-- *********************************************************************
		--              B R A I N P O O L   2 2 4   R 1   C U R V E
		-- *********************************************************************
		if nn >= 224 then
			echol(" ___  ___  _  _   ");
			echol("|__ \|__ \| || |  ");
			echol("   ) |  ) | || |_ ");
			echol("  / /  / /|__   _|");
			echol(" / /_ / /_   | |  ");
			echol("|____|____|  |_|  ");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(224);
			nn_s <= 224;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready; -- or poll_until_ready

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(FALSE,             0);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(224, CURVE_PARAM_224);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                  y
			--          size         |            |                  |
			--           |           |            |                  |
			--           V           V            V                  V
			scalar_mult(224,         SCALAR_K224, BIG_XP_BPOOL224r1, BIG_YP_BPOOL224r1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(224);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 224

		-- *********************************************************************
		--                      F p 2 5 6 v 1   C U R V E
		-- *********************************************************************
		if nn >= 256 then
			echol(" ___  _____   __  ");
			echol("|__ \| ____| / /  ");
			echol("   ) | |__  / /_  ");
			echol("  / /|___ \| '_ \ ");
			echol(" / /_ ___) | (_) |");
			echol("|____|____/ \___/ ");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(256);
			nn_s <= 256;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(TRUE,              63);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(256, CURVE_PARAM_256);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                y
			--          size         |            |                |
			--           |           |            |                |
			--           V           V            V                V
			scalar_mult(256,         SCALAR_K256, BIG_XP_FRP256v1, BIG_YP_FRP256v1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(256);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 256

		-- *********************************************************************
		--              B R A I N P O O L   3 2 0   R 1   C U R V E
		-- *********************************************************************
		if nn >= 320 then
			echol(" ____ ___   ___  ");
			echol("|___ \__ \ / _ \ ");
			echol("  __) | ) | | | |");
			echol(" |__ < / /| | | |");
			echol(" ___) / /_| |_| |");
			echol("|____/____|\___/ ");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(320);
			nn_s <= 320;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(FALSE,             0);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(320, CURVE_PARAM_320);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                  y
			--          size         |            |                  |
			--           |           |            |                  |
			--           V           V            V                  V
			scalar_mult(320,         SCALAR_K320, BIG_XP_BPOOL320r1, BIG_YP_BPOOL320r1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(320);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 320

		-- *********************************************************************
		--              B R A I N P O O L   3 8 4   R 1   C U R V E
		-- *********************************************************************
		if nn >= 384 then
			echol(" ____   ___  _  _   ");
			echol("|___ \ / _ \| || |  ");
			echol("  __) | (_) | || |_ ");
			echol(" |__ < > _ <|__   _|");
			echol(" ___) | (_) |  | |  ");
			echol("|____/ \___/   |_|  ");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(384);
			nn_s <= 384;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(TRUE,              72);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(384, CURVE_PARAM_384);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                  y
			--          size         |            |                  |
			--           |           |            |                  |
			--           V           V            V                  V
			scalar_mult(384,         SCALAR_K384, BIG_XP_BPOOL384r1, BIG_YP_BPOOL384r1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(384);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 384

		-- *********************************************************************
		--              B R A I N P O O L   5 1 2    R 1   C U R V E
		-- *********************************************************************
		if nn >= 512 then
			echol(" _____ __ ___  ");
			echol("| ____/_ |__ \ ");
			echol("| |__  | |  ) |");
			echol("|___ \ | | / / ");
			echol(" ___) || |/ /_ ");
			echol("|____/ |_|____|");

			-- ------------------------------------------------------
			-- set nn (prime size)
			-- ------------------------------------------------------
			-- emulate write of value of nn
			set_nn(512);
			nn_s <= 512;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(TRUE,              72);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding config and is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(512, CURVE_PARAM_512);
			-- poll until IP is ready
			poll_until_ready;

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			--          prime        k            x                  y
			--          size         |            |                  |
			--           |           |            |                  |
			--           V           V            V                  V
			scalar_mult(512,         SCALAR_K512, BIG_XP_BPOOL512R1, BIG_YP_BPOOL512R1);
			--           ^           ^
			--           |           |
			--          use          |
			--          random       shuffle
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_kp_done; -- or poll_until_ready

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(512);

			delay_and_sync(100 us); -- for sake of waveform readability
		end if; -- nn >= 512

		-- *********************************************************************
		--                 E N D   O F   S I M U L A T I O N
		-- *********************************************************************

		wait;
	
	end process;

end architecture sim;
