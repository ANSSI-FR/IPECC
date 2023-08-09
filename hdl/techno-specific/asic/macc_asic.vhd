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

use work.ecc_log.all; -- for ln2()
use work.ecc_pkg.all;
use work.mm_ndsp_pkg.all; -- for 'ndsp'

entity macc_asic is
	generic(
		breg : positive range 1 to 2;
		accumulate : boolean
	); port (
		clk  : in std_logic;
		-- signals to/from general purpose logic fabric
		rst  : in std_logic;
		rstm : in std_logic;
		rstp : in std_logic;
		A     : in std_logic_vector(ww - 1 downto 0);
		B     : in std_logic_vector(ww - 1 downto 0);
		PCIN  : in std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
		P     : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
		ACOUT : out std_logic_vector(ww - 1 downto 0);
		BCOUT : out std_logic_vector(ww - 1 downto 0);
		-- CE of DSP registers
		CEA : in std_logic;
		CEB1 : in std_logic;
		CEB2 : in std_logic;
		CEP : in std_logic
	);
end entity macc_asic;

architecture rtl of macc_asic is

	signal ra : unsigned(ww - 1 downto 0);
	signal rb1 : unsigned(ww - 1 downto 0);
	signal rb2 : unsigned(ww - 1 downto 0);
	signal rm : unsigned(2*ww - 1 downto 0);
	signal rp : unsigned(2*ww + ln2(ndsp) - 1 downto 0);

begin

	process(clk)
	begin
		if clk'event and clk = '1' then
			if CEA = '1' then
				ra <= unsigned(A); 
			end if;
			-- 2 modes of operation : multiply or accumulate
			if not accumulate then
				if CEB1 = '1' then
					rb1 <= unsigned(B);
				end if;
				-- ra & rb1 are both unsigned so "*" operator will produce an
				-- unsigned result (meaning w/ an MSbit that is NOT a sign bit)
				-- (see VHDL file <numeric_std.vhd> from IEEE Std 1076-2008,
				-- search twice for string "A.15")
				rm <= ra * rb1;
				if CEP = '1' then
					-- (s0) rm being an unsigned, resize function can't but add 0
					-- as MSbits, keeping resulting numver positive
					-- (see VHDL file <numeric_std.vhd> from IEEE Std 1076-2008,
					-- search twice for string "R.2")
					-- see also (s1) below
					rp <= resize(rm, 2*ww + ln2(ndsp));
				end if;
			else -- accumulate
				if CEB1 = '1' then
					rb1 <= unsigned(B);
				end if;
				if CEB2 = '1' then
					rb2 <= rb1;
				end if;
				rm <= ra * rb2; -- two's complement sign extension
				if CEP = '1' then
					rp <= unsigned(PCIN)
						-- (s1) same remark on resize function as for (s0) above
					  + resize(rm, 2*ww + ln2(ndsp));
				end if;
			end if;
			-- synchronous resets
			if rst = '1' then
				ra <= (others => '0');
				rb1 <= (others => '0');
				rb2 <= (others => '0');
			end if;
			if rstm = '1' then
				rm <= (others => '0');
			end if;
			if rstp = '1' then
				rp <= (others => '0');
			end if;
		end if;
	end process;

	P <= std_logic_vector(rp);
	ACOUT <= std_logic_vector(ra);

	b0: if accumulate generate
		BCOUT <= std_logic_vector(rb2);
	end generate;

	b1: if not accumulate generate
		BCOUT <= std_logic_vector(rb1);
	end generate;

end architecture rtl;
