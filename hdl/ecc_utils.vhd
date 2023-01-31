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

use work.ecc_custom.all;

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

	-- log2(i)
	--
	-- returns the number of bits required to write unsigned natural i
	-- in positive non-signed representation (not in two's complement: in
	-- two's complement we'd need to add an extra null bit in most significant
	-- position to identify that the number i is positive)
	--
	-- log2() function is identical to the floor function applied to mathe-
	-- matical log function in base 2, plus 1. This is because writing numbers
	-- which are exact power of 2 (2**n) in binary format requires n + 1 bits,
	-- not n.
	--
	-- Examples :
	--
	--   1. log2(31) = 5   since   31 =  11111
	--      log2(32) = 6   since   32 = 100000
	--
	--   2. log2(2**n) = n + 1 and NOT n
	--
	--   3. log2(1) = 1 and NOT 0! (1 bit is required to binary-encode number 1)
	function log2(i : natural) return positive;

	-- ln2(i)
	--
	-- function ln2() differs from log2().
	-- It is equal to the mathematical composition of log funtion (in basis 2)
	-- with ceil function.
	-- ln2 is used to determine the number of extra bits resulting from the
	-- addition (i.e accumulation) of several terms of equal bitwidth
	--
	-- Examples:
	--
	--   1. ln2(2) = 1 as adding 2 terms requires one extra bit
	--   2. ln2(3) = 2 as adding 3 terms requires two extra bits
	function ln2(i : positive) return natural;

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

	-- log10(i)
	--
	-- returns the mathematical composition of log funtion (in basis 10)
	-- with ceil function, plus 1
	-- used only by simulaton log
	function log10(i : natural) return positive;

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
	procedure hex_write(l: inout line; value: in std_logic_vector);
	-- pragma translate_on

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

	-- log2() is equal to the mathematical composition of log funtion
	-- (in basis 2) with floor function, plus 1, but floor function is not
	-- defined in standard VHDL packages (but for type 'real', from package
	-- 'math_real', which we do not want to use) so we use instead a basic
	-- iterative computation in order to compute log2.
	-- Mind that with this definition log2(1) = 1 (1 bit is needed to represent
	-- the integer number 1) and not 0
	function log2(i : natural) return positive is
		variable ret_val : positive := 1; -- log2(1)=1! (1 bit is needed to code 1)
	begin
		while i >= (2**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
		return ret_val;
	end function;

	-- same remark as for log2() function above
	function ln2(i : positive) return natural is
		variable ret_val : natural := 0;
	begin
		while i > (2**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
	 	return ret_val;
	end function ln2;

	function log10(i : natural) return positive is
		variable ret_val : positive := 1; -- log2(10)=1! (1 digit needed to code 1)
	begin
		while i >= (10**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
	 	return ret_val;
	end function log10;

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
		elsif techno = series7 or techno = virtex6 then tmp := 16;
		elsif techno = ialtera then tmp := 24;
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
	procedure hex_write(l: inout line; value: in std_logic_vector) is
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
