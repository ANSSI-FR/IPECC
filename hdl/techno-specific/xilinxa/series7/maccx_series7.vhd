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

library UNISIM;
use UNISIM.vcomponents.all;

use work.ecc_log.all; -- for ln2()
use work.ecc_pkg.all;
use work.mm_ndsp_pkg.all; -- for 'ndsp'

entity maccx is
	port(
		clk  : in std_logic;
		rst  : in std_logic;
		A    : in std_logic_vector(ww - 1 downto 0);
		B    : in std_logic_vector(ww - 1 downto 0);
		dspi : in maccx_array_in_type;
		P    : out std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0)
	);
end entity maccx;

architecture struct of maccx is

	component macc_series7 is
		generic(
			acc : positive;
			breg : positive range 1 to 2;
			ain : string := "DIRECT"; -- DIRECT: path A fed with A otherwise ACIN
			bin : string := "DIRECT" -- DIRECT: path B fed with B, otherwise BCIN
		); port (
			clk  : in std_logic;
			-- signals to/from general purpose logic fabric
			rst  : in std_logic;
			rstm : in std_logic;
			rstp : in std_logic;
			A    : in std_logic_vector(29 downto 0);
			B    : in std_logic_vector(17 downto 0);
			C    : in std_logic_vector(47 downto 0);
			P    : out std_logic_vector(47 downto 0);
			inmode : in std_logic_vector(4 downto 0);
			alumode :  in std_logic_vector(3 downto 0);
			opmode : in std_logic_vector(6 downto 0);
			-- signals to/from adjacent DSP block
			ACIN : in std_logic_vector(29 downto 0);
			BCIN : in std_logic_vector(17 downto 0);
			PCIN : in std_logic_vector(47 downto 0);
			ACOUT : out std_logic_vector(29 downto 0);
			BCOUT : out std_logic_vector(17 downto 0);
			PCOUT : out std_logic_vector(47 downto 0);
			-- CE of DSP registers
			CEINMODE : in std_logic;
			CEA1 : in std_logic;
			CEALUMODE : in std_logic;
			CEB1 : std_logic;
			CEB2 : std_logic;
			CEC : std_logic;
			CEP : std_logic;
			CECTRL : std_logic
		);
	end component macc_series7;

	signal vcc, gnd : std_logic;
	signal gndxa : std_logic_vector(29 downto 0);
	signal gndxb : std_logic_vector(17 downto 0);
	signal gndxc : std_logic_vector(47 downto 0);

	constant CST_X7_INMODE_0 : std_logic_vector(4 downto 0) := "10001"; -- B1/A1
	constant CST_X7_INMODE_i : std_logic_vector(4 downto 0) := "00000"; -- B2/A2
	constant CST_X7_ALUMODE : std_logic_vector(3 downto 0) := "0000";
	-- cosntant CST_X7_OPMODE_0 matches operation "P <- A * B"
	constant CST_X7_OPMODE_0 : std_logic_vector(6 downto 0) := "0000101";
	-- cosntant CST_X7_OPMODE_i matches operation "P <- A * B + PCIN"
	constant CST_X7_OPMODE_i : std_logic_vector(6 downto 0) := "0010101";

	subtype std_logic_ww is std_logic_vector(ww - 1 downto 0);
	subtype std_logic_30 is std_logic_vector(29 downto 0);
	subtype std_logic_18 is std_logic_vector(17 downto 0);
	--subtype std_logic_wwa is std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);
	subtype std_logic_48 is std_logic_vector(47 downto 0);

	type dspac_array_type is array(0 to ndsp - 1) of std_logic_30;
	type dspbc_array_type is array(0 to ndsp - 1) of std_logic_18;
	type dsppc_array_type is array(0 to ndsp - 1) of std_logic_48;

	signal dsp_ac : dspac_array_type;
	signal dsp_bc : dspbc_array_type;
	signal dsp_pc : dsppc_array_type;
	signal dsp_pp : dsppc_array_type;

	signal dspi_0_pcin : std_logic_48; --std_logic_vector(2*ww + ln2(ndsp) - 1 downto 0);

	signal A_s : std_logic_vector(29 downto 0);
	signal B_s : std_logic_vector(17 downto 0);

	signal r_dsp_rst : std_logic_vector(ndsp - 1 downto 0);

	attribute DONT_TOUCH : string;
	attribute DONT_TOUCH of r_dsp_rst : signal is "TRUE";

begin

	vcc <= '1';
	gnd <= '0';
	gndxa <= (others => '0');
	gndxb <= (others => '0');
	gndxc <= (others => '0');
	dspi_0_pcin <= (others => '0');
	dsp_pp(0) <= (others => '0');

	A_s <= std_logic_vector(to_unsigned(0, 30 - ww)) & A;
	B_s <= std_logic_vector(to_unsigned(0, 18 - ww)) & B;

	-- the first DSP block calls for a specific configuration
	-- (has only one register on the multiplier's B input operand path,
	-- instead of 2 for the others)
	d0: macc_series7
		generic map(
			acc => 2*ww + ln2(ndsp), -- (s0), see (s101) in mm_ndsp.vhd
			breg => 1,
			ain => "DIRECT",
			bin => "DIRECT")
		port map(
			clk => clk,
			rst => r_dsp_rst(0),
			rstm => dspi(0).rstm,
			rstp => dspi(0).rstp,
			A => A_s,
			B => B_s,
			C => gndxc,
			P => dsp_pp(0), -- => could stay 'open'
			inmode => CST_X7_INMODE_0, -- A_MULT <= A1, B_MULT <= B1
			alumode => CST_X7_ALUMODE,
			opmode => CST_X7_OPMODE_0,
			acin => gndxa,
			bcin => gndxb,
			acout => dsp_ac(0),
			bcout => dsp_bc(0),
			pcin => dspi_0_pcin,
			pcout => dsp_pc(0),
			-- CE of DSP registers
			CEINMODE => vcc,
			CEA1 => dspi(0).ace,
			CEALUMODE => vcc,
			CEB1 => dspi(0).bce,
			CEB2 => dspi(0).bce,
			CEC => gnd,
			CEP => dspi(0).pce,
			CECTRL => vcc
		);

	-- remaining DSP block instances
	d1: for i in 1 to ndsp - 1 generate
		d0: macc_series7
			generic map(
				acc => 2*ww + ln2(ndsp), -- (s0), see (s101) in mm_ndsp.vhd
				breg => 2,
				ain => "CASCADE",
				bin => "CASCADE")
			port map(
				clk => clk,
				rst => r_dsp_rst(i),
				rstm => dspi(i).rstm,
				rstp => dspi(i).rstp,
				A => gndxa,
				B => gndxb,
				C => gndxc,
				-- among all DSP block instances, the only one with an actually
				-- connected P port is the last lone (i = ndsp - 1)
				-- All other instances use PCIN/PCOUT ports
				P => dsp_pp(i),
				inmode => CST_X7_INMODE_i, -- A_MULT <= A2, B_MULT <= B2
				alumode => CST_X7_ALUMODE,
				opmode => CST_X7_OPMODE_i,
				acin => dsp_ac(i - 1),
				bcin => dsp_bc(i - 1),
				acout => dsp_ac(i),
				bcout => dsp_bc(i),
				pcin => dsp_pc(i - 1),
				pcout => dsp_pc(i),
				-- CE of DSP registers
				CEINMODE => vcc,
				CEA1 => dspi(i).ace,
				CEALUMODE => vcc,
				CEB1 => dspi(i).bce,
				CEB2 => dspi(i).bce,
				CEC => gnd,
				CEP => dspi(i).pce,
				CECTRL => vcc
			);
	end generate;

	-- explicitly duplicating the reset signals : one per DSP block
	r0: for i in 0 to ndsp - 1 generate
		rp0: process(clk)
		begin
			if clk'event and clk = '1' then
				r_dsp_rst(i) <= rst;
			end if;
		end process;
	end generate;

	-- output of complete DSP chain
	P <= dsp_pp(ndsp - 1)(2*ww + ln2(ndsp) - 1 downto 0);

end architecture struct;
