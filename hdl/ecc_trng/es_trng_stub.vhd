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
use work.ecc_custom.all; -- for 'simtrngfile'
use work.ecc_utils.all; -- for log2() & ge_pow_of_2()

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity es_trng_stub is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with ecc_trng_pp
		data_t : out std_logic_vector(7 downto 0);
		valid_t : out std_logic;
		rdy_t : in std_logic;
		-- following signals are for debug & statistics
		dbgtrngta : in unsigned(19 downto 0);
		dbgtrngrawreset : in std_logic;
		dbgtrngrawfull : out std_logic;
		dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawdata : out std_logic;
		dbgtrngppdeact : in std_logic;
		dbgtrngrawduration : out unsigned(31 downto 0);
		dbgtrngvonneuman : in std_logic;
		dbgtrngidletime : in unsigned(3 downto 0)
	);
end entity es_trng_stub;

architecture struct of es_trng_stub is

	type reg_type is record
		data_t : std_logic_vector(7 downto 0);
		valid_t : std_logic;
		oor : std_logic;
	end record;

	signal r, rin : reg_type;

	file fr: text is simtrngfile;

begin

	comb: process(r, rstn, rdy_t, dbgtrngrawreset, swrst)
		variable v : reg_type;
		variable tline : line;
		variable good : boolean;
		--variable byte : std_logic_vector(7 downto 0);
		variable nb : integer;
		variable nbl : integer := 1;
	begin
		v := r;

		v.oor := '0';

		if r.oor = '0' and r.valid_t = '0' then -- out-of-reset
			-- read a new line from input file
			readline(fr, tline);
			read(tline, nb);
			assert nb < 256
				report "wrong random value from input test file (line "
							 & integer'image(nbl) & ")"
					severity failure;
			nbl := nbl + 1;
			v.data_t := std_logic_vector(to_unsigned(nb, 8));
			v.valid_t := '1';
		end if;

		-- each time a new value is transferred, read again from file if needed
		if r.valid_t = '1' and rdy_t = '1' then
			-- read a new line from input file
			readline(fr, tline);
			read(tline, nb);
			assert nb < 256
				report "wrong random value from input test file (line "
							 & integer'image(nbl) & ")"
					severity failure;
			nbl := nbl + 1;
			v.data_t := std_logic_vector(to_unsigned(nb, 8));
		end if;

		-- synchronous reset
		if rstn = '0' or dbgtrngrawreset = '1' or swrst = '1' then
			v.valid_t := '0';
			v.oor := '1';
		end if;

		rin <= v;
	end process comb;

	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			r <= rin;
		end if;
	end process regs;

	-- drive outputs
	data_t <= r.data_t;
	valid_t <= r.valid_t;
	dbgtrngrawfull <= 'X';
	dbgtrngrawwaddr <= (others => 'X');
	dbgtrngrawdata <= 'X';
	dbgtrngrawduration <= (others => 'X');

end architecture struct;
