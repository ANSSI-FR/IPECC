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

use work.ecc_customize.all; -- for 'debug' parameter
use work.ecc_log.all;
use work.ecc_utils.all;
use work.ecc_pkg.all;
use work.ecc_trng_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

-- This released version of ecc_trng_pp DOES NOT actually implement any
-- cryptographic preprocessing - instead it only reformats bytes received
-- from the entropy source (es_trng) into words of 'pp_irn_width' bits
-- (generic parameter that should typically be set to 32 or 64 bits).

entity ecc_trng_pp is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with ecc_scalar
		irn_reset : in std_logic;
		-- interface with es_trng
		data_t : in std_logic_vector(7 downto 0);
		valid_t : in std_logic;
		rdy_t : out std_logic;
		-- interface with ecc_trng_srv
		data_s : out std_logic_vector(pp_irn_width - 1 downto 0);
		valid_s : out std_logic;
		rdy_s : in std_logic;
		dbgtrngrawpullppdis : in std_logic;
		dbgtrngusepseudosource : in std_logic;
		-- interface with the external pseudo TRNG component
		dbgpseudotrngdata : in std_logic_vector(7 downto 0);
		dbgpseudotrngvalid : in std_logic;
		dbgpseudotrngrdy : out std_logic
	);
end entity ecc_trng_pp;

architecture rtl of ecc_trng_pp is

	type reg_type is record
		rdy_t : std_logic;
		shdata8 : std_logic_vector(7 downto 0);
		sh8canberead : std_logic;
		shicanbewritten : std_logic;
		shdatai : std_logic_vector(pp_irn_width - 1 downto 0);
		shcnt8 : unsigned(2 downto 0);
		shcnti : unsigned(log2(pp_irn_width - 1) - 1 downto 0);
		valid_s : std_logic;
		-- debug pseudo TRNG device
		pseudo_rdy : std_logic;
		usepstprev : std_logic;
		raw_pull_inactive : std_logic;
	end record;

	signal r, rin : reg_type;

begin

	comb: process(r, rstn, data_t, valid_t, rdy_s, swrst, irn_reset,
		            dbgtrngrawpullppdis, dbgtrngusepseudosource,
		            dbgpseudotrngdata, dbgpseudotrngvalid)
		variable v : reg_type;
	begin
		v := r;

		if debug then -- statically resolved by synthesizer
			if dbgtrngusepseudosource = '0' then
				-- valid_t/rdy_t handshake, with real TRNG source
				if r.rdy_t = '1' and valid_t = '1' then
					v.shdata8 := data_t;
					v.sh8canberead := '1';
					--v.shcnt8 := (others => '0'); -- useless
					v.rdy_t := '0';
				end if;
			elsif dbgtrngusepseudosource = '1' then
				if r.pseudo_rdy = '1' and dbgpseudotrngvalid = '1' then
					v.shdata8 := dbgpseudotrngdata;
					v.sh8canberead := '1';
					v.pseudo_rdy := '0';
				end if;
			end if;
		else -- not debug
			-- valid_t/rdy_t handshake
			if r.rdy_t = '1' and valid_t = '1' then
				v.shdata8 := data_t;
				v.sh8canberead := '1';
				--v.shcnt8 := (others => '0'); -- useless
				v.rdy_t := '0';
			end if;
		end if;
		
		if r.sh8canberead = '1' and r.shicanbewritten = '1' then
			-- empty r.shdata8
			v.shdata8 := '0' & r.shdata8(7 downto 1);
			-- fill r.shdatai
			v.shdatai := r.shdata8(0) & r.shdatai(pp_irn_width - 1 downto 1);
			-- counters
			v.shcnt8 := r.shcnt8 + 1;
			v.shcnti := r.shcnti + 1;
			-- detect and handle counters overflow
			if r.shcnt8 = to_unsigned(7, 3) then
				v.sh8canberead := '0';
				if (not debug) -- statically resolved by synthesizer
					or dbgtrngusepseudosource = '0'
				then
					v.rdy_t := '1';
				elsif dbgtrngusepseudosource = '1' then
					v.pseudo_rdy := '1';
				end if;
			end if;
			if r.shcnti = to_unsigned(pp_irn_width - 1, log2(pp_irn_width - 1)) then
				v.shicanbewritten := '0';
				v.valid_s := '1';
			end if;
		end if;

		-- valid_s/rdy_s handshake
		if rdy_s = '1' and r.valid_s = '1' then
			v.valid_s := '0';
			v.shcnti := (others => '0');
			v.shicanbewritten := '1';
		end if;

		-- Switch from one state to the other (real to pseudo or pseudo to real).
		if debug then -- statically resolved by synthesizer
			-- When switching from one state to the other (real/pseudo TRNG source)
			-- we must do as if there was a reset.
			v.usepstprev := dbgtrngusepseudosource;
			if r.usepstprev = '0' and dbgtrngusepseudosource = '1' then
				-- We switch from real TRNG to pseudo TRNG.
				v.rdy_t := '0';
				v.pseudo_rdy := '1';
				v.sh8canberead := '0';
				v.shicanbewritten := '1';
				v.valid_s := '0';
				v.shcnt8 := (others => '0');
				v.shcnti := (others => '0');
				v.shdata8 := (others => '0');
				v.shdatai := (others => '0');
			elsif r.usepstprev = '1' and dbgtrngusepseudosource = '0' then
				-- We switch from pseudo TRNG to real one.
				v.pseudo_rdy := '0';
				v.rdy_t := '1';
				v.sh8canberead := '0';
				v.shicanbewritten := '1';
				v.valid_s := '0';
				v.shcnt8 := (others => '0');
				v.shcnti := (others => '0');
				v.shdata8 := (others => '0');
				v.shdatai := (others => '0');
			end if;
		end if;

		-- Activation/deactivation (by software) of the logic pulling bytes
		-- from the raw random source, whether it is the real TRNG source
		-- (the one internal to the IP) or the external pseudo TRNG one.
		-- This obviously only concerns debug mode.
		if debug then -- statically resolved by synthesizer
			v.raw_pull_inactive := dbgtrngrawpullppdis;
			if dbgtrngrawpullppdis = '1' then
				-- The software has disabled the pulling of bytes.
				v.rdy_t := '0';
				v.pseudo_rdy := '0';
			elsif r.raw_pull_inactive = '1' and dbgtrngrawpullppdis = '0' then
				-- The software has activated the pulling of bytes.
				if dbgtrngusepseudosource = '0' then
					v.rdy_t := '1';
					v.pseudo_rdy := '0';
				elsif dbgtrngusepseudosource = '1' then
					v.rdy_t := '0';
					v.pseudo_rdy := '1';
				end if;
			end if;
		end if; -- debug

		-- synchronous reset
		if rstn = '0' or swrst = '1' or (debug and irn_reset = '1') then
			if not debug then -- statically resolved by synthesizer
				-- In production mode, we only use the real TRNG source,
				-- and we immediately start pulling data from it as soon as
				-- we leave the reset state.
				v.rdy_t := '1';
				v.pseudo_rdy := '0';
			else
				-- In debug mode, pulling raw random bytes (from either the
				-- real TRNG or the pseudo TRNG) is kept stalled at the output
				-- of reset.
				-- This allows software to choose the source (real or pseudo)
				-- and then activate the pulling from it, making the subsequent
				-- IRN stream totally deterministic when using the pseudo TRNG
				-- source (for comparison with the HDL simulation testbench).
				v.rdy_t := '0';
				v.pseudo_rdy := '0';
				v.raw_pull_inactive := '1';
			end if;
			v.sh8canberead := '0';
			v.shicanbewritten := '1';
			v.shcnt8 := (others => '0');
			v.shcnti := (others => '0');
			v.valid_s := '0';
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
	rdy_t <= r.rdy_t;
	valid_s <= r.valid_s;
	data_s <= r.shdatai;

	-- handshake with pseudo TRNG external device
	dbgpseudotrngrdy <= r.pseudo_rdy;

end architecture rtl;
