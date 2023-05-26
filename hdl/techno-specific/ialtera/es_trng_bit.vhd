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

use work.ecc_custom.simtrngfile;

entity es_trng_bit is
	generic(
		jittervalfile : string := simtrngfile
	);
	port(
		ro1en : in std_logic;
		ro2en : in std_logic;
		raw : out std_logic;
		valid : out std_logic
	);
end entity es_trng_bit;

architecture behav of es_trng_bit is

	signal ro1out : std_logic;
	signal ro2out : std_logic;
	signal stage0, stage1, stage2, stage3 : std_logic;
	signal raw_d, raw_q : std_logic;
	signal valid_d, valid_q : std_logic;
	signal ro1en_n : std_logic;

	attribute KEEP : string;
	attribute KEEP of ro1out : signal is "TRUE";
	attribute KEEP of ro2out : signal is "TRUE";
	attribute KEEP of stage0 : signal is "TRUE";
	attribute KEEP of stage1 : signal is "TRUE";
	attribute KEEP of stage2 : signal is "TRUE";
	attribute KEEP of stage3 : signal is "TRUE";
	attribute KEEP of ro1en_n : signal is "TRUE";
	attribute KEEP of raw_d : signal is "TRUE";
	attribute KEEP of valid_d : signal is "TRUE";
	attribute KEEP of raw_q : signal is "TRUE";
	attribute KEEP of valid_q : signal is "TRUE";

begin

	-- --------------
	-- RO1 oscillator
	-- --------------
	-- combinational loop:
	--   - synthesizer probably won't like it
	--   - simulator will hang on it - so don't simulate it, use instead
	--     file es_trng_stub.vhd (from folder common/ecc_trng/) and set
	--     parameter 'notrng' to TRUE in ecc_customize.vhd.
	ro1out <= ro1en and not ro1out;

	-- --------------
	-- RO2 oscillator
	-- --------------
	ro2out <= not ro2out;

	stage0 <= ro1out;
	stage1 <= stage0;
	stage2 <= stage1;
	stage3 <= stage2;

	-- -------------
	-- bit-extractor
	-- -------------
	raw_d <= raw_q when valid_q = '1'
			else (not (stage0 xor stage1)) or (stage1 xor stage2);
	valid_d <= valid_q or (stage0 xor stage2);

	process(ro2out, ro1en_n)
	begin
		if ro1en_n = '0' then
			-- asynchronous clear
			raw_q <= '0';
		elsif ro2out'event and ro2out = '1' then
			raw_q <= raw_d;
		end if;
	end process;

	process(ro2out, ro1en_n)
	begin
		if ro1en_n = '0' then
			-- asynchronous clear
			valid_q <= '0';
		elsif ro2out'event and ro2out = '1' then
			valid_q <= valid_d;
		end if;
	end process;

	ro1en_n <= not ro1en;

	-- drive outputs
	raw <= raw_q;
	valid <= valid_q;

end architecture behav;
