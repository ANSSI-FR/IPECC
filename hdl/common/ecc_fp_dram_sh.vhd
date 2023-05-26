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

use work.ecc_customize.all; -- for rdlat
use work.ecc_utils.all;
use work.ecc_pkg.all;
--use work.ecc_trng_pkg.all;

entity ecc_fp_dram_sh is
	generic(
		rdlat : positive range 1 to 2);
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- port A: write-only interface from ecc_fp
		-- (actually for write-access from AXI-lite interface)
		ena : in std_logic;
		wea : in std_logic;
		addra : in std_logic_vector(FP_ADDR - 1 downto 0);
		dia : in std_logic_vector(ww - 1 downto 0);
		-- port B: read-only interface to ecc_fp
		reb : in std_logic;
		addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
		dob : out std_logic_vector(ww - 1 downto 0);
		-- interface with ecc_scalar
		permute : in std_logic;
		permuterdy : out std_logic;
		permuteundo : in std_logic;
		-- interface with ecc_trng
		trngvalid : in std_logic;
		trngrdy : out std_logic;
		trngdata : in std_logic_vector(FP_ADDR - 1 downto 0)
		-- pragma translate_off
		-- interface with ecc_fp (simu only)
		; fpdram : out fp_dram_type;
		fprwmask : out std_logic_vector(FP_ADDR - 1 downto 0)
		-- pragma translate_on
	);
end entity ecc_fp_dram_sh;

architecture syn of ecc_fp_dram_sh is

	component ecc_fp_dram is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			-- port A: write-only interface from ecc_fp
			-- (actually for write-access from AXI-lite interface)
			ena : in std_logic;
			wea : in std_logic;
			addra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(ww - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type
			-- pragma translate_on
		);
	end component ecc_fp_dram;

	type state_type is (idle, random0, random1, shuffling);

	type mux_type is (fp, perm, none);

	signal dob0, dob1 : std_logic_vector(ww - 1 downto 0);

	type raddrsh_type is array(integer range rdlat downto 0) of
		std_logic_vector(FP_ADDR - 1 downto 0);

	type perm_type is record
		--rmask : std_logic_vector(FP_ADDR - 1 downto 0); -- for R
		wmask : std_logic_vector(FP_ADDR - 1 downto 0); -- for W
		-- registered access of permutation logic to both e0 and e1
		we : std_logic;
		waddr : std_logic_vector(FP_ADDR - 1 downto 0);
		re : std_logic;
		raddr : std_logic_vector(FP_ADDR - 1 downto 0);
		rdata : std_logic_vector(ww - 1 downto 0);
		-- other control signals
		cnt : unsigned(FP_ADDR - 1 downto 0);
		cnten : std_logic;
		resh : std_logic_vector(rdlat downto 0);
		raddrsh : raddrsh_type;
		endsh : std_logic_vector(rdlat + 1 downto 0);
	end record;

	type reg_type is record
		flip, flop : std_logic;
		state : state_type;
		permuterdy : std_logic;
		fpmask : std_logic_vector(FP_ADDR - 1 downto 0); -- both for R/W
		w0mux, r0mux, w1mux, r1mux : mux_type;
		-- registered access to write interface of instance e0 of ecc_fp_dram
		addra0 : std_logic_vector(FP_ADDR - 1 downto 0);
		dia0 : std_logic_vector(ww - 1 downto 0);
		wea0 : std_logic;
		-- registered access to read interface of instance e0 of ecc_fp_dram
		addrb0 : std_logic_vector(FP_ADDR - 1 downto 0);
		reb0 : std_logic;
		-- registered access to write interface of instance e1 of ecc_fp_dram
		addra1 : std_logic_vector(FP_ADDR - 1 downto 0);
		dia1 : std_logic_vector(ww - 1 downto 0);
		wea1 : std_logic;
		-- registered access to read interface of instance e1 of ecc_fp_dram
		addrb1 : std_logic_vector(FP_ADDR - 1 downto 0);
		reb1 : std_logic;
		dob : std_logic_vector(ww - 1 downto 0);
		-- shuffling control logic
		perm : perm_type;
		-- trng
		trngrdy : std_logic;
	end record;

	signal r, rin : reg_type;

	-- pragma translate_off
	signal fpdram0, fpdram1 : fp_dram_type;
	-- pragma translate_on

begin

	-- instance of ecc_fp_dram actual data memory
	e0: ecc_fp_dram
		generic map(rdlat => rdlat)
		port map(
			clk => clk,
			-- port A (write-only)
			ena => r.wea0,
			wea => r.wea0,
			addra => r.addra0,
			dia => r.dia0,
			-- port B (read-only)
			reb => r.reb0,
			addrb => r.addrb0,
			dob => dob0
			-- pragma translate_off
			, fpdram => fpdram0
			-- pragma translate_on
		);

	-- instance of ecc_fp_dram actual data memory
	e1: ecc_fp_dram
		generic map(rdlat => rdlat)
		port map(
			clk => clk,
			-- port A (write-only)
			ena => r.wea1,
			wea => r.wea1,
			addra => r.addra1,
			dia => r.dia1,
			-- port B (read-only)
			reb => r.reb1,
			addrb => r.addrb1,
			dob => dob1
			-- pragma translate_off
			, fpdram => fpdram1
			-- pragma translate_on
		);

	comb: process(r, rstn, ena, wea, addra, dia, reb, addrb, permute, permuteundo,
	              dob0, dob1, trngvalid, trngdata, swrst)
		variable v : reg_type;
	begin
		v := r;

		-- some direct latches
		v.perm.resh := r.perm.re & r.perm.resh(rdlat downto 1);
		v.perm.raddrsh := r.perm.raddr & r.perm.raddrsh(rdlat downto 1);

		v.perm.waddr := r.perm.raddrsh(0) xor r.perm.wmask;
		v.perm.we := r.perm.resh(0);

		-- -----------------------------------------------------------------------
		--                    M U X   A C C E S S   T O   T W O
		--            I N S T A N C E S   o f   e c c _ f p _ d r a m
		-- -----------------------------------------------------------------------

		-- mux ctrl for W access to instance e0 of ecc_fp_dram
		case r.w0mux is
			when fp =>
				v.addra0 := addra xor r.fpmask;
				v.dia0 := dia;
				v.wea0 := wea;
			when perm =>
				v.addra0 := r.perm.waddr;
				v.dia0 := r.perm.rdata; -- permutation logic merely writes what was read
				v.wea0 := r.perm.we;
			when none =>
				v.wea0 := '0';
		end case;

		-- mux ctrl for R access to instance e0 of ecc_fp_dram
		case r.r0mux is
			when fp =>
				v.addrb0 := addrb xor r.fpmask;
				v.reb0 := reb;
				v.dob := dob0;
			when perm =>
				v.addrb0 := r.perm.raddr;
				v.reb0 := r.perm.re;
				v.perm.rdata := dob0;
				v.dob := (others => '1');
			when none =>
				v.reb0 := '0';
		end case;

		-- mux ctrl for W access to instance e1 of ecc_fp_dram
		case r.w1mux is
			when fp =>
				v.addra1 := addra xor r.fpmask;
				v.dia1 := dia;
				v.wea1 := wea;
			when perm =>
				v.addra1 := r.perm.waddr;
				v.dia1 := r.perm.rdata; -- permutation logic merely writes what was read
				v.wea1 := r.perm.we;
			when none =>
				v.wea1 := '0';
		end case;

		-- mux ctrl for R access to instance e1 of ecc_fp_dram
		case r.r1mux is
			when fp =>
				v.addrb1 := addrb xor r.fpmask;
				v.reb1 := reb;
				v.dob := dob1;
			when perm =>
				v.addrb1 := r.perm.raddr;
				v.reb1 := r.perm.re;
				v.perm.rdata := dob1;
				v.dob := (others => '1');
			when none =>
				v.reb1 := '0';
		end case;
		
		-- -----------------------------------------------------------------------
		--                   M A I N   C O N T R O L   L O G I C
		-- -----------------------------------------------------------------------

		-- start overall operation (& switch to random0 state)
		if permute = '1' and r.permuterdy = '1' and r.state = idle then
			v.permuterdy := '0'; -- see (s22) and (s23) in ecc_scalar.vhd
			v.state := random0;
			v.trngrdy := '1';
			if permuteundo = '0' then
				v.state := random0;
			elsif permuteundo = '1' then
				v.state := random1;
				v.perm.wmask := r.fpmask;
			end if;
		end if;

		-- random0 state (& switch to random1)
		if r.state = random0 then
			if r.trngrdy = '1' and trngvalid = '1' then
				v.perm.wmask := trngdata;
				v.state := random1;
				-- let r.trngrdy asserted for random1
			end if;
		end if;

		-- random1 state (& switch to shuffling)
		if r.state = random1 then
			if r.trngrdy = '1' and trngvalid = '1' then
				v.state := shuffling;
				v.perm.cnten := '1';
				v.trngrdy := '0';
				v.perm.cnt := to_unsigned((2**FP_ADDR) - 1, FP_ADDR);
				if r.flip = '0' then
					-- read from e0
					v.r0mux := perm;
					-- write into e1
					v.w1mux := perm;
					-- no read from e1, no write into e0
					v.r1mux := none;
					v.w0mux := none;
				elsif r.flip = '1' then
					-- read from e1
					v.r1mux := perm;
					-- write into e0
					v.w0mux := perm;
					-- no read from e0, no write into e1
					v.r0mux := none;
					v.w1mux := none;
				end if;
				v.perm.raddr := trngdata;
				v.perm.re := '1';
			end if;
		end if;

		if r.perm.cnten = '1' then
			v.perm.cnt := r.perm.cnt - 1;
			v.perm.raddr := std_logic_vector(unsigned(r.perm.raddr) + 1);
		end if;

		-- shuffling state
		v.perm.endsh := '0' & r.perm.endsh(rdlat + 1 downto 1);
		if r.state = shuffling then
			if r.perm.cnt(FP_ADDR - 1) = '0' and v.perm.cnt(FP_ADDR - 1) = '1'
			then
				v.perm.endsh(rdlat + 1) := '1';
				v.perm.cnten := '0';
			end if;
		end if;

		-- give last data time to go through the pipeline before switching
		-- multiplexors r.[rw][01]mux
		if r.perm.endsh(0) = '1' then
			-- shuffling is done
			v.state := idle;
			v.flip := not r.flip;
			v.flop := not r.flop;
			-- mux control
			if r.flip = '0' then
				-- ecc_fp will now have access to e1 both in R/W
				v.w1mux := fp;
				v.r1mux := fp;
				-- e0 becomes inaccessible
				v.w0mux := none;
				v.r0mux := none;
			elsif r.flip = '1' then
				-- ecc_fp will now have access to e0 both in R/W
				v.w0mux := fp;
				v.r0mux := fp;
				-- e1 becomes inaccessible
				v.w1mux := none;
				v.r1mux := none;
			end if;
			v.perm.we := '0';
			v.permuterdy := '1';
			v.fpmask := r.fpmask xor r.perm.wmask;
		end if;

		-- ------------------------------
		-- synchronous (active low) reset
		-- ------------------------------
		if rstn = '0' or swrst = '1' then
			v.flip := '0';
			v.flop := '1';
			v.state := idle;
			v.permuterdy := '1';
			v.w0mux := fp;
			v.r0mux := fp;
			v.w1mux := none;
			v.r1mux := none;
			v.wea0 := '0'; -- not taking any chance despite mux access
			v.wea1 := '0'; -- not taking any chance despite mux access
			v.perm.we := '0';
			v.perm.cnten := '0';
			v.fpmask := (others => '0');
			-- no need to reset r.perm.addrsh nor r.perm.resh
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
	dob <= r.dob;

	-- pragma translate_off
	fpdram <= fpdram0 when r.w0mux = fp
	          else fpdram1 when r.w1mux = fp
	          else (others => (others => 'X'));
	fprwmask <= r.fpmask;
	-- pragma translate_on

	trngrdy <= r.trngrdy;
	permuterdy <= r.permuterdy;

end architecture syn;
