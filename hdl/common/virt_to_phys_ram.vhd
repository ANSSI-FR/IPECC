library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_pkg.all;
use work.ecc_utils.all;
use work.ecc_log.all;
use work.ecc_customize.all;
use work.ecc_shuffle_pkg.all;

-- code below conforms to Xilinx's synthesis recommandations for
-- VHDL coding style of a simple dual-port BRAM with _two_clocks_
-- (see Vivado Design Suite User Guide, Synthesis, UG901, v2014.1,
-- May 1, 2014, pp. 107-108)
-- except that it describes a two-cycle delay on the read data path.
-- Depending on the FPGA vendor/family device target, an extra-layer of
-- register may be present inside the Block-RAM providing such 2-cycle
-- latency, as it leads to better timing performance (at the cost of
-- a small increase in the Block-RAM area).
-- In this case it is best for area performance to ensure that the
-- extra register layer on the read data path is held back inside
-- the Block-RAM by back-end tools
entity virt_to_phys_ram is
	generic(
		rdlat : positive range 1 to 2);
	port(
		clk : in std_logic;
		-- port A: write-only interface
		wea : in std_logic;
		waddra : in std_logic_vector(5 + log2(w - 1) - 1 downto 0);
		dia : in std_logic_vector(5 + log2(w - 1) - 1 downto 0);
		-- port B: read-only interface
		reb : in std_logic;
		addrb : in std_logic_vector(5 + log2(w  - 1) - 1 downto 0);
		dob : out std_logic_vector(5 + log2(w - 1) - 1 downto 0)
		-- pragma translate_off
		; vtophys : out virt_to_phys_table_type
		-- pragma translate_on
	);
end entity virt_to_phys_ram;

architecture syn of virt_to_phys_ram is

	signal predoutb : phys_addr;

	-- if FPGA technology does not support the initialization of memory at
	-- configuration time a small amount of logic should be added to write
	-- Identity permutation into memory at reset time (actually it is so
	-- small we could add the feature whatever the target)
	-- This means writing 0 at address 0, 1 at address 1, 2 at address 2,
	-- etc until the top word in memory
	function init_virt_to_phys_ram return virt_to_phys_table_type is
		variable m : virt_to_phys_table_type;
	begin
		for i in 0 to 2**(5 + log2(w - 1)) - 1 loop
			m(i) := std_logic_vector(to_unsigned(i, 5 + log2(w - 1)));
		end loop;
		return m;
	end function;

	shared variable mem_content :
	  virt_to_phys_table_type := init_virt_to_phys_ram;

begin

	-- -------------------
	-- port A (write-only)
	-- -------------------
	process(clk)
	begin
		if (clk'event and clk = '1') then
			if (wea = '1') then
				mem_content(to_integer(unsigned(waddra))) := dia;
			end if;
		end if;
	end process;

	-- ------------------
	-- port B (read-only)
	-- ------------------
	r1: if rdlat = 1 generate
		process(clk)
		begin
			if (clk'event and clk = '1') then
				if (reb = '1') then
					dob <= mem_content(to_integer(unsigned(addrb)));
				end if;
			end if;
		end process;
	end generate;

	r2: if rdlat = 2 generate
		process(clk)
		begin
			if (clk'event and clk = '1') then
				if (reb = '1') then
					predoutb <= mem_content(to_integer(unsigned(addrb)));
				end if;
				dob <= predoutb;
			end if;
		end process;
	end generate;

	-- pragma translate_off
	process(clk)
	begin
		if (clk'event and clk = '1') then
			vtophys <= mem_content;
		end if;
	end process;
	-- pragma translate_on

end architecture syn;
