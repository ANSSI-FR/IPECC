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

use work.ecc_utils.all;
use work.ecc_pkg.all;
use work.ecc_trng_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

-- released version of ecc_trng_pp DOES NOT actually implement any crypto-
-- graphic preprocessing - instead it only reformats bytes received from
-- the entropy source (es_trng) into words of 'pp_irn_width' bits (generic
-- parameter that should typically be set to 32 or 64 bits).

entity ecc_trng_pp is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with es_trng
		data_t : in std_logic_vector(7 downto 0);
		valid_t : in std_logic;
		rdy_t : out std_logic;
		-- interface with ecc_trng_srv
		data_s : out std_logic_vector(pp_irn_width - 1 downto 0);
		valid_s : out std_logic;
		rdy_s : in std_logic
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
	end record;

	signal r, rin : reg_type;

begin

	comb: process(r, rstn, data_t, valid_t, rdy_s, swrst)
		variable v : reg_type;
	begin
		v := r;

		-- valid_t/rdy_t handshake
		if r.rdy_t = '1' and valid_t = '1' then
			v.shdata8 := data_t;
			v.sh8canberead := '1';
			--v.shcnt8 := (others => '0'); -- useless
			v.rdy_t := '0';
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
				v.rdy_t := '1';
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

		-- synchronous reset
		if rstn = '0' or swrst = '1' then
			v.rdy_t := '1';
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

end architecture rtl;
