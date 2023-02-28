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

entity macc_series7 is
	generic(
		acc : positive;
		breg : positive range 1 to 2;
		ain : string := "DIRECT"; -- DIRECT: path A fed with A input, otherwise ACIN
		bin : string := "DIRECT" -- DIRECT: path B fed with B input, otherwise BCIN
	); port (
		clk  : in std_logic;
		-- signals to/from general purpose logic fabric
		rst  : in std_logic;
		rstm : in std_logic;
		rstp : in std_logic;
		A    : in std_logic_vector(29 downto 0);
		B    : in std_logic_vector(17 downto 0);
		C    : in std_logic_vector(47 downto 0);
		P    : out std_logic_vector(47 downto 0);
		inmode : in std_logic_vector(4 downto 0);
		alumode :  in std_logic_vector(3 downto 0);
		opmode : in std_logic_vector(6 downto 0);
		-- signals to/from adjacent DSP block
		ACIN : in std_logic_vector(29 downto 0);
		BCIN : in std_logic_vector(17 downto 0);
		PCIN : in std_logic_vector(47 downto 0);
		ACOUT : out std_logic_vector(29 downto 0);
		BCOUT : out std_logic_vector(17 downto 0);
		PCOUT : out std_logic_vector(47 downto 0);
		-- CE of DSP registers
		CEINMODE : in std_logic;
		CEA1 : in std_logic;
		CEALUMODE : in std_logic;
		CEB1 : std_logic;
		CEB2 : std_logic;
		CEC : std_logic;
		CEP : std_logic;
		CECTRL : std_logic
	);
end entity macc_series7;

architecture struct of macc_series7 is

	signal gnd : std_logic := '0';
	signal gnd3 : std_logic_vector(2 downto 0) := (others => '0');
	signal gnd18 : std_logic_vector(17 downto 0) := (others => '0');
	signal gnd25 : std_logic_vector(24 downto 0) := (others => '0');
	signal gnd48 : std_logic_vector(47 downto 0) := (others => '0');
	signal vcc : std_logic := '1';
	signal A_s : std_logic_vector(29 downto 0);
	signal B_s : std_logic_vector(17 downto 0);
	signal C_s : std_logic_vector(47 downto 0);
	signal P_s : std_logic_vector(47 downto 0);
	signal ACIN_s : std_logic_vector(29 downto 0);
	signal BCIN_s : std_logic_vector(17 downto 0);
	signal PCIN_s : std_logic_vector(47 downto 0);
	signal ACOUT_s : std_logic_vector(29 downto 0);
	signal BCOUT_s : std_logic_vector(17 downto 0);
	signal PCOUT_s : std_logic_vector(47 downto 0);

begin

	-- for consistency of B_s signal definition
	assert (ww < 18)
		report
		"ecc_pkg.ww parameter must not exceed 17 bits for Xilinx 7-series targets"
			severity FAILURE;

	-- for consistency of A_s signal definition
	-- (redundant with condition on B_s, but kept here for sake of readability)
	assert (ww < 30)
		report
		"ecc_pkg.ww parameter must not exceed 29 bits for Xilinx 7-series targets"
			severity FAILURE;

	-- for consistency of C_s & P_s signals definition
	assert (acc < 48)
		report
		"macc_series7.acc parameter must not exceed 47 bits for Xilinx 7-series targets"
			severity FAILURE;

	gnd <= '0';
	gnd3 <= (others => '0');
	gnd18 <= (others => '0');
	gnd25 <= (others => '0');
	gnd48 <= (others => '0');
	vcc <= '1';

	--A_s <= std_logic_vector(to_unsigned(0, 30 - ww)) & A;
	A_s <= A;
	--ACIN_s <= std_logic_vector(to_unsigned(0, 30 - ww)) & ACIN;
	ACIN_s <= ACIN;
	--B_s <= std_logic_vector(to_unsigned(0, 18 - ww)) & B;
	B_s <= B;
	--BCIN_s <= std_logic_vector(to_unsigned(0, 18 - ww)) & BCIN;
	BCIN_s <= BCIN;
	--C_s <= std_logic_vector(to_unsigned(0, 48 - acc)) & C;
	C_s <= C;
	--PCIN_s <= std_logic_vector(to_unsigned(0, 48 - acc)) & PCIN;
	PCIN_s <= PCIN;
	--P <= P_s(acc - 1 downto 0);
	P <= P_s;
	--ACOUT <= ACOUT_s(ww - 1 downto 0);
	ACOUT <= ACOUT_s;
	--BCOUT <= BCOUT_s(ww - 1 downto 0);
	BCOUT <= BCOUT_s;
	--PCOUT <= PCOUT_s(acc - 1 downto 0);
	PCOUT <= PCOUT_s;

	d0: DSP48E1
		generic map (
			A_INPUT => ain,
			B_INPUT => bin,
			USE_DPORT => FALSE,
			USE_MULT => "MULTIPLY",
			AUTORESET_PATDET => "NO_RESET",
			MASK => X"FFFFFF",
			PATTERN => X"000000000000",
			SEL_MASK => "MASK",
			SEL_PATTERN => "PATTERN",
			-- Enable pattern detect ("PATDET" or "NO_PATDET")
			USE_PATTERN_DETECT => "NO_PATDET",
			ACASCREG => 1,
			ADREG => 1,
			ALUMODEREG => 1,
			AREG => 1,
			BCASCREG => breg,
			BREG => breg,
			CARRYINREG => 1,
			CARRYINSELREG => 1,
			CREG => 1,
			DREG => 1,
			INMODEREG => 1,
			MREG => 1,
			OPMODEREG => 1,
			PREG => 1,
			USE_SIMD => "ONE48"
		) port map (
			ACOUT => ACOUT_s,
			BCOUT => BCOUT_s,
			CARRYCASCOUT => open,
			MULTSIGNOUT => open,
			PCOUT => PCOUT_s,
			OVERFLOW => open,
			PATTERNBDETECT => open,
			PATTERNDETECT => open,
			UNDERFLOW => open,
			CARRYOUT => open,
			P => P_s,
			ACIN => ACIN_s,
			BCIN => BCIN_s,
			CARRYCASCIN => gnd,
			MULTSIGNIN => gnd,
			PCIN => PCIN_s,
			ALUMODE => alumode,
			CARRYINSEL => gnd3,
			CEINMODE => CEINMODE,
			CLK => clk,
			INMODE => inmode,
			OPMODE => opmode,
			RSTINMODE => rst,
			A => A_s,
			B => B_s,
			C => C_s,
			CARRYIN => gnd,
			D => gnd25,
			CEA1 => CEA1,
			CEA2 => CEA1,
			CEAD => gnd,
			CEALUMODE => CEALUMODE,
			CEB1 => CEB1,
			CEB2 => CEB2,
			CEC => CEC,
			-- for CECARRYIN: "Tie to logic one if not used"
			-- ([UG953] (v2018.2) June 6, 2018, p. 269)
			CECARRYIN => vcc,
			CECTRL => CECTRL,
			CED => gnd,
			CEM => vcc,
			CEP => CEP,
			RSTA => rst,
			RSTALLCARRYIN => rst,
			RSTALUMODE => rst,
			RSTB => rst,
			RSTC => rst,
			RSTCTRL => rst,
			RSTD => gnd,
			RSTM => rstm,
			RSTP => rstp
	);

end architecture struct;
