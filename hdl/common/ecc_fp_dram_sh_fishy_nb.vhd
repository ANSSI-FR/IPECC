library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- pragma translate_off
use ieee.std_logic_textio.all;
use std.textio.all;
-- pragma translate_on

use work.ecc_pkg.all;
use work.ecc_utils.all;
use work.ecc_customize.all;
use work.ecc_trng_pkg.irn_width_sh;
use work.ecc_shuffle_pkg.all;
use work.ecc_log.all;

entity ecc_fp_dram_sh_fishy_nb is
	generic(
		rdlat : positive range 1 to 2);
	port(
		clk : in std_logic;
		rstn : in std_logic;
		swrst : in std_logic;
		-- port A: write-only interface from ecc_fp
		wea : in std_logic;
		addra : in std_logic_vector(FP_ADDR - 1 downto 0);
		dia : in std_logic_vector(ww - 1 downto 0);
		-- port B: read-only interface to ecc_fp
		reb : in std_logic;
		addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
		dob : out std_logic_vector(ww - 1 downto 0);
		-- interface with ecc_axi
		nndyn_wm1 : in unsigned(log2(w - 1) - 1 downto 0);
		-- interface with ecc_scalar
		permute : in std_logic;
		permuterdy : out std_logic;
		-- interface with ecc_trng
		trngvalid : in std_logic;
		trngrdy : out std_logic;
		trngdata : in std_logic_vector(irn_width_sh - 1 downto 0)
		-- pragma translate_off
		-- interface with ecc_fp (simu only)
		; fpdram : out fp_dram_type;
		vtophys : out virt_to_phys_table_type
		-- pragma translate_on
	);
end entity ecc_fp_dram_sh_fishy_nb;

architecture syn of ecc_fp_dram_sh_fishy_nb is

	component ecc_fp_dram is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			-- port A: write-only interface from ecc_fp
			-- (actually for write-access from AXI-lite interface)
			wea : in std_logic;
			addra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(ww - 1 downto 0);
			-- port B: read-only interface to ecc_fp
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(ww - 1 downto 0)
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			; fpdram : out fp_dram_type
			-- pragma translate_on
		);
	end component ecc_fp_dram;

	component virt_to_phys_async is
		generic(
			datawidth : natural range 1 to integer'high;
			datadepth : natural range 1 to integer'high);
		port(
			clk : in std_logic;
			-- port A (write-only, synchronous)
			we : in std_logic;
			waddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			di : in std_logic_vector(datawidth - 1 downto 0);
			-- port B (read-only, ASYNchronous)
			re : in std_logic;
			raddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			do : out std_logic_vector(datawidth - 1 downto 0)
			-- pragma translate_off
			; vtophys : out virt_to_phys_table_type
			-- pragma translate_on
		);
	end component virt_to_phys_async;

	-- registers on interface to virt_to_phys_async
	-- (virtual-to-physical translation memory)
	type vp_reg_type is record
		waddr : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		we : std_logic;
		wdata : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		raddr0 : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		re0 : std_logic;
		raddr1 : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		re1 : std_logic;
		swap : std_logic;
	end record;

	-- registers on interface to ecc_fp_dram
	type fp_reg_type is record
		we : std_logic;
		waddr : std_logic_vector(FP_ADDR - 1 downto 0);
		waddr_lsb : std_logic_vector(FP_ADDR_LSB - 1 downto 0);
		wdata : std_logic_vector(ww - 1 downto 0);
		wdata_del : std_logic_vector(ww - 1 downto 0);
		resh, resh1 : std_logic_vector(rdlat downto 0);
		raddr : std_logic_vector(FP_ADDR - 1 downto 0);
		raddr_lsb : std_logic_vector(FP_ADDR_LSB - 1 downto 0);
	end record;

	type state_type is (idle, permutation);

	constant NB_MAX_SHIFT : natural := FP_ADDR_MSB - 1;
	constant NB_JSH_REG : natural := div(log2(NB_MAX_SHIFT), 2);

	subtype msb_addr is std_logic_vector(FP_ADDR_MSB - 1 downto 0);

	type barrel_sh_type is
		array(integer range 0 to NB_JSH_REG) of msb_addr;

	-- registers used for generation of a new address-space permutation
	type permute_reg_type is record
		active : std_logic;
		rdy : std_logic;
		i : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		aofi : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		do_brlphase_sh : std_logic_vector(1 downto 0);
		i_next : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		trngrdy : std_logic;
		brlsh : std_logic_vector(0 to NB_JSH_REG);
		brl : barrel_sh_type;
		brlcmd, brlcmd_next : std_logic_vector((2 * NB_JSH_REG) - 1 downto 0);
		jtoobig : std_logic;
		brl_phase : std_logic;
		brlout_sel : std_logic_vector(0 to NB_JSH_REG);
		brlout_sel_next : std_logic_vector(0 to NB_JSH_REG);
		doburst : std_logic;
		finish : std_logic_vector(rdlat downto 0);
		-- pragma translate_off
		-- for sake of waveform readability during simulation
		j : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
		aofi_times_n : integer;
		aofj_times_n : integer;
		ok : std_logic;
		-- pragma translate_on
	end record;

	-- all registers
	type reg_type is record
		state : state_type;
		vp : vp_reg_type;
		fp : fp_reg_type;
		permute : permute_reg_type;
	end record;

	signal r, rin : reg_type;

	-- read data bus on ports A & B of virt-to-phys translation RAM
	signal vp0rdata : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
	signal vp1rdata : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
	signal fprdata : std_logic_vector(ww - 1 downto 0);

	signal gnd : std_logic;
	signal vcc : std_logic;

	function zeros(arg: natural) return std_logic_vector is
		variable tmp : std_logic_vector(arg - 1 downto 0);
	begin
		tmp := (others => '0');
	return tmp;
	end function zeros;

	-- pragma translate_off
	signal r_permute_rdy : std_logic;
	-- pragma translate_on

begin

	-- Notation: the comments in the code below use a[i] & a[j] (or
	-- sometimes equivalently a_i & a_j) to designate the virtual addresses
	-- of large numbers i & j. From the perspective of the Fisher-Yates
	-- algorithm that the logic below implements, the aim is to generate
	-- a complete random permutation of the array 'a' holding virtual
	-- addresses of the large numbers that reside in ecc_fp_dram memory
	-- (which instance is named 'd0' below).
	--
	-- At "runtime" there are two different modes of the present module:
	--
	--   - The 1st mode is when register r.permute.active = 0
	--
	--         As long as register r.permute.active is low, the logic acts
	--         as a virtual-to-physical address translator, meaning that
	--         addresses presented to the module are first translated as
	--         physical addresses into ecc_fp_dram before actually being
	--         served (either for writes or for reads). The instance of
	--         memory 'virt_to_phys_async' named 'vp0' below is used to translate
	--         addresses for the write accesses, while the one named 'vp1'
	--         is used to translate addresses for the read accesses (two
	--         instances are required indeed, as ecc_fp needs to access
	--         to large numbers both in read & write simultaneously).
	--         Note that 'vp0' & 'vp1' memories always store the exact same
	--         content, which is why their respective write ports are con-
	--         nected to the exact same signals.
	--
	--   - The 2nd mode is when register r.permute.active = 1
	--
	--         When r.permute.active is high, it means that d0/ecc_fp_dram
	--         memory cannot be accessed, neither to serve read nor to serve
	--         writes, because a complete run of the Fisher-Yates algorithm is
	--         currently under way to completely re-shuffle the content of the 'a'
	--         array (equivalently saying: of the vp0 & vp1 memories). Of course,
	--         simultaneously to the permutation of the 'a' array, the content
	--         of d0/ecc_fp_dram is also reformated to reflect the exact change
	--         in the virtual-to-physical mapping stored in 'a'
	--
	-- Generally speaking, the Fisher-Yates algorithm is used to randomly
	-- generate any permutation of an n-element set among the total n!
	-- possibilities of doing so. The algorithm is very simple and consists
	-- in scanning the n items (for instance in the range i from n - 1
	-- downto 0), generating a random number j in [0..i] at each step i and
	-- swapping the items of the set in positions i and j (a[i] <-> a[j]).
	--
	-- That is exactly what the logic below describes: i & j now denote
	-- base addresses of large numbers in d0/ecc_fp_dram. For each value i,
	-- a random number j is drawn which goes through a barrel-shifter (which
	-- purpose is to dynamically right-shift the value of j so as to increase
	-- the probability that it falls in the proper [0..i] interval). Value
	-- a[i] is read from vp0, value a[j] from vp1. Then a burst is undertaken
	-- consisting in 'w' beats, each reading two values of the large numbers
	-- of index a[i] & a[j], and swapping their locations.
	-- Obviously the swap a[i] <-> a[j] is also performed in vp0 & vp1.
	--
	-- Once the job is done for all the 'nblargenb' large numbers,
	-- r.permute.active is deasserted and the memory becomes available
	-- again to serve reads & writes from the outside of the module
	-- (as it would if shuffle countermeasure was not activated, but
	-- simply with the extra lantecy in reads incurred by the virtual-
	-- to-physical address translations).

	-- vp0: 1st instance of the virtual-to-physical address translation table
	-- (used for WRITE accesses to d0/ecc_fp_dram from the outside of the
	-- module)
	vp0: virt_to_phys_async
		generic map(
			datawidth => FP_ADDR_MSB, -- (defined as log2(nblargenb - 1) in ecc_pkg)
			datadepth => nblargenb)
		port map(
			clk => clk,
			-- port A (synchronous write)
			waddr => r.vp.waddr,
			we => r.vp.we,
			di => r.vp.wdata,
			-- port B (asynchronous read)
			-- this is the port used for virtual-to-physical translations
			raddr => r.vp.raddr0, --(FP_ADDR - 1 downto FP_ADDR - FP_ADDR_MSB),
			re => r.vp.re0,
			do => vp0rdata
			-- pragma translate_off
			, vtophys => vtophys
			-- pragma translate_on
		);

	-- vp1: 2nd instance of the virtual-to-physical address translation table
	-- (used for READ accesses to d0/ecc_fp_dram from the outside of the
	-- module)
	vp1: virt_to_phys_async
		generic map(
			datawidth => FP_ADDR_MSB, -- (defined as log2(nblargenb - 1) in ecc_pkg)
			datadepth => nblargenb)
		port map(
			clk => clk,
			-- port A (synchronous write)
			waddr => r.vp.waddr,
			we => r.vp.we,
			di => r.vp.wdata,
			-- port B (asynchronous read)
			-- this is the port used for virtual-to-physical translations
			raddr => r.vp.raddr1, --(FP_ADDR - 1 downto FP_ADDR - FP_ADDR_MSB),
			re => r.vp.re1,
			do => vp1rdata
		);

	gnd <= '0';
	vcc <= '1';

	-- d0: instance of ecc_fp_dram actual data memory (exact same entity,
	-- with the exact same interface, as when shuffle countermeasure is
	-- not present)
	d0: ecc_fp_dram
		generic map(rdlat => rdlat)
		port map(
			clk => clk,
			-- port A (write-only)
			wea => r.fp.we,
			addra => r.fp.waddr,
			dia => r.fp.wdata,
			-- port B (read-only)
			reb => r.fp.resh(rdlat),
			addrb => r.fp.raddr,
			dob => fprdata
			-- pragma translate_off
			-- interface with ecc_fp (simu only)
			, fpdram => fpdram
			-- pragma translate_on
		);

	-- -------------------
	-- combinational logic
	-- -------------------
	comb: process(r, rstn, wea, addra, dia, reb, addrb, vp0rdata, vp1rdata,
		            fprdata, permute, trngdata, trngvalid, swrst,
		            nndyn_wm1)
		-- TODO: complete sensitivity list!
		variable v : reg_type;
		variable v_i_minus_j : unsigned(FP_ADDR_MSB downto 0);
		variable vbrlin, vbrl0 : std_logic_vector(FP_ADDR_MSB - 1 downto 0);
	begin
		v := r;

		-- (s0), bypassed by (s1), (s6), (s19) & (s37)
		v.vp.re0 := '0'; -- (s0)

		-- (s7), bypassed by (s8) & (s13)
		v.vp.re1 := '0'; -- (s7)

		-- (s9), bypassed by (s11) & (s20)
		v.fp.resh := '0' & r.fp.resh(rdlat downto 1); -- (s9)

		-- (s33), bypassed by (s34) & (s35)
		v.vp.we := '0'; -- (s33)

		-- (s38), bypassed by (s39) & (s40)
		v.permute.do_brlphase_sh := '0' & r.permute.do_brlphase_sh(1); -- (s38)

		-- -------------------------------------------------------------
		--                generation of next permutation
		--                    [r.state = permutation]
		-- -------------------------------------------------------------
		if permute = '1' then
			v.permute.active := '1';
			v.permute.rdy := '0';
			v.state := permutation;
			v.permute.i := std_logic_vector(to_unsigned(nblargenb - 1, FP_ADDR_MSB));
			v.vp.raddr0 := v.permute.i;
			v.vp.re0 := '1'; -- (s1), bypass of (s0)
			v.permute.trngrdy := '1';
			v.permute.brlcmd := (others => '0');
			v.permute.brl_phase := '0';
			v.permute.brlout_sel := (0 => '1', others => '0');
			v.permute.brlout_sel_next := (0 => '1', others => '0');
			v.permute.do_brlphase_sh(1) := '1'; -- (s39), bypass of (s38)
			-- pragma translate_off
			v.permute.ok := '0';
			-- pragma translate_on
		end if;

		-- shift-register to account for passage of j through barrel-shifter
		v.permute.brlsh :=
			'0' & r.permute.brlsh(0 to NB_JSH_REG - 1); -- (s2), bypassed by (s3)

		-- get random from TRNG
		if r.permute.trngrdy = '1' and trngvalid = '1' then
			v.permute.trngrdy := '0';
			v.permute.brlsh(0) := '1'; -- (s3), bypass of (s2)
			v.permute.brl(0) := trngdata;
		end if;

		-- --------------
		-- barrel-shifter
		-- (2 bits of the controlling number, that is the number telling of how many
		-- positions the input should be right-shifted, are processed per cycle)
		-- --------------
		for i in 0 to NB_JSH_REG - 1 loop
			vbrlin := r.permute.brl(i);
			if i < NB_JSH_REG - 1 then
				-- all stages (of the barrel-shifter) except the last one
				--   1st bit
				if r.permute.brlcmd(2*i) = '1' then
					vbrl0 :=
						zeros(2**(2*i))
						& vbrlin(FP_ADDR_MSB - 1 downto 2**(2*i));
				elsif r.permute.brlcmd(2*i) = '0' then
					vbrl0 := vbrlin;
				end if;
				--   2nd bit
				if r.permute.brlcmd((2*i) + 1) = '1' then
					vbrl0 :=
						zeros(2**((2*i) + 1))
						& vbrl0(FP_ADDR_MSB - 1 downto 2**((2*i) + 1));
				elsif r.permute.brlcmd((2*i) + 1) = '0' then
					null; -- vbrl0 := vbrl0;
				end if;
			else
				-- last stage of the barrel-shifter
				-- (possibly also the first one, this is not exclusive)
				if log2(NB_MAX_SHIFT) mod 2 = 0 then -- statically resolv by synth.
					-- even case
					--   1st bit
					if r.permute.brlcmd(2*i) = '1' then
						vbrl0 :=
							zeros(2**(2*i))
							& vbrlin(FP_ADDR_MSB - 1 downto 2**(2*i));
					elsif r.permute.brlcmd(2*i) = '0' then
						vbrl0 := vbrlin;
					end if;
					--   2nd bit
					if r.permute.brlcmd((2*i) + 1) = '1' then
						vbrl0 :=
							zeros(2**((2*i) + 1))
							& vbrl0(FP_ADDR_MSB - 1 downto 2**((2*i) + 1));
					elsif r.permute.brlcmd((2*i) + 1) = '0' then
						null; -- vbrl0 := vbrl0;
					end if;
				else -- odd (statically resolv by synth.)
					if r.permute.brlcmd(2*i) = '1' then
						vbrl0 :=
							zeros(2**(2*i)) & vbrlin(FP_ADDR_MSB - 1 downto 2**(2*i));
					elsif r.permute.brlcmd(2*i) = '0' then
						vbrl0 := vbrlin;
					end if;
				end if;
			end if; -- if i < last stage
			v.permute.brl(i + 1) := vbrl0;
		end loop;

		-- optimization: select the ouput of the barrel-register according to
		-- r.permute.brlout_sel (for most values of i, the value drawn from
		-- the TRNG does not require to go through all the stages of the barrel-
		-- shifter)
		for i in 0 to NB_JSH_REG loop
			if r.permute.brlsh(i) = '1' and r.permute.brlout_sel(i) = '1' then
				-- means the output r.permute.brl(i) is the one we can use as
				-- random value for j to potentially swap i & j places in the
				-- Fisher-Yates algorithm (we still need to check that j <= i,
				-- and if it's not the case we'll have to draw a new random value
				-- for j)
				v.vp.raddr1 := r.permute.brl(i); -- (s36)
				v_i_minus_j := 
					resize(unsigned(r.permute.i), FP_ADDR_MSB + 1) -
					resize(unsigned(r.permute.brl(i)), FP_ADDR_MSB + 1);
				v.permute.jtoobig := v_i_minus_j(FP_ADDR_MSB);
				-- (s8) triggers a new read from vp1, but it's possible
				-- that the read be "cancelled" at next cycle if j happens
				-- not to be suitable for the permutation, see (s10) below
				v.vp.re1 := '1'; -- (s8), bypass of (s7)
				-- TODO: check the effect on synthesis of the 'exit' instruction
				-- below (however since the range of the loop is expected to
				-- be very small (NB_JSH_REG ~ log(log(nn))) there should not be
				-- a problem - this also means that the fan-in of r.vp.raddr0
				-- should remain very low (2 or 3 paths at most)
				exit;
				-- (actually we could also remove the 'exit', because we know
				-- that r.permute.brlsh cannot have more that one bit set at
				-- a time
			end if;
		end loop;

		-- Note that the type of rdlat ensures that it cannot take any other
		-- value than 1 or 2
		if rdlat = 1 then -- statically resolved by synthesizer
			-- rolling shift-register
			v.fp.resh1 := r.fp.resh1(0) & r.fp.resh1(rdlat downto 1);
		elsif rdlat = 2 then -- statically resolved by synthesizer
			v.fp.resh1 := (not r.fp.resh1(rdlat)) & r.fp.resh1(rdlat downto 1);
		end if;

		-- the only value read from vp1 memory when .active = 1 is a[j]
		if r.vp.re1 = '1' and r.permute.active = '1' then
			-- read from vp1 is only pertinent if .jtoobig = '0'
			if r.permute.jtoobig = '1' then
				-- (s10)
				-- means i < j strictly, we must reject j and start again a
				-- random extraction from the TRNG.
				-- The read from vp1 memory initiated by (s8) is "cancelled"
				-- (meaning the read data is simply ignored)
				v.permute.trngrdy := '1';
			elsif r.permute.jtoobig = '0' then
				-- means i >= j hence j is a suitable random, and the read of
				-- a[j] is pertinent.
				-- We can start the burst of read & write from/to ecc_fp_dram
				-- aiming at swaping the values of large numbers f(a[i]) & f(a[j]).
				-- Set the base address of both read & write bus of ecc_fp_dram,
				-- that is the FP_ADDR_MSB most significant bits
				v.permute.doburst := '1';
				v.fp.resh(rdlat) := '1'; -- (s20), bypass of (s9)
				-- In (s21) below, pushing a logic 1 in r.fp.resh1(rdlat) identifies
				-- a read of an a_i limb, while a logic 0 would identifie read of
				-- an a_j limb, see (s22). Hence the importance of the reset of
				-- r.fp.resh1 (see (s23)). Pushing a 0 or a 1 into r.fp.resh1(rdat)
				-- is later used to determine from which large number a limb was
				-- read (the one indexed by i, see (s31), or the one indexed by j,
				-- see (s30))
							--v.fp.resh1 := (rdlat => '1', others => '0'); -- (s21)
				v.fp.resh1 := (others => '0');
				v.fp.resh1(rdlat) := '1'; -- (s21)
				-- initialize r.fp.raddr, also initialize the least significant
				-- bits of r.fp.waddr
				if nn_dynamic then -- statically resolved by synthesizer
					v.fp.raddr := vp0rdata & std_logic_vector(nndyn_wm1);
					v.fp.waddr(FP_ADDR_LSB - 1 downto 0) :=
						std_logic_vector(nndyn_wm1);
				else
					v.fp.raddr := vp0rdata &
						std_logic_vector(to_unsigned(w - 1, FP_ADDR_LSB));
					v.fp.waddr(FP_ADDR_LSB - 1 downto 0) := std_logic_vector(
						to_unsigned(w - 1, FP_ADDR_LSB));
				end if;
				v.permute.aofi := vp0rdata;
				-- at the same time we start the burst. Also switch a_i & a_j
				-- in vp0 & vp1 virtual-top-physical translation memories,
				-- the 1st step for that is to write a_j at address i
				v.vp.we := '1'; -- (s34), bypass of (s33)
				v.vp.swap := '1';
				v.vp.waddr := r.permute.i;
				v.vp.wdata := vp1rdata;
				-- pragma translate_off
				v.permute.j := r.vp.raddr1; -- still valid from (s36)
				v.permute.aofi_times_n := to_integer(unsigned(vp0rdata)) * n;
				v.permute.aofj_times_n := to_integer(unsigned(vp1rdata)) * n;
				v.permute.ok := '1';
				-- pragma translate_on
			end if;
		end if;

		-- the 2nd & last step for the a_i <-> a_j switch is to write a_i
		-- at address j
		if r.vp.swap = '1' then
			v.vp.swap := '0';
			v.vp.we := '1'; -- (s35), bypass of (s33)
			-- the value of j is still driven on bus r.vp.raddr1, from (s36)
			v.vp.waddr := r.vp.raddr1;
			v.vp.wdata := vp0rdata;
		end if;

		-- (s42), bypassed by (s43)
		v.permute.finish := '0' & r.permute.finish(rdlat downto 1); -- (s42)

		-- (s44), end of one complete permutation cycle (one copmplete pass
		-- of the Fisher-Yates algorithm, operating a complete permutation
		-- of the content of the virtual-to-physical address translation
		-- memories vp0 & vp1, and the corresponding permtuation on the
		-- d0/ecc_fp_dram memory of large numbers)
		if r.permute.finish(0) = '1' then
			v.state := idle;
			v.permute.rdy := '1';
			v.permute.active := '0';
		end if;

		-- burst (swapping the 'w' limbs of large numbers a_i & a_j)
		if r.permute.doburst = '1' then
			v.fp.resh(rdlat) := '1'; -- (s11), bypass of (s9), bypassed by (s12)
			if r.fp.resh1(rdlat) = '0' then
				-- decrement the least significant part (FP_ADDR_LSB bits) of the
				-- address every cycle of two reads
				v.fp.raddr(FP_ADDR_LSB - 1 downto 0) := std_logic_vector(
					unsigned(r.fp.raddr(FP_ADDR_LSB - 1 downto 0)) - 1);
				if r.fp.raddr(FP_ADDR_LSB - 1 downto 0) =
					std_logic_vector(to_unsigned(0, FP_ADDR_LSB))
				then
					-- terminate one swapping burst
					v.permute.doburst := '0';
					v.fp.resh(rdlat) := '0'; -- (s12), bypass of (s11)
					-- switch to next value of i (next step of the Fisher-Yates algorithm)
					v.permute.i := r.permute.i_next;
					v.permute.brlout_sel := r.permute.brlout_sel_next;
					v.permute.do_brlphase_sh(1) := '1'; -- (s40), bypass of (s38)
					if r.permute.i_next = (r.permute.i_next'range => '0') then
						-- (s42) below aims at arming a delaying shift-register
						-- in order to end the permutation (by (s44) above) BUT AFTER
						-- having let time to the last writing burst in ecc_fp_dram
						-- (operating the last swap of the Fisher-Yates algo) to complete
						v.permute.finish(rdlat) := '1'; -- (s43)
					else
						v.permute.trngrdy := '1';
						v.permute.brlcmd := r.permute.brlcmd_next;
						v.vp.raddr0 := r.permute.i_next;
						v.vp.re0 := '1'; -- (s37), bypass of (s0)
					end if;
					-- pragma translate_off
					v.permute.ok := '0';
					-- pragma translate_on
				end if;
			end if;
			-- (s22)
			-- the base address of r.fp.raddr (most signifiant bits, in a
			-- quantity FP_ADDR_MSB) must switch at each cycle between a_i
			-- and a_j
			if r.fp.resh1(rdlat) = '1' then -- identifies a_i, see (s21)
				v.fp.raddr(FP_ADDR - 1 downto FP_ADDR_LSB) := vp1rdata;
			elsif r.fp.resh1(rdlat) = '0' then -- identifies a_j, see (s21)
				v.fp.raddr(FP_ADDR - 1 downto FP_ADDR_LSB) := vp0rdata;
			end if;
		end if;

		v.fp.we :=  '0'; -- (s15), bypassed by (s16) & (s18)

		-- set write address into d0/ecc_fp_dram during the swapping burst
		-- of large numbers
		if r.permute.active = '1' and r.fp.resh(0) = '1' then
			v.fp.we := '1'; -- (s16), bypass of (s15), bypassed by (s17)
			if r.fp.resh1(0) = '0' then -- identifies an a_j limb
				v.fp.waddr(FP_ADDR - 1 downto FP_ADDR_LSB) := r.permute.aofi; -- (s31)
			elsif r.fp.resh1(0) = '1' then -- identifies an a_i limb
				v.fp.waddr(FP_ADDR - 1 downto FP_ADDR_LSB) := vp1rdata; -- (s30)
				-- in this cycle we also decrement the LSbits of r.fp.waddr
				if r.fp.we = '1' then
					v.fp.waddr(FP_ADDR_LSB - 1 downto 0) := std_logic_vector(
						unsigned(r.fp.waddr(FP_ADDR_LSB - 1 downto 0)) - 1);
				end if;
			end if;
			-- drive write data bus into ecc_fp_dram
			v.fp.wdata := fprdata;
		end if;

		if r.fp.resh(0) = '0' and r.fp.resh1(0) = '1' then
			v.fp.we := '0'; -- (s17), bypass of (s16)
		end if;

		-- compute next versions of r.permute.brlcmd & r.permute.brlout_sel
		v.permute.i_next := std_logic_vector(unsigned(r.permute.i) - 1);
		-- increment of the barrel command input (this is the nb of right-shift
		-- we need to apply to each value j drawn from the random source so as
		-- to increase its likelihood not to be rejected (for the reason that
		-- it would be greater than i) - as Fisher-Yates algorithm requires,
		-- at step i, to draw a random number from 0 to i)
		if (r.permute.i and r.permute.i_next) = (r.permute.i'range => '0') then
			v.permute.brlcmd_next := std_logic_vector(unsigned(r.permute.brlcmd) + 1);
			-- (s41) below will happen only 1 cycle thx to (s38)
			if r.permute.do_brlphase_sh(0) = '1' then -- (s41)
				v.permute.brl_phase := not r.permute.brl_phase;
				if r.permute.brl_phase = '1' then
					v.permute.brlout_sel_next := '0' & 
						r.permute.brlout_sel_next(0 to NB_JSH_REG - 1);
				end if;
			end if;
		else
			v.permute.brlcmd_next := r.permute.brlcmd;
		end if;

		-- -------------------------------------------------------------
		--                "normal" access to  ecc_fp_dram
		--                   (using redirection tables)
		--                        [r.state = idle]
		-- -------------------------------------------------------------

		-- TODO: several multi-cycle constraints are possible on paths
		-- below (among ones launched from register r.permute.active)
		if r.permute.active = '0' then
			-- perform address translation to service the reads
			if reb = '1' then
				v.vp.re1 := '1'; -- (s13), bypass of (s7)
				v.vp.raddr1 := addrb(FP_ADDR - 1 downto FP_ADDR_LSB);
				--v.fp.raddr(FP_ADDR_MSB - 1 downto 0) :=
				--	addrb(FP_ADDR_MSB - 1 downto 0);
				v.fp.raddr_lsb := addrb(FP_ADDR_LSB - 1 downto 0);
			end if;
			-- perform address translation to service the writes
			if wea = '1' then
				v.vp.re0 := '1'; -- (s19), bypass of (s0)
				v.vp.raddr0 := addra(FP_ADDR - 1 downto FP_ADDR_LSB);
				--v.fp.waddr(FP_ADDR_MSB - 1 downto 0) :=
				--	addra(FP_ADDR_MSB - 1 downto 0);
				v.fp.wdata_del := dia;
				v.fp.waddr_lsb := addra(FP_ADDR_LSB - 1 downto 0);
			end if;
		end if;

		-- transfer reads to d0/ecc_fp_dram, with a translated address
		-- read from vp1
		if r.permute.active = '0' and r.vp.re1 = '1' then
			v.fp.resh(rdlat) := '1'; -- (s14), bypass of (s9)
			--v.fp.raddr(FP_ADDR - 1 downto FP_ADDR_MSB) := vp1rdata;
			v.fp.raddr := vp1rdata & r.fp.raddr_lsb;
		end if;

		-- transfer writes to d0/ecc_fp_dram, with a translated address
		-- read from vp0
		if r.permute.active = '0' and r.vp.re0 = '1' then
			v.fp.we := '1'; -- (s18), bypass of (s15)
			--v.fp.waddr(FP_ADDR - 1 downto FP_ADDR_MSB) := vp0rdata;
			v.fp.wdata := r.fp.wdata_del;
			v.fp.waddr := vp0rdata & r.fp.waddr_lsb;
		end if;

		-- synchronous (active low) reset
		if rstn = '0' or swrst = '1' then
			v.state := idle;
			v.vp.we := '0';
			--v.vp.re0 := '0';    (no need to reset r.vp.re[01] as long as
			--v.vp.re1 := '0';     r.permute.active is reset low)
			v.fp.resh := (others => '0');
			v.fp.we := '0';
			v.fp.resh1 := (others => '0'); -- (s23), see (s21) & (s22)
			v.vp.swap := '0';
			v.permute.active := '0';
			v.permute.rdy := '1';
			v.permute.trngrdy := '0';
			-- no need to reset r.permute.brlsh
			-- no need to reset r.permute.brl_phase
			-- no need to reset r.permute.brlout_sel[_next]
			v.permute.doburst := '0';
			v.permute.do_brlphase_sh := "00";
			v.permute.finish := (others => '0');
		end if;

		rin <= v;
	end process comb;

	-- registers latch
	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			r <= rin;
		end if;
	end process regs;

	-- drive outputs
	dob <= fprdata;
	permuterdy <= r.permute.rdy;
	trngrdy <= r.permute.trngrdy;

	-- pragma translate_off
	process(clk, rstn)
		file output : TEXT open write_mode is "/tmp/shuffling-nb.log";
		variable lineout : line;
	begin
		if clk'event and clk = '1' then
			r_permute_rdy <= r.permute.rdy;
			if r.vp.we = '1' then
				write(lineout, string'("vp("));
				write(lineout, to_integer(unsigned(r.vp.waddr)));
				write(lineout, string'(") <- "));
				write(lineout, to_integer(unsigned(r.vp.wdata)));
				write(lineout, string'("  ["));
				write(lineout, now);
				write(lineout, string'("]"));
				writeline(output, lineout);
			end if;
			if r.permute.active = '1' and r.fp.we = '1' then
				write(lineout, string'("                    fp("));
				write(lineout, to_integer(unsigned(r.fp.waddr)));
				write(lineout, string'(") <- 0x"));
				hwrite(lineout, r.fp.wdata);
				write(lineout, string'("  ["));
				write(lineout, now);
				write(lineout, string'("]"));
				writeline(output, lineout);
			end if;
			if r.permute.rdy = '1' and r_permute_rdy = '0' then
				-- we've just finished a complete permutation of memory
				-- just print a delimieter in the log file so as to make
				-- it more readable
				write(lineout, string'("========"));
				writeline(output, lineout);
			end if;
		end if;
	end process;
	-- pragma translate_on

end architecture syn;
