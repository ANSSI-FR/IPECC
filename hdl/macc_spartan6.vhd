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

library UNISIM;
use UNISIM.vcomponents.all;

use work.ecc_pkg.all;

entity macc_spartan6 is
	generic(wth : positive);
	port(
		clk  : in std_logic;
		rst  : in std_logic;
		A    : in std_logic_vector(ww - 1 downto 0);
		B    : in std_logic_vector(ww - 1 downto 0);
		C    : in std_logic_vector(wth - 1 downto 0);
		P    : out std_logic_vector(wth - 1 downto 0);
		opmode : in std_logic_vector(6 downto 0);
		-- CE of DSP registers
		CEA : in std_logic;
		CEB : in std_logic;
		CEC : in std_logic;
		CEP : in std_logic
	);
end entity macc_spartan6;

architecture struct of macc_spartan6 is

	signal gnd : std_logic := '0';
	signal gnd3 : std_logic_vector(2 downto 0) := (others => '0');
	signal gnd18 : std_logic_vector(17 downto 0) := (others => '0');
	signal gnd25 : std_logic_vector(24 downto 0) := (others => '0');
	signal gnd30 : std_logic_vector(29 downto 0) := (others => '0');
	signal gnd48 : std_logic_vector(47 downto 0) := (others => '0');
	signal vcc : std_logic := '1';
	signal A_s : std_logic_vector(17 downto 0);
	signal B_s : std_logic_vector(17 downto 0);
	signal C_s : std_logic_vector(47 downto 0);
	signal P_s : std_logic_vector(47 downto 0);
	signal opmode_s : std_logic_vector(7 downto 0);

begin

	-- for consistency of B_s signal definition
	assert (ww < 18)
		report "ecc_pkg.ww parameter must not exceed 17 bits for Xilinx targets"
			severity FAILURE;

	-- for consistency of A_s signal definition
	-- (redundant with condition on B_s, but kept here for sake of readability)
	assert (ww < 30)
		report "ecc_pkg.ww parameter must not exceed 29 bits for Xilinx targets"
			severity FAILURE;

	-- for consistency of C_s & P_s signals definition
	assert (wth < 48)
		report "macc_spartan6.wth parameter must not exceed 47 bits for Xilinx targets"
			severity FAILURE;

	gnd <= '0';
	gnd3 <= (others => '0');
	gnd18 <= (others => '0');
	gnd25 <= (others => '0');
	gnd30 <= (others => '0');
	gnd48 <= (others => '0');
	vcc <= '1';

	opmode_s <= '0' & opmode;
	A_s <= std_logic_vector(to_unsigned(0, 18 - ww)) & A;
	B_s <= std_logic_vector(to_unsigned(0, 18 - ww)) & B;
	C_s <= std_logic_vector(to_unsigned(0, 48 - wth)) & C;
	P <= P_s(wth - 1 downto 0);

	d0: DSP48A1
		generic map (
			A0REG => 1,
			A1REG => 0,
			B0REG => 1,
			B1REG => 0,
			CARRYINREG => 1,
			CARRYINSEL => "OPMODE5", -- TODO
			CARRYOUTREG => 0,
			CREG => 1,
			DREG => 1,
			MREG => 1,
			OPMODEREG => 1,
			PREG => 1,
			RSTTYPE => "SYNC"
			-- 7 series -- A_INPUT => "DIRECT",
			-- 7 series -- B_INPUT => "DIRECT",
			-- 7 series -- USE_DPORT => FALSE,
			-- 7 series -- USE_MULT => "MULTIPLY",
			-- 7 series -- AUTORESET_PATDET => "NO_RESET",
			-- 7 series -- MASK => X"FFFFFF",
			-- 7 series -- PATTERN => X"000000000000",
			-- 7 series -- SEL_MASK => "MASK",
			-- 7 series -- SEL_PATTERN => "PATTERN",
			-- 7 series -- USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect
			-- 7 series -- ACASCREG => 1,
			-- 7 series -- ADREG => 0,
			-- 7 series -- ALUMODEREG => 1,
			-- 7 series -- AREG => 1,
			-- 7 series -- BCASCREG => 1,
			-- 7 series -- BREG => 1,
			-- 7 series -- CARRYINREG => 1,
			-- 7 series -- CARRYINSELREG => 1,
			-- 7 series -- CREG => 1,
			-- 7 series -- DREG => 1,
			-- 7 series -- INMODEREG => 1,
			-- 7 series -- MREG => 1,
			-- 7 series -- OPMODEREG => 1,
			-- 7 series -- PREG => 1,
			-- 7 series -- USE_SIMD => "ONE48"
		) port map (
			BCOUT => open,
			PCOUT => open,
			CARRYOUT => open,
			CARRYOUTF => open,
			M => open,
			P => P_s,
			PCIN => gnd48,
			CLK => clk,
			OPMODE => opmode_s,
			A => A_s,
			B => B_s,
			C => C_s,
			CARRYIN => gnd,
			D => gnd18,
			CEA => CEA,
			CEB => CEB,
			CEC => CEC,
			-- for CECARRYIN: "Tie to logic one if not used and CARRYINREG=1"
			-- ([UG615] v14.7, Oct 2, 2013, p. 93)
			CECARRYIN => vcc,
			CED => vcc,
			CEM => vcc,
			CEOPMODE => vcc,
			CEP => CEP,
			RSTA => rst,
			RSTB => rst,
			RSTC => rst,
			RSTCARRYIN => rst,
			RSTD => rst,
			RSTM => rst,
			RSTOPMODE => rst,
			RSTP => rst
			-- 7 series -- ACOUT => open,
			-- 7 series -- BCOUT => open,
			-- 7 series -- CARRYCASCOUT => open,
			-- 7 series -- MULTSIGNOUT => open,
			-- 7 series -- OVERFLOW => open,
			-- 7 series -- PATTERNBDETECT => open, -- 1-bit output: Pattern bar detect output
			-- 7 series -- PATTERNDETECT => open,
			-- 7 series -- UNDERFLOW => open,
			-- 7 series -- CARRYOUT => open,
			-- 7 series -- ACIN => gnd30,
			-- 7 series -- BCIN => gnd18,
			-- 7 series -- CARRYCASCIN => gnd,
			-- 7 series -- MULTSIGNIN => gnd,
			-- 7 series -- ALUMODE => alumode,
			-- 7 series -- CARRYINSEL => gnd3,
			-- 7 series -- CEINMODE => CEINMODE,
			-- 7 series -- INMODE => inmode,
			-- 7 series -- RSTINMODE => rst,
			-- 7 series -- A => A_s,
			-- 7 series -- B => B_s,
			-- 7 series -- C => C_s,
			-- 7 series -- CARRYIN => gnd,
			-- 7 series -- CEA1 => vcc,
			-- 7 series -- CEA2 => CEA,
			-- 7 series -- CEAD => vcc,
			-- 7 series -- CEALUMODE => CEALUMODE,
			-- 7 series -- CEB1 => vcc,
			-- 7 series -- CEB2 => CEB,
			-- 7 series -- CEC => CEC,
			-- 7 series -- CECARRYIN => vcc,
			-- 7 series -- CECTRL => CECTRL,
			-- 7 series -- CED => vcc,
			-- 7 series -- CEM => vcc,
			-- 7 series -- CEP => CEP,
	);

end architecture struct;
