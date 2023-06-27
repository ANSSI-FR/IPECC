library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- pragma translate_off
use ieee.std_logic_textio.all;
use std.textio.all;
-- pragma translate_on

use work.ecc_pkg.all;
use work.ecc_utils.all;
use work.ecc_customize.all; -- for nblargenb
use work.ecc_shuffle_pkg.all;

entity ecc_fp_dram_sh_fishy is
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
		-- interface with ecc_scalar
		permute : in std_logic;
		permuterdy : out std_logic;
		-- interface with ecc_trng
		trngvalid : in std_logic;
		trngrdy : out std_logic;
		trngdata : in std_logic_vector(FP_ADDR - 1 downto 0)
		-- pragma translate_off
		-- interface with ecc_fp (simu only)
		; fpdram : out fp_dram_type;
		vtophys : out virt_to_phys_table_type
		-- pragma translate_on
	);
end entity ecc_fp_dram_sh_fishy;

architecture syn of ecc_fp_dram_sh_fishy is

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

	component virt_to_phys_ram is
		generic(
			rdlat : positive range 1 to 2);
		port(
			clk : in std_logic;
			-- port A: write-only interface
			wea : in std_logic;
			waddra : in std_logic_vector(FP_ADDR - 1 downto 0);
			dia : in std_logic_vector(FP_ADDR - 1 downto 0);
			-- port B: read-only interface
			reb : in std_logic;
			addrb : in std_logic_vector(FP_ADDR - 1 downto 0);
			dob : out std_logic_vector(FP_ADDR - 1  downto 0)
			-- pragma translate_off
			; vtophys : out virt_to_phys_table_type
			-- pragma translate_on
		);
	end component virt_to_phys_ram;

	-- registers on interface to virt_to_phys_ram
	type vp_reg_type is record
		-- read/write (port A)
		wep : std_logic;
		deuce : std_logic;
		repsh : std_logic_vector(rdlat downto 0);
		waddrp : std_logic_vector(FP_ADDR - 1 downto 0);
		wdatap : std_logic_vector(FP_ADDR - 1 downto 0);
	end record;

	-- registers on interface to ecc_fp_dram
	type fp_reg_type is record
		we : std_logic;
		waddr : std_logic_vector(FP_ADDR - 1 downto 0);
		wdata : std_logic_vector(ww - 1 downto 0);
		resh : std_logic_vector(rdlat downto 0);
		raddr : std_logic_vector(FP_ADDR - 1 downto 0);
	end record;

	type state_type is (idle, permutation);

	constant NB_MAX_SHIFT : natural := FP_ADDR - 1;
	constant NB_JSH_REG : natural := div(log2(NB_MAX_SHIFT), 2);

	type barrel_sh_type is
		array(integer range 0 to NB_JSH_REG) of phys_addr; -- defined in ecc_pkg

	-- registers used for generation of a new address-space permutation
	type permute_reg_type is record
		active : std_logic;
		rdy : std_logic;
		i : std_logic_vector(FP_ADDR - 1 downto 0);
		aofi : std_logic_vector(FP_ADDR - 1 downto 0);
		do_brlsel_sh : std_logic_vector(2 downto 0);
		i_next : std_logic_vector(FP_ADDR - 1 downto 0);
		trngrdy : std_logic;
		brlsh : std_logic_vector(0 to NB_JSH_REG);
		brl : barrel_sh_type;
		-- the MSbit of register .brlcmd (the bit of position (2 * NB_JSH_REG))
		-- is only used to allow the register .brlhbit to point to it. Without
		-- this extra bit we could get a nasty simulation/synthesis mismatch
		brlcmd, brlcmd_next : std_logic_vector((2 * NB_JSH_REG) downto 0);
		brlhbit : unsigned(log2(2 * NB_JSH_REG) - 1 downto 0);
		jtoobig : std_logic;
		brlout_sel : std_logic_vector(0 to NB_JSH_REG);
		brlout_sel_next : std_logic_vector(0 to NB_JSH_REG);
		aofi_read : std_logic;
		test_j : std_logic;
		fofaofi_read : std_logic;
		-- pragma translate_off
		-- for sake of waveform readability during simulation
		j : std_logic_vector(FP_ADDR - 1 downto 0);
		aofj : std_logic_vector(FP_ADDR - 1 downto 0);
		ok : std_logic;
		-- pragma translate_on
	end record;

	type trans_wdatash_type is array(rdlat downto 0) of std_logic_ww;

	type trans_reg_type is record
		read_raddr : std_logic_vector(FP_ADDR - 1 downto 0);
		write_resh : std_logic_vector(rdlat downto 0);
		write_raddr : std_logic_vector(FP_ADDR - 1 downto 0);
		write_wdatash : trans_wdatash_type;
	end record;

	-- all registers
	type reg_type is record
		state : state_type;
		vp : vp_reg_type;
		fp : fp_reg_type;
		permute : permute_reg_type;
		trans : trans_reg_type;
	end record;

	signal r, rin : reg_type;

	-- read data bus on ports A & B of virt-to-phys translation RAM
	signal wphaddr : std_logic_vector(FP_ADDR - 1 downto 0);
	signal rphaddr : std_logic_vector(FP_ADDR - 1 downto 0);
	signal fprdata : std_logic_vector(ww - 1 downto 0);

	signal gnd : std_logic;
	signal vcc : std_logic;

	-- pragma translate_off
	signal r_vp_wep : std_logic;
	signal r_vp_rwaddrp : std_logic_vector(FP_ADDR - 1 downto 0);
	signal r_vp_wdatap : std_logic_vector(FP_ADDR - 1 downto 0);
	signal r_permute_rdy : std_logic;
	-- pragma translate_on

	function zeros(arg: natural) return std_logic_vector is
		variable tmp : std_logic_vector(arg - 1 downto 0);
	begin
		tmp := (others => '0');
	return tmp;
	end function zeros;

begin

	-- 1st virtual-to-physical translation table
	-- (for write access to ecc_fp_dram)
	vp0: virt_to_phys_ram
		generic map(rdlat => rdlat)
		port map(
			clk => clk,
			-- port A (write-only)
			wea => r.vp.wep,
			waddra => r.vp.waddrp,
			dia => r.vp.wdatap,
			-- port B (read-only)
			--   used for address translations upon WRITE access to ecc_fp_dram
			reb => r.trans.write_resh(rdlat),
			addrb => r.trans.write_raddr,
			dob => wphaddr
			-- pragma translate_off
			, vtophys => vtophys
			-- pragma translate_on
		);

	-- 2nd virtual-to-physical translation table
	-- (for read access to ecc_fp_dram)
	vp1: virt_to_phys_ram
		generic map(rdlat => rdlat)
		port map(
			clk => clk,
			-- port A (write-only)
			wea => r.vp.wep,
			waddra => r.vp.waddrp,
			dia => r.vp.wdatap,
			-- port B (read-only)
			--   used for address translations upon READ access to ecc_fp_dram
			--   AND also during permutations
			reb => r.vp.repsh(rdlat),
			addrb => r.trans.read_raddr,
			dob => rphaddr
			-- pragma translate_off
			, vtophys => open
			-- pragma translate_on
		);

	gnd <= '0';
	vcc <= '1';

	-- instance of ecc_fp_dram actual data memory
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
	comb: process(r, rstn, wea, addra, dia, reb, addrb, wphaddr, rphaddr,
		            fprdata, permute, trngdata, trngvalid, swrst)
		-- TODO: complete sensitivity list!
		variable v : reg_type;
		variable v_i_minus_j : unsigned(FP_ADDR downto 0);
		variable vbrlin, vbrl0 : std_logic_vector(FP_ADDR - 1 downto 0);
	begin
		v := r;

		-- (s0), bypassed by (s1), (s4) & (s29)
		v.vp.repsh := '0' & r.vp.repsh(rdlat downto 1); -- (s0)

		-- (s22), bypassed by (s30)
		v.fp.resh := '0' & r.fp.resh(rdlat downto 1); -- (s22)

		v.vp.wep := '0'; -- (s19), bypassed by (s20) & (s21)

		v.fp.we :=  '0'; -- (s25), bypassed by (s26), (s28) & (s31)

		-- (s38), bypassed by (s39) & (s40)
		v.permute.do_brlsel_sh := '0' & r.permute.do_brlsel_sh(2 downto 1); -- (s38)

		-- -------------------------------------------------------------
		--                "normal" access to  ecc_fp_dram
		--                   (using redirection tables)
		--                        [r.state = idle]
		-- -------------------------------------------------------------

		-- shift registers to account for read latency through vp0 & vp1
		-- virtual-to-physical translation memories
		v.trans.write_resh := '0' & r.trans.write_resh(rdlat downto 1);
		v.trans.write_wdatash(rdlat - 1 downto 0) :=
			r.trans.write_wdatash(rdlat downto 1);

		if r.permute.active = '0' then
			-- ---------------------------------------------------------------
			-- service the reads using virtual-to-physical address translation
			-- (through the read port of vp1 memory)
			-- ---------------------------------------------------------------
			v.vp.repsh(rdlat) := reb;
			v.trans.read_raddr := addrb;
			if r.vp.repsh(0) = '1' then
				v.fp.raddr := rphaddr;
				v.fp.resh(rdlat) := '1'; -- (s30), bypass of (s22)
			end if;
			-- ----------------------------------------------------------------
			-- service the writess using virtual-to-physical address translation
			-- (through the read port of vp0 memory)
			-- ----------------------------------------------------------------
			v.trans.write_resh(rdlat) := wea;
			v.trans.write_raddr := addra;
			v.trans.write_wdatash(rdlat) := dia;
			if r.trans.write_resh(0) = '1' then
				v.fp.waddr := wphaddr;
				v.fp.we := '1'; -- (s31), bypass of (s25)
				-- note that (s25) still applies for automatic reset of .we
				v.fp.wdata := r.trans.write_wdatash(0);
			end if;
		end if;

		-- -------------------------------------------------------------
		--                generation of next permutation
		--                    [r.state = permutation]
		-- -------------------------------------------------------------
		if permute = '1' then
			v.permute.active := '1';
			v.permute.rdy := '0';
			v.state := permutation;
			v.permute.i := std_logic_vector(to_unsigned((nblargenb*n) - 1, FP_ADDR));
			v.trans.read_raddr := v.permute.i;
			v.vp.repsh(rdlat) := '1'; -- (s1), bypass of (s0)
			v.permute.trngrdy := '1';
			v.permute.brlcmd := (others => '0');
			v.permute.brlout_sel := (0 => '1', others => '0');
			v.permute.brlout_sel_next := (0 => '1', others => '0');
			v.permute.do_brlsel_sh(2) := '1'; -- (s39), bypass of (s38)
			v.permute.brlhbit := (others => '0');
			v.permute.aofi_read := '0';
			v.permute.fofaofi_read := '0';
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
						& vbrlin(FP_ADDR - 1 downto 2**(2*i));
				elsif r.permute.brlcmd(2*i) = '0' then
					vbrl0 := vbrlin;
				end if;
				--   2nd bit
				if r.permute.brlcmd((2*i) + 1) = '1' then
					vbrl0 :=
						zeros(2**((2*i) + 1))
						& vbrl0(FP_ADDR - 1 downto 2**((2*i) + 1));
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
							& vbrlin(FP_ADDR - 1 downto 2**(2*i));
					elsif r.permute.brlcmd(2*i) = '0' then
						vbrl0 := vbrlin;
					end if;
					--   2nd bit
					if r.permute.brlcmd((2*i) + 1) = '1' then
						vbrl0 :=
							zeros(2**((2*i) + 1))
							& vbrl0(FP_ADDR - 1 downto 2**((2*i) + 1));
					elsif r.permute.brlcmd((2*i) + 1) = '0' then
						null; -- vbrl0 := vbrl0;
					end if;
				else -- odd (statically resolv by synth.)
					if r.permute.brlcmd(2*i) = '1' then
						vbrl0 :=
							zeros(2**(2*i)) & vbrlin(FP_ADDR - 1 downto 2**(2*i));
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
				v.trans.read_raddr := r.permute.brl(i); -- (s18)
				v_i_minus_j := 
					resize(unsigned(r.permute.i), FP_ADDR + 1) -
					resize(unsigned(r.permute.brl(i)), FP_ADDR + 1);
				v.permute.jtoobig := v_i_minus_j(FP_ADDR);
				v.permute.test_j := '1';
				-- TODO: check the effect on synthesis of the 'exit' instruction
				-- below (however since the range of the loop is expected to
				-- be very small (NB_JSH_REG ~ log(log(nn))) there should not be
				-- any problem - this also means that the fan-in of r.vp.raddr0
				-- should remain very low (2 or 3 paths at most)
				exit;
				-- (actually we could also remove the 'exit', because we know
				-- that r.permute.brlsh cannot have more that one bit set at
				-- a time
			end if;
		end loop;

		-- (s5)
		if r.permute.test_j = '1' and r.permute.aofi_read = '1' and
			r.permute.active = '1'
		then
			v.permute.test_j := '0';
			if r.permute.jtoobig = '1' then
				-- means i < j strictly, we must reject i and start again
				-- with another random
				v.permute.trngrdy := '1';
			elsif r.permute.jtoobig = '0' then
				-- means i >= j hence j is a suitable random
				-- if a[i] has already been read, then don't wait to read a[j]
				v.vp.repsh(rdlat) := '1'; -- (s4), bypass of (s0)
				-- pragma translate_off
				v.permute.j := r.trans.read_raddr; -- still valid from  (s18)
				-- pragma translate_on
			end if;
		end if;

		-- read a[i]/a[j] from virt_to_phys (vp0) memory
		if r.vp.repsh(0) = '1' and r.permute.active = '1' then
			if r.permute.aofi_read = '0' then
				v.permute.aofi := rphaddr;
				v.permute.aofi_read := '1';
				-- read f(a[i]), that is the value in ecc_fp_dram at address a[i]
				v.fp.raddr := rphaddr;
				v.fp.resh(rdlat) := '1'; -- read data will be sampled by (s24) below
			elsif r.permute.aofi_read = '1' then
				-- the value currently available (meaning, in this cycle) on bus
				-- rphaddr is a[j], that we can directly set down on bus r.vp.wdatap
				-- (data write into VP memory) to perform action a[i] <- a[j]
				v.vp.wdatap := rphaddr;
				v.vp.wep := '1'; -- (s20), bypass of (s19)
				v.vp.deuce := '1';
				v.vp.waddrp := r.permute.i;
				-- also read f(a[j]), that is the value in ecc_fp_dram at address a[j]
				v.fp.raddr := rphaddr; -- (s27), this is a[j]
				v.fp.resh(rdlat) := '1';
				-- pragma translate_off
				v.permute.aofj := rphaddr;
				v.permute.ok := '1';
				-- pragma translate_on
			end if;
		end if;

		-- write a[j] <- a[i]
		if r.vp.wep = '1' and r.vp.deuce = '1' then
			v.vp.deuce := '0';
			-- a[j] will be available on bus rphaddr in one cycle.
			-- Perform operation a[j] <- a[i] now
			v.vp.wdatap := r.permute.aofi;
			v.vp.wep := '1'; -- (s21), bypass of (s19)
			-- set r.vp.rwaddrp from r.trans.read_raddr, as it still drives
			-- value of 'j' from (s18)
			v.vp.waddrp := r.trans.read_raddr;
		end if;

		-- (s24) read data f(a[j]) from ecc_fp_dram
		if r.fp.resh(0) = '1' and r.permute.active = '1' then
			if r.permute.fofaofi_read = '1' then
				-- this is f(a[j]) which is currently driven on bus prdata
				v.fp.wdata := fprdata;
				v.fp.we := '1'; -- (s28), bypass of (s25)
				v.fp.waddr := r.permute.aofi;
				-- switch to next value of i (next step of the Fisher-Yates algorithm)
				v.permute.i := r.permute.i_next;
				v.permute.brlout_sel := r.permute.brlout_sel_next;
				v.permute.do_brlsel_sh(2) := '1'; -- (s40), bypass of (s38)
				if r.permute.i_next = (r.permute.i_next'range => '0') then
					v.permute.active := '0';
					v.state := idle;
					v.permute.rdy := '1';
				else
					v.trans.read_raddr := r.permute.i_next;
					v.vp.repsh(rdlat) := '1'; -- (s29), bypass of (s0)
					v.permute.trngrdy := '1';
					v.permute.aofi_read := '0';
					v.permute.brlcmd := r.permute.brlcmd_next;
					v.permute.fofaofi_read := '0';
					-- pragma translate_off
					v.permute.ok := '0';
					-- pragma translate_on
				end if;
			elsif r.permute.fofaofi_read = '0' then
				-- this is f(a[i]) which is currently driven on bus fprdata
				v.permute.fofaofi_read := '1';
			end if;
		end if;

		-- compute next values of r.permute.brlcmd & r.permute.brlout_sel
		-- (meaning for the next step i of the Fisher-Yates algorithm)
		v.permute.i_next := std_logic_vector(unsigned(r.permute.i) - 1);
		-- increment of the barrel command input (this is the nb of right-shift
		-- we need to apply to each value j drawn from the random source so as
		-- to increase its likelihood not to be rejected (for the reason that
		-- it would be greater than i) - as Fisher-Yates algorithm requires,
		-- at step i, to draw a random number from 0 to i)
		if (r.permute.i and r.permute.i_next) = (r.permute.i'range => '0') then
			v.permute.brlcmd_next :=
				std_logic_vector(unsigned(r.permute.brlcmd) + 1); -- (s42)
			-- (s41) below will happen only 1 cycle (thx to (s38)) and it will
			-- happen in the cycle where the increment or .brlcmd_next made just
			-- above by (s42), if it was to be done, is done actually. Hence
			-- in this cycle we can test if .brlcmd_next has reached a new power of 2
			if r.permute.do_brlsel_sh(0) = '1' then -- (s41)
				-- the two multiplexers indexed by .brlhbit below should not be
				-- scary as .brlhbit is a very small bit vector ( width ~ log(log()) )
				if r.permute.brlcmd(to_integer(r.permute.brlhbit)) = '0'
					and r.permute.brlcmd_next(to_integer(r.permute.brlhbit)) = '1'
				then
					v.permute.brlout_sel_next := '0' & 
						r.permute.brlout_sel_next(0 to NB_JSH_REG - 1);
					v.permute.brlhbit := r.permute.brlhbit + 2;
				end if;
			end if;
		else
			v.permute.brlcmd_next := r.permute.brlcmd;
		end if;

		if r.fp.resh(1) = '1' and r.permute.fofaofi_read = '1' and
			r.permute.active = '1'
		then
			v.fp.wdata := fprdata; -- that is still f(a[i])
			v.fp.we := '1'; -- (s26), bypass of (s25)
			v.fp.waddr := r.fp.raddr; -- this is a[j], from (s27)
		end if;

		-- synchronous (active low) reset
		if rstn = '0' or swrst = '1' then
			v.state := idle;
			v.vp.wep := '0';
			v.vp.repsh := (others => '0');
			v.fp.resh := (others => '0');
			v.fp.we := '0';
			v.permute.active := '0';
			v.permute.rdy := '1';
			v.permute.trngrdy := '0';
			v.permute.brlsh := (others => '0');
			v.permute.test_j := '0';
			v.vp.deuce := '0';
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
		file output : TEXT open write_mode is "/tmp/shuffling.log";
		variable lineout : line;
	begin
		if clk'event and clk = '1' then
			r_permute_rdy <= r.permute.rdy;
			if r.vp.wep = '1' then
				write(lineout, string'("vp("));
				write(lineout, to_integer(unsigned(r.vp.waddrp)));
				write(lineout, string'(") <- "));
				write(lineout, to_integer(unsigned(r.vp.wdatap)));
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
