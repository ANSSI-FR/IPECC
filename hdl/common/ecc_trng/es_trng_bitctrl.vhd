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

use work.ecc_customize.all; -- for 'simtrngfile'

entity es_trng_bitctrl is
	generic(index : natural);
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with es_trng_aggreg_all
		raw : out std_logic;
		valid : out std_logic;
		rdy : in std_logic;
		-- following signals are for debug & statistics
		dbgtrngta : in unsigned(19 downto 0);
		dbgtrngvonneuman : in std_logic;
		dbgtrngidletime : in unsigned(3 downto 0)
	);
end entity es_trng_bitctrl;

architecture rtl of es_trng_bitctrl is

	constant jittervalfile_i : string := simtrngfile & '.' & integer'image(index);

	component es_trng_bit is
		-- pragma translate_off
		generic(
			jittervalfile : string
		);
		-- pragma translate_on
		port(
			ro1en : in std_logic;
			ro2en : in std_logic;
			raw : out std_logic;
			valid : out std_logic
		);
	end component es_trng_bit;

	type state_type is (idle, ro1, ro1ro2, wait2bpulled);

	type debug_type is record
		idlecnt : unsigned(3 downto 0);
	end record;

	type reg_type is record
		state : state_type;
		ro1en : std_logic;
		ro2en : std_logic;
		tacnt : unsigned(19 downto 0);
		validin0, validin1, validin : std_logic;
		rawin0, rawin1, rawin : std_logic;
		von, vonbit : std_logic;
		valid : std_logic;
		debug : debug_type;
	end record;

	signal r, rin : reg_type;

	signal validin, rawin : std_logic;

begin

	-- ES_TRNG instanciation
	t0: es_trng_bit
		-- pragma translate_off
		generic map(
			jittervalfile => jittervalfile_i
		)
		-- pragma translate_on
		port map(
			ro1en => r.ro1en,
			ro2en => r.ro2en,
			raw => rawin,
			valid => validin
		);

	-- combinational logic
	comb: process(r, rstn, swrst, rawin, validin, rdy,
	              dbgtrngta, dbgtrngvonneuman, dbgtrngidletime)
		variable v : reg_type;
	begin
		v := r;

		-- resynchronization of 'valid' signal (comes from RO2 clock domain)
		v.validin0 := validin;
		v.validin1 := r.validin0;
		v.validin := r.validin1;
		v.rawin0 := rawin;
		v.rawin1 := r.rawin0;
		v.rawin := r.rawin1;

		-- main state machine
		if r.state = ro1 then
			-- 'ro1' denotes the state where only RO1 oscillator is free & running
			v.tacnt := r.tacnt - 1;
			if r.tacnt(19) = '0' and v.tacnt(19) = '1' then
				v.ro2en := '1';
				v.state := ro1ro2;
			end if;
		elsif r.state = ro1ro2 then
			-- 'ro1ro2' denotes the state where both RO1 & RO2 are free & running
			if r.validin = '1' then
				-- 1 raw random bit is available from ES-TRNG
				v.ro1en := '0';
				v.ro2en := '0';
				if (dbgtrngvonneuman = '1' and r.von = '0') then
					v.vonbit := r.rawin;
					v.von := '1';
					v.state := idle;
					v.debug.idlecnt := dbgtrngidletime;
				elsif (dbgtrngvonneuman = '0' or r.von = '1') then
					v.von := '0';
					if ( (dbgtrngvonneuman = '1') and ((r.vonbit xor r.rawin) = '1') )
						or (dbgtrngvonneuman = '0') 
					then
						-- do not wait for rdy to be asserted to drive valid, or it will
						-- lead to deadlock
						v.valid := '1';
						v.state := wait2bpulled;
					else
						-- being here means that Von Neuman debiasing is activated
						-- but the two consecutive bits were identical
						v.state := idle;
						v.debug.idlecnt := dbgtrngidletime;
					end if;
				else
					-- it is normally impossible to enter here (TODO: remove it)
					v.state := idle;
					v.debug.idlecnt := dbgtrngidletime;
				end if;
			end if;
		elsif r.state = wait2bpulled then
			if rdy = '1' then
				v.valid := '0';
				v.state := idle;
				v.debug.idlecnt := dbgtrngidletime;
			end if;
		elsif r.state = idle then
			-- in debug mode we stay in idle state a nb of clk cycles equal to
			-- dbgtrngidletime - 1 (otherwise we directly switch to ro1 state,
			-- idle state thus lasting only 1 cycle)
			v.debug.idlecnt := r.debug.idlecnt - 1;
			if (not debug) or r.debug.idlecnt = (r.debug.idlecnt'range => '0') then
				-- enforce transition to ro1 state upon exit of reset
				v.state := ro1;
				v.ro1en := '1';
				if debug then
					v.tacnt := dbgtrngta;
				else
					v.tacnt := to_unsigned(trngta, 20); -- trngta defined in ecc_customize
				end if;
			end if;
		end if;

		-- synchronous reset
		if rstn = '0' or swrst = '1' then
			v.state := idle;
			-- no need to reset r.debug.idlecnt other than in behav simulation
			-- pragma translate_off
			v.debug.idlecnt := (others => '0');
			-- pragma translate_on
			-- no need to reset r.byte
			v.ro1en := '0';
			v.ro2en := '0';
			-- no need to reset r.tacnt, r.rawin*, r.validin*
			v.valid := '0';
			v.von := '0';
		end if;

		rin <= v;
	end process comb;

	-- registers
	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			r  <= rin;
		end if;
	end process regs;

	-- drive outputs
	valid <= r.valid;
	raw <= r.rawin;

end architecture rtl;
