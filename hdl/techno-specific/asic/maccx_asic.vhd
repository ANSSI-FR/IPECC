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

use work.ecc_utils.all; -- for ln2()
use work.ecc_pkg.all;
use work.mm_ndsp_pkg.all; -- for 'ndsp'

entity maccx is
	port(
		clk  : in std_logic;
		rst  : in std_logic;
		A    : in std_logic_vector(ww - 1 downto 0);
		B    : in std_logic_vector(ww - 1 downto 0);
		dspi : in maccx_array_in_type;
		P    : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0)
	);
end entity maccx;

architecture struct of maccx is

	component macc_asic is
		generic(
			breg : positive range 1 to 2;
			accumulate : boolean
		); port (
			clk  : in std_logic;
			-- signals to/from general purpose logic fabric
			rst  : in std_logic;
			rstm : in std_logic;
			rstp : in std_logic;
			A     : in std_logic_vector(ww - 1 downto 0);
			B     : in std_logic_vector(ww - 1 downto 0);
			PCIN  : in std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
			P     : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
			ACOUT : out std_logic_vector(ww - 1 downto 0);
			BCOUT : out std_logic_vector(ww - 1 downto 0);
			-- CE of DSP registers
			CEA : in std_logic;
			CEB1 : in std_logic;
			CEB2 : in std_logic;
			CEP : in std_logic
		);
	end component macc_asic;

	signal vcc, gnd : std_logic;
	signal gndxa : std_logic_vector(ww - 1 downto 0);
	signal gndxb : std_logic_vector(ww - 1 downto 0);
	signal gndxc : std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
	signal gndww : std_logic_vector(ww - 1 downto 0);

	subtype std_logic_ww is std_logic_vector(ww - 1 downto 0);
	subtype std_logic_wwa is std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);

	type dspww_array_type is array(0 to ndsp - 1) of std_logic_ww;
	type dspwwa_array_type is array(0 to ndsp - 1) of std_logic_wwa;

	signal dsp_ac : dspww_array_type;
	signal dsp_bc : dspww_array_type;
	signal dsp_pc : dspwwa_array_type;

	signal dspi_0_pcin : std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);

begin

	vcc <= '1';
	gnd <= '0';
	gndxa <= (others => '0');
	gndxb <= (others => '0');
	gndww <= (others => '0');
	dspi_0_pcin <= (others => '0');

	-- the first DSP block calls for a specific configuration
	-- (has only one register on the multiplier's B input operand path,
	-- instead of 2 for the others)
	d0: macc_asic
		generic map(breg => 1, accumulate => FALSE)
		port map(
			clk => clk,
			rst => rst,
			rstm => dspi(0).rstm,
			rstp => dspi(0).rstp,
			A => A,
			B => B,
			PCIN => dspi_0_pcin,
			P => dsp_pc(0),
			ACOUT => dsp_ac(0),
			BCOUT => dsp_bc(0),
			-- CE of DSP registers
			CEA => dspi(0).ace,
			CEB1 => dspi(0).bce,
			CEB2 => dspi(0).bce,
			CEP => dspi(0).pce
		);

	-- remaining DSP block instances
	d1: for i in 1 to ndsp - 1 generate
		d0: macc_asic
			generic map(breg => 2, accumulate => TRUE)
			port map(
				clk => clk,
				rst => rst,
				rstm => dspi(i).rstm,
				rstp => dspi(i).rstp,
				A => dsp_ac(i - 1),
				B => dsp_bc(i - 1),
				P => dsp_pc(i),
				acout => dsp_ac(i),
				bcout => dsp_bc(i),
				pcin => dsp_pc(i - 1),
				-- CE of DSP registers
				CEA => dspi(i).ace,
				CEB1 => dspi(i).bce,
				CEB2 => dspi(i).bce,
				CEP => dspi(i).pce
			);
	end generate;

	-- output of complete DSP chain
	P <= dsp_pc(ndsp - 1);

end architecture struct;
