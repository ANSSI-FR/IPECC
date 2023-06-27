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

use work.ecc_utils.all;
use work.ecc_customize.all;
use work.ecc_pkg.all;

package ecc_trng_pkg is

	-- raw_ram_size
	--
	-- this is the size in bits of TRNG memory in which all raw random bits are
	-- buffered (this memory can be accessible by software in debug mode only,
	-- to allow for statistical analysis of the physical TRNG)
	-- parameter trng_ramsz_raw is defined in ecc_customize
	constant raw_ram_size : positive := ge_pow_of_2(trng_ramsz_raw * 1024 * 8);

	-- pp_irn_width
	-- 
	-- this is the bus size of data driven out by the TRNG post-processing
	-- component (if any, but there SHOULD be)
	constant pp_irn_width : positive := 32;

	-- irn_fifo_size_axi
	--
	-- this is the size of the FIFO of TRNG internal random numbers served to
	-- AXI interface (for on-the-fly masking of the scalar)
	-- parameter trng_ramsz_axi is defined in ecc_customize
	constant irn_fifo_size_axi : positive := ge_pow_of_2(
		(trng_ramsz_axi * 1024 * 8) / ww);

	-- irn_fifo_size_fp
	--
	-- this is the size of the FIFO of TRNG internal random numbers served to
	-- ecc_fp (Fp ALU) (for implementation of the NNRND instruction)
	-- parameter trng_ramsz_fpr is defined in ecc_customize
	constant irn_fifo_size_fp : positive := ge_pow_of_2(
		(trng_ramsz_fpr * 1024 * 8) / ww);

	-- irn_fifo_size_curve
	--
	-- this is the size of the FIFO of TRNG internal random numbers served to
	-- ecc_curve (for implementation of the shuffling of [XY]R[01] coordinates)
	-- parameter trng_ramsz_crv is defined in ecc_customize
	constant irn_fifo_size_curve : positive := ge_pow_of_2(
		(trng_ramsz_crv * 1024 * 8) / 2);

	-- irn_width_sh
	--
	-- this is the size in bit of each TRNG internal random number served to
	-- ecc_fp_dram_sh (for implementation of the large numbers memory shuffling)
	constant irn_width_sh : positive := set_irn_width_sh; -- defined in ecc_pkg

	-- irn_fifo_size_sh
	--
	-- this is the size of the FIFO of TRNG internal random numbers served to
	-- ecc_fp_dram_sh (for implementation of the large numbers memory shuffling)
	-- parameter trng_ramsz_shf is defined in ecc_customize
	constant irn_fifo_size_sh : positive := ge_pow_of_2(
		(trng_ramsz_shf * 1024 * 8) / irn_width_sh);

end package ecc_trng_pkg;
