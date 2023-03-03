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
use work.ecc_tb_pkg.all;
use work.ecc_tb_vec.all;

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

	signal axi : axi_in_type;
	signal axo : axi_out_type;

	signal s_axi_aclk, s_axi_aresetn : std_logic;

	signal clkmm : std_logic;

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
			C_S_AXI_ADDR_WIDTH => AXIAW)
		port map(
			-- AXI clock & reset
			s_axi_aclk => s_axi_aclk,
			s_axi_aresetn => s_axi_aresetn,
			-- AXI write-address channel
			s_axi_awaddr => axi.awaddr,
			s_axi_awprot => axi.awprot,
			s_axi_awvalid => axi.awvalid,
			s_axi_awready => axo.awready,
			-- AXI write-data channel
			s_axi_wdata => axi.wdata,
			s_axi_wstrb => axi.wstrb,
			s_axi_wvalid => axi.wvalid,
			s_axi_wready => axo.wready,
			-- AXI write-response channel
			s_axi_bresp => axo.bresp,
			s_axi_bvalid => axo.bvalid,
			s_axi_bready => axi.bready,
			-- AXI read-address channel
			s_axi_araddr => axi.araddr,
			s_axi_arprot => axi.arprot,
			s_axi_arvalid => axi.arvalid,
			s_axi_arready => axo.arready,
			--  AXI read-data channel
			s_axi_rdata => axo.rdata,
			s_axi_rresp => axo.rresp,
			s_axi_rvalid => axo.rvalid,
			s_axi_rready => axi.rready,
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
	begin

		-- *********************************************************************
		--                          i n i t   s t u f f
		-- *********************************************************************

		-- ------------------------------------------------------
		-- time 0
		-- ------------------------------------------------------
		axi.awvalid <= '0';
		axi.wvalid <= '0';
		axi.bready <= '1';
		axi.arvalid <= '0';
		axi.rready <= '1';

		-- ------------------------------------------------------
		-- wait for out-of-reset
		-- ------------------------------------------------------
		wait until s_axi_aresetn = '1';
		echol("ECC_TB: Out-of-reset");
		wait for 333 ns;
		wait until s_axi_aclk'event and s_axi_aclk = '1';

		echol("ECC_TB: Waiting for init");

		-- ------------------------------------------------------
		-- wait until IP has done its (possible) init stuff
		-- ------------------------------------------------------
		poll_until_ready(s_axi_aclk, axi, axo);

		echol("ECC_TB: Init done");

		configure_shuffle(s_axi_aclk, axi, axo, TRUE);
		configure_irq(s_axi_aclk, axi, axo, TRUE);

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
			set_nn(s_axi_aclk, axi, axo, 160);
			nn_s <= 160;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, FALSE,             0);
			--                 blind/don't blind, nb blind bits
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 160, CURVE_PARAM_160);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 160,
			            SCALAR_K160, BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 160);

			wait for 100 us; -- for sake of waveform readability

			-- P O I N T   A D D I T I O N   :   P + [12]P
			echol("ECC_TB: **** P + [12]P");
			-- send points' coordinates
			point_add(s_axi_aclk, axi, axo, 160,
			          BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
								BIG_X160_12P,      BIG_Y160_12P,      FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display coordinates of P + Q point result
			read_and_display_ptadd_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- P O I N T   D O U B L I N G   :   [2]P
			echol("ECC_TB: **** [2]Q  with Q = [12]P");
			-- send point coordinates
			point_double(s_axi_aclk, axi, axo, 160,
			             BIG_X160_12P, BIG_Y160_12P, FALSE);
			-- poll until IP has completed point-doubling and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display coordinates of [2]P point result
			read_and_display_ptdbl_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- P O I N T   D O U B L I N G   :   [2]0
			echol("ECC_TB: **** [2]0");
			-- send point coordinates
			point_double(s_axi_aclk, axi, axo,
			             160, BIG_X160_12P, BIG_Y160_12P, TRUE);
			-- poll until IP has completed point-doubling and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display coordinates of [2]P point result
			read_and_display_ptdbl_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- P O I N T   O P P O S I T E   :   -P
			echol("ECC_TB: **** -Q  with Q = [12]P");
			-- send point coordinates
			point_negate(s_axi_aclk, axi, axo, 160,
			             BIG_X160_12P, BIG_Y160_12P, FALSE);
			-- poll until IP has completed opposite-point computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display coordinates of -P point result
			read_and_display_ptneg_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- P O I N T   O P P O S I T E   :   -0
			echol("ECC_TB: **** -0");
			-- send point coordinates
			point_negate(s_axi_aclk, axi, axo, 160,
			             BIG_X160_12P, BIG_Y160_12P, TRUE);
			-- poll until IP has completed opposite-point computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display coordinates of -P point result
			read_and_display_ptneg_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- A R E   P O I N T   E Q U A L   :   P == Q
			echol("ECC_TB: **** P == Q  with Q = [12]P");
			-- send points' coordinates
			point_test_equal(s_axi_aclk, axi, axo, 160,
			                 BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
			                 BIG_X160_12P,      BIG_Y160_12P, FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display test result
			read_and_display_pttest_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

			-- A R E   P O I N T   E Q U A L   :   P == P
			echol("ECC_TB: **** P == P");
			-- send points' coordinates
			point_test_equal(s_axi_aclk, axi, axo, 160,
			                 BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1,
			                 BIG_XP_BPOOL160R1, BIG_YP_BPOOL160R1, FALSE, FALSE);
			-- poll until IP has completed point-addition and is ready
			poll_until_ready(s_axi_aclk, axi, axo);
			-- check & display status of R0 & R1 points
			check_and_display_if_r0_r1_null(s_axi_aclk, axi, axo);
			-- get and display test result
			read_and_display_pttest_result(s_axi_aclk, axi, axo, 160);
			-- for sake of waveform readability
			wait for 100 us;

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
			set_nn(s_axi_aclk, axi, axo, 192);
			nn_s <= 192;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, TRUE, 19);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 192, CURVE_PARAM_192);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 192,
			            SCALAR_K192, BIG_XP_BPOOL192r1, BIG_YP_BPOOL192r1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 192);

			wait for 100 us; -- for sake of waveform readability
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
			set_nn(s_axi_aclk, axi, axo, 224);
			nn_s <= 224;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, FALSE, 0);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 224, CURVE_PARAM_224);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 224,
			            SCALAR_K224, BIG_XP_BPOOL224r1, BIG_YP_BPOOL224r1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 224);

			wait for 100 us; -- for sake of waveform readability
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
			set_nn(s_axi_aclk, axi, axo, 256);
			nn_s <= 256;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, TRUE, 63);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 256, CURVE_PARAM_256);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 256,
			            SCALAR_K256, BIG_XP_FRP256v1, BIG_YP_FRP256v1);
			--
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 256);

			wait for 100 us; -- for sake of waveform readability
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
			set_nn(s_axi_aclk, axi, axo, 320);
			nn_s <= 320;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, FALSE, 0);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 320, CURVE_PARAM_320);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 320,
			            SCALAR_K320, BIG_XP_BPOOL320r1, BIG_YP_BPOOL320r1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 320);

			wait for 100 us; -- for sake of waveform readability
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
			set_nn(s_axi_aclk, axi, axo, 384);
			nn_s <= 384;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, TRUE, 72);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 384, CURVE_PARAM_384);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 384,
			            SCALAR_K384, BIG_XP_BPOOL384r1, BIG_YP_BPOOL384r1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 384);

			wait for 100 us; -- for sake of waveform readability
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
			set_nn(s_axi_aclk, axi, axo, 512);
			nn_s <= 512;
			-- poll until IP has done the job related to the new nn value and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- blinding & shuffle configuration
			-- ------------------------------------------------------
			configure_blinding(s_axi_aclk, axi, axo, TRUE, 72);
			-- poll until IP has done the stuff related to blinding and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- set curve parameters
			-- ------------------------------------------------------
			set_curve(s_axi_aclk, axi, axo, 512, CURVE_PARAM_512);
			-- poll until IP is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- ------------------------------------------------------
			-- scalar multiplication
			-- ------------------------------------------------------
			--
			scalar_mult(s_axi_aclk, axi, axo, 512,
			            SCALAR_K512, BIG_XP_BPOOL512R1, BIG_YP_BPOOL512R1);
			--
			-- poll until IP has completed [k]P computation and is ready
			poll_until_ready(s_axi_aclk, axi, axo);

			-- get and display coordinates of [k]P point result
			read_and_display_kp_result(s_axi_aclk, axi, axo, 512);

			wait for 100 us; -- for sake of waveform readability
		end if; -- nn >= 512

		-- *********************************************************************
		--                 E N D   O F   S I M U L A T I O N
		-- *********************************************************************

		wait;
	
	end process;

end architecture sim;
