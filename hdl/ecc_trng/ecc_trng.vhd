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

use work.ecc_custom.all; -- for simnotrng
use work.ecc_utils.all;
use work.ecc_pkg.all;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity ecc_trng is
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- interface with ecc_scalar
		irn_reset : in std_logic;
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
		data3 : out std_logic_vector(FP_ADDR - 1 downto 0);
		irncount3 : out std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
		-- interface with ecc_axi (only usable in debug mode)
		dbgtrngta : in unsigned(19 downto 0);
		dbgtrngrawreset : in std_logic;
		dbgtrngrawfull : out std_logic;
		dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
		dbgtrngrawdata : out std_logic;
		dbgtrngppdeact : in std_logic;
		dbgtrngcompletebypass : in std_logic;
		dbgtrngrawduration : out unsigned(31 downto 0);
		dbgtrngvonneuman : in std_logic;
		dbgtrngidletime : in unsigned(3 downto 0)
	);
end entity ecc_trng;

architecture rtl of ecc_trng is

	component es_trng is
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- interface with ecc_trng_pp
			data_t : out std_logic_vector(7 downto 0);
			valid_t : out std_logic;
			rdy_t : in std_logic;
			-- following signals are for debug & statistics
			dbgtrngta : in unsigned(19 downto 0);
			dbgtrngrawreset : in std_logic;
			dbgtrngrawfull : out std_logic;
			dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawdata : out std_logic;
			dbgtrngppdeact : in std_logic;
			dbgtrngrawduration : out unsigned(31 downto 0);
			dbgtrngvonneuman : in std_logic;
			dbgtrngidletime : in unsigned(3 downto 0)
		);
	end component es_trng;

	-- pragma translate_off
	component es_trng_stub is
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- interface with ecc_trng_pp
			data_t : out std_logic_vector(7 downto 0);
			valid_t : out std_logic;
			rdy_t : in std_logic;
			-- following signals are for debug & statistics
			dbgtrngta : in unsigned(19 downto 0);
			dbgtrngrawreset : in std_logic;
			dbgtrngrawfull : out std_logic;
			dbgtrngrawwaddr : out std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawraddr : in std_logic_vector(log2(raw_ram_size-1) - 1 downto 0);
			dbgtrngrawdata : out std_logic;
			dbgtrngppdeact : in std_logic;
			dbgtrngrawduration : out unsigned(31 downto 0);
			dbgtrngvonneuman : in std_logic;
			dbgtrngidletime : in unsigned(3 downto 0)
		);
	end component es_trng_stub;
	-- pragma translate_on

	component ecc_trng_pp is
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			-- interface with es_trng
			data_t : in std_logic_vector(7 downto 0);
			valid_t : in std_logic;
			rdy_t : out std_logic;
			-- interface with ecc_trng_srv
			data_s : out std_logic_vector(pp_irn_width - 1 downto 0);
			valid_s : out std_logic;
			rdy_s : in std_logic
		);
	end component ecc_trng_pp;

	component ecc_trng_srv is
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
			data3 : out std_logic_vector(FP_ADDR - 1 downto 0);
			irncount3 : out std_logic_vector(log2(irn_fifo_size_sh) - 1 downto 0);
			-- interface with ecc_axi (only usable in debug mode)
			dbgtrngcompletebypass : in std_logic
		);
	end component ecc_trng_srv;

	-- signals between es_trng & ecc_trng_pp
	signal data_t : std_logic_vector(7 downto 0);
	signal valid_t : std_logic;
	signal rdy_t : std_logic;
	-- signals between ecc_trng_pp & ecc_trng_srv
	signal data_s : std_logic_vector(31 downto 0);
	signal valid_s : std_logic;
	signal rdy_s : std_logic;

begin

	t0: if simnotrng = FALSE generate
		-- ES-TRNG: real physical entropy source based on Xilinx LUTs & DFFs
		t0: es_trng
			port map(
				clk => clk,
				rstn => rstn,
				swrst => swrst,
				data_t => data_t,
				valid_t => valid_t,
				rdy_t => rdy_t,
				dbgtrngta => dbgtrngta,
				dbgtrngrawreset => dbgtrngrawreset,
				dbgtrngrawfull => dbgtrngrawfull,
				dbgtrngrawwaddr => dbgtrngrawwaddr,
				dbgtrngrawraddr => dbgtrngrawraddr,
				dbgtrngrawdata => dbgtrngrawdata,
				dbgtrngppdeact => dbgtrngppdeact,
				dbgtrngrawduration => dbgtrngrawduration,
				dbgtrngvonneuman => dbgtrngvonneuman,
				dbgtrngidletime => dbgtrngidletime
			);
	end generate;

	-- pragma translate_off
	t1: if simnotrng = TRUE generate
		-- es_trng_stub reads randomness from local file
		-- and provide them to ecc_trng_pp
		t0: es_trng_stub
			port map(
				clk => clk,
				rstn => rstn,
				swrst => swrst,
				data_t => data_t,
				valid_t => valid_t,
				rdy_t => rdy_t,
				dbgtrngta => dbgtrngta,
				dbgtrngrawreset => dbgtrngrawreset,
				dbgtrngrawfull => dbgtrngrawfull,
				dbgtrngrawwaddr => dbgtrngrawwaddr,
				dbgtrngrawraddr => dbgtrngrawraddr,
				dbgtrngrawdata => dbgtrngrawdata,
				dbgtrngppdeact => dbgtrngppdeact,
				dbgtrngrawduration => dbgtrngrawduration,
				dbgtrngvonneuman => dbgtrngvonneuman,
				dbgtrngidletime => dbgtrngidletime
			);
	end generate;
	-- pragma translate_on

	-- post processing unit
	p0: ecc_trng_pp
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			data_t => data_t,
			valid_t => valid_t,
			rdy_t => rdy_t,
			data_s => data_s,
			valid_s => valid_s,
			rdy_s => rdy_s
		);

	-- unit serving internal random numbers
	s0: ecc_trng_srv
		port map(
			clk => clk,
			rstn => rstn,
			swrst => swrst,
			-- interface with ecc_scalar
			irn_reset => irn_reset,
			-- interface with ecc_trng_pp
			data_s => data_s,
			valid_s => valid_s,
			rdy_s => rdy_s,
			-- interface with entropy client ecc_fp
			rdy0 => rdy0,
			valid0 => valid0,
			data0 => data0,
			irncount0 => irncount0,
			-- interface with entropy client ecc_fp_dram_sh
			rdy1 => rdy1,
			valid1 => valid1,
			data1 => data1,
			irncount1 => irncount1,
			-- common interface to ecc_fp & ecc_curve
			rdy2 => rdy2,
			valid2 => valid2,
			data2 => data2,
			irncount2 => irncount2,
			-- common interface to ecc_fp & ecc_fp_dram_sh
			rdy3 => rdy3,
			valid3 => valid3,
			data3 => data3,
			irncount3 => irncount3,
			-- following signals are for debug (statistics)
			dbgtrngcompletebypass => dbgtrngcompletebypass
		);

end architecture rtl;
