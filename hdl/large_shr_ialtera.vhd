library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_pkg.all;

entity large_shr_ialtera is
	generic(size : positive := 2*w*ww);
	port(
		clk : in std_logic;
		ce : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity large_shr_ialtera;

architecture struct of large_shr_ialtera is

	component large_shr_behav is
		generic(size : positive := 2*w*ww);
		port(
			clk : in std_logic;
			ce : in std_logic;
			d : in std_logic;
			q : out std_logic
		);
	end component large_shr_behav;

begin

	-- for now just instanciate a behavioral model (TODO)
	l0 : large_shr_behav
		generic map(size => size)
		port map(clk => clk, ce => ce, d => d, q => q);

end architecture struct;
