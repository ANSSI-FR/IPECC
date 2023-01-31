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

use work.ecc_custom.all; -- for 'techno'
use work.ecc_utils.all; -- for ln2()
use work.ecc_pkg.all;
use work.mm_ndsp_pkg.all;

entity maccx is
	port (
		clk : std_logic;
		rst : std_logic; -- global reset
		A : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
		B : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
		dspii: maccx_array_in_type;
		P : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0) -- output
	);
end entity maccx;

architecture struct of maccx is

	component maccx_series7 is
		port (
			clk : in std_logic;
			rst : in std_logic; -- global reset
			A : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			B : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			dspi : in maccx_array_in_type;
			P : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0) -- output
		);
	end component maccx_series7;

	--component maccx_spartan6 is
	--	port (
	--		clk : std_logic;
	--		rst : std_logic; -- global reset
	--		A : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
	--		B : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
	--		dspi : maccx_array_in_type;
	--		P : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0) -- output
	--	);
	--end component maccx_spartan6;

	component maccx_ialtera is
		port (
			clk : std_logic;
			rst : std_logic; -- global reset
			A : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			B : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			dspi : maccx_array_in_type;
			P : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0) -- output
		);
	end component maccx_ialtera;

	component maccx_asic is
		port (
			clk : std_logic;
			rst : std_logic; -- global reset
			A : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			B : in std_logic_vector(ww - 1 downto 0); -- input to DSP chain
			dspi : maccx_array_in_type;
			P : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0) -- output
		);
	end component maccx_asic;

begin

	mxs7: if techno = series7 generate
		m0: maccx_series7
			port map(clk => clk, rst => rst, A => A, B => B, dspi => dspii, P => P);
	end generate;

	--mxs6: if techno = spartan6 generate
	--	m0: maccx_spartan6
	--		port map(clk, rst, A, B, dspi, P);
	--			port map(clk => clk, rst => rst, A => A, B => B, dspi => dspi, P => P);
	--end generate;

	mia7: if techno = ialtera generate
		m0: maccx_ialtera
			port map(clk => clk, rst => rst, A => A, B => B, dspi => dspii, P => P);
	end generate;

	ma: if techno = asic generate
		m0: maccx_asic
			port map(clk => clk, rst => rst, A => A, B => B, dspi => dspii, P => P);
	end generate;

end architecture struct;
