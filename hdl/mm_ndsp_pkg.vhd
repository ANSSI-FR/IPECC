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

	constant WEIGHT_BITS : positive := log2((2*w) - 1);

	type maccx_in_type is record
		rstm : std_logic;
		rstp : std_logic;
		ace : std_logic;
		bce : std_logic;
		pce : std_logic;
	end record;

	-- 'ndsp'
	--
	-- this is the actual number of DSP primitives that will be instanciated
	-- in the design at synthesis time, based on the user choice (parameter
	-- nbdsp) expressed in ecc_customize.vhd and the value of the parameter
	-- 'w' (defined from values of 'nn' and 'ww')
	-- So nbdsp is the user (designer) choice, ndsp is the value which is
	-- deduced from the user choice, in order to enforce that the nb of DSP
	-- blocks actually in the hardware does not exceed parameter 'w', which
	-- would not make sense
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

end package body mm_ndsp_pkg;
