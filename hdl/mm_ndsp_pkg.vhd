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

package mm_ndsp_pkg is

	function get_dsp_maxacc return positive;
	function is_barrel_shifter_needed return boolean;

	constant VALUE_BITS : positive := ln2((4*w) + 3) + ww;
	constant WEIGHT_BITS : positive := log2((2*w) - 1);
	constant NBTERMS_BITS : positive := log2((4*w) + 3);
	constant RAMWORD_BITS : positive := VALUE_BITS + NBTERMS_BITS;

	constant WEIGHT_ZERO : unsigned(WEIGHT_BITS - 1 downto 0) := (others => '0');

	type maccx_in_type is record
		rstm : std_logic;
		rstp : std_logic;
		ace : std_logic;
		bce : std_logic;
		pce : std_logic;
	end record;

	-- 'ndsp'
	--
	-- this is the actual number of DSP primitives in the design, based on
	-- the user choice expressed above (nbdsp) and the value of the 'w'
	-- parameter (defined from values of 'nn' and 'ww' user parameters)
	constant ndsp : positive := set_ndsp;

	type maccx_array_in_type is array(0 to ndsp - 1) of maccx_in_type;

end package mm_ndsp_pkg;

package body mm_ndsp_pkg is

	function get_dsp_maxacc return positive is
		variable tmp : positive := 2*ww + ln2(ndsp);
	begin
		if techno = spartan6 then tmp := 48;
		elsif techno = series7 or techno = virtex6 then tmp := 48;
		elsif techno = ialtera then tmp := 64;
		elsif techno = asic then tmp := 2*ww + ln2(ndsp); -- no max
		end if;
		return tmp;
	end function get_dsp_maxacc;

	function is_barrel_shifter_needed return boolean is
		variable tmp : boolean;
	begin
		if (not nn_dynamic) and ((nn + 2) mod ww = 0) then
			tmp := FALSE;
		else
			tmp := TRUE;
		end if;
		return tmp;
	end function is_barrel_shifter_needed;

end package body mm_ndsp_pkg;
