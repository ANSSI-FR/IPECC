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

use work.ecc_custom.all; -- for techno
use work.ecc_pkg.all;

entity large_shr is
	generic(size : positive := 2*w*ww);
	port(
		clk : in std_logic;
		ce : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity large_shr;

architecture struct of large_shr is

	component large_shr_xilinx is
		generic(size : positive := 2*w*ww);
		port(
			clk : in std_logic;
			ce : in std_logic;
			d : in std_logic;
			q : out std_logic
		);
	end component large_shr_xilinx;

	component large_shr_ialtera is
		generic(size : positive := 2*w*ww);
		port(
			clk : in std_logic;
			ce : in std_logic;
			d : in std_logic;
			q : out std_logic
		);
	end component large_shr_ialtera;

	component large_shr_behav is
		generic(size : positive := 2*w*ww);
		port(
			clk : in std_logic;
			ce : in std_logic;
			d : in std_logic;
			q : out std_logic
		);
	end component large_shr_behav;

begin

	x0: if techno = spartan6 or techno = virtex6 or techno = series7 generate
		x00 : large_shr_xilinx
			generic map(size => size)
			port map(clk => clk, ce => ce, d => d, q => q);
	end generate;

	a0: if techno = ialtera generate
		s00 : large_shr_ialtera
			generic map(size => size)
			port map(clk => clk, ce => ce, d => d, q => q);
	end generate;

	s0 : if techno = asic generate
		s00 : large_shr_behav
			generic map(size => size)
			port map(clk => clk, ce => ce, d => d, q => q);
	end generate;

end architecture struct;
