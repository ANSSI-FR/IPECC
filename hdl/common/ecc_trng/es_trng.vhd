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
use work.ecc_customize.all; -- for 'nbtrng'
use work.ecc_utils.all; -- for ge_pow_of_2()
use work.ecc_trng_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity es_trng is
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
end entity es_trng;

architecture struct of es_trng is

	component es_trng_bitctrl is
		generic(index : natural);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- interface with es_trng_aggreg
			raw : out std_logic;
			valid : out std_logic;
			rdy : in std_logic;
			-- following signals are for debug & statistics
			dbgtrngrawreset : in std_logic;
			dbgtrngta : in unsigned(15 downto 0);
			dbgtrngvonneuman : in std_logic;
			dbgtrngidletime : in unsigned(3 downto 0)
		);
	end component es_trng_bitctrl;

	component es_trng_aggreg is
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
			-- following signal is for debug
			dbgtrngrawreset : in std_logic
		);
	end component es_trng_aggreg;

	subtype std_logic_nbtrng is std_logic_vector(nbtrng - 1 downto 0);
	type arreg_array_type is array(0 to nbtrng - 1) of std_logic2;

	signal raw0, valid0, rdy0 : std_logic_vector(nbtrng - 1 downto 0);
	signal raw1, valid1, rdy1 : std_logic_vector(nbtrng - 1 downto 0);

	signal validi, rawi : std_logic;
	signal full, empty : std_logic;
	signal rawout : std_logic_vector(0 downto 0);
	signal count : std_logic_vector(log2(raw_ram_size) - 1 downto 0);

	type reg_type is record
		-- interface w/ the production side of the FIFO (es_trng_bitctrl's)
		rdyi : std_logic;
		rawi : std_logic;
		we : std_logic;
		-- interface w/ the consuming side of the FIFO (ecc_trng_pp)
		re : std_logic;
		react : std_logic;
		rawout : std_logic;
		recnt : unsigned(3 downto 0);
		shre0, shre1 : std_logic;
		shbyte : std_logic_vector(7 downto 0);
		valid_t : std_logic;
		shcnt : unsigned(2 downto 0);
		fifotime : unsigned(31 downto 0);
		fifodocnt : std_logic;
	end record;

	signal r, rin : reg_type;
	signal r_rawi : std_logic_vector(0 downto 0);

	-- pragma translate_off
	signal r_rawnb : natural := 0;
	signal r_rawnb0 : natural := 0;
	signal r_rawnb1 : natural := 0;
	signal r_rawnb2 : natural := 0;
	signal r_rawnb3 : natural := 0;
	signal r_raw0 : std_logic_vector(ww - 1 downto 0);
	signal r_raw1 : std_logic_vector(ww - 1 downto 0);
	signal r_raw2 : std_logic_vector(1 downto 0);
	signal r_raw3 : std_logic_vector((2*(5+log2(n)-1)) - 1 downto 0);
	-- pragma translate_on

begin

	b: if nbtrng = 1 generate
		b: es_trng_bitctrl
			generic map(index => 0)
			port map(
				clk => clk,
				rstn => rstn,
				swrst => swrst,
				-- interface with downstream es_trng_aggreg
				raw => rawi,
				valid => validi,
				rdy => r.rdyi,
				-- following signals are for debug & statistics
				dbgtrngrawreset => dbgtrngrawreset,
				dbgtrngta => dbgtrngta,
				dbgtrngvonneuman => dbgtrngvonneuman,
				dbgtrngidletime => dbgtrngidletime
			);
	end generate;

	bn:  if nbtrng > 1 generate
		-- all es_trng_bitctrl instances
		bg: for i in 0 to nbtrng - 1 generate
			b: es_trng_bitctrl
				generic map(index => i)
				port map(
					clk => clk,
					rstn => rstn,
					swrst => swrst,
					-- interface with downstream es_trng_aggreg
					raw => raw0(i),
					valid => valid0(i),
					rdy => rdy0(i),
					-- following signals are for debug & statistics
					dbgtrngrawreset => dbgtrngrawreset,
					dbgtrngta => dbgtrngta,
					dbgtrngvonneuman => dbgtrngvonneuman,
					dbgtrngidletime => dbgtrngidletime
				);
		end generate;
		-- all es_trng_aggreg instances but the (i,j)=(0,0) one (the most upstream)
		ag: for i in 0 to nbtrng - 2 generate
			a: es_trng_aggreg
				port map(
					clk => clk,
					rstn => rstn,
					swrst => swrst,
					-- interface with downstream es_trng_aggreg
					raw => raw1(i),
					valid => valid1(i),
					rdy => rdy1(i),
					-- interface with first upstream es_trng_aggreg
					raw0 => raw0(i),
					valid0 => valid0(i),
					rdy0 => rdy0(i),
					-- interface with second upstream es_trng_aggreg
					raw1 => raw1(i + 1),
					valid1 => valid1(i + 1),
					rdy1 => rdy1(i + 1),
					-- debug
					dbgtrngrawreset => dbgtrngrawreset
				);
		end generate; -- i
		raw1(nbtrng - 1) <= raw0(nbtrng - 1);
		valid1(nbtrng - 1) <= valid0(nbtrng - 1);
		rdy0(nbtrng - 1) <= rdy1(nbtrng - 1);
		-- connection of aggreg #0 to output
		rawi <= raw1(0);
		validi <= valid1(0);
		rdy1(0) <= r.rdyi;
	end generate; -- nbtrng

	r_rawi(0) <= r.rawi;

	-- This is the raw random FIFO.
	f0: fifo
		generic map(
			datawidth => 1, datadepth => raw_ram_size,
			debug => debug)
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			datain => r_rawi,
			we => r.we,
			werr => open,
			full => full,
			dataout => rawout,
			re => r.re,
			empty => empty,
			rerr => open,
			count => count,
			-- debug feature
			dbgdeact => dbgtrngrawfiforeaddis,
			dbgwaddr => dbgtrngrawwaddr,
			dbgraddr => dbgtrngrawraddr,
			dbgrst => dbgtrngrawreset
		);

	comb: process(r, rstn, rawi, validi, rawout, full, empty, count, rdy_t,
		            dbgtrngrawfiforeaddis, dbgtrngrawreset, swrst)
		variable v : reg_type;
	begin
		v := r;

		-- -------------------------
		-- WRITE-into-the-FIFO logic
		-- -------------------------

		-- Continuously fill the FIFO with raw random bits as long as it does
		-- not show a FULL state;

		v.we := '0';

		if validi = '1' and r.rdyi = '1' then
			v.rawi := rawi;
			v.we := '1';
		end if;

		-- Deassertion of r.rdyi
		if r.we = '1' and count = std_logic_vector(
			to_unsigned(raw_ram_size - 2, log2(raw_ram_size)))
		then
			v.rdyi := '0';
		end if;

		-- Reassertion of r.rdyi
		if full = '0' then
			v.rdyi := '1';
		end if;
	
		-- ------------------------
		-- READ-from-the-FIFO-logic
		-- ------------------------

		-- Continuously empty the bits from the FIFO as long as it does not
		-- show an EMPTY state (and as long as we're not in debug deactivation
		-- mode (which is indicated by input port 'dbgtrngrawfiforeaddis'
		-- asserted high).

		v.re := '0';

		-- Condition dbgtrngrawfiforeaddis = '0' below ensures that r.re will stay
		-- low whenever dbgtrngrawfiforeaddis = 1.
		if empty = '0' and r.recnt /= to_unsigned(8, 4) and r.react = '1'
			and ((not debug) or dbgtrngrawfiforeaddis = '0')
		then
			v.re := '1';
		end if;

		if r.re = '1' then
			v.recnt := r.recnt + 1;
			if r.recnt = to_unsigned(7, 4) then
				v.re := '0';
				v.react := '0';
			end if;
		end if;

		if r.re = '1' and unsigned(count) = to_unsigned(1, log2(raw_ram_size)) then
			v.re := '0';
		end if;

		v.shre0 := r.re;
		v.shre1 := r.shre0;

		-- Shift-register
		if r.shre1 = '1' then
			v.shbyte := rawout(0) & r.shbyte(7 downto 1);
			v.shcnt := r.shcnt + 1;
			if r.shcnt = to_unsigned(7, 3) then
				v.valid_t := '1';
			end if;
		end if;

		-- Hansdhake valid_t/rdy_t
		if r.valid_t = '1' and rdy_t = '1' then
			v.valid_t := '0';
			v.react := '1';
			v.recnt := (others => '0');
		end if;

		if r.fifodocnt = '1' then
			v.fifotime := r.fifotime + 1;
		end if;

		-- As soon as the FIFO becomes FULL for the first time following last
		-- reset, we stop counting cycles.
		-- This allows any debug software to know the time it took to
		-- completely fill the FIFO, and hence to estimate the random
		-- production throughput of es_trng.
		-- Of course this requires to first set the FIFO into debug
		-- deactivation mode (by asserting 'dbgtrngrawfiforeaddis' high) so that the
		-- FIFO can no longer be accessed (emptied) by ecc_trng_pp component.
		if full = '1' then
			v.fifodocnt := '0';
		end if;

		-- Synchronous reset
		if rstn = '0' or dbgtrngrawreset = '1' or swrst = '1' then
			v.we := '0';
			v.rdyi := '1';
			v.re := '0';
			v.react := '1';
			v.recnt := (others => '0');
			v.shre0 := '0';
			v.shre1 := '0';
			v.valid_t := '0';
			v.shcnt := (others => '0');
			v.fifotime := (others => '0');
			v.fifodocnt := '1';
		end if;

		rin <= v;
	end process comb;

	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			r <= rin;
		end if;
	end process regs;

	-- Drive outputs
	data_t <= r.shbyte;
	valid_t <= r.valid_t;
	dbgtrngrawfull <= full;
	dbgtrngrawdata <= rawout(0);
	dbgtrngrawduration <= r.fifotime;

end architecture struct;
