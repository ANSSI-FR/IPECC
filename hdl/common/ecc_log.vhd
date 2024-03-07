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

package ecc_log is

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
	--   3. log2(1) = 1 and NOT 0 ! (1 bit is required to binary-encode number 1)
	--   4. log2(0) = 1  exists   ! (1 bit is required to binary-encode number 0)
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
	--   1. ln2(1) = 0
	--   2. ln2(2) = 1 as adding 2 terms together requires one extra bit
	--   3. ln2(3) = 2 as adding 3 terms together requires two extra bits
	--   4. ln2(0) has no meaning (hence the 'positive' restriction on input)
	function ln2(i : positive) return natural;

	-- log10(i)
	--
	-- returns the mathematical composition of log funtion (in basis 10)
	-- with ceil function, plus 1
	function log10(i : natural) return positive;

end package ecc_log;

package body ecc_log is

	-- log2() is equal to the mathematical composition of log funtion
	-- (in basis 2) with floor function, plus 1, but floor function is not
	-- defined in standard VHDL packages (but for type 'real', from package
	-- 'math_real', which we do not want to use) so we use instead a basic
	-- iterative computation in order to compute log2.
	-- Mind that with this definition log2(1) = 1 (1 bit is needed to represent
	-- the integer number 1) and not 0, likewise log2(0) exists and is 1.
	function log2(i : natural) return positive is
		variable ret_val : positive := 1;
	begin
		while i >= (2**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
		return ret_val;
	end function;

	-- ln2(): same remark as for log2() function above
	function ln2(i : positive) return natural is
		variable ret_val : natural := 0;
	begin
		while i > (2**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
	 	return ret_val;
	end function ln2;

	-- log10(): same remark as for log2() function above
	function log10(i : natural) return positive is
		variable ret_val : positive := 1; -- log2(10)=1! (1 digit needed to code 1)
	begin
		while i >= (10**ret_val) loop
			ret_val := ret_val + 1;
		end loop;
	 	return ret_val;
	end function log10;

end package body ecc_log;
