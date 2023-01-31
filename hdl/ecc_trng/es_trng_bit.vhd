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

entity es_trng_bit is
	-- pragma translate_off
	generic(jittervalfile : string);
	-- pragma translate_on
	port(
		ro1en : in std_logic;
		ro2en : in std_logic;
		raw : out std_logic;
		valid : out std_logic
	);
end entity es_trng_bit;

architecture struct of es_trng_bit is

	component es_trng_bit_xilinx is
		-- pragma translate_off
		generic(jittervalfile : string);
		-- pragma translate_on
		port(
			ro1en : in std_logic;
			ro2en : in std_logic;
			raw : out std_logic;
			valid : out std_logic
		);
	end component;

	component es_trng_bit_ialtera is
		-- pragma translate_off
		generic(jittervalfile : string);
		-- pragma translate_on
		port(
			ro1en : in std_logic;
			ro2en : in std_logic;
			raw : out std_logic;
			valid : out std_logic
		);
	end component;

	component es_trng_bit_asic is
		-- pragma translate_off
		generic(jittervalfile : string);
		-- pragma translate_on
		port(
			ro1en : in std_logic;
			ro2en : in std_logic;
			raw : out std_logic;
			valid : out std_logic
		);
	end component;

begin

	x0: if techno = spartan6 or techno = virtex6 or techno = series7 generate
		x00: es_trng_bit_xilinx
			-- pragma translate_off
			generic map(jittervalfile => jittervalfile)
			-- pragma translate_on
			port map(ro1en => ro1en, ro2en => ro2en, raw => raw, valid => valid);
	end generate;

	i0: if techno = ialtera generate
		x00: es_trng_bit_ialtera
			-- pragma translate_off
			generic map(jittervalfile => jittervalfile)
			-- pragma translate_on
			port map(ro1en => ro1en, ro2en => ro2en, raw => raw, valid => valid);
	end generate;

	a0: if techno = asic generate
		x00: es_trng_bit_asic
			-- pragma translate_off
			generic map(jittervalfile => jittervalfile)
			-- pragma translate_on
			port map(ro1en => ro1en, ro2en => ro2en, raw => raw, valid => valid);
	end generate;

end architecture struct;
