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
use work.ecc_utils.all;
use work.ecc_pkg.all;

package ecc_trng_pkg is

	-- raw_ram_size
	--
	-- this is the size of TRNG memory in which all raw random bits are buffered
	-- (this memory is only instanciated, and accessible for read, in debug mode,
	-- to allow for statistical analysis of the physical TRNG).
	-- We account for the RC4 key (256 bytes) also but not for the flip/flop
	-- structure
	constant raw_ram_size : natural := 32768; -- TODO: set something smarter

	-- trngta
	--
	-- Biblio: [Yang, Rozic, Grujic, Mentens, Verbauwhede, "ES-TRNG, A High-
	-- throughput, Low-area True Random Number Generator based on Edge Sampling"]
	-- (https://tches.iacr.org/index.php/TCHES/article/view/7276)
	--
	-- this is the main parameter of ES-TRNG, named TA in the article above.
	-- It denotes the number of system clock cycles (i.e AXI clock cycles
	-- in our IP) that we wait before activating edge-detection of RO1 oscillator
	-- by RO2 oscillator.
	--
	-- THE HIGHER trngta IS, THE MORE JITTER-NOISE HAS BEEN ACCUMULATED IN
	-- RO1 EDGES, THE GREATER IS THE ENTROPY PER BIT ISSUED BY ES-TRNG
	--
	-- trngta is defined as a global constant here (instead of a generic
	-- parameter local to es_trng_* components) because in debug mode this
	-- parameter can be edited by software through the AXI interface, and
	-- therefore ecc_axi must access it. In debug mode trngta serves as an
	-- out-of-reset default value.
	--
	-- When not in debug mode, the parameter cannot be edited and trngta
	-- denotes the constant value of the parameter, statically set at
	-- synthesis time
	--constant trngta : natural range 1 to 4095 := 32;
	-- trngta can be set in the list of user-modifiable custom parameters
	-- (see ecc_customize.vhd)

	constant pp_irn_width : positive := 32;

	constant irn_fifo_size_axi : positive := 4 * 2 * n; -- ~256 bytes (nn=256)
	constant irn_fifo_size_fp : positive := ge_pow_of_2(4 * 6 * n); -- ~768 bytes (nn=256)
	constant irn_fifo_size_curve : positive := ge_pow_of_2(2 * nn * 32); -- 4 Kbytes (nn=256)
	constant irn_fifo_size_sh : positive := ge_pow_of_2(32768 / (2 * (5 + log2(n) - 1)));

end package ecc_trng_pkg;

package body ecc_trng_pkg is
end package body ecc_trng_pkg;
