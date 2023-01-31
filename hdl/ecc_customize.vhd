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

package ecc_custom is

	-- ----------------------------------
	-- starf of: user-editable parameters
	-- ----------------------------------
	constant nn : positive := 528;
	constant nn_dynamic : boolean := TRUE;
	type techno_type is (spartan6, virtex6, series7, ialtera, asic);
	constant techno : techno_type := series7; -- choose one of 'techno_type' values
	-- multwidth is only used if 'techno' = 'asic'
	-- (otherwise its value has no meaning and can be ignored)
	constant multwidth : positive := 16; -- 32 seems fair for an ASIC default
	constant nbmult : positive range 1 to 2 := 2;
	constant nbdsp : positive := 8;
	constant sramlat : positive range 1 to 2 := 1;
	constant async : boolean := TRUE;
	constant shuffle : boolean := FALSE;
	constant nbtrng : positive := 1;
	constant trngta : natural range 1 to 4095 := 32;
	constant axi32or64 : natural := 32;
	constant debug : boolean := TRUE;
	constant nblargenb : positive := 32;  -- change these two parameters only if
	constant nbopcodes : positive := 1024; -- you really know what you're doing
	-- below concerns simulation only
	constant simkb : natural range 0 to natural'high := 0; -- if 0 then ignored
	constant simlog : string := "/tmp/ecc.log";
	constant simnotrng : boolean := FALSE; -- TRUE for simu, FALSE for synthesis
	constant simtrngfile: string := "/tmp/random.txt";
	-- --------------------------------
	-- end of: user-editable parameters
	-- --------------------------------
	
end package ecc_custom;
