library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_pkg.all;

entity large_shr is
	generic(size : positive := 2*w*ww);
	port(
		clk : in std_logic;
		ce : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity large_shr;

architecture rtl of large_shr is

	signal r : std_logic_vector(size - 1 downto 0);

begin

	assert(size > 1)
		report "parameter size for component large_shr must be at least 2"
			severity FAILURE;

	process(clk)
	begin
		if clk'event and clk = '1' then
			if ce = '1' then
				r <= d & r(size - 1 downto 1);
			end if;
		end if;
	end process;

	q <= r(0);


end architecture rtl;
