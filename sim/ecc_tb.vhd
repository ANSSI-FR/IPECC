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
use work.ecc_utils.all;
use work.ecc_pkg.all;
use work.ecc_tb_pkg.all;
use work.ecc_tb_vec.all;
use work.ecc_vars.all;
use work.ecc_software.all;

use std.textio.all;
use ieee.std_logic_textio.hread;
use ieee.std_logic_textio.hwrite;

entity ecc_tb is
end entity ecc_tb;

architecture sim of ecc_tb is

	-- Parameter 'CONTINUE_ON_ERROR'
	--
	-- If TRUE then simulation will continue even if a mismatch is detected
	-- between the simulated RTL and the expected result from the input test-
	-- vectors file.
	--
	-- If FALSE then the simulation will stop upon the first test where a
	-- mismatch is detected.
	--
	constant CONTINUE_ON_ERROR: boolean := FALSE;

	-- DuT component declaration
	component ecc is
		generic(
			-- Width of S_AXI data bus
			C_S_AXI_DATA_WIDTH : integer := axi32or64; -- in ecc_customize
			-- Width of S_AXI address bus
			C_S_AXI_ADDR_WIDTH : integer := AXIAW -- in ecc_pkg
			);
		port(
			-- AXI clock & reset
			s_axi_aclk : in  std_logic;
			s_axi_aresetn : in std_logic; -- asyn asserted, syn deasserted, active low
			-- AXI write-address channel
			s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			s_axi_awprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_awvalid : in std_logic;
			s_axi_awready : out std_logic;
			-- AXI write-data channel
			s_axi_wdata : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			s_axi_wstrb : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
			s_axi_wvalid : in std_logic;
			s_axi_wready : out std_logic;
			-- AXI write-response channel
			s_axi_bresp : out std_logic_vector(1 downto 0);
			s_axi_bvalid : out std_logic;
			s_axi_bready : in std_logic;
			-- AXI read-address channel
			s_axi_araddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			s_axi_arprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_arvalid : in std_logic;
			s_axi_arready : out std_logic;
			--  AXI read-data channel
			s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			s_axi_rresp : out std_logic_vector(1 downto 0);
			s_axi_rvalid : out std_logic;
			s_axi_rready : in std_logic;
			-- clock for Montgomery multipliers in the async case
			clkmm : in std_logic;
			-- interrupt
			irq : out std_logic;
			-- general busy signal
			busy : out std_logic;
			-- debug feature (off-chip trigger)
			dbgtrigger : out std_logic;
			dbghalted : out std_logic;
			--   pseudo-trng port
			dbgptdata : in std_logic_vector(7 downto 0);
			dbgptvalid : in std_logic;
			dbgptrdy : out std_logic
		);
	end component ecc;

	-- Pseudo TRNG device
	component pseudo_trng is
		generic(
			-- width of AXI data bus
			constant C_S_AXI_DATA_WIDTH : integer := 32;
			-- width of AXI address bus
			constant C_S_AXI_ADDR_WIDTH : integer := 4
		);
		port(
			-- AXI clock
			s_axi_aclk : in std_logic;
			-- AXI reset (expected active low, async asserted, sync deasserted) 
			s_axi_aresetn : in std_logic;
			-- AXI write-address channel
			s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1  downto 0);
			s_axi_awprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_awvalid : in std_logic;
			s_axi_awready : out std_logic;
			-- AXI write-data channel
			s_axi_wdata : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
			s_axi_wstrb : in std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
			s_axi_wvalid : in std_logic;
			s_axi_wready : out std_logic;
			-- AXI write-response channel
			s_axi_bresp : out std_logic_vector(1 downto 0);
			s_axi_bvalid : out std_logic;
			s_axi_bready : in std_logic;
			-- AXI read-address channel
			s_axi_araddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
			s_axi_arprot : in std_logic_vector(2 downto 0); -- ignored
			s_axi_arvalid : in std_logic;
			s_axi_arready : out std_logic;
			-- AXI read-data channel
			s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
			s_axi_rresp : out std_logic_vector(1 downto 0);
			s_axi_rvalid : out std_logic;
			s_axi_rready : in std_logic;
			-- interrupt (when the FIFO is half empty)
			irq : out std_logic;
			-- data port with handshake signals
			dbgptdata : out std_logic_vector(7 downto 0);
			dbgptvalid : out std_logic;
			dbgptrdy : in std_logic
		);
	end component pseudo_trng;

	-- AXI signal buses (DuT)
	signal axi0 : axi_in_type;
	signal axo0 : axi_out_type;

	type axi1_in_type is record
		-- in
		aclk :  std_logic;
		aresetn : std_logic; -- asyn asserted, syn deasserted, active low
		awaddr : std_logic_vector(3 downto 0);
		awprot : std_logic_vector(2 downto 0); -- ignored
		awvalid : std_logic;
		wdata : std_logic_vector(31 downto 0);
		wstrb : std_logic_vector(3 downto 0); -- ignored
		wvalid : std_logic;
		bready : std_logic;
		araddr : std_logic_vector(3 downto 0);
		arprot : std_logic_vector(2 downto 0); -- ignored
		arvalid : std_logic;
		rready : std_logic;
	end record;
	type axi1_out_type is record
		-- out
		awready : std_logic;
		wready : std_logic;
		bresp : std_logic_vector(1 downto 0);
		bvalid : std_logic;
		arready : std_logic;
		rdata : std_logic_vector(31 downto 0);
		rresp : std_logic_vector(1 downto 0);
		rvalid : std_logic;
	end record;

	-- AXI signal buses (pseudo TRNG)
	signal axi1 : axi1_in_type;
	signal axo1 : axi1_out_type;

	signal s_axi_aclk, s_axi_aresetn : std_logic;

	signal clkmm : std_logic;

	signal nn_s : integer range 1 to nn := nn;

	-- Handshake signals (between 'ecc' & 'pseudo_trng')
	signal dbgptdata : std_logic_vector(7 downto 0);
	signal dbgptvalid : std_logic;
	signal dbgptrdy : std_logic;

	signal r_fifo_count : natural;
	signal once_out_of_reset : std_logic;
	signal pseudo_trng_irq : std_logic;

	-- A 32-bit number needs at most 10 decimal digits to be encoded in base 10.
	type digit_array_type is array(0 to 9) of integer;

	-- Procedure 'str_to_int' below extracts, starting from position 'inpos'
	-- of string 's', a natural written in decimal ASCII and converts it into
	-- the natural number 'nb'.
	--
	-- Number should not exceed VHDL attribute 'high' of 'integer' type (i.e
	-- 2147483647 = +2^31 - 1).
	--
	-- If something went wrong (non decimal number, too large a value, etc.)
	-- then 'ok' is set to FALSE, otherwise to TRUE. Also 'outpos' is positioned
	-- to the last correct encountered character.
	procedure str_to_int(
		constant s: in string; constant inpos: in positive; constant maxpos: in positive;
		variable nb: inout natural;
		variable ok: inout boolean; variable outpos: out positive)
	is
		variable da: digit_array_type;
		variable sz: natural;
		variable d: natural;
		variable uns, prod: unsigned(33 downto 0);
	begin
		nb := 0;
		ok := false;
		sz := 0;
		for i in inpos to maxpos loop
			if (character'pos(s(i)) < character'pos('0') or character'pos(s(i)) >
				character'pos('9'))
			then
				exit;
				outpos := i; -- First char position where no digit were found.
			else
				da(i - inpos) := character'pos(s(i)) - character'pos('0');
				ok := true;
				sz := sz + 1;
			end if;
		end loop;
		if ok then
			-- We've already constrained the input number not to exceed 10 decimal
			-- digits.
			-- The maximum number that can be represented with 10 decimal digits is
			-- 9.999.999.999, which is 0x2540BE3FF, which is 34-bits long. Hence by
			-- reconstructing the input number using a precision of 34 bits (using
			-- an unsigned(33 downto 0) type, we can enforce that that number does
			-- also not exceed 2**31 - 1 (defines natural'high). This is the case if
			-- and only if the bits 33 downto 31 of the unsigned array are null.
			d := 0;
			uns := (others => '0');
			for i in sz - 1 downto 0 loop
				prod := resize(to_unsigned(da(i), 34) * to_unsigned(10**d, 34), 34);
				uns := uns + prod;
				d := d + 1;
			end loop;
		end if;
		if uns(33 downto 31) /= "000" then
			ok := FALSE;
			echol("[     ecc_tb.vhd ]: ERROR: Too large an integer (the maximum "
				& "allowed value for an integer number is 2147483647 = 2^31 - 1).");
			assert FALSE severity FAILURE;
		else
			nb := to_integer(uns);
		end if;
	end procedure str_to_int;

	function is_char_an_hex_digit(constant c: in character) return boolean is
	begin
		if (
			(character'pos(c) >= character'pos('0') and
			 character'pos(c) <= character'pos('9'))
		or
			(character'pos(c) >= character'pos('a') and
			 character'pos(c) <= character'pos('f'))
		or
			(character'pos(c) >= character'pos('A') and
			 character'pos(c) <= character'pos('F')))
		then
			return TRUE;
		else
			return FALSE;
		end if;
	end function is_char_an_hex_digit;

	-- For procedure 'char_to_stdlogic4' we don't use a 'good' output variable
	-- like in some IEEE packages' procedures, as when we use the procedure
	-- we have already tested for their correctness.
	--
	-- Simply the output std_logic is set with all bits to 'X' (force unknown)
	-- in case the input character is illegitimate (which is not expected to
	-- happen in our context of use).
	procedure char_to_stdlogic4(
		constant c: in character; variable s: out std_logic4) is
	begin
		case c is 
			when '0' => s := "0000";
			when '1' => s := "0001";
			when '2' => s := "0010";
			when '3' => s := "0011";
			when '4' => s := "0100";
			when '5' => s := "0101";
			when '6' => s := "0110";
			when '7' => s := "0111";
			when '8' => s := "1000";
			when '9' => s := "1001";
			when 'a'|'A' => s := "1010";
			when 'b'|'B' => s := "1011";
			when 'c'|'C' => s := "1100";
			when 'd'|'D' => s := "1101";
			when 'e'|'E' => s := "1110";
			when 'f'|'F' => s := "1111";
			when others => s := "XXXX";
		end case;
	end procedure char_to_stdlogic4;

	procedure str_to_stdlogic(
		variable s: in string; constant inpos: in positive; constant maxpos: in positive;
		variable st: inout std_logic512;
		constant valnn: in integer; variable ok: inout boolean; variable outpos: out positive)
	is
		variable leading_zeros : boolean;
		variable begpos, endpos: integer;
		variable zero: boolean;
		variable s4: std_logic4;
	begin
		st := (others => '0');
		-- Parse the string input argument till the first non-hexadecimal
		-- digit character is hit (that includes meta-character such as CR,
		-- LF, etc).
		-- If this happens from the start, position 'ok' to false and leave.
		leading_zeros := true;
		begpos := inpos;
		zero := FALSE;
		outpos := inpos;
		endpos := inpos;
		if not (maxpos >= begpos) then
			echol("[     ecc_tb.vhd ]: ERROR: Missing hexadecimal value after prefix '0x'.");
			assert FALSE severity FAILURE;
		end if;
		for i in inpos to maxpos loop
			if leading_zeros then
				if s(i) = '0' then
					ok := TRUE;
					if i = maxpos then
						zero := TRUE;
						exit;
					else
						next;
					end if;
				else
					if not is_char_an_hex_digit(s(i)) then
						-- If we have moved at least of one position in the character string
						-- then we can leave wo/ error with a null std_logic_vector.
						if i > inpos then
							ok := TRUE;
							zero := TRUE;
							exit;
						else
							-- Force an unknown output bit vector.
							st := (others => 'X');
							ok := FALSE;
							exit;
						end if;
					else -- It is an hex digit, and it isn't '0'.
						ok := TRUE;
						begpos := i;
						endpos := i;
						leading_zeros := FALSE;
					end if;
				end if;
			else -- Met at least one valid hex non-null digit.
				if is_char_an_hex_digit(s(i)) then
					endpos := i;
				else
					echol("[     ecc_tb.vhd ]: ERROR: '" & s(i) & "' is not an hexadecimal digit.");
					ok := FALSE;
					exit;
				end if;
			end if;
		end loop;
		if ok and not zero then
			outpos := endpos;
			-- Also enforce that the nb of hexadecimal digits that was found does not
			-- exceed the maximal nb of hex digits for a bit vector of 'valnn' bits.
			if endpos - begpos + 1 > div(valnn, 4) then
				echol("[     ecc_tb.vhd ]: ERROR: Too large an hexadecimal value "
						& "as compared to the current value of nn = "
						& integer'image(valnn) & ".");
				assert FALSE severity FAILURE;
			end if;
			if ok then
				for i in endpos downto begpos loop
					char_to_stdlogic4(
						s(i), st(4*(endpos - i) + 3 downto 4*(endpos - i)));
				end loop;
				-- Since we have ignored any leading zeros, we can also enforce that
				-- the most significant character (the first non-null we met) does not
				-- create an overflow of 'valnn' bits.
				-- Now parse again, this time backward.
				if endpos - begpos + 1 = div(valnn, 4) and (valnn mod 4) > 0 then
					-- Let fc be set with the first non-null hex digit character met.
					char_to_stdlogic4(s(begpos), s4);
					for i in 3 downto (valnn mod 4) loop
						if s4(i) /= '0' then
							echol("[     ecc_tb.vhd ]: ERROR: Too large an hexadecimal value "
									& "as compared to the current value of nn.");
							assert FALSE severity FAILURE;
						end if;
					end loop;
				end if; -- valnn not a mult. of 4
			end if; -- if ok
		end if; -- if ok and not zero
	end procedure str_to_stdlogic;

	-- Compare two points coordinates
	function compare_two_points_coords(constant x0: in std_logic512;
		constant y0: in std_logic512; constant x1: in std_logic512;
		constant y1: in std_logic512; constant valnn : in positive)
		return boolean is
	begin
		if x0(valnn - 1 downto 0) = x1(valnn - 1 downto 0) and
			y0(valnn - 1 downto 0) = y1(valnn - 1 downto 0)
		then
			return TRUE;
		else
			return FALSE;
		end if;
	end function compare_two_points_coords;

	--
	--	To help parsing the input file/stream.
	--
	type line_t is
		(EXPECT_NONE, EXPECT_CURVE, EXPECT_NN, EXPECT_P, EXPECT_A, EXPECT_B,
		 EXPECT_Q, EXPECT_PX, EXPECT_PY, EXPECT_QX, EXPECT_QY, EXPECT_K,
		 EXPECT_KPX_OR_BLD, EXPECT_KPY, EXPECT_P_PLUS_QX, EXPECT_P_PLUS_QY,
		 EXPECT_TWOP_X, EXPECT_TWOP_Y, EXPECT_NEGP_X, EXPECT_NEGP_Y,
		 EXPECT_TRUE_OR_FALSE);

	--
	-- Operations on curve points supported by the driver.
	--
	type operation_t is
		(OP_NONE, OP_KP, OP_PTADD, OP_PTDBL, OP_PTNEG, OP_TST_CHK, OP_TST_EQU,
		 OP_TST_OPP);

	procedure echo_test_label(
		constant t: in string(1 to 16384); constant sz: in natural;
		constant op: in string) is
	begin
		echo("[     ecc_tb.vhd ]: **** END TEST " & op);
		if sz > 0 then
			echo(t(1 to sz));
		end if;
	end procedure echo_test_label;

	function str_low_case(constant s: string) return string is
		variable so: string(1 to s'length);
	begin
		for i in 1 to s'length loop
			if character'pos(s(i)) >= character'pos('A') and
				character'pos(s(i)) <= character'pos('Z')
			then
				so(i) := character'val(
					character'pos(s(i)) - character'pos('A') + character'pos('a')); 
			else
				so(i) := s(i);
			end if;
		end loop;
		return so;
	end function str_low_case;

begin

	-- Emulate AXI reset.
	process
	begin
		s_axi_aresetn <= '0';
		wait for 333 ns;
		s_axi_aresetn <= '1';
		wait;
	end process;

	-- Emulate AXI clock (100 MHz).
	process
	begin
		s_axi_aclk <= '0';
		wait for 5 ns;
		s_axi_aclk <= '1';
		wait for 5 ns;
	end process;

	-- Emulate clkmm clock (250 MHz).
	process
	begin
		clkmm <= '0';
		wait for 2 ns;
		clkmm <= '1';
		wait for 2 ns;
	end process;

	-- DuT instance
	e0: ecc
		generic map(
			C_S_AXI_DATA_WIDTH => AXIDW,
			C_S_AXI_ADDR_WIDTH => AXIAW)
		port map(
			-- AXI clock & reset
			s_axi_aclk => s_axi_aclk,
			s_axi_aresetn => s_axi_aresetn,
			-- AXI write-address channel
			s_axi_awaddr => axi0.awaddr,
			s_axi_awprot => axi0.awprot,
			s_axi_awvalid => axi0.awvalid,
			s_axi_awready => axo0.awready,
			-- AXI write-data channel
			s_axi_wdata => axi0.wdata,
			s_axi_wstrb => axi0.wstrb,
			s_axi_wvalid => axi0.wvalid,
			s_axi_wready => axo0.wready,
			-- AXI write-response channel
			s_axi_bresp => axo0.bresp,
			s_axi_bvalid => axo0.bvalid,
			s_axi_bready => axi0.bready,
			-- AXI read-address channel
			s_axi_araddr => axi0.araddr,
			s_axi_arprot => axi0.arprot,
			s_axi_arvalid => axi0.arvalid,
			s_axi_arready => axo0.arready,
			--  AXI read-data channel
			s_axi_rdata => axo0.rdata,
			s_axi_rresp => axo0.rresp,
			s_axi_rvalid => axo0.rvalid,
			s_axi_rready => axi0.rready,
			-- Clock for Montgomery multipliers in the async case
			clkmm => clkmm,
			-- Interrupt
			irq => open,
			-- General busy signal
			busy => open,
			-- Debug feature (off-chip trigger)
			dbgtrigger => open,
			dbghalted => open,
			-- Pseudo-trng port
			dbgptdata => dbgptdata,
			dbgptvalid => dbgptvalid,
			dbgptrdy => dbgptrdy
		);

	-- Pseudo TRNG device
	pt0: pseudo_trng
		port map(
			-- AXI clock & reset
			s_axi_aclk => s_axi_aclk,
			s_axi_aresetn => s_axi_aresetn,
			-- AXI write-address channel
			s_axi_awaddr => axi1.awaddr,
			s_axi_awprot => axi1.awprot,
			s_axi_awvalid => axi1.awvalid,
			s_axi_awready => axo1.awready,
			-- AXI write-data channel
			s_axi_wdata => axi1.wdata,
			s_axi_wstrb => axi1.wstrb,
			s_axi_wvalid => axi1.wvalid,
			s_axi_wready => axo1.wready,
			-- AXI write-response channel
			s_axi_bresp => axo1.bresp,
			s_axi_bvalid => axo1.bvalid,
			s_axi_bready => axi1.bready,
			-- AXI read-address channel
			s_axi_araddr => axi1.araddr,
			s_axi_arprot => axi1.arprot,
			s_axi_arvalid => axi1.arvalid,
			s_axi_arready => axo1.arready,
			--  AXI read-data channel
			s_axi_rdata => axo1.rdata,
			s_axi_rresp => axo1.rresp,
			s_axi_rvalid => axo1.rvalid,
			s_axi_rready => axi1.rready,
			-- interrupt
			irq => pseudo_trng_irq,
			-- pseudo-trng port
			dbgptdata => dbgptdata,
			dbgptvalid => dbgptvalid,
			dbgptrdy => dbgptrdy
		);

	-- --------------------------------------
	-- Emulating stimuli signals to DuT (ecc)
	-- --------------------------------------
	steam: process
		-- Input file (containing input test-vectors)
		file fvin : text open read_mode is simvecfile;
		variable tline : line;
		variable rdok : boolean;
		-- A few strings used while parsing input test-vectors file
		variable nline, nline0 : string(1 to 16384); -- "== NEW CURVE #" or "== TEST *"
		variable nbcurve : natural;
		variable nbtest : natural;
		variable newpos : natural;
		--variable new_test_kp : string(1 to 14); -- "== TEST [k]P #"
		variable valnn : natural;
		--
		-- Curve specific
		--
		variable p_val : std_logic512;
		variable a_val : std_logic512;
		variable b_val : std_logic512;
		variable q_val : std_logic512;
		variable curve_param : curve_param_type;
		--
		-- Common to different point operations
		--
		--   Point P
		--
		variable sw_p_is_null : boolean;
		variable px_val : std_logic512;
		variable py_val : std_logic512;
		--
		--   Point Q
		--
		variable sw_q_is_null : boolean;
		variable qx_val : std_logic512;
		variable qy_val : std_logic512;
		--
		-- Scalar multiplication
		--
		variable k_val : std_logic512;
		variable vtoken : std_logic512;
		--   Expected (software)
		variable sw_kp_is_null : boolean;
		variable sw_kpx_val : std_logic512;
		variable sw_kpy_val : std_logic512;
		--   Obtained (hardware)
		variable hw_kp_is_null : boolean;
		variable hw_kpx_val : std_logic512;
		variable hw_kpy_val : std_logic512;
		--
		-- Point addition
		--
		--   Expected (software)
		variable sw_pplusq_is_null : boolean;
		variable sw_pplusqx_val : std_logic512;
		variable sw_pplusqy_val : std_logic512;
		--   Obtained (hardware)
		variable hw_pplusq_is_null : boolean;
		variable hw_pplusqx_val : std_logic512;
		variable hw_pplusqy_val : std_logic512;
		--
		-- Point doubling
		--
		--   Expected (software)
		variable sw_twop_is_null : boolean;
		variable sw_twopx_val : std_logic512;
		variable sw_twopy_val : std_logic512;
		--   Obtained (hardware)
		variable hw_twop_is_null : boolean;
		variable hw_twopx_val : std_logic512;
		variable hw_twopy_val : std_logic512;
		--
		-- Point opposite
		--
		--   Expected (software)
		variable sw_negp_is_null : boolean;
		variable sw_negpx_val : std_logic512;
		variable sw_negpy_val : std_logic512;
		--   Obtained (hardware)
		variable hw_negp_is_null : boolean;
		variable hw_negpx_val : std_logic512;
		variable hw_negpy_val : std_logic512;
		--
		-- Logical tests on point(s)
		--
		variable sw_answer: boolean;
		variable hw_answer: boolean;
		--
		variable void : integer;
		variable str3 : string(1 to 3);
		variable line_length : integer;
		variable test_label : string(1 to 16384);
		variable test_label_sz : natural;
		variable nbbld : natural; -- Nb of blinding bits.
		variable op: operation_t;
		variable line_type_expected : line_t;
		variable test_is_an_exception : boolean;
		-- Statistics
		variable stats_ok: natural;
		variable stats_nok: natural;
		variable stats_total: natural;

		procedure print_stats_and_exit is
		begin
			echol("Statistics so far: ok = " & integer'image(stats_ok) & ", nok = "
				& integer'image(stats_nok) & ", total = " & integer'image(stats_total));
			assert FALSE severity FAILURE;
		end procedure print_stats_and_exit;

		procedure print_stats_and_possibly_exit is
		begin
			if CONTINUE_ON_ERROR = FALSE then
				echol("Statistics so far: ok = " & integer'image(stats_ok) & ", nok = "
					& integer'image(stats_nok) & ", total = " & integer'image(stats_total));
				assert FALSE severity FAILURE;
			end if;
		end procedure print_stats_and_possibly_exit;

	begin

		--
		-- Time 0
		--
		axi0.awvalid <= '0';
		axi0.wvalid <= '0';
		axi0.bready <= '1';
		axi0.arvalid <= '0';
		axi0.rready <= '1';

		--
		-- Wait for out-of-reset.
		--
		wait until s_axi_aresetn = '1';
		echol("[     ecc_tb.vhd ]: Out-of-reset");
		wait for 333 ns;
		wait until s_axi_aclk'event and s_axi_aclk = '1';

		echol("[     ecc_tb.vhd ]: Waiting for init");

		--
		-- Wait until IP has done its (possible) init stuff.
		--
		poll_until_ready(s_axi_aclk, axi0, axo0);

		echol("[     ecc_tb.vhd ]: Init done");

		configure_irq(s_axi_aclk, axi0, axo0, TRUE);

 		-- Enable XY-shuffling
 		debug_enable_xyshuf(s_axi_aclk, axi0, axo0);
 
 		-- Enable AXI on-the-fly masking of the scalar
 		debug_enable_aximask(s_axi_aclk, axi0, axo0);
 
 		-- Enable memory shuffling
 		enable_shuffle(s_axi_aclk, axi0, axo0);

		-- Reset diagnostic TRNG counters
		debug_reset_trng_diagnostic_counters(s_axi_aclk, axi0, axo0);

		-- Choice of the TRNG random source.
		debug_trng_use_real(s_axi_aclk, axi0, axo0);

		-- Enable the post-processing unit from reading raw random bytes.
		debug_trng_pp_start_pulling_raw(s_axi_aclk, axi0, axo0);

		-- End of IP initialization & config

		-- -----------------------------------------------------------------
		-- Main infinite loop, getting lines from input file 'simvecfile'
		-- (parameter defined in ecc_customize.vhd) to extract:
		--   - input vectors
		--   - type of operation
		--   - expected result,
		-- then have the same computation done by RTL of DuT, and then check
		-- the result of simulated hardware against the expected one.
		-- -----------------------------------------------------------------

		echol("[     ecc_tb.vhd ]: Reading test-vectors from input file: """
			& simvecfile & """");

		nbbld := 0; op := OP_NONE; line_type_expected := EXPECT_NONE;
		stats_ok := 0; stats_nok := 0; stats_total := 0;

		while not endfile(fvin) loop
			-- Read a new line from input test-vectors file.
			readline(fvin, tline);
			--echol("TITI tline'length = " & integer'image(tline'length));
			line_length := tline'length;
			--
			-- Allow empty lines
			--
			if line_length = 0 then
				next;
			end if;
			-- Extract the whole line as a fixed constant (very large) character string.
			read(tline, nline(1 to tline'length), rdok);
			if not rdok then
				echol("[     ecc_tb.vhd ]: ERROR: While reading one line " &
						"from" & """" & simtrngfile & " file. Aborting.");
				print_stats_and_exit;
			end if;
			--
			-- Allow comment lines starting with #
			-- (simply assert exception flag if it starts with "# EXCEPTION"
			-- because in this case this comment is meaningful).
			--
			if nline(1) = '#' then 
				if tline'length >= 11 and tline(1 to 11) = "# EXCEPTION" then
					test_is_an_exception := TRUE;
				end if;
				next;
			end if;
			--
			-- Process line according to some kind of finite state
			-- machine on input vector test format.
			--
			case line_type_expected is

				when EXPECT_NONE =>
					if nline(1 to 12) = "== NEW CURVE" then
						--
						-- Line is a "== NEW CURVE" line.
						-- Read curve Id.
						--
						echo("[     ecc_tb.vhd ]: ==== NEW CURVE");
						-- print anything that may follow "NEW CURVE"
						for i in 13 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_NN;
					elsif nline(1 to 12) = "== TEST [k]P" then
						--
						-- Line is a "[k]P" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST [k]P");
						-- print anything that may follow "TEST [k]P"
						test_label_sz := 0;
						for i in 13 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 12) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_KP;
					elsif nline(1 to 11) = "== TEST P+Q" then
						--
						-- Line is a "P+Q" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST P+Q");
						-- print anything that may follow "TEST P+Q"
						test_label_sz := 0;
						for i in 12 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 11) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_PTADD;
					elsif nline(1 to 12) = "== TEST [2]P" then
						--
						-- Line is a "[2]P" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST [2]P");
						-- print anything that may follow "TEST [2]P"
						test_label_sz := 0;
						for i in 13 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 12) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_PTDBL;
					elsif nline(1 to 10) = "== TEST -P" then
						--
						-- Line is a "-P" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST (-P)");
						-- print anything that may follow "TEST (-P)"
						test_label_sz := 0;
						for i in 11 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 10) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_PTNEG;
					elsif nline(1 to 18) = "== TEST isPoncurve" then
						--
						-- Line is a "isPoncurve" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST isPoncurve");
						-- print anything that may follow "TEST isPoncurve"
						test_label_sz := 0;
						for i in 19 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 18) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_TST_CHK;
					elsif nline(1 to 14) = "== TEST isP==Q" then
						--
						-- Line is a "isP==Q" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST isP==Q");
						-- print anything that may follow "TEST isP==Q"
						test_label_sz := 0;
						for i in 15 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 14) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_TST_EQU;
					elsif nline(1 to 15) = "== TEST isP==-Q" then
						--
						-- Line is a "isP==-Q" line.
						-- Read test Id.
						--
						echo("[     ecc_tb.vhd ]: **** NEW TEST isP==-Q");
						-- print anything that may follow "TEST isP==-Q"
						test_label_sz := 0;
						for i in 16 to line_length loop
							if nline(i) = LF then
								exit;
							else
								echoc(nline(i));
								test_label(i - 15) := nline(i);
								test_label_sz := test_label_sz + 1;
							end if;
						end loop;
						echol("");
						line_type_expected := EXPECT_PX;
						op := OP_TST_OPP;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file.");
						print_stats_and_exit;
					end if;

				when EXPECT_NN =>
					if nline(1 to 3) = "nn=" then
						--
						-- Line is an "nn=" line.
						-- Read 'nn' value.
						--
						str_to_int(nline, 4, line_length, valnn, rdok, void);
						if rdok then
							echol("[     ecc_tb.vhd ]: nn=" & natural'image(valnn));
							line_type_expected := EXPECT_P;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an integer value after ""nn="").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting token ""nn="").");
						print_stats_and_exit;
					end if;

				when EXPECT_P =>
					if nline(1 to 4) = "p=0x" then
						--
						-- Line is a "p=0x" line.
						-- Read value of 'p'.
						--
						str_to_stdlogic(nline, 5, line_length, p_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: p=0x");
							hex_echol(p_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_A;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""p=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""p=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_A =>
					if nline(1 to 4) = "a=0x" then
						--
						-- Line is a "a=0x" line.
						-- Read value of 'a'.
						--
						str_to_stdlogic(nline, 5, line_length, a_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: a=0x");
							hex_echol(a_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_B;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""a=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""a=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_B =>
					if nline(1 to 4) = "b=0x" then
						--
						-- Line is a "b=0x" line.
						-- Read value of 'b'.
						--
						str_to_stdlogic(nline, 5, line_length, b_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: b=0x");
							hex_echol(b_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_Q;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""b=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""b=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_Q =>
					if nline(1 to 4) = "q=0x" then
						--
						-- Line is a "q=0x" line.
						-- Read value of 'q'.
						--
						str_to_stdlogic(nline, 5, line_length, q_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: q=0x");
							hex_echol(q_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_NONE;
							--
							-- Set curve parameters in dedicated structure.
							--
							curve_param(0) := p_val;
							curve_param(1) := a_val;
							curve_param(2) := b_val;
							curve_param(3) := q_val;
							--
							-- First set 'nn', if needed.
							--
							if (nn_s /= valnn) then
								set_nn(s_axi_aclk, axi0, axo0, valnn);
								nn_s <= valnn;
							end if;
							--
							-- Then set curve according to the parameters extracted
							-- from the testbench input file.
							--
							set_curve(s_axi_aclk, axi0, axo0, valnn, curve_param);
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""q=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""q=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_PX =>
					if nline(1 to 5) = "Px=0x" then
						--
						-- Line is a "Px=0x" line.
						-- Read value of 'P.x'.
						--
						str_to_stdlogic(nline, 6, line_length, px_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Px=0x");
							hex_echol(px_val(valnn - 1 downto 0));
							sw_p_is_null := FALSE;
							line_type_expected := EXPECT_PY;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""Px=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 3) = "P=0" then
						--
						-- Point P is null, no X-Y coordinates to read, simply raise
						-- appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: P=0");
						sw_p_is_null := TRUE;
						if op = OP_KP then
							line_type_expected := EXPECT_K;
						elsif op = OP_PTADD then
							line_type_expected := EXPECT_QX;
						elsif op = OP_PTDBL then
							line_type_expected := EXPECT_TWOP_X;
						elsif op = OP_PTNEG then
							line_type_expected := EXPECT_NEGP_X;
						elsif op = OP_TST_CHK then
							line_type_expected := EXPECT_TRUE_OR_FALSE;
						elsif op = OP_TST_EQU or op = OP_TST_OPP then
							line_type_expected := EXPECT_QX;
						else
							echol("[     ecc_tb.vhd ]: Internal ERROR: (unknown "
								& "operation type).");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""Px=0x"" or ""P=0"").");
						print_stats_and_exit;
					end if;

				when EXPECT_PY =>
					if nline(1 to 5) = "Py=0x" then
						--
						-- Line is a "Py=0x" line.
						-- Read value of 'P.y'.
						--
						str_to_stdlogic(nline, 6, line_length, py_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Py=0x");
							hex_echol(py_val(valnn - 1 downto 0));
							if op = OP_KP then
								line_type_expected := EXPECT_K;
							elsif op = OP_PTADD then
								line_type_expected := EXPECT_QX;
							elsif op = OP_PTDBL then
								line_type_expected := EXPECT_TWOP_X;
							elsif op = OP_PTNEG then
								line_type_expected := EXPECT_NEGP_X;
							elsif op = OP_TST_CHK then
								line_type_expected := EXPECT_TRUE_OR_FALSE;
							elsif op = OP_TST_EQU or op = OP_TST_OPP then
								line_type_expected := EXPECT_QX;
							else
								echol("[     ecc_tb.vhd ]: Internal ERROR (unknown operation "
									& "type.");
								print_stats_and_exit;
							end if;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""Py=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""Py=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_QX =>
					if nline(1 to 5) = "Qx=0x" then
						--
						-- Line is a "Qx=0x" line.
						-- Read value of 'Q.x'.
						--
						str_to_stdlogic(nline, 6, line_length, qx_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Qx=0x");
							hex_echol(qx_val(valnn - 1 downto 0));
							sw_q_is_null := FALSE;
							line_type_expected := EXPECT_QY;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""Qx=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 3) = "Q=0" then
						--
						-- Point Q is null, no X-Y coordinates to read, simply raise
						-- appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: Q=0");
						sw_q_is_null := TRUE;
						if op = OP_PTADD then
							line_type_expected := EXPECT_P_PLUS_QX;
						elsif op = OP_TST_EQU or op = OP_TST_OPP then
							line_type_expected := EXPECT_TRUE_OR_FALSE;
						else
							echol("[     ecc_tb.vhd ]: Internal ERROR (unknown "
								& "operation type).");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""Qx=0x"" or ""Q=0"").");
						print_stats_and_exit;
					end if;

				when EXPECT_QY =>
					if nline(1 to 5) = "Qy=0x" then
						--
						-- Line is a "Qy=0x" line.
						-- Read value of 'Q.y'.
						--
						str_to_stdlogic(nline, 6, line_length, qy_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Qy=0x");
							hex_echol(qy_val(valnn - 1 downto 0));
							if op = OP_PTADD then
								line_type_expected := EXPECT_P_PLUS_QX;
							elsif op = OP_TST_EQU or op = OP_TST_OPP then
								line_type_expected := EXPECT_TRUE_OR_FALSE;
							else
								echol("[     ecc_tb.vhd ]: Internal ERROR (unknown "
									& "operation type.");
								print_stats_and_exit;
							end if;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""Py=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""Py=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_K =>
					if nline(1 to 4) = "k=0x" then
						--
						-- Line is a "k=0x" line.
						-- Read value of 'k'.
						--
						str_to_stdlogic(nline, 5, line_length, k_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: k=0x");
							hex_echol(k_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_KPX_OR_BLD;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""k=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""k=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_KPX_OR_BLD =>
					if nline(1 to 6) = "kPx=0x" then
						--
						-- Line is a "kPx=0x" line.
						-- Read value of '[k]P.x'.
						--
						str_to_stdlogic(nline, 7, line_length, sw_kpx_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: [k]P.x = 0x");
							hex_echol(sw_kpx_val(valnn - 1 downto 0));
							sw_kp_is_null := FALSE;
							line_type_expected := EXPECT_KPY;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""kPx=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 4) = "kP=0" then
						--
						-- Result point [k]P is null, no X-Y coordinates to read,
						-- simply raise appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: Expecting result: [k]P = 0.");
						sw_kp_is_null := TRUE;
						line_type_expected := EXPECT_NONE;
						-- --------------------------------------------------------
						--              Program one [k]P computation now.
						-- --------------------------------------------------------
						--
						-- Configure blinding according to what is told in the testbench
						-- input vectors file.
						--
						if nbbld > 0 then
							configure_blinding(s_axi_aclk, axi0, axo0, TRUE, nbbld);
						else
							configure_blinding(s_axi_aclk, axi0, axo0, FALSE, 0);
						end if;
						--
						-- Set point & scalar according to parameters extracted
						-- from the input test-vectors file.
						--
						-- Acquire a token to mask [k]P coordinates with.
						--
						vtoken := (others => '0');
						get_token(s_axi_aclk, axi0, axo0, valnn, vtoken);
						echo("[     ecc_tb.vhd ]: Acquired masking token: 0x");
						hex_echol(vtoken(valnn - 1 downto 0));
						-- The last argument of procedure 'scalar_mult' (see call just below)
						-- defines if the point P to be multiplied is or is not the point at
						-- infinity.
						-- Hence here it is set to 'sw_p_is_null' according to what was given
						-- in the input test-vectors file.
						scalar_mult(s_axi_aclk, axi0, axo0, valnn, k_val, px_val, py_val,
							sw_p_is_null);
						--
						-- Poll until IP has completed computation and is ready.
						--
						poll_until_ready(s_axi_aclk, axi0, axo0);
						-- Check & display possible errors.
						display_errors(s_axi_aclk, axi0, axo0);
						-- Check if R1 is null.
						check_if_r1_null(s_axi_aclk, axi0, axo0, hw_kp_is_null);
						if hw_kp_is_null then
							echo_test_label(test_label, test_label_sz, "[k]P");
							echol(" - SUCCESSFULL: RTL result for [k]P matches the one "
								& "expected by test-vectors file (both are the null point).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						else
							-- Read back the [k]P result coordinates.
							read_and_return_kp_result(s_axi_aclk, axi0, axo0, valnn, vtoken,
								hw_kpx_val, hw_kpy_val);
							echo_test_label(test_label, test_label_sz, "[k]P");
							echol(" **** FAILED! **** Mismatch between simulated RTL ([k]P != 0) "
								& "and result expected by test-vectors file ([k]P = 0).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						end if;
						-- Acknowledge possible errors.
						ack_all_errors(s_axi_aclk, axi0, axo0);
					elsif nline(1 to 6) = "nbbld=" then
						--
						-- Line is a "nbbld=0" line.
						-- Read value of 'nbbld'.
						--
						str_to_int(nline, 7, line_length, nbbld, rdok, void);
						if rdok then
							if (nbbld > valnn - 1) then
								echol("[     ecc_tb.vhd ]: ERROR: Too large a blinding size "
									& "as compared to the current value of nn = "
									& integer'image(valnn) & ".");
								print_stats_and_exit;
							else
								echol("[     ecc_tb.vhd ]: nbbld=" & integer'image(nbbld));
								-- We keep expect_kpx_sw to TRUE
								line_type_expected := EXPECT_KPX_OR_BLD; -- 4sake of readability
							end if;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an integer value after ""nbbld"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""kPx=0x"" or ""kP=0"" or ""nbbld="").");
						print_stats_and_exit;
					end if;

				when EXPECT_KPY =>
					if nline(1 to 6) = "kPy=0x" then
						--
						-- Line is a "kPy=0x" line.
						-- Read value of '[k]P.y'.
						--
						str_to_stdlogic(nline, 7, line_length, sw_kpy_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: [k]P.y = 0x");
							hex_echol(sw_kpy_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_NONE;
							-- --------------------------------------------------------
							--              Program one [k]P computation now.
							-- --------------------------------------------------------
							--
							-- Configure blinding according to what is told in the testbench
							-- input vectors file.
							--
							if nbbld > 0 then
								configure_blinding(s_axi_aclk, axi0, axo0, TRUE, nbbld);
							else
								configure_blinding(s_axi_aclk, axi0, axo0, FALSE, 0);
							end if;
							--
							-- Set point & scalar according to parameters extracted
							-- from the input test-vectors file.
							--
							-- Acquire a token to mask [k]P coordinates with.
							--
							vtoken := (others => '0');
							get_token(s_axi_aclk, axi0, axo0, valnn, vtoken);
							echo("[     ecc_tb.vhd ]: Acquired masking token: 0x");
							hex_echol(vtoken(valnn - 1 downto 0));
							-- The last argument of procedure 'scalar_mult' (see call just below)
							-- defines if the point P to be multiplied is or is not the point at
							-- infinity.
							-- Hence here it is set to 'sw_p_is_null' according to what was given
							-- in the input test-vectors file.
							scalar_mult(s_axi_aclk, axi0, axo0, valnn, k_val, px_val, py_val,
								sw_p_is_null);
							--
							-- Poll until IP has completed computation and is ready.
							--
							poll_until_ready(s_axi_aclk, axi0, axo0);
							-- Check & display possible errors.
							display_errors(s_axi_aclk, axi0, axo0);
							-- Check if R1 is null.
							check_if_r1_null(s_axi_aclk, axi0, axo0, hw_kp_is_null);
							if hw_kp_is_null then
								echo_test_label(test_label, test_label_sz, "[k]P");
								echol(" **** FAILED! **** Mismatch between simulated RTL ([k]P = 0) "
									& "and result expected by test-vectors file ([k]P != 0).");
								stats_nok := stats_nok + 1;
								stats_total := stats_total + 1;
								assert CONTINUE_ON_ERROR severity FAILURE;
							else
								-- We need to compare the coordinates with the ones given
								-- in the input test-vectors file.
								-- Read back the [k]P result coordinates.
								read_and_return_kp_result(s_axi_aclk, axi0, axo0, valnn, vtoken,
									hw_kpx_val, hw_kpy_val);
								-- Compare coordinates
								if compare_two_points_coords(sw_kpx_val, sw_kpy_val,
									hw_kpx_val xor vtoken, hw_kpy_val xor vtoken, valnn)
								then
									echo_test_label(test_label, test_label_sz, "[k]P");
									echol(" - SUCCESSFULL: [k]P point coordinates match the ones given "
										& "in the input test-vectors file.");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "[k]P");
									echol(" **** FAILED! **** Mismatch on points coordinates. Simulated hardware gave:");
									echo("[     ecc_tb.vhd ]: [k]P.x = 0x");
									hex_echol(hw_kpx_val(valnn - 1 downto 0) xor vtoken(valnn - 1 downto 0));
									echo("[     ecc_tb.vhd ]: [k]P.y = 0x");
									hex_echol(hw_kpy_val(valnn - 1 downto 0) xor vtoken(valnn - 1 downto 0));
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							end if;
							-- Acknowledge possible errors.
							ack_all_errors(s_axi_aclk, axi0, axo0);
						else -- not rdok
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""kPy=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""kPy=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_P_PLUS_QX =>
					if nline(1 to 10) = "PplusQx=0x" then
						--
						-- Line is a "PplusQx=0x" line.
						-- Read value of 'P+Q.x'.
						--
						str_to_stdlogic(nline, 11, line_length, sw_pplusqx_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: (P+Q).x = 0x");
							hex_echol(sw_pplusqx_val(valnn - 1 downto 0));
							sw_pplusq_is_null := FALSE;
							line_type_expected := EXPECT_P_PLUS_QY;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""PplusQx=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 8) = "PplusQ=0" then
						--
						-- Result point P + Q is null, no X-Y coordinates to read,
						-- simply raise appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: Expecting result: P+Q = 0.");
						sw_pplusq_is_null := TRUE;
						line_type_expected := EXPECT_NONE;
						-- --------------------------------------------------------
						--              Program one P + Q computation now.
						-- --------------------------------------------------------
						--
						-- Set points to add according to parameters extracted
						-- from the input test-vectors file.
						--
						-- The two last arguments of procedure 'point_add' (see call just
						-- below) resp. define if the point P (resp. Q) is or is not the
						-- point at infinity.
						--
						-- Hence here they are set to 'sw_p_is_null' (resp. sw_q_is_null)
						-- according to what was given in the input test-vectors file.
						--
						point_add(s_axi_aclk, axi0, axo0, valnn, px_val, py_val, qx_val,
							qy_val, sw_p_is_null, sw_q_is_null);
						--
						-- Poll until IP has completed computation and is ready.
						--
						poll_until_ready(s_axi_aclk, axi0, axo0);
						-- Check & display possible errors.
						display_errors(s_axi_aclk, axi0, axo0);
						-- Check if result P + Q (now buffered in R1) is null.
						check_if_r1_null(s_axi_aclk, axi0, axo0, hw_pplusq_is_null);
						if hw_pplusq_is_null then
							echo_test_label(test_label, test_label_sz, "P+Q");
							echol(" - SUCCESSFULL: RTL result for P+Q matches the one "
								& "expected by test-vectors file (both are the null point).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						else
							echo_test_label(test_label, test_label_sz, "P+Q");
							echol(" **** FAILED! **** Mismatch between simulated RTL (P+Q != 0) and "
								& "result expected by test-vectors file (P+Q = 0).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						end if;
						-- Acknowledge possible errors.
						ack_all_errors(s_axi_aclk, axi0, axo0);
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""PplusQx=0x"" or ""PplusQ=0"").");
						print_stats_and_exit;
					end if;

				when EXPECT_P_PLUS_QY =>
					if nline(1 to 10) = "PplusQy=0x" then
						--
						-- Line is a "kPy=0x" line.
						-- Read value of '[k]P.y'.
						--
						str_to_stdlogic(nline, 11, line_length, sw_pplusqy_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: (P+Q).y = 0x");
							hex_echol(sw_pplusqy_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_NONE;
							-- --------------------------------------------------------
							--              Program one P + Q computation now.
							-- --------------------------------------------------------
							--
							-- Set points to add according to parameters extracted
							-- from the input test-vectors file.
							--
							-- The two last arguments of procedure 'point_add' (see call just
							-- below) resp. define if the point P (resp. Q) is or is not the
							-- point at infinity.
							--
							-- Hence here they are set to 'sw_p_is_null' (resp. sw_q_is_null)
							-- according to what was given in the input test-vectors file.
							--
							point_add(s_axi_aclk, axi0, axo0, valnn, px_val, py_val, qx_val,
								qy_val, sw_p_is_null, sw_q_is_null);
							--
							-- Poll until IP has completed computation and is ready.
							--
							poll_until_ready(s_axi_aclk, axi0, axo0);
							-- Check & display possible errors.
							display_errors(s_axi_aclk, axi0, axo0);
							-- Check if result P + Q (now buffered in R1) is null.
							check_if_r1_null(s_axi_aclk, axi0, axo0, hw_pplusq_is_null);
							if hw_pplusq_is_null then
								if sw_pplusq_is_null then
									echo_test_label(test_label, test_label_sz, "P+Q");
									echol(" - SUCCESSFULL: RTL result for P+Q matches the one "
										& "expected by test-vectors file (both are the null "
										& "point).");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "P+Q");
									echol(" **** FAILED! **** Mismatch between simulated RTL (P+Q = 0) "
										& "and result expected by test-vectors file (P+Q != 0).");
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							else
								-- We need to compare the coordinates with the ones given
								-- in the input test-vectors file.
								-- Read back the P + Q result coordinates.
								read_and_return_ptadd_result(s_axi_aclk, axi0, axo0, valnn,
									hw_pplusqx_val, hw_pplusqy_val);
								-- Compare coordinates
								if compare_two_points_coords(sw_pplusqx_val, sw_pplusqy_val,
									hw_pplusqx_val, hw_pplusqy_val, valnn)
								then
									echo_test_label(test_label, test_label_sz, "P+Q");
									echol(" - SUCCESSFULL: P+Q point coordinates match the ones given "
										& "in the input test-vectors file.");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "P+Q");
									echol(" **** FAILED! **** Mismatch on points coordinates. "
										& "Simulated RTL gave:");
									echo("[     ecc_tb.vhd ]: (P+Q).x = 0x");
									hex_echol(hw_pplusqx_val(valnn - 1 downto 0));
									echo("[     ecc_tb.vhd ]: (P+Q).y = 0x");
									hex_echol(hw_pplusqy_val(valnn - 1 downto 0));
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							end if;
							-- Acknowledge possible errors.
							ack_all_errors(s_axi_aclk, axi0, axo0);
						else -- not rdok
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""PplusQy=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""PplusQy=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_TWOP_X =>
					if nline(1 to 8) = "twoPx=0x" then
						--
						-- Line is a "twoPx=0x" line.
						-- Read value of '[2]P.x'.
						--
						str_to_stdlogic(nline, 9, line_length, sw_twopx_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: [2]P.x = 0x");
							hex_echol(sw_twopx_val(valnn - 1 downto 0));
							sw_twop_is_null := FALSE;
							line_type_expected := EXPECT_TWOP_Y;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""twoPx=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 6) = "twoP=0" then
						--
						-- Result point [2]P is null, no X-Y coordinates to read,
						-- simply raise appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: Expecting result: [2]P = 0.");
						sw_twop_is_null := TRUE;
						line_type_expected := EXPECT_NONE;
						-- --------------------------------------------------------
						--              Program one [2]P computation now.
						-- --------------------------------------------------------
						--
						-- Set point to double according to parameters extracted
						-- from the input test-vectors file.
						--
						-- The last arguments of procedure 'point_double' (see call just
						-- below) defines if the point P is or is not the point at infi-
						-- nity.
						--
						-- Hence here it is set to 'sw_p_is_null' according to what was
						-- given in the input test-vectors file.
						--
						point_double(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
							sw_p_is_null);
						--
						-- Poll until IP has completed computation and is ready.
						--
						poll_until_ready(s_axi_aclk, axi0, axo0);
						-- Check & display possible errors.
						display_errors(s_axi_aclk, axi0, axo0);
						-- Check if result [2]P (now buffered in R1) is null.
						check_if_r1_null(s_axi_aclk, axi0, axo0, hw_twop_is_null);
						if hw_twop_is_null then
							echo_test_label(test_label, test_label_sz, "[2]P");
							echol(" - SUCCESSFULL: RTL result for [2]P matches the one "
								& "expected by test-vectors file (both are the null point).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						else
							echo_test_label(test_label, test_label_sz, "[2]P");
							echol(" **** FAILED! **** Mismatch between simulated RTL ([2]P != 0) and "
								& "result expected by test-vectors file ([2]P = 0).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						end if;
						-- Acknowledge possible errors.
						ack_all_errors(s_axi_aclk, axi0, axo0);
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""twoPx=0x"" or ""twoP=0"").");
						print_stats_and_exit;
					end if;

				when EXPECT_TWOP_Y =>
					if nline(1 to 8) = "twoPy=0x" then
						--
						-- Line is a "twoPy=0x" line.
						-- Read value of '[2]P.y'.
						--
						str_to_stdlogic(nline, 9, line_length, sw_twopy_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: [2]P.y = 0x");
							hex_echol(sw_twopy_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_NONE;
							-- --------------------------------------------------------
							--              Program one [2]P computation now.
							-- --------------------------------------------------------
							--
							-- Set point to add according to parameters extracted
							-- from the input test-vectors file.
							--
							-- The last argument of procedure 'point_double' (see call just
							-- below) defines if the point P is or is not the point at
							-- infinity.
							--
							-- Hence it is set to 'sw_p_is_null' according to what was
							-- given in the input test-vectors file.
							--
							point_double(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
								sw_p_is_null);
							--
							-- Poll until IP has completed computation and is ready.
							--
							poll_until_ready(s_axi_aclk, axi0, axo0);
							-- Check & display possible errors.
							display_errors(s_axi_aclk, axi0, axo0);
							-- Check if result [2]P (now buffered in R1) is null.
							check_if_r1_null(s_axi_aclk, axi0, axo0, hw_twop_is_null);
							if hw_twop_is_null then
								if sw_twop_is_null then
									echo_test_label(test_label, test_label_sz, "[2]P");
									echol(" - SUCCESSFULL: RTL result for [2]P matches the one "
										& "expected by test-vectors file (both are the null "
										& "point).");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "[2]P");
									echol(" **** FAILED! **** Mismatch between simulated RTL ([2]P = 0) "
										& "and result expected by test-vectors file ([2]P != 0).");
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							else
								-- We need to compare the coordinates with the ones given
								-- in the input test-vectors file.
								-- Read back the [2]P result coordinates.
								read_and_return_ptdbl_result(s_axi_aclk, axi0, axo0, valnn,
									hw_twopx_val, hw_twopy_val);
								-- Compare coordinates
								if compare_two_points_coords(sw_twopx_val, sw_twopy_val,
									hw_twopx_val, hw_twopy_val, valnn)
								then
									echo_test_label(test_label, test_label_sz, "[2]P");
									echol(" - SUCCESSFULL: [2]P point coordinates match the ones given "
										& "in the input test-vectors file.");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "[2]P");
									echol(" **** FAILED! **** Mismatch on points coordinates. "
										& "Simulated RTL gave:");
									echo("[     ecc_tb.vhd ]: [2]P.x = 0x");
									hex_echol(hw_twopx_val(valnn - 1 downto 0));
									echo("[     ecc_tb.vhd ]: [2]P.y = 0x");
									hex_echol(hw_twopy_val(valnn - 1 downto 0));
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							end if;
							-- Acknowledge possible errors.
							ack_all_errors(s_axi_aclk, axi0, axo0);
						else -- not rdok
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""twoPy=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""twoPy=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_NEGP_X =>
					if nline(1 to 8) = "negPx=0x" then
						--
						-- Line is a "negPx=0x" line.
						-- Read value of '(-)P.x'.
						--
						str_to_stdlogic(nline, 9, line_length, sw_negpx_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: (-P).x = 0x");
							hex_echol(sw_negpx_val(valnn - 1 downto 0));
							sw_negp_is_null := FALSE;
							line_type_expected := EXPECT_NEGP_Y;
						else
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""negPx=0x"").");
							print_stats_and_exit;
						end if;
					elsif nline(1 to 6) = "negP=0" then
						--
						-- Result point -P is null, no X-Y coordinates to read,
						-- simply raise appropriate flag.
						--
						echol("[     ecc_tb.vhd ]: Expecting result: (-P) = 0.");
						sw_negp_is_null := TRUE;
						line_type_expected := EXPECT_NONE;
						-- --------------------------------------------------------
						--               Program one -P computation now.
						-- --------------------------------------------------------
						--
						-- Set point to double according to parameters extracted
						-- from the input test-vectors file.
						--
						-- The last arguments of procedure 'point_negate' (see call just
						-- below) defines if the point P is or is not the point at infi-
						-- nity.
						--
						-- Hence here it is set to 'sw_p_is_null' according to what was
						-- given in the input test-vectors file.
						--
						point_negate(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
							sw_p_is_null);
						--
						-- Poll until IP has completed computation and is ready.
						--
						poll_until_ready(s_axi_aclk, axi0, axo0);
						-- Check & display possible errors.
						display_errors(s_axi_aclk, axi0, axo0);
						-- Check if result -P (now buffered in R1) is null.
						check_if_r1_null(s_axi_aclk, axi0, axo0, hw_negp_is_null);
						if hw_negp_is_null then
							echo_test_label(test_label, test_label_sz, "(-P)");
							echol(" - SUCCESSFULL: RTL result for (-P) matches the one "
								& "expected by test-vectors file (both are the null point).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						else
							echo_test_label(test_label, test_label_sz, "(-P)");
							echol(" **** FAILED! **** Mismatch between simulated RTL (-P != 0) and "
								& "result expected by test-vectors file (-P = 0).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						end if;
						-- Acknowledge possible errors.
						ack_all_errors(s_axi_aclk, axi0, axo0);
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of token ""negPx=0x"" or ""negP=0"").");
						print_stats_and_exit;
					end if;

				when EXPECT_NEGP_Y =>
					if nline(1 to 8) = "negPy=0x" then
						--
						-- Line is a "negPy=0x" line.
						-- Read value of '(-P).y'.
						--
						str_to_stdlogic(nline, 9, line_length, sw_negpy_val, valnn, rdok, void);
						if rdok then
							echo("[     ecc_tb.vhd ]: Expecting result: (-P).y = 0x");
							hex_echol(sw_negpy_val(valnn - 1 downto 0));
							line_type_expected := EXPECT_NONE;
							-- --------------------------------------------------------
							--              Program one -P computation now.
							-- --------------------------------------------------------
							--
							-- Set point to add according to parameters extracted
							-- from the input test-vectors file.
							--
							-- The last argument of procedure 'point_double' (see call just
							-- below) defines if the point P is or is not the point at
							-- infinity.
							--
							-- Hence it is set to 'sw_p_is_null' according to what was
							-- given in the input test-vectors file.
							--
							point_negate(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
								sw_p_is_null);
							--
							-- Poll until IP has completed computation and is ready.
							--
							poll_until_ready(s_axi_aclk, axi0, axo0);
							-- Check & display possible errors.
							display_errors(s_axi_aclk, axi0, axo0);
							-- Check if result -P (now buffered in R1) is null.
							check_if_r1_null(s_axi_aclk, axi0, axo0, hw_negp_is_null);
							if hw_negp_is_null then
								if sw_negp_is_null then
									echo_test_label(test_label, test_label_sz, "(-P)");
									echol(" - SUCCESSFULL: RTL result for (-P) matches the one "
										& "expected by test-vectors file (both are the null "
										& "point).");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "(-P)");
									echol(" **** FAILED! **** Mismatch between simulated RTL (-P = 0) "
										& "and result expected by test-vectors file (-P != 0).");
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							else
								-- We need to compare the coordinates with the ones given
								-- in the input test-vectors file.
								-- Read back the -P result coordinates.
								read_and_return_ptneg_result(s_axi_aclk, axi0, axo0, valnn,
									hw_negpx_val, hw_negpy_val);
								-- Compare coordinates
								if compare_two_points_coords(sw_negpx_val, sw_negpy_val,
									hw_negpx_val, hw_negpy_val, valnn)
								then
									echo_test_label(test_label, test_label_sz, "(-P)");
									echol(" - SUCCESSFULL: (-P) point coordinates match the ones given "
										& "in the input test-vectors file.");
									stats_ok := stats_ok + 1;
									stats_total := stats_total + 1;
								else
									echo_test_label(test_label, test_label_sz, "(-P)");
									echol(" **** FAILED! **** Mismatch on points coordinates. "
										& "Simulated RTL gave:");
									echo("[     ecc_tb.vhd ]: (-P).x = 0x");
									hex_echol(hw_negpx_val(valnn - 1 downto 0));
									echo("[     ecc_tb.vhd ]: (-P).y = 0x");
									hex_echol(hw_negpy_val(valnn - 1 downto 0));
									stats_nok := stats_nok + 1;
									stats_total := stats_total + 1;
									assert CONTINUE_ON_ERROR severity FAILURE;
								end if;
							end if;
							-- Acknowledge possible errors.
							ack_all_errors(s_axi_aclk, axi0, axo0);
						else -- not rdok
							echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
								& "(expecting an hexadecimal number after ""negPy=0x"").");
							print_stats_and_exit;
						end if;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting token ""negPy=0x"").");
						print_stats_and_exit;
					end if;

				when EXPECT_TRUE_OR_FALSE =>
					if line_length >= 4 and str_low_case(nline(1 to 4)) = "true" then
						echol("[     ecc_tb.vhd ]: Expecting answer: TRUE.");
						sw_answer := TRUE;
					elsif line_length >= 5 and str_low_case(nline(1 to 5)) = "false" then
						echol("[     ecc_tb.vhd ]: Expecting answer: FALSE.");
						sw_answer := FALSE;
					else
						echol("[     ecc_tb.vhd ]: ERROR: Wrong syntax in input file "
							& "(expecting one of tokens ""true"" or ""false"").");
						print_stats_and_exit;
					end if;
					line_type_expected := EXPECT_NONE;
					-- --------------------------------------------------------
					--              Program one point test now.
					-- --------------------------------------------------------
					--
					-- Set point(s) to do the test on, according to parameters
					-- extracted from the input test-vectors file.
					--
					case op is
						when OP_TST_CHK =>
							point_test_on_curve(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
								sw_p_is_null);
						when OP_TST_EQU =>
							point_test_equal(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
								qx_val, qy_val, sw_p_is_null, sw_q_is_null);
						when OP_TST_OPP =>
							point_test_opposite(s_axi_aclk, axi0, axo0, valnn, px_val, py_val,
								qx_val, qy_val, sw_p_is_null, sw_q_is_null);
						when others =>
							echol("[     ecc_tb.vhd ]: Internal ERROR (Unknown test type).");
							print_stats_and_exit;
					end case;
					--
					-- Poll until IP has completed computation and is ready.
					--
					poll_until_ready(s_axi_aclk, axi0, axo0);
					-- Check & display possible errors.
					display_errors(s_axi_aclk, axi0, axo0);
					-- Get answer to test from DuT.
					check_test_answer(s_axi_aclk, axi0, axo0, hw_answer);
					-- Compare DuT answer with the expected one from input test-vectors
					-- file.
					case op is
						when OP_TST_CHK =>
							echo_test_label(test_label, test_label_sz, "isPoncurve");
						when OP_TST_EQU =>
							echo_test_label(test_label, test_label_sz, "isP==Q");
						when OP_TST_OPP =>
							echo_test_label(test_label, test_label_sz, "isP==-Q");
						when others =>
							echol("[     ecc_tb.vhd ]: Internal ERROR (Unknown test type).");
							print_stats_and_exit;
					end case;
					if hw_answer then
						if sw_answer then
							echol(" - SUCCESSFULL: RTL test answer matches the one given "
								& "in the input test-vectors file (both are TRUE).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						else -- sw_answer = false
							echol(" **** FAILED! **** Mismatch between simulated RTL answer (TRUE) "
								& "and the one given in input test-vectors file (FALSE).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						end if;
					else -- hw_answer = false
						if sw_answer then
							echol(" **** FAILED! **** Mismatch between simulated RTL answer (FALSE) "
								& "and the one given in input test-vectors file (TRUE).");
							stats_nok := stats_nok + 1;
							stats_total := stats_total + 1;
							assert CONTINUE_ON_ERROR severity FAILURE;
						else -- sw_answer = false
							echol(" - SUCCESSFULL: RTL test answer matches the one given "
								& "in the input test-vectors file (both are FALSE).");
							stats_ok := stats_ok + 1;
							stats_total := stats_total + 1;
						end if;
					end if;

				when others =>

					echol("[     ecc_tb.vhd ]: Internal ERROR (Unknown value of "
						& "variable line_type_expected).");
					print_stats_and_exit;

			end case;

			-- Reset a certain number of flags is expect_none = TRUE.
			if line_type_expected = EXPECT_NONE then
				nbbld := 0;
				op := OP_NONE;
				test_is_an_exception := FALSE;
			end if;

		end loop; -- while not EOF

		echol("[     ecc_tb.vhd ]: End of testbench simulation (EOF) (" & time'image(now) & ")");

		echol("[     ecc_tb.vhd ]: Tests statistics:");
		echol("[     ecc_tb.vhd ]:      ok = " & integer'image(stats_ok));
		echol("[     ecc_tb.vhd ]:      nok = " & integer'image(stats_nok));
		echol("[     ecc_tb.vhd ]:      total = " & integer'image(stats_total));

		-- Wait indefinitely.
		wait;

	end process steam;

	-- ------------------------------------------------------------------
	-- Generation of stimuli signals to pseudo_trng.
	--
	-- This process emulates the AXI initiator that would talk to it in
	-- a real hardware, pushing a file to it that will act as the "true"
	-- physical source in the testbench instead of ES-TRNG.
	--
	-- Note: this process is actually useless since it is equivalent to
	-- using simulation file for ES-TRNG (es_trng_sim.vhd) instead of
	-- pseudo_trng with the same input file, however we had to write
	-- this process in order to validate through behav. simulation the
	-- RTL of pseudo_trng. :)
	--
	-- Anyway the presence of this process does no harm and that's why
	-- it was left here as is.
	-- ------------------------------------------------------------------
	process
		-- Value of 'simtrngfile' is set in 'ecc_customize'.
		file psfr: text is simtrngfile;
		variable tline : line;
		variable nb : integer;
		variable nbl : integer := 1;
		variable dw : std_logic_vector(31 downto 0);
		variable fifo_count : natural;
	begin
		--
		-- time 0
		--
		axi1.awvalid <= '0';
		axi1.wvalid <= '0';
		axi1.bready <= '1';
		axi1.arvalid <= '0';
		axi1.rready <= '1';
		once_out_of_reset <= '1';
		--
		-- wait for out-of-reset
		--
		wait until s_axi_aresetn = '1';
		wait for 666 ns; -- The devil looks after his own
		wait until s_axi_aclk'event and s_axi_aclk = '1';

		-- Infinite loop polling the PSEUDOTRNG_R_FIFO_COUNT register
		-- and pushing into register PSEUDOTRNG_W_WRITE_DATA as many bytes as
		-- the FIFO count says we can.
		loop
			-- If we just left the reset state, we push a complete 4096 bytes
			-- into the FIFO (we know it's empty), and then for subsequent writes
			-- we wait until the Irq of pseudo-TRNG tells us that half of its FIFO
			-- content was read on its consumer side.
			if once_out_of_reset = '1' then
				once_out_of_reset <= '0';
				for i in 1 to 4096 loop
					wait until s_axi_aclk'event and s_axi_aclk = '1';
					-- write PSEUDOTRNG_W_WRITE_DATA register
					axi1.awaddr <= PSEUDOTRNG_W_WRITE_DATA & "000"; axi1.awvalid <= '1';
					wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.awready = '1';
					axi1.awaddr <= (others => 'X'); axi1.awvalid <= '0';
					-- Read a new line from input file, get a byte from it, and send it
					-- on the AXI write data channel
					readline(psfr, tline);
					read(tline, nb);
					assert nb < 256
						report "wrong random value from input file (line "
									 & integer'image(nbl) & ")"
							severity failure;
					dw := std_logic_vector(to_unsigned(nb, 32));
					axi1.wdata <= dw;
					axi1.wvalid <= '1';
					wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.wready = '1';
					axi1.wdata <= (others => 'X'); axi1.wvalid <= '0';
					wait until s_axi_aclk'event and s_axi_aclk = '1';
				end loop;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			else -- once_out_of_reset = 0
				--
				-- wait for Irq
				--
				wait until pseudo_trng_irq'event and pseudo_trng_irq = '1';
				for i in 0 to 15 loop
					wait until s_axi_aclk'event and s_axi_aclk = '1';
				end loop;
				--
				-- AXI transaction to read the PSEUDOTRNG_R_FIFO_COUNT register.
				--
				wait until s_axi_aclk'event and s_axi_aclk = '1';
				-- read PSEUDOTRNG_R_FIFO_COUNT register
				axi1.araddr <= PSEUDOTRNG_R_FIFO_COUNT & "000";
				axi1.arvalid <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.arready = '1';
				axi1.araddr <= (others => 'X');
				axi1.arvalid <= '0';
				axi1.rready <= '1';
				wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.rvalid = '1';
				axi1.rready <= '0';
				-- decode content of PSEUDOTRNG_R_FIFO_COUNT register
				fifo_count := to_integer(unsigned(axo1.rdata));
				r_fifo_count <= fifo_count;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
				-- If value of 'fifo_count' shows an "almost full" state for the FIFO
				-- (this is not supposed to happen because we just received the "half
				-- empty" Irq) then don't try to write anything more to it.
				--
				-- Instead we reiterate the loop to poll again PSEUDOTRNG_R_FIFO_COUNT.
				--
				-- The "- 4" in "4096 - 4" on the line below means that we allow our-
				-- selves a little margin to allow the FIFO to update its word count
				-- in case there is some small latency to produce this signal (there
				-- must be).
				next when (fifo_count >= 4096 - 4);
				--
				-- Now perform as many "blind" writes into the FIFO (through
				-- the AXI interfacea) as the FIFO count is telling us we can
				-- (that is, without creating a write error).
				-- 
				for i in 1 to (4096 - fifo_count) loop
					wait until s_axi_aclk'event and s_axi_aclk = '1';
					-- write PSEUDOTRNG_W_WRITE_DATA register
					axi1.awaddr <= PSEUDOTRNG_W_WRITE_DATA & "000"; axi1.awvalid <= '1';
					wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.awready = '1';
					axi1.awaddr <= (others => 'X'); axi1.awvalid <= '0';
					-- Read a new line from input file, get a byte from it, and send it
					-- on the AXI write data channel
					readline(psfr, tline);
					read(tline, nb);
					assert nb < 256
						report "wrong random value from input file (line "
									 & integer'image(nbl) & ")"
							severity failure;
					dw := std_logic_vector(to_unsigned(nb, 32));
					axi1.wdata <= dw;
					axi1.wvalid <= '1';
					wait until s_axi_aclk'event and s_axi_aclk = '1' and axo1.wready = '1';
					axi1.wdata <= (others => 'X'); axi1.wvalid <= '0';
					wait until s_axi_aclk'event and s_axi_aclk = '1';
				end loop;
				wait until s_axi_aclk'event and s_axi_aclk = '1';
			end if; -- once_out_of_reset
		end loop;

	end process;

end architecture sim;
