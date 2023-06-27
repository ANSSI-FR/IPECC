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

library unisim;
use unisim.vcomponents.all;

entity es_trng_bit is
	-- pragma translate_off
	generic(jittervalfile : string);
	-- pragma translate_on
	port(
		ro1en : in std_logic;
		ro2en : in std_logic;
		raw : out std_logic;
		valid : out std_logic
	);
end entity es_trng_bit;

architecture struct of es_trng_bit is

	signal ro1out : std_logic;
	signal ro1out_s : std_logic;
	signal ro2s0, ro2s1 : std_logic;
	signal ro2s1_s : std_logic;
	signal ro2out : std_logic;
	signal tapdi8, tapsi8 : std_logic_vector(7 downto 0);
	signal stage : std_logic_vector(7 downto 0);
	signal r_stage : std_logic_vector(2 downto 0);
	signal raw_d, raw_q : std_logic;
	signal valid_d, valid_q : std_logic;
	signal ro1en_n : std_logic;
	signal gnd : std_logic := '0';
	signal gnd4 : std_logic_vector(3 downto 0) := "0000";
	signal vcc4 : std_logic_vector(3 downto 0) := "1111";
	signal vcc : std_logic := '1';
	signal tapci : std_logic;

	attribute DONT_TOUCH : string;
	attribute DONT_TOUCH of ro1out : signal is "TRUE";
	attribute DONT_TOUCH of ro2out : signal is "TRUE";
	attribute DONT_TOUCH of ro2s0 : signal is "TRUE";
	attribute DONT_TOUCH of ro2s1 : signal is "TRUE";
	attribute DONT_TOUCH of stage : signal is "TRUE";
	attribute DONT_TOUCH of r_stage : signal is "TRUE";
	attribute DONT_TOUCH of ro1en : signal is "TRUE";
	attribute DONT_TOUCH of ro2en : signal is "TRUE";
	attribute DONT_TOUCH of ro1en_n : signal is "TRUE";
	attribute DONT_TOUCH of raw_d : signal is "TRUE";
	attribute DONT_TOUCH of valid_d : signal is "TRUE";
	attribute DONT_TOUCH of raw_q : signal is "TRUE";
	attribute DONT_TOUCH of valid_q : signal is "TRUE";

	attribute ALLOW_COMBINATORIAL_LOOPS : string;
	attribute ALLOW_COMBINATORIAL_LOOPS of ro1out : signal is "TRUE";
	attribute ALLOW_COMBINATORIAL_LOOPS of ro2out : signal is "TRUE";

begin

	-- -------------------------------------
	-- RO1 oscillator 1 x LUT2 (w/ 2 inputs)
	-- -------------------------------------
	--   I1       I0       O = I1.\I0
	-- (ro1en) (ro1out)
	--    0        0       0
	--    0        1       0
	--    1        0       1
	--    1        1       0
	ro1: LUT2
		generic map(
			INIT => x"4"
		) port map(
			I0 => ro1out,
			I1 => ro1en,
			O => ro1out
		);

	-- -------------------------------------------------------
	-- RO2 oscillator  1 x LUT2 (same eq. as ro1) and 2 x LUT1
	-- -------------------------------------------------------
	ro2_0: LUT2 -- O = I1.!I0
		generic map(
			INIT => x"4"
		) port map(
			I0 => ro2s1,
			I1 => ro2en,
			O => ro2out
		);

	ro2_1: LUT1 -- O = I0
		generic map(
			INIT => "10"
		) port map(
			I0 => ro2out,
			O => ro2s0
		);

	ro2_2: LUT1 -- O = I0
		generic map(
			INIT => "10"
		) port map(
			I0 => ro2s0,
			O => ro2s1
		);

	-- ---------------------------------------------------
	-- tapped delay chain
	-- ---------------------------------------------------
	tap0: CARRY8
		generic map(
			CARRY_TYPE => "DUAL_CY4"
		)
		port map (
			CO => stage,
			O => open,
			CI => tapci,
			CI_TOP => gnd,
			DI => tapdi8,
			S => tapsi8
		);

	tapdi8 <= gnd & gnd & gnd & gnd & gnd & gnd & gnd & ro1out;
	tapsi8 <= vcc & vcc & vcc & vcc & vcc & vcc & vcc & gnd;

	-- ---------------------------------------
	-- registering the 3 x stage(2..0) signals
	-- ---------------------------------------
	st0: FDCE
		generic map(
			INIT => '0'
		) port map (
			Q => r_stage(0),
			C => ro2out, -- clock'd by RO2 output
			CE => vcc,
			CLR => gnd,
			D => stage(0)
		);
	st1: FDCE
		generic map(
			INIT => '0'
		) port map (
			Q => r_stage(1),
			C => ro2out, -- clock'd by RO2 output
			CE => vcc,
			CLR => gnd,
			D => stage(1)
		);
	st2: FDCE
		generic map(
			INIT => '0'
		) port map (
			Q => r_stage(2),
			C => ro2out, -- clock'd by RO2 output
			CE => vcc,
			CLR => gnd,
			D => stage(2)
		);

	bx01: LUT6_2
		generic map(
			INIT => x"FFFF5A5AFF004242"
		) port map(
			I5 => vcc,
			I4 => valid_q,
			I3 => raw_q,
			I2 => r_stage(2),
			I1 => r_stage(1),
			I0 => r_stage(0),
			O5 => raw_d,
			O6 => open
		);

	bx02: LUT6_2
		generic map(
			INIT => x"FFFF5A5AFF004242"
		) port map(
			I5 => vcc,
			I4 => valid_q,
			I3 => raw_q,
			I2 => r_stage(2),
			I1 => r_stage(1),
			I0 => r_stage(0),
			O5 => open,
			O6 => valid_d
		);

	-- bit 'raw'
	bx2: FDCE
		generic map(
			INIT => '0'
		) port map (
			Q => raw_q,
			C => ro2out, -- clock'd by RO2 output
			CE => vcc,
			CLR => ro1en_n,
			D => raw_d
		);

	-- bit 'valid'
	bx3: FDCE
		generic map(
			INIT => '0'
		) port map (
			Q => valid_q,
			C => ro2out, -- clock'd by RO2 output
			CE => vcc,
			CLR => ro1en_n,
			D => valid_d
		);

	ro1en_n <= not ro1en;

	-- GND tied-down & VCC tied-up signals
	gnd <= '0';
	gnd4 <= "0000";
	vcc <= '1';
	vcc4 <= "1111";

	-- drive outputs
	raw <= raw_q;
	valid <= valid_q;

end architecture struct;
