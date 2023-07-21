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

use work.ecc_customize.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

package ecc_utils is

	-- ----------------------------------------------------------------
	-- Below are declaration & implementation of "helper" functions,
	-- as long as VHDL constants, types & components used throughout
	-- the code - don't modify unless you really know what you're doing
	-- ----------------------------------------------------------------

	-- div(i, s)
	--
	-- returns the number of s-bit words required to write an i-bit number.
	-- This is equal to the ceil function applied to rational number i/s
	-- but ceil function is not defined in standard VHDL packages - but for
	-- type 'real' from package 'math_real', which we do not want to use.
	function div(i : natural; s : natural) return positive;

	-- ge_pow_of_2(i)
	--
	-- returns the power-of-2 which is either equal to or directly greater than i
	-- e.g ge_pow_of_2(16) = 16
	--     ge_pow_of_2(17) = 32
	function ge_pow_of_2(i : natural) return natural;

	-- max(a, b)
	function max(a, b: natural) return natural;

	function set_ww return positive;

	function is_a_power_of_two(i : natural) return boolean;

	function is_not_a_multiple_of_four(i : natural) return natural;

	function set_op_arith_fill(opsz: positive; pcsz: positive) return integer;
	function set_op_branch_fill(opsz: positive; pcsz: positive) return integer;

	function set_readlat return positive;

	-- pragma translate_off
	-- write something to the console (without flushing the line)
	procedure echo(arg : in string := "");
	-- write something to the console & flush the line
	procedure echol(arg : in string := "");
	-- write hexadecimal value to the console (without flushing the line)
	procedure hex_echo(value: in std_logic_vector);
	-- write hexadecimal value to the console & flush the line
	procedure hex_echol(value: in std_logic_vector);
	-- write hexadecimal value on a given input 'line'
	procedure hex_write(l: inout line; constant value: in std_logic_vector);
	-- pragma translate_on

	subtype std_logic2 is std_logic_vector(1 downto 0);
	subtype std_logic3 is std_logic_vector(2 downto 0);
	subtype std_logic4 is std_logic_vector(3 downto 0);
	subtype std_logic5 is std_logic_vector(4 downto 0);
	subtype std_logic8 is std_logic_vector(7 downto 0);
	subtype std_logic15 is std_logic_vector(14 downto 0);
	subtype std_logic16 is std_logic_vector(15 downto 0);
	subtype std_logic17 is std_logic_vector(16 downto 0);
	subtype std_logic24 is std_logic_vector(23 downto 0);
	subtype std_logic32 is std_logic_vector(31 downto 0);
	subtype std_logic192 is std_logic_vector(191 downto 0);
	subtype std_logic256 is std_logic_vector(255 downto 0);
	subtype std_logic272 is std_logic_vector(271 downto 0);
	subtype std_logic288 is std_logic_vector(287 downto 0);
	subtype std_logic320 is std_logic_vector(319 downto 0);
	subtype std_logic323 is std_logic_vector(322 downto 0);
	subtype std_logic352 is std_logic_vector(351 downto 0);
	subtype std_logic384 is std_logic_vector(383 downto 0);
	subtype std_logic512 is std_logic_vector(511 downto 0);

	function std_nat(arg, size: natural) return std_logic_vector;

	function ge_even(arg: natural) return natural;

end package ecc_utils;

package body ecc_utils is

	-- div() returns the number of s-bit words required to write an i-bit number.
	-- This is equal to ceil function applied to the rational number i/s,
	-- but ceil function is not defined in standard VHDL packages - but for
	-- type 'real' from package 'math_real', which we do not want to use.
	-- That's why we use built-in operators to compute div()
	function div(i : natural; s : natural) return positive is
	begin
		if (i mod s) = 0 then
			return (i / s);
		else
			return (i / s) + 1;
		end if;
	end function div;

	function ge_pow_of_2(i : natural) return natural is
		variable tmp : positive := 1;
	begin
		while (tmp < i) loop
			tmp := tmp * 2;
		end loop;
		return tmp;
	end function ge_pow_of_2;

	function max(a, b: natural) return natural is
		variable tmp : natural;
	begin
		if a > b then
			tmp := a;
		else
			tmp := b;
		end if;
		return tmp;
	end function max;

	function set_ww return positive is
		variable tmp : positive := 32;
	begin
		if techno = spartan6 then tmp := 16;
		elsif techno = series7 or techno = virtex6 or
			techno = ultrascale then tmp := 16;
		elsif techno = ialtera then tmp := 27;
		elsif techno = asic then tmp := multwidth;
		end if;
		return tmp;
	end function set_ww;

	function is_a_power_of_two(i : natural) return boolean is
		variable tmp : positive := 1;
	begin
		assert i <= (2**30)
			report "wrong call to function is_a_power_of_two() (parameter too large)"
				severity failure;
		while (tmp <= i) loop
			if tmp = i then
				return TRUE;
			else
				tmp := tmp * 2;
			end if;
		end loop;
		return FALSE;
	end function is_a_power_of_two;

	function is_not_a_multiple_of_four(i : natural) return natural is
	begin
		if (i mod 4) = 0 then
			return 0;
		else
			return 1;
		end if;
	end function is_not_a_multiple_of_four;

	function set_op_arith_fill(opsz: positive; pcsz: positive) return integer is
	begin
		if (3*opsz >= pcsz) then
			return 0;
		else -- (3*opsz < pcsz) then
			return pcsz - opsz;
		end if;
	end function set_op_arith_fill;

	function set_op_branch_fill(opsz: positive; pcsz: positive) return integer is
	begin
		if (3*opsz >= pcsz) then
			return 3*opsz - pcsz;
		else -- (3*opsz < pcsz) then
			return 0;
		end if;
	end function set_op_branch_fill;

	function set_readlat return positive is
		variable tmp : positive;
	begin
		if shuffle_type /= none then -- defined in package ecc_customize
			case shuffle_type is
				when linear => tmp := sramlat + 2;
				when permute_lgnb => tmp := sramlat + 2;
				when permute_limbs => tmp := (2 * sramlat) + 2;
				when others =>
					assert FALSE report "unknown value for 'shuffle_type' parameter " &
						"in ecc_customize.vhd"
							severity FAILURE;
			end case;
		else -- no shuffle hardware present at all in the design
			tmp := sramlat; -- defined in package ecc_customize
		end if;
		return tmp;
	end function set_readlat;

	function std_nat(arg, size: natural) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(arg, size));
	end function std_nat;

	function ge_even(arg: natural) return natural is
	begin
		if (arg mod 2) = 0 then
			return arg;
		else
			return arg + 1;
		end if;
	end function ge_even;

	-- pragma translate_off
	-- write something to the console (without flushing the line)
	procedure echo(arg : in string := "") is
	begin
		std.textio.write(std.textio.output, arg);
	end procedure echo;

	-- write something to the console & flush the line
	procedure echol(arg : in string := "") is
	begin
		std.textio.write(std.textio.output, arg & LF);
	end procedure echol;

	-- write hexadecimal value to the console (without flushing the line)
	procedure hex_echo(value: in std_logic_vector) is
		variable tmp : std_logic_vector(
			value'length + (4 * is_not_a_multiple_of_four(value'length)) - 1 downto 0)
				:= (others => '0');
		variable start_ndx : natural;
		variable ndx : integer;
		variable str : string(1 to (tmp'length/4));
		variable i : natural;
		variable nibble : std_logic_vector(3 downto 0);
	begin
		-- set starting index (always a multiple-of-4 minus 1, e.g 7 or 15)
		if value'length mod 4 = 0 then
			start_ndx := value'length - 1;
		else
			start_ndx := value'length - 1 + (4 - value'length mod 4);
		end if;
		-- init meaning bits of tmp
		tmp(value'length - 1 downto 0) := value;
		-- now simply write heax characters nibble by nibble starting from
		-- start_ndx and proceeding to the right
		ndx := start_ndx;
		i := 1;
		while ndx > 0 loop
			nibble := to_X01(tmp(ndx downto ndx - 3));
			case nibble is
				when x"0" => str(i) := '0';
				when x"1" => str(i) := '1';
				when x"2" => str(i) := '2';
				when x"3" => str(i) := '3';
				when x"4" => str(i) := '4';
				when x"5" => str(i) := '5';
				when x"6" => str(i) := '6';
				when x"7" => str(i) := '7';
				when x"8" => str(i) := '8';
				when x"9" => str(i) := '9';
				when x"a" => str(i) := 'a';
				when x"b" => str(i) := 'b';
				when x"c" => str(i) := 'c';
				when x"d" => str(i) := 'd';
				when x"e" => str(i) := 'e';
				when x"f" => str(i) := 'f';
				when others => str(i) := 'X';
			end case;
			ndx := ndx - 4;
			i := i + 1;
		end loop;
		std.textio.write(std.textio.output, str);
	end procedure hex_echo;

	-- write hexadecimal value to the console & flush the line
	procedure hex_echol(value: in std_logic_vector) is
		variable tmp : std_logic_vector(
			value'length + (4 * is_not_a_multiple_of_four(value'length)) - 1 downto 0)
				:= (others => '0');
		variable start_ndx : natural;
		variable ndx : integer;
		variable str : string(1 to (tmp'length/4));
		variable i : natural;
		variable nibble : std_logic_vector(3 downto 0);
	begin
		-- set starting index (always a multiple-of-4 minus 1, e.g 7 or 15)
		if value'length mod 4 = 0 then
			start_ndx := value'length - 1;
		else
			start_ndx := value'length - 1 + (4 - value'length mod 4);
		end if;
		-- init meaning bits of tmp
		tmp(value'length - 1 downto 0) := value;
		-- now simply write heax characters nibble by nibble starting from
		-- start_ndx and proceeding to the right
		ndx := start_ndx;
		i := 1;
		while ndx > 0 loop
			nibble := to_X01(tmp(ndx downto ndx - 3));
			case nibble is
				when x"0" => str(i) := '0';
				when x"1" => str(i) := '1';
				when x"2" => str(i) := '2';
				when x"3" => str(i) := '3';
				when x"4" => str(i) := '4';
				when x"5" => str(i) := '5';
				when x"6" => str(i) := '6';
				when x"7" => str(i) := '7';
				when x"8" => str(i) := '8';
				when x"9" => str(i) := '9';
				when x"a" => str(i) := 'a';
				when x"b" => str(i) := 'b';
				when x"c" => str(i) := 'c';
				when x"d" => str(i) := 'd';
				when x"e" => str(i) := 'e';
				when x"f" => str(i) := 'f';
				when others => str(i) := 'X';
			end case;
			ndx := ndx - 4;
			i := i + 1;
		end loop;
		std.textio.write(std.textio.output, str & LF);
	end procedure hex_echol;

	-- write hexadecimal value on a given input 'line'
	procedure hex_write(l: inout line; constant value: in std_logic_vector) is
		variable tmp : std_logic_vector(
			value'length + (4 * is_not_a_multiple_of_four(value'length)) - 1 downto 0)
				:= (others => '0');
		variable start_ndx : natural;
		variable ndx : integer;
		variable str : string(1 to (tmp'length/4));
		variable i : natural;
		variable nibble : std_logic_vector(3 downto 0);
	begin
		-- set starting index (always a multiple-of-4 minus 1, e.g 7 or 15)
		if value'length mod 4 = 0 then
			start_ndx := value'length - 1;
		else
			start_ndx := value'length - 1 + (4 - value'length mod 4);
		end if;
		-- init meaning bits of tmp
		tmp(value'length - 1 downto 0) := value;
		-- now simply write heax characters nibble by nibble starting from
		-- start_ndx and proceeding to the right
		ndx := start_ndx;
		i := 1;
		while ndx > 0 loop
			nibble := to_X01(tmp(ndx downto ndx - 3));
			case nibble is
				when x"0" => str(i) := '0';
				when x"1" => str(i) := '1';
				when x"2" => str(i) := '2';
				when x"3" => str(i) := '3';
				when x"4" => str(i) := '4';
				when x"5" => str(i) := '5';
				when x"6" => str(i) := '6';
				when x"7" => str(i) := '7';
				when x"8" => str(i) := '8';
				when x"9" => str(i) := '9';
				when x"a" => str(i) := 'a';
				when x"b" => str(i) := 'b';
				when x"c" => str(i) := 'c';
				when x"d" => str(i) := 'd';
				when x"e" => str(i) := 'e';
				when x"f" => str(i) := 'f';
				when others => str(i) := 'X';
			end case;
			ndx := ndx - 4;
			i := i + 1;
		end loop;
		std.textio.write(l, str);
	end procedure hex_write;
	-- pragma translate_on

end package body ecc_utils;
