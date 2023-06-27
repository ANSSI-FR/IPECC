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

use work.ecc_customize.all;
use work.ecc_pkg.all;

package ecc_shuffle_pkg is

	constant vp_addr_width : positive := set_phys_addr_width;

	subtype phys_addr is std_logic_vector(vp_addr_width - 1 downto 0);

	type virt_to_phys_table_type is
	  array(integer range 0 to (2**vp_addr_width) - 1) of phys_addr;

end package ecc_shuffle_pkg;
