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
use work.ecc_pkg.all; -- for syncram_sdp
use work.ecc_customize.all; -- for 'debug'

entity fifo is
	generic(
		datawidth : natural range 1 to integer'high;
		datadepth : natural range 1 to integer'high);
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		datain : in std_logic_vector(datawidth - 1 downto 0);
		we : in std_logic;
		werr : out std_logic;
		full : out std_logic;
		dataout : out std_logic_vector(datawidth - 1 downto 0);
		re : in std_logic;
		empty : out std_logic;
		rerr : out std_logic;
		count : out std_logic_vector(log2(datadepth) - 1 downto 0);
		-- debug feature
		-- When 'dbgdeact' is high, the read interface into the FIFO is
		-- no longer active ('re' input is simply ignored), instead the
		-- read address to the memory array is sampled from 'dbgraddr'
		-- (output data remains driven onto 'dataout' port, same as in
		-- non-debug mode).
		-- Thus using 'dbgwaddr' and 'count' output ports, user debug logic
		-- can read the whole content of the FIFO without interfering with
		-- its content.
		-- Once 'dbgdeact' becomes low again, the read address to the memory
		-- array takes back the value it was holding at the time 'dbgdeact'
		-- was asserted, and the read interface into the FIFO becomes available
		-- again.
		-- The debug feature does not modify the behiavour of the write
		-- side interface of the FIFO
		dbgdeact : in std_logic;
		dbgwaddr : out std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		dbgraddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		dbgrst : in std_logic
	);
end entity fifo;

architecture syn of fifo is

	type reg_type is record
		we : std_logic;
		datain : std_logic_vector(datawidth - 1 downto 0);
		full : std_logic;
		empty : std_logic;
		count : std_logic_vector(log2(datadepth) - 1 downto 0);
		waddr : std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		raddr : std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		dbgraddrbkup : std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		dbgdeactprev : std_logic;
		werr, rerr : std_logic;
	end record;

	signal r, rin : reg_type;

	signal vcc : std_logic;

begin

	vcc <= '1';

	-- memory array
	s0 : syncram_sdp
		generic map(
			rdlat => 2,
			datawidth => datawidth,
			datadepth => datadepth)
		port map(
			clk => clk,
			-- port A (write/push/fill)
			addra => r.waddr,
			ena => vcc,
			wea => r.we,
			dia => r.datain,
			-- port B (read/pull/empty)
			addrb => r.raddr,
			enb => re,
			dob => dataout
		);

	-- combinational logic to generate count + empty & full flags
	comb : process(r, rstn, we, datain, re, dbgdeact, dbgraddr, dbgrst, swrst)
		variable v : reg_type;
	begin
		v := r;

		v.we := '0';

		v.dbgdeactprev := dbgdeact;

		-- write interface
		if we = '1' and r.full = '0' then
			v.datain := datain;
			v.we := '1';
			-- deassertion of empty flag
			v.empty := '0';
		end if;

		if r.we = '1' then
			v.waddr := std_logic_vector(unsigned(r.waddr) + 1);
		end if;

		-- read interface
		if ((debug and dbgdeact = '0' and r.dbgdeactprev = '0') or (not debug))
			and re = '1' and r.empty = '0'
		then
			v.raddr := std_logic_vector(unsigned(r.raddr) + 1);
			-- deassertion of full flag
			v.full := '0';
		end if;

		-- word count update
		if we = '1' and r.full = '0' then
			-- a write is occuring
			if ((debug and dbgdeact = '0' and r.dbgdeactprev = '0') or (not debug))
				and re = '1' and r.empty = '0'
			then
				-- the write is occuring with a simultaneous read
				null; -- r.count must stay the same
			elsif re = '0' or dbgdeact = '1' or r.dbgdeactprev = '1' then
				-- the write is occuring without a simultaneous read
				-- so increment r.count
				v.count := std_logic_vector(unsigned(r.count) + 1);
				if r.count = std_logic_vector(
					to_unsigned(datadepth - 1, log2(datadepth)))
				then
					-- assertion of full flag
					v.full := '1';
				end if;
			end if;
		end if;

		if ((debug and dbgdeact = '0' and r.dbgdeactprev = '0') or (not debug))
			and re = '1' and r.empty = '0'
			-- a read is occuring
		then
			if we = '1' and r.full = '0' then
				-- the read is occuring with a simultaneous write
				null; -- r.count must stay the same
			elsif we = '0' then
				-- the read is occuring without a simultaneous write
				-- so decrement r.count
				v.count := std_logic_vector(unsigned(r.count) - 1);
				if r.count = std_logic_vector(to_unsigned(1, log2(datadepth))) then
					-- assertion of empty flag
					v.empty := '1';
				end if;
			end if;
		end if;

		-- entering into debug deactivation mode
		if debug and r.dbgdeactprev = '0' and dbgdeact = '1' then
			-- back-up the current read address
			v.dbgraddrbkup := r.raddr;
		end if;

		-- while in debug deactivation mode, read address into memory array
		-- is taken from debug input port 'dbgraddr'
		if debug and dbgdeact = '1' then
			v.raddr := dbgraddr;
		end if;

		-- leaving the debug deactivation mode
		if debug and r.dbgdeactprev = '1' and dbgdeact = '0' then
			-- restore the nominal read address which was backed-up
			v.raddr := r.dbgraddrbkup;
		end if;

		-- error flags
		v.werr := '0';
		if we = '1' and r.full = '1' then
			v.werr := '1';
		end if;
		v.rerr := '0';
		if re = '1' and r.empty = '1' then
			v.rerr := '1';
		end if;

		-- synchronous reset
		if rstn = '0' or (debug and dbgrst = '1') or swrst = '1' then
			v.we := '0';
			v.count := (others => '0');
			v.empty := '1';
			v.full := '0';
			v.waddr := (others => '0');
			v.raddr := (others => '0');
			v.werr := '0';
			v.rerr := '0';
		end if;

		rin <= v;
	end process;

	regs : process(clk)
	begin
		if (clk'event and clk = '1') then
			r <= rin;
		end if;
	end process;

	-- generate outputs
	full <= r.full;
	empty <= r.empty;
	count <= r.count;
	dbgwaddr <= r.waddr;

end architecture syn;
