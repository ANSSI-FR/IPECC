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

use work.ecc_pkg.all; -- for std_logic2 & hex_write()
use work.ecc_customize.all; -- for nbtrng
use work.ecc_utils.all; -- for log2() & ge_pow_of_2()
use work.ecc_trng_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity ecc_trng_srv is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with ecc_scalar
		irn_reset : in std_logic;
		-- interface with ecc_trng_pp
		data_s : in std_logic_vector(pp_irn_width - 1 downto 0);
		valid_s : in std_logic;
		rdy_s : out std_logic;
		-- interface with entropy client ecc_axi
		rdy0 : in std_logic;
		valid0 : out std_logic;
		data0 : out std_logic_vector(ww - 1 downto 0);
		irncount0 : out std_logic_vector(log2(irn_fifo_size_axi) - 1 downto 0);
		-- interface with entropy client ecc_fp
		rdy1 : in std_logic;
		valid1 : out std_logic;
		data1 : out std_logic_vector(ww - 1 downto 0);
		irncount1 : out std_logic_vector(log2(irn_fifo_size_fp) - 1 downto 0);
		-- interface with entropy client ecc_curve
		rdy2 : in std_logic;
		valid2 : out std_logic;
		data2 : out std_logic_vector(1 downto 0);
		irncount2 : out std_logic_vector(log2(irn_fifo_size_curve) - 1 downto 0);
		-- interface with entropy client ecc_fp_dram_sh
		rdy3 : in std_logic;
		valid3 : out std_logic;
		data3 : out std_logic_vector(irn_width_sh - 1 downto 0);
		irncount3 : out std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
		-- interface with ecc_axi (only usable in debug mode)
		dbgtrngcompletebypassbit : in std_logic;
		dbgtrngcompletebypass : in std_logic
	);
end entity ecc_trng_srv;

architecture struct of ecc_trng_srv is

	type set_reg_type is record
		can_be_filled : std_logic;
		we : std_logic;
		re : std_logic;
		re0, re1 : std_logic;
		valid : std_logic;
		rdy : std_logic;
	end record;

	type set_reg_type_array is array(0 to 3) of set_reg_type;

	type reg_type is record
		ppdatain : std_logic_vector(pp_irn_width - 1 downto 0);
		ppdatain_can_be_emptied : std_logic;
		ppdatain_cnt : unsigned(log2(pp_irn_width - 1) - 1 downto 0);
		ppdatain0 : std_logic_vector(ww - 1 downto 0);
		ppdatain0_cnt : unsigned(log2(ww - 1) - 1 downto 0);
		ppdatain1 : std_logic_vector(ww - 1 downto 0);
		ppdatain1_cnt : unsigned(log2(ww - 1) - 1 downto 0);
		ppdatain2 : std_logic_vector(1 downto 0);
		ppdatain2_cnt : unsigned(log2(2 - 1) - 1 downto 0); -- 0 downto 0 so what?
		ppdatain3 : std_logic_vector(irn_width_sh - 1 downto 0);
		ppdatain3_cnt : unsigned(log2(irn_width_sh - 1) - 1 downto 0);
		irn : set_reg_type_array;
		rdy_s : std_logic;
		priority : natural range 0 to 3;
		valid : std_logic_vector(0 to 3);
		data0 : std_logic_vector(ww - 1 downto 0);
		data1 : std_logic_vector(ww - 1 downto 0);
		data2 : std_logic_vector(1 downto 0);
		data3 : std_logic_vector(irn_width_sh - 1 downto 0);
		-- pragma translate_off
		selected : natural range 0 to 3;
		one_selected : boolean;
		-- pragma translate_on
	end record;

	signal ppdataout0 : std_logic_vector(ww - 1 downto 0);
	signal ppdataout1 : std_logic_vector(ww - 1 downto 0);
	signal ppdataout2 : std_logic_vector(1 downto 0);
	signal ppdataout3 : std_logic_vector(irn_width_sh - 1 downto 0);
	signal empty, full : std_logic_vector(3 downto 0);
	signal count0 : std_logic_vector(log2(irn_fifo_size_axi) - 1 downto 0);
	signal count1 : std_logic_vector(log2(irn_fifo_size_fp) - 1 downto 0);
	signal count2 : std_logic_vector(log2(irn_fifo_size_curve) - 1 downto 0);
	signal count3 : std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
	signal gnd : std_logic;
	signal gndd0 : std_logic_vector(log2(irn_fifo_size_axi - 1) - 1 downto 0);
	signal gndd1 : std_logic_vector(log2(irn_fifo_size_fp - 1) - 1 downto 0);
	signal gndd2 : std_logic_vector(log2(irn_fifo_size_curve - 1) - 1 downto 0);
	signal gndd3 : std_logic_vector(log2(irn_fifo_size_sh - 1) - 1 downto 0);

	signal r, rin : reg_type;

	-- pragma translate_off
	signal r_irncnt0 : natural := 0;
	signal r_irncnt1 : natural := 0;
	signal r_irncnt2 : natural := 0;
	signal r_irncnt3 : natural := 0;
	-- pragma translate_on

	signal rdy : std_logic_vector(0 to 3);

begin

	gnd <= '0';
	gndd0 <= (others => '0');
	gndd1 <= (others => '0');
	gndd2 <= (others => '0');
	gndd3 <= (others => '0');

	rdy <= rdy0 & rdy1 & rdy2 & rdy3;

	-- IRN fifo for ecc_axi random data
	f0: fifo
		generic map(datawidth => ww, datadepth => irn_fifo_size_axi)
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			datain => r.ppdatain0,
			we => r.irn(0).we,
			werr => open,
			full => full(0),
			dataout => ppdataout0,
			re => r.irn(0).re,
			empty => empty(0),
			rerr => open,
			count => count0,
			-- debug feature (not used here)
			dbgdeact => gnd,
			dbgwaddr => open,
			dbgraddr => gndd0,
			dbgrst => gnd
		);

	-- IRN fifo for ecc_fp random data
	f1: fifo
		generic map(datawidth => ww, datadepth => irn_fifo_size_fp)
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			datain => r.ppdatain1,
			we => r.irn(1).we,
			werr => open,
			full => full(1),
			dataout => ppdataout1,
			re => r.irn(1).re,
			empty => empty(1),
			rerr => open,
			count => count1,
			-- debug feature (not used here)
			dbgdeact => gnd,
			dbgwaddr => open,
			dbgraddr => gndd1,
			dbgrst => gnd
		);

	-- IRN fifo for ecc_curve random data
	f2: fifo
		generic map(datawidth => 2, datadepth => irn_fifo_size_curve)
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			datain => r.ppdatain2,
			we => r.irn(2).we,
			werr => open,
			full => full(2),
			dataout => ppdataout2,
			re => r.irn(2).re,
			empty => empty(2),
			rerr => open,
			count => count2,
			-- debug feature (not used here)
			dbgdeact => gnd,
			dbgwaddr => open,
			dbgraddr => gndd2,
			dbgrst => gnd
		);

	-- IRN fifo for ecc_fp_dram_sh random data
	f3: fifo
		generic map(
			datawidth => irn_width_sh,
			datadepth => irn_fifo_size_sh)
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			datain => r.ppdatain3,
			we => r.irn(3).we,
			werr => open,
			full => full(3),
			dataout => ppdataout3,
			re => r.irn(3).re,
			empty => empty(3),
			rerr => open,
			count => count3,
			-- debug feature (not used here)
			dbgdeact => gnd,
			dbgwaddr => open,
			dbgraddr => gndd3,
			dbgrst => gnd
		);

	comb: process(r, rstn, irn_reset, data_s, valid_s, rdy, swrst,
		            --rdy0, rdy1, rdy2, rdy3, dbgtrngcompletebypass,
	              full, empty, ppdataout0, ppdataout1,
		            ppdataout2, ppdataout3, count0, count1, count2, count3)
		variable v : reg_type;
		variable v_selected : natural range 0 to 3;
		variable v_one_selected : boolean;
	begin
		v := r;

		-- -----------------------------------------------------------------
		-- get one word of size 'pp_irn_width' from the post-processing unit
		-- -----------------------------------------------------------------

		if valid_s = '1' and r.rdy_s = '1' then
			v.ppdatain := data_s;
			v.ppdatain_can_be_emptied := '1';
			v.ppdatain_cnt := to_unsigned(pp_irn_width - 1, log2(pp_irn_width - 1));
			v.rdy_s := '0'; -- (s1) will be reasserted by (s2)
		end if;

		-- distribute this word into the different IRN r.ppdatain[0-3]
		-- one bit at a time, in a fair round-robin schedule, and, of course,
		-- according to the availability of each

		-- (s3) - select the one out of 4 targets to which a random bit
		--        can be pushed to
		v_one_selected := FALSE;
		v_selected := 0;
		if r.priority = 0 then
			if r.irn(0).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 0;
			elsif r.irn(1).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 1;
			elsif r.irn(2).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 2;
			elsif r.irn(3).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 3;
			end if;
		elsif r.priority = 1 then
			if r.irn(1).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 1;
			elsif r.irn(0).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 0;
			elsif r.irn(2).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 2;
			elsif r.irn(3).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 3;
			end if;
		elsif r.priority = 2 then
			if r.irn(2).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 2;
			elsif r.irn(0).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 0;
			elsif r.irn(1).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 1;
			elsif r.irn(3).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 3;
			end if;
		elsif shuffle and r.priority = 3 then
			if r.irn(3).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 3;
			elsif r.irn(0).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 0;
			elsif r.irn(1).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 1;
			elsif r.irn(2).can_be_filled = '1' then
				v_one_selected := TRUE;
				v_selected := 2;
			end if;
		end if;

		-- pragma translate_off
		v.selected := v_selected;
		v.one_selected := v_one_selected;
		-- pragma translate_on

		if r.ppdatain_can_be_emptied = '1' and v_one_selected then -- (s0)
			-- -----------------------------------
			-- shift-empty one bit from r.ppdatain
			-- -----------------------------------
			v.ppdatain(pp_irn_width - 2 downto 0) :=
				r.ppdatain(pp_irn_width - 1 downto 1);
			-- decrement source counter r.ppdatain_cnt
			v.ppdatain_cnt := r.ppdatain_cnt - 1;
			-- detect and handle underflow of source counter r.ppdatain_cnt
			if r.ppdatain_cnt = (r.ppdatain_cnt'range => '0') then
				v.ppdatain_can_be_emptied := '0'; -- to inhibit (s0)
				-- reset counter
				v.ppdatain_cnt := to_unsigned(pp_irn_width - 1, log2(pp_irn_width - 1));
				-- inform the handshake logic with ecc_trng_pp that we can accept
				-- again an IRN of pp_irn_width size
				v.rdy_s := '1'; -- (s2) reassertion of (s1)
			end if;
			-- -------------------------------------------
			-- shift-fill one bit into the selected target
			-- -------------------------------------------
			if v_selected = 0 then
				v.ppdatain0(ww - 1 downto 0) :=
					r.ppdatain(0) & r.ppdatain0(ww - 1 downto 1);
				-- decrement counter for target 0
				v.ppdatain0_cnt := r.ppdatain0_cnt - 1;
				-- detect and handle underflow of counter for target 0
				if r.ppdatain0_cnt = (r.ppdatain0_cnt'range => '0') then
					-- reset the counter for target 0
					v.ppdatain0_cnt := to_unsigned(ww - 1, log2(ww - 1));
					-- set register r.ppdatain0 as valid to enter the FIFO #0
					v.irn(0).valid := '1';
					v.irn(0).can_be_filled := '0'; -- to inhibit target 0 in (s3)
				end if;
				v.priority := 1;
			elsif v_selected = 1 then
				v.ppdatain1(ww - 1 downto 0) :=
					r.ppdatain(0) & r.ppdatain1(ww - 1 downto 1);
				-- decrement counter for target 1
				v.ppdatain1_cnt := r.ppdatain1_cnt - 1;
				-- detect and handle underflow of counter for target 1
				if r.ppdatain1_cnt = (r.ppdatain1_cnt'range => '0') then
					-- reset the counter for target 1
					v.ppdatain1_cnt := to_unsigned(ww - 1, log2(ww - 1));
					-- set register r.ppdatain1 as valid to enter the FIFO #1
					v.irn(1).valid := '1';
					v.irn(1).can_be_filled := '0'; -- to inhibit target 1 in (s3)
				end if;
				v.priority := 2;
			elsif v_selected = 2 then
				v.ppdatain2(1 downto 0) :=
					r.ppdatain(0) & r.ppdatain2(1 downto 1);
				-- decrement counter for target 2
				v.ppdatain2_cnt := r.ppdatain2_cnt - 1;
				-- detect and handle underflow of counter for target 2
				if r.ppdatain2_cnt = (r.ppdatain2_cnt'range => '0') then
					-- reset the counter for target 2
					v.ppdatain2_cnt := to_unsigned(1, log2(1));
					-- set register r.ppdatain2 as valid to enter the FIFO #2
					v.irn(2).valid := '1';
					v.irn(2).can_be_filled := '0'; -- to inhibit target 2 in (s3)
				end if;
				if shuffle then
					v.priority := 3;
				else
					v.priority := 0;
				end if;
			elsif v_selected = 3 then
				v.ppdatain3(irn_width_sh - 1 downto 0) :=
					r.ppdatain(0) & r.ppdatain3(irn_width_sh - 1 downto 1);
				-- decrement counter for target 3
				v.ppdatain3_cnt := r.ppdatain3_cnt - 1;
				-- detect and handle underflow of counter for target 3
				if r.ppdatain3_cnt = (r.ppdatain3_cnt'range => '0') then
					-- reset the counter for target 3
					v.ppdatain3_cnt := to_unsigned(
						irn_width_sh - 1, log2(irn_width_sh - 1));
					-- set register r.ppdatain3 as valid to enter the FIFO #3
					v.irn(3).valid := '1';
					v.irn(3).can_be_filled := '0'; -- to inhibit target 3 in (s3)
				end if;
				v.priority := 0;
			end if;
		end if;

		-- ------------------------------------------------------------
		--                         F I F O S
		-- ------------------------------------------------------------

		-- --------------------------
		-- WRITE-into-the-FIFOs logic
		-- --------------------------
		-- continuously fill the FIFO with random words as long as it does
		-- not show a FULL state
		for i in 0 to 3 loop
			v.irn(i).we := '0';
		end loop;
		if r.irn(0).valid = '1' and r.irn(0).rdy = '1' and full(0) = '0' then
			if not (r.irn(0).we = '1' and count0 = std_logic_vector(to_unsigned(
				irn_fifo_size_axi - 1, log2(irn_fifo_size_axi))))
			then
				v.irn(0).we := '1';
				v.irn(0).valid := '0';
			end if;
		end if;
		if r.irn(1).valid = '1' and r.irn(1).rdy = '1' and full(1) = '0' then
			if not (r.irn(1).we = '1' and count1 = std_logic_vector(to_unsigned(
				irn_fifo_size_fp - 1, log2(irn_fifo_size_fp))))
			then
				v.irn(1).we := '1';
				v.irn(1).valid := '0';
			end if;
		end if;
		if r.irn(2).valid = '1' and r.irn(2).rdy = '1' and full(2) = '0' then
			if not (r.irn(2).we = '1' and count2 = std_logic_vector(to_unsigned(
				irn_fifo_size_curve - 1, log2(irn_fifo_size_curve))))
			then
				v.irn(2).we := '1';
				v.irn(2).valid := '0';
			end if;
		end if;
		if r.irn(3).valid = '1' and r.irn(3).rdy = '1' and full(3) = '0' then
			if not (r.irn(3).we = '1' and count3 = std_logic_vector(to_unsigned(
				irn_fifo_size_curve - 1, log2(irn_fifo_size_sh))))
			then
				v.irn(3).we := '1';
				v.irn(3).valid := '0';
			end if;
		end if;
		for i in 0 to 3 loop
			if r.irn(i).we = '1' then
				v.irn(i).can_be_filled := '1'; -- to reauthorize target #i in (s3)
			end if;
		end loop;

		-- deassertion of r.irn(0).rdy
		if r.irn(0).we = '1' and count0 = std_logic_vector(
			to_unsigned(irn_fifo_size_axi - 2, log2(irn_fifo_size_axi)))
		then
			v.irn(0).rdy := '0';
		elsif full(0) = '0' then
			v.irn(0).rdy := '1';
		end if;
		-- deassertion of r.irn(1).rdy
		if r.irn(1).we = '1' and count1 = std_logic_vector(
			to_unsigned(irn_fifo_size_fp - 2, log2(irn_fifo_size_fp)))
		then
			v.irn(1).rdy := '0';
		elsif full(1) = '0' then
			v.irn(1).rdy := '1';
		end if;
		-- deassertion of r.irn(2).rdy
		if r.irn(2).we = '1' and count2 = std_logic_vector(
			to_unsigned(irn_fifo_size_curve - 2, log2(irn_fifo_size_curve)))
		then
			v.irn(2).rdy := '0';
		elsif full(2) = '0' then
			v.irn(2).rdy := '1';
		end if;
		-- deassertion of r.irn(3).rdy
		if r.irn(3).we = '1' and count3 = std_logic_vector(
			to_unsigned(irn_fifo_size_sh - 2, log2(irn_fifo_size_sh)))
		then
			v.irn(3).rdy := '0';
		elsif full(3) = '0' then
			v.irn(3).rdy := '1';
		end if;
		---- reassertion of r.irn(0).rdy
		--if full(0) = '0' then v.irn(0).rdy := '1'; end if;
		---- reassertion of r.irn(1).rdy
		--if full(1) = '0' then v.irn(1).rdy := '1'; end if;
		---- reassertion of r.irn(2).rdy
		--if full(2) = '0' then v.irn(2).rdy := '1'; end if;
		---- reassertion of r.irn(3).rdy
		--if full(3) = '0' then v.irn(3).rdy := '1'; end if;

		-- -------------------------
		-- READ-from-the-FIFOs logic
		-- -------------------------
		-- continuously empty the bits from the FIFO as long as it does not
		-- show an EMPTY state OR it contains only 1 word (count = 1) and we're
		-- currently reading it
		for i in 0 to 3 loop
			v.irn(i).re := '0';
			if empty(i) = '0' and r.irn(i).re = '0' and r.irn(i).re0 = '0'
				and r.irn(i).re1 = '0' and
				(r.valid(i) = '0' or (r.valid(i) = '1' and rdy(i) = '1'))
			then
				v.irn(i).re := '1';
			end if;
		end loop;
		-- specific to target 0
		if r.irn(0).re = '1' and
			unsigned(count0) = to_unsigned(1, log2(irn_fifo_size_axi))
		then
			v.irn(0).re := '0';
		end if;
		-- specific to target 1
		if r.irn(1).re = '1' and
			unsigned(count1) = to_unsigned(1, log2(irn_fifo_size_fp))
		then
			v.irn(1).re := '0';
		end if;
		-- specific to target 2
		if r.irn(2).re = '1' and
			unsigned(count2) = to_unsigned(1, log2(irn_fifo_size_curve))
		then
			v.irn(2).re := '0';
		end if;
		-- specific to target 3
		if r.irn(3).re = '1' and
			unsigned(count3) = to_unsigned(1, log2(irn_fifo_size_sh))
		then
			v.irn(3).re := '0';
		end if;
		-- propagate the .re signals
		for i in 0 to 3 loop
			v.irn(i).re0 := r.irn(i).re;
			v.irn(i).re1 := r.irn(i).re0;
		end loop;
		-- specific to target 0
		if r.irn(0).re1 = '1' then
			v.data0 := ppdataout0;
			v.valid(0) := '1';
		end if;
		-- specific to target 1
		if r.irn(1).re1 = '1' then
			v.data1 := ppdataout1;
			v.valid(1) := '1';
		end if;
		-- specific to target 2
		if r.irn(2).re1 = '1' then
			v.data2 := ppdataout2;
			v.valid(2) := '1';
		end if;
		-- specific to target 3
		if r.irn(3).re1 = '1' then
			v.data3 := ppdataout3;
			v.valid(3) := '1';
		end if;
		for i in 0 to 3 loop
			-- handshake with client #i
			if r.valid(i) = '1' and rdy(i) = '1' then
				v.valid(i) := '0';
			end if;
		end loop;
	
		-- synchronous reset
		if rstn = '0' or irn_reset = '1' or swrst = '1' then
			v.ppdatain_can_be_emptied := '0';
			v.priority := 0;
			v.valid(0) := '0'; -- on reset, nothing to serve to client 0
			v.valid(1) := '0'; -- on reset, nothing to serve to client 1
			v.valid(2) := '0'; -- on reset, nothing to serve to client 2
			v.valid(3) := '0'; -- on reset, nothing to serve to client 3
			for i in 0 to 3 loop
				v.irn(i).we := '0';
				v.irn(i).re := '0';
				v.irn(i).re0 := '0';
				v.irn(i).re1 := '0';
			end loop;
			v.ppdatain0_cnt := to_unsigned(ww - 1, log2(ww - 1));
			v.ppdatain1_cnt := to_unsigned(ww - 1, log2(ww - 1));
			v.ppdatain2_cnt := to_unsigned(1, log2(1));
			v.ppdatain3_cnt :=
				to_unsigned(irn_width_sh - 1, log2(irn_width_sh - 1));
			for i in 0 to 3 loop
				v.irn(i).can_be_filled := '1';
				v.irn(i).valid := '0';
			end loop;
			v.rdy_s := '1'; -- on reset, ready to recv data from ecc_trng_pp
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
	--   client 0
	valid0 <= r.valid(0) when ((not debug) or dbgtrngcompletebypass = '0')
						else '1';
	-- if complete bypass of TRNG wasn't a debug feature, we could set
	-- a multi-cycle constraint on path: dbgtrngcompletebypass -> data[0-3]
	data0 <= r.data0 when ((not debug) or dbgtrngcompletebypass = '0')
	         else (data0'range => dbgtrngcompletebypassbit);
	irncount0 <= count0;
	--   client 1
	valid1 <= r.valid(1) when ((not debug) or dbgtrngcompletebypass = '0')
						else '1';
	data1 <= r.data1 when ((not debug) or dbgtrngcompletebypass = '0')
	         else (data1'range => dbgtrngcompletebypassbit);
	irncount1 <= count1;
	--   client 2
	valid2 <= r.valid(2) when ((not debug) or dbgtrngcompletebypass = '0')
						else '1';
	data2 <= r.data2 when ((not debug) or dbgtrngcompletebypass = '0')
	         else (data2'range => dbgtrngcompletebypassbit);
	irncount2 <= count2;
	--   client 3
	valid3 <= r.valid(3) when ((not debug) or dbgtrngcompletebypass = '0')
						else '1';
	data3 <= r.data3 when ((not debug) or dbgtrngcompletebypass = '0')
	         else (data3'range => dbgtrngcompletebypassbit);
	irncount3 <= count3;
	--   handshake with ecc_trng_pp
	rdy_s <= r.rdy_s;

end architecture struct;
