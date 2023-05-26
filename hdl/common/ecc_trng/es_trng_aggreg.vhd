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

use work.ecc_customize.all; -- for 'debug'

entity es_trng_aggreg is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with downstream es_trng_aggreg
		raw : out std_logic;
		valid : out std_logic;
		rdy : in std_logic;
		-- interface with first upstream es_trng_aggreg
		raw0 : in std_logic;
		valid0 : in std_logic;
		rdy0 : out std_logic;
		-- interface with second upstream es_trng_aggreg
		raw1 : in std_logic;
		valid1 : in std_logic;
		rdy1 : out std_logic;
		-- following signals are for debug & statistics
		dbgtrngrawreset : in std_logic
	);
end entity es_trng_aggreg;

architecture rtl of es_trng_aggreg is

	type reg_type is record
		priority : std_logic;
		raw : std_logic;
		valid : std_logic;
		rdy0, rdy1 : std_logic;
	end record;

	signal vcc : std_logic := '1';

	signal r, rin : reg_type;

begin

	-- combinational logic
	comb: process(r, rstn, rdy, raw0, valid0, raw1, valid1,
			swrst, dbgtrngrawreset)
		variable v : reg_type;
		variable valid01 : std_logic_vector(0 to 1);
	begin
		v := r;

		valid01 := valid0 & valid1;

		-- handshake with downstream es_trng_aggreg
		if r.valid = '1' and rdy = '1' then
			v.valid := '0';
			v.rdy0 := not r.priority;
			v.rdy1 := r.priority;
		end if;

		-- handshake with first upstream es_trng_aggreg
		if valid0 = '1' and r.rdy0 = '1' then
			v.rdy0 := '0';
			v.raw := raw0;
			v.valid := '1';
			v.priority := '1';
		end if;

		-- handshake with second upstream es_trng_aggreg
		if valid1 = '1' and r.rdy1 = '1' then
			v.rdy1 := '0';
			v.raw := raw1;
			v.valid := '1';
			v.priority := '0';
		end if;

		if valid0 = '0' and -- no bit on input 0
			(valid1 = '1' and r.rdy1 = '0') and -- a bit on input 1 but no grant
			(r.valid = '0' or rdy = '1') -- local buffer free or about to become
		then
			v.rdy1 := '1'; -- grant input 1
			v.rdy0 := '0'; -- forbid intput 0
		end if;

		if valid1 = '0' and -- no bit on input 1
			(valid0 = '1' and r.rdy0 = '0') and -- a bit on input 0 but no grant
			(r.valid = '0' or rdy = '1') -- local buffer free or about to become
		then
			v.rdy0 := '1'; -- grant input 0
			v.rdy1 := '0'; -- forbid input 1
		end if;

		if valid0 = '0' and valid1 = '0' and -- no bit neither on input 0 nor 1
			(r.valid = '0' or rdy = '1') -- local buffer free or about to become
		then
			v.rdy0 := not r.priority; -- grant the input that has priority
			v.rdy1 := r.priority;     -- and forbid the other one
		end if;

		-- synchronous reset
		if rstn = '0' or (debug and dbgtrngrawreset = '1') or swrst = '1' then
			v.priority := '0';
			v.valid := '0';
			v.rdy0 := '1';
			v.rdy1 := '0';
		end if;

		rin <= v;
	end process comb;

	-- registers
	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			r  <= rin;
		end if;
	end process regs;

	-- drive outputs
	raw <= r.raw;
	valid <= r.valid;
	rdy0 <= r.rdy0;
	rdy1 <= r.rdy1;

end architecture rtl;
