library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_utils.all; -- for log2()
use work.ecc_pkg.all;
use work.ecc_customize.all; -- for techno

-- code below conforms to Xilinx's synthesis recommandations for
-- VHDL coding style of a simple dual-port BRAM with two asynchronous clocks
-- (see e.g Vivado Design Suite User Guide, Synthesis, UG901, v2014.1,
--  May 1, 2014) see p. 105 "Simple Dual-Port Block RAM with Dual Clocks
--  VHDL Coding Example" except that it describes a two-cycle delay
-- on the read data path.
-- Depending on the FPGA vendor/family/device target, an extra-layer of
-- register may be present inside the Block-RAM providing such 2-cycle
-- latency, as it leads to better timing performance.
-- In this case it is best for area performance to ensure that the
-- extra register layer on the read data path is held back inside
-- the Block-RAM by synthesis/back-end tools
entity sync2ram_sdp is
	generic(
		rdlat : positive range 1 to 2;
		datawidth : natural range 1 to integer'high;
		datadepth : natural range 1 to integer'high);
	port(
		-- port A (write-only)
		clka : in std_logic;
		addra : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		wea : in std_logic;
		dia : in std_logic_vector(datawidth - 1 downto 0);
		-- port B (read-only)
		clkb : in std_logic;
		addrb : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
		reb : in std_logic;
		dob : out std_logic_vector(datawidth - 1 downto 0)
	);
end entity sync2ram_sdp;

architecture syn of sync2ram_sdp is

	subtype std_ram_word is std_logic_vector(datawidth - 1 downto 0);
	type mem_content_type is array(integer range 0 to datadepth - 1)
		of std_ram_word;
	shared variable mem_content : mem_content_type;

	signal predob : std_ram_word;

begin

	-- -------------------
	-- port A (write-only) in clka clock-domain
	-- -------------------
	process(clka)
	begin
		if (clka'event and clka = '1') then
			-- write logic
			-- (in simulation, only affects array content if no METAVALUE in addra)
			-- otherwise issue a WARNING message
			if (wea = '1') then
				assert(not is_X(addra))
					report "write to sync2ram_sdp with a METAVALUE address"
						severity WARNING;
				mem_content(to_integer(unsigned(addra))) := dia;
			end if;
		end if;
	end process;

	-- ------------------
	-- port B (read-only) in clkb clock-domain
	-- ------------------
	r1 : if rdlat = 1 generate
		process(clkb)
		begin
			if (clkb'event and clkb = '1') then
				-- read logic
				-- (in simulation returns 'force unknown' ('X') if METAVALUE in addrb)
				if (reb = '1') then
					-- pragma translate_off
					if is_X(addrb) then
						dob <= (others => 'X');
					else
					-- pragma translate_on
						dob <= mem_content(to_integer(unsigned(addrb)));
					-- pragma translate_off
					end if;
					-- pragma translate_on
				end if;
			end if;
		end process;
	end generate;

	r2 : if rdlat = 2 generate
		process(clkb)
		begin
			if (clkb'event and clkb = '1') then
				dob <= predob;
				-- read logic
				-- (in simulation returns 'force unknown' ('X') if METAVALUE in addrb)
				if (reb = '1') then
					-- pragma translate_off
					if is_X(addrb) then
						predob <= (others => 'X');
					else
					-- pragma translate_on
						predob <= mem_content(to_integer(unsigned(addrb)));
					-- pragma translate_off
					end if;
					-- pragma translate_on
				end if;
			end if;
		end process;
	end generate;

end architecture syn;
