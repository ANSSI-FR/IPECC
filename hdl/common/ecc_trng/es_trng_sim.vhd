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

use work.ecc_pkg.all; -- for 'std_logic2'
use work.ecc_log.all;
use work.ecc_customize.all; -- for 'simtrngfile'
use work.ecc_trng_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity es_trng_sim is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with ecc_trng_pp
		data_t : out std_logic_vector(7 downto 0);
		valid_t : out std_logic;
		rdy_t : in std_logic;
		-- following signals are for debug & statistics
		dbgtrngta : in unsigned(15 downto 0);
		dbgtrngrawreset : in std_logic;
		dbgtrngrawfull : out std_logic;
		dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawdata : out std_logic;
		dbgtrngrawfiforeaddis : in std_logic;
		dbgtrngrawduration : out unsigned(31 downto 0);
		dbgtrngvonneuman : in std_logic;
		dbgtrngidletime : in unsigned(3 downto 0)
	);
end entity es_trng_sim;

architecture struct of es_trng_sim is

	signal r_valid_t : std_logic;
	signal r_oor : std_logic;

	-- This is where the file whose name is set in 'ecc_customize' is read.
	file fr: text is simtrngfile;

begin

	process(clk)
		variable tline : line;
		variable nb : integer;
		variable nbl : integer := 1;
	begin
		if clk'event and clk = '1' then
			if rstn = '0' or dbgtrngrawreset = '1' or swrst = '1' then
				data_t <= (others => 'X');
				r_valid_t <= '0';
				r_oor <= '1';
			else
				r_oor <= '0';
				if r_oor = '1' then
					-- Read a new line from input file.
					readline(fr, tline);
					read(tline, nb);
					assert nb < 256
						report "wrong random value from input test file (line "
									 & integer'image(nbl) & ")"
							severity failure;
					data_t <= std_logic_vector(to_unsigned(nb, 8));
					r_valid_t <= '1';
				elsif r_oor = '0' then
					if r_valid_t = '1' and rdy_t = '1' then 
						-- Read a new line from input file.
						readline(fr, tline);
						read(tline, nb);
						assert nb < 256
							report "wrong random value from input test file (line "
										 & integer'image(nbl) & ")"
								severity failure;
						data_t <= std_logic_vector(to_unsigned(nb, 8));
						r_valid_t <= '1';
					end if;
				end if;
			end if;
		end if;
	end process;

	valid_t <= r_valid_t;

	dbgtrngrawfull <= 'X';
	dbgtrngrawwaddr <= (others => 'X');
	dbgtrngrawdata <= 'X';
	dbgtrngrawduration <= (others => 'X');

end architecture struct;
