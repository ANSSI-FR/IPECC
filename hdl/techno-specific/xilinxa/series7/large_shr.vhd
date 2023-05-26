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

use work.ecc_pkg.all;
use work.ecc_utils.all; -- for function div()

entity large_shr is
	generic(size : positive := 2*w*ww);
	port(
		clk : in std_logic;
		ce : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity large_shr;

architecture struct of large_shr is

	signal r_srlx : std_logic_vector(div(size,32) downto 0);

begin

	-- generic instanciation of 'ww'-bit-wide shift-registers
	-- (pasted from <7series_hdl.pdf> UG768 (v 14.5) March 20, 2013, p. 432)

	r_srlx(0) <= d;

	x0 : for j in 0 to div(size,32) - 1 generate

		-- all SRLC32 primitives but the last one
		x00 : if j < div(size,32) - 1 generate
			x000 : SRLC32E
				port map (
					d => r_srlx(j),
					a => "11111", -- doesn't matter as we use output Q31
					ce => ce,
					clk => clk,
					q => open, --r_srlxo(i),
					q31 => r_srlx(j + 1)
			);
		end generate;

		-- last SRLC32 primitive (x01 is like an elsif of x00)
		x01 : if j = div(size,32) - 1 generate

			x010 : if (size mod 32) /= 0 generate
				x0100 : SRLC32E
					port map (
						d => r_srlx(j),
						-- a input matters as we do NOT use ouput Q31 but Q output instead
						a => std_logic_vector( to_unsigned((size mod 32) - 1, 5) ),
						ce => ce,
						clk => clk,
						q => r_srlx(j + 1),
						q31 => open
				);
			end generate;

			x011 : if (size mod 32) = 0 generate
				x0110 : SRLC32E
					port map (
						d => r_srlx(j),
						a => "11111", -- doesn't matter as we use output Q31
						ce => ce,
						clk => clk,
						q => open,
						q31 => r_srlx(j + 1)
				);
			end generate;

		end generate;
	end generate;

	q <= r_srlx(div(size,32));

end architecture struct;
