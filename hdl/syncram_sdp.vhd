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

use work.ecc_utils.all; -- for log2()
use work.ecc_pkg.all;
use work.ecc_customize.all; -- for techno

-- code below conforms to Xilinx's synthesis recommandations for
-- VHDL coding style of a simple dual-port BRAM with common clock
-- (see e.g Vivado Design Suite User Guide, Synthesis, UG901, v2014.1,
--  May 1, 2014)
-- except that it describes a two-cycle delay on the read data path.
-- Depending on the FPGA vendor/family/device target, an extra-layer of
-- register may be present inside the Block-RAM providing such 2-cycle
-- latency, as it leads to better timing results.
-- In this case it is best for area performance to ensure that the
-- extra register layer on the read data path is held back inside
-- the Block-RAM by synthesis/back-end tools
entity syncram_sdp is
	generic(
		rdlat : positive range 1 to 2;
		datawidth : natural range 1 to integer'high;
		datadepth : natural range 1 to integer'high);
	port(
		clk : in std_logic;
		-- port A (write-only)
		addra : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		ena : in std_logic;
		wea : in std_logic;
		dia : in std_logic_vector(datawidth - 1 downto 0);
		-- port B (read-only)
		addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		enb : in std_logic;
		dob : out std_logic_vector(datawidth - 1 downto 0)
	);
end entity syncram_sdp;

architecture syn of syncram_sdp is

	subtype std_ram_word is std_logic_vector(datawidth - 1 downto 0);
	type mem_content_type is array(integer range 0 to datadepth - 1)
		of std_ram_word;
	shared variable mem_content : mem_content_type;

	signal predob : std_ram_word;

begin

	-- -------------------
	-- port A (write-only)
	-- -------------------
	process(clk)
	begin
		if (clk'event and clk = '1') then
			-- write logic
			-- (in simulation, only affects array content if no METAVALUE in addra)
			-- otherwise issue a WARNING message
			if (ena = '1') then
				if (wea = '1') then
					assert(not is_X(addra))
						report "write to syncram_sdp with a METAVALUE address"
							severity WARNING;
					mem_content(to_integer(unsigned(addra))) := dia;
				end if;
			end if;
		end if;
	end process;

	-- ------------------
	-- port B (read-only)
	-- ------------------
	r1 : if rdlat = 1 generate
		process(clk)
		begin
			if (clk'event and clk = '1') then
				-- read logic
				-- (in simulation returns 'force unknown' ('X') if METAVALUE in addrb)
				if (enb = '1') then
					-- pragma translate_off
					if is_X(addrb) then
						dob <= (others => 'X');
					else
					-- pragma translate_on
						dob <= mem_content(to_integer(unsigned(addrb)));
					-- pragma translate_off
					end if;
					-- pragma translate_on
				end if;
			end if;
		end process;
	end generate;

	r2 : if rdlat = 2 generate
		process(clk)
		begin
			if (clk'event and clk = '1') then
				dob <= predob;
				-- read logic
				-- (in simulation returns 'force unknown' ('X') if METAVALUE in addrb)
				if (enb = '1') then
					-- pragma translate_off
					if is_X(addrb) then
						predob <= (others => 'X');
					else
					-- pragma translate_on
						predob <= mem_content(to_integer(unsigned(addrb)));
					-- pragma translate_off
					end if;
					-- pragma translate_on
				end if;
			end if;
		end process;
	end generate;

end architecture syn;
