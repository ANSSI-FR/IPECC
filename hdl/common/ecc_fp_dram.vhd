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

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

use work.ecc_customize.all;
use work.ecc_utils.all;
use work.ecc_pkg.all;
use work.ecc_vars.all;

-- code below conforms to Xilinx's synthesis recommandations for
-- VHDL coding style of a simple dual-port BRAM with _two_clocks_
-- (see Vivado Design Suite User Guide, Synthesis, UG901, v2014.1,
--  May 1, 2014, pp. 104-105)
-- except that it describes a two-cycle delay on the read data path.
-- Depending on the FPGA vendor/family device target, an extra-layer of
-- register may be present inside the Block-RAM providing such 2-cycle
-- latency, as it leads to better timing performance (at the cost of
-- a small increase in the Block-RAM area).
-- In this case it is best for area performance to ensure that the
-- extra register layer on the read data path is held back inside
-- the Block-RAM by back-end tools
entity ecc_fp_dram is
	generic(rdlat : positive range 1 to 2);
	port(
		clk : in std_logic;
		-- port A: write-only interface from ecc_fp
		-- (actually for write-access from AXI-lite interface)
		ena : in std_logic;
		wea : in std_logic;
		addra : in std_logic_vector(FP_ADDR - 1 downto 0);
		dia : in std_logic_vector(ww - 1 downto 0);
		-- port B: read-only interface to ecc_fp
		reb : in std_logic;
		addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
		dob : out std_logic_vector(ww - 1 downto 0)
		-- pragma translate_off
		-- interface with ecc_fp (simu only)
		; fpdram : out fp_dram_type
		-- pragma translate_on
	);
end entity ecc_fp_dram;

architecture syn of ecc_fp_dram is

	function init_ecc_fp_dram return fp_dram_type is
		variable vram : fp_dram_type;
		variable v_constant_r : std_logic_ww;
	begin
		for i in 0 to n - 1 loop
			vram((LARGE_NB_R_ADDR * n) + i) := (others => '0');
		end loop;
		v_constant_r := (others => '0');
		v_constant_r((nn + 2) mod ww) := '1';
		vram((LARGE_NB_R_ADDR * n) + ((nn + 2)/ww)) := v_constant_r;
		-- big number 1 constant
		for i in 1 to n - 1 loop
			vram((LARGE_NB_ONE_ADDR * n) + i) := (others => '0');
		end loop;
		vram(LARGE_NB_ONE_ADDR * n) := std_logic_vector(to_unsigned(1, ww));
		-- big number constant 0
		for i in 0 to n - 1 loop
			vram((LARGE_NB_ZERO_ADDR * n) + i) := (others => '0');
		end loop;
		return vram;
	end function;

	-- if FPGA technology does not support the initialization of memory at
	-- configuration time a small smount of logic should be added to write
	-- number 1 (as a 'ww'-bit word) at address 30*n of memory at reset time
	-- (actually it is so small we could add the feature whatever the target)
	shared variable mem_content : fp_dram_type := init_ecc_fp_dram;

	signal predob : std_logic_ww;

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
						report "write to ecc_fp_dram with a METAVALUE address"
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
				if (reb = '1') then
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
				if (reb = '1') then
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

	-- pragma translate_off
	process(clk)
	begin
		if (clk'event and clk = '1') then
			fpdram <= mem_content;
		end if;
	end process;
	-- pragma translate_on

end architecture syn;
