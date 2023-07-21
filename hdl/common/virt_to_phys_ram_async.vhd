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

use work.ecc_log.all;
use work.ecc_pkg.all;
use work.ecc_customize.all; -- for techno
use work.ecc_shuffle_pkg.all; -- for techno

entity virt_to_phys_async is
	generic(
		datawidth : natural range 1 to integer'high;
		datadepth : natural range 1 to integer'high);
	port(
		clk : in std_logic;
		-- port A (synchronous write)
		waddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		we : in std_logic;
		di : in std_logic_vector(datawidth - 1 downto 0);
		-- port B (read-only, asynchronous)
		raddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		re : in std_logic;
		do : out std_logic_vector(datawidth - 1 downto 0)
		-- pragma translate_off
		; vtophys : out virt_to_phys_table_type
		-- pragma translate_on
	);
end entity virt_to_phys_async;

architecture syn of virt_to_phys_async is

	--subtype std_ram_word is std_logic_vector(datawidth - 1 downto 0);
	--type mem_content_type is array(integer range 0 to datadepth - 1)
	--	of std_ram_word;

	-- if FPGA technology does not support the initialization of memory at
	-- configuration time, or if you're targeting an ASIC, a small amount of
	-- logic should be added to write Identity permutation into memory at
	-- reset time (actually it is so small we could add the feature whatever
	-- the target). This means writing 0 at address 0, 1 at address 1, 2 at
	-- address 2, etc until the top word in memory
	function init_vp_ram return virt_to_phys_table_type is
		variable m : virt_to_phys_table_type;
	begin
		for i in 0 to nblargenb - 1 loop
			m(i) := std_logic_vector(to_unsigned(i, log2(nblargenb - 1)));
		end loop;
		return m;
	end function;

	signal r_mem_content : virt_to_phys_table_type := init_vp_ram;

begin

	-- --------------------------
	-- port A (synchronous write)
	-- --------------------------
	process(clk)
	begin
		if (clk'event and clk = '1') then
			-- (in simulation, only affects array content if no METAVALUE in rwaddra)
			-- otherwise issue a WARNING message
			if (we = '1') then
				assert(not is_X(waddr))
					report "write to virt_to_phys_async with a METAVALUE address"
						severity WARNING;
				r_mem_content(to_integer(unsigned(waddr))) <= di;
			end if;
		end if;
	end process;

	-- --------------------------
	-- port B (asynchronous read)
	-- --------------------------
	process(raddr, re)
	begin
		-- (in simulation returns 'force unknown' ('X') if METAVALUE in raddrb)
		if (re = '1') then
			-- pragma translate_off
			if is_X(raddr) then
				do <= (others => 'X');
			else
			-- pragma translate_on
				do <= r_mem_content(to_integer(unsigned(raddr)));
			-- pragma translate_off
			end if;
			-- pragma translate_on
		end if;
	end process;
	
	-- pragma translate_off
	process(clk)
	begin
		if (clk'event and clk = '1') then
			vtophys <= r_mem_content;
		end if;
	end process;
	-- pragma translate_on

end architecture syn;
