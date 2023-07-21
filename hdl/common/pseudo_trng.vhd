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

use work.ecc_log.all;

entity pseudo_trng is
	generic(
		-- width of AXI data bus
		constant C_S_AXI_DATA_WIDTH : integer := 32;
		-- width of AXI address bus
		constant C_S_AXI_ADDR_WIDTH : integer := 4
	);
	port(
		-- AXI clock
		s_axi_aclk : in std_logic;
		-- AXI reset (expected active low, async asserted, sync deasserted) 
		s_axi_aresetn : in std_logic;
		-- AXI write-address channel
		s_axi_awaddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1  downto 0);
		s_axi_awprot : in std_logic_vector(2 downto 0); -- ignored
		s_axi_awvalid : in std_logic;
		s_axi_awready : out std_logic;
		-- AXI write-data channel
		s_axi_wdata : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		s_axi_wstrb : in std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
		s_axi_wvalid : in std_logic;
		s_axi_wready : out std_logic;
		-- AXI write-response channel
		s_axi_bresp : out std_logic_vector(1 downto 0);
		s_axi_bvalid : out std_logic;
		s_axi_bready : in std_logic;
		-- AXI read-address channel
		s_axi_araddr : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
		s_axi_arprot : in std_logic_vector(2 downto 0); -- ignored
		s_axi_arvalid : in std_logic;
		s_axi_arready : out std_logic;
		-- AXI read-data channel
		s_axi_rdata : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
		s_axi_rresp : out std_logic_vector(1 downto 0);
		s_axi_rvalid : out std_logic;
		s_axi_rready : in std_logic;
		-- interrupt (when the FIFO is half empty)
		irq : out std_logic;
		-- data port with handshake signals
		dbgptdata : out std_logic_vector(7 downto 0);
		dbgptvalid : out std_logic;
		dbgptrdy : in std_logic
	);
end entity pseudo_trng;

architecture rtl of pseudo_trng is

	constant FIFO_BYTE_SIZE : natural := 4096;

	-- Following attributes are Xilinx specific but they should not do any harm
	-- on other platforms.
	attribute X_INTERFACE_INFO : string;
	attribute X_INTERFACE_PARAMETER : string;
	attribute X_INTERFACE_INFO of irq : signal is
		"xilinx.com:signal:interrupt:1.0 irq INTERRUPT";
	attribute X_INTERFACE_PARAMETER of irq : signal is "SENSITIVITY EDGE_RISING";

	constant CST_AXI_RESP_OKAY : std_logic_vector(1 downto 0) := "00";

	type reg_axi_type is record
		awpending : std_logic;
		dwpending : std_logic;
		waddr : std_logic_vector(0 downto 0);
		-- Write signals
		awready : std_logic;
		wready : std_logic;
		bvalid : std_logic;
		wdatax : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- AXI W data
		-- Read signals
		arready : std_logic;
		rvalid : std_logic;
		rdatax : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- AXI R data
	end record;

	type state_type is (idle, fifo_pushing);

	type reg_ctrl_type is record
		irq : std_logic;
		irqsh : std_logic_vector(3 downto 0);
		dataout : std_logic_vector(7 downto 0);
		valid : std_logic;
		fifo_count : std_logic_vector(log2(FIFO_BYTE_SIZE) - 1 downto 0);
		state : state_type;
		fifo_empty : std_logic;
	end record;

	type reg_fifo_type is record
		reset : std_logic;
		wdata : std_logic_vector(7 downto 0);
		we : std_logic;
		re, re0, re1 : std_logic;
	end record;

	-- All registers
	type reg_type is record
		axi : reg_axi_type;
		ctrl : reg_ctrl_type;
		fifo : reg_fifo_type;
	end record;

	signal r, rin : reg_type;

	component fifo is
		generic(
			datawidth : natural range 1 to integer'high;
			datadepth : natural range 1 to integer'high);
		port(
			clk : in std_logic;
			rstn : in std_logic;
			swrst : in std_logic;
			datain : in std_logic_vector(datawidth - 1 downto 0);
			we : in std_logic;
			werr : out std_logic;
			full : out std_logic;
			dataout : out std_logic_vector(datawidth - 1 downto 0);
			re : in std_logic;
			empty : out std_logic;
			rerr : out std_logic;
			count : out std_logic_vector(log2(datadepth) - 1 downto 0);
			dbgdeact : in std_logic;
			dbgwaddr : out std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			dbgraddr : in std_logic_vector(log2(datadepth - 1) - 1 downto 0);
			dbgrst : in std_logic
		);
	end component fifo;

	signal fifo_rdata : std_logic_vector(7 downto 0);
	signal fifo_empty : std_logic;
	signal fifo_count : std_logic_vector(log2(FIFO_BYTE_SIZE) - 1 downto 0);
	signal gnd : std_logic;
	signal gnddd : std_logic_vector(log2(FIFO_BYTE_SIZE - 1) - 1 downto 0);

begin

	gnd <= '0';
	gnddd <= (others => '0');

	f0: fifo
		generic map(datawidth => 8, datadepth => FIFO_BYTE_SIZE)
		port map(
			clk => s_axi_aclk,
			rstn => s_axi_aresetn,
			swrst => r.fifo.reset,
			datain => r.fifo.wdata,
			we => r.fifo.we,
			werr => open,
			full => open,
			dataout => fifo_rdata,
			re => r.fifo.re,
			empty => fifo_empty,
			rerr => open,
			count => fifo_count,
			dbgdeact => gnd,
			dbgwaddr => open,
			dbgraddr => gnddd,
			dbgrst => gnd
		);

	-- combinational logic
	comb: process(s_axi_aresetn, r,
	              s_axi_awaddr, s_axi_awprot, s_axi_awvalid,
	              s_axi_wdata, s_axi_wvalid, s_axi_bready,
	              s_axi_araddr, s_axi_arprot, s_axi_arvalid,
	              s_axi_rready,
								dbgptrdy, fifo_rdata, fifo_empty, fifo_count)
		variable v : reg_type;
		variable dw : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
	begin

		v.fifo.we := '0'; -- (s6)

		-- ----------
		-- AXI Writes
		-- ----------

		-- handshake over AXI address-write channel
		if s_axi_awvalid = '1' and r.axi.awready = '1' then
			v.axi.awpending := '1';
			v.axi.waddr := s_axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 3);
			v.axi.awready := '0'; -- (s0), will be reasserted back by (s2)
			v.axi.arready := '0'; -- (s4), will be reasserted back by (s5)
		end if;

		-- handshake over AXI data-write channel
		if s_axi_wvalid = '1' and r.axi.wready = '1' then
			v.axi.dwpending := '1';
			v.axi.wdatax := s_axi_wdata;
			v.axi.wready := '0'; -- (s1), will be reasserted back by (s3)
		end if;

		-- handshake over AXI write-response channel
		if r.axi.bvalid = '1' and s_axi_bready = '1' then
			v.axi.bvalid := '0';
		end if;

		-- -----------------------------------------------------------
		-- r.axi.awpending & r.axi.dwpending both HIGH: new write-beat
		-- -----------------------------------------------------------
		v.fifo.reset := '0';
		if r.axi.awpending = '1' and r.axi.dwpending = '1' then
			v.axi.awpending := '0';
			v.axi.dwpending := '0';
			if r.axi.waddr(0) = '0' then -- 0x00
				-- this is the W_SOFT_RESET register
				v.fifo.reset := '1';
			elsif r.axi.waddr(0) = '1' then -- 0x08
				-- This is the W_WRITE_DATA register.
				-- We do not control if the fifo is full: since the software
				-- has access to the data count, see (s10), it can adjust the
				-- quantity it writes.
				v.fifo.wdata := r.axi.wdatax(7 downto 0);
				v.fifo.we := '1'; -- asserted only 1 cycle thx to (s6)
			end if;
			-- assert both AWREADY & WREADY signals to allow a new AXI data-beat
			-- to happen again
			v.axi.awready := '1'; -- (s2), had been deasserted by (s0)
			v.axi.wready := '1'; -- (s3), had been deasserted by (s1)
			v.axi.arready := '1'; -- (s5), had been deasserted by (s4)
			-- drive write-response to initiator
			v.axi.bvalid := '1';
		end if;

		-- ---------
		-- AXI Reads
		-- ---------

		-- handshake over AXI address-read channel
		if s_axi_arvalid = '1' and r.axi.arready = '1' then
			-- By immediately deasserting r.axi.arready (which directly drives
			-- s_axi_arready) in (s7) below, we're telling AXI fabric that
			-- we're not ready to accept a new read address again.
			-- Signal s_axi_arready will be reasserted upon actual transfer
			-- of the 32-bit data on the AXI read-data channel, see (s8) below
			v.axi.arready := '0'; -- (s7), will be reasserted by (s8)
			-- There's no need to decode the AXI read address as there's only
			-- one read register (R_FIFO_COUNT) - (s10)
			dw := std_logic_vector(resize(unsigned(fifo_count), C_S_AXI_DATA_WIDTH));
			v.axi.rdatax := dw;
			v.axi.rvalid := '1';
		end if;

		-- handshake over AXI data-read channel
		if r.axi.rvalid = '1' and s_axi_rready = '1' then
			v.axi.rvalid := '0';
			-- tell AXI fabric that our AXI address-read channel is ready
			-- to accept a new address again
			v.axi.arready := '1'; -- (s8), had been deasserted by (s7)
			-- pragma translate_off
			v.axi.rdatax := (others => 'X');
			-- pragma translate_on
		end if;

		-- --------------------------------------------
		-- logic constantly pulling bytes from the FIFO
		-- --------------------------------------------

		v.fifo.re := '0'; -- (s9)

		if r.ctrl.state = idle and fifo_empty = '0' then
			v.fifo.re := '1'; -- asserted only 1 cycle thx to (s9)
			v.ctrl.state := fifo_pushing;
		end if;

		v.fifo.re0 := r.fifo.re;
		v.fifo.re1 := r.fifo.re0;

		-- Sample output data from the FIFO.
		if r.fifo.re1 = '1' then
			v.ctrl.dataout := fifo_rdata;
			v.ctrl.valid := '1';
		end if;

		-- Handshake with the external pseudo-random consumer
		if r.ctrl.valid = '1' and dbgptrdy = '1' then
			v.ctrl.valid := '0';
			v.ctrl.state := idle;
		end if;

		-- --------------
		-- Irq generation
		-- --------------

		-- Interrupt, once raised, lasts 4 cycles.
		v.ctrl.irqsh := '0' & r.ctrl.irqsh(3 downto 1);
		if r.ctrl.irqsh(0) = '1' then
			v.ctrl.irq := '0';
		end if;

		v.ctrl.fifo_count := fifo_count;
		v.ctrl.fifo_empty := fifo_empty;

		if (r.ctrl.fifo_count(fifo_count'length - 1) = '1' and
			fifo_count(fifo_count'length - 1) = '0')
			-- The nb of bytes in the FIFO has just passed below its half
			-- threshold, generate an irq so that software/producer push
			-- more data.
		or (r.ctrl.fifo_empty = '0' and fifo_empty = '1')
			-- The FIFO just turned empty.
			-- (It is possible that the FIFO turned out empty without
			-- having passed the half threeshold in the top-down direction,
			-- if it had not passed it in the bottom-up direction to begin
			-- with, and in this case the empty flag is used to trigger
			-- the Irq).
		then
			v.ctrl.irqsh(3) := '1';
			v.ctrl.irq := '1';
		end if;

		-- Synchronous (active low) reset
		if s_axi_aresetn = '0' then
			v.axi.awpending := '0';
			v.axi.dwpending := '0';
			v.axi.awready := '1';
			v.axi.wready := '1';
			v.axi.bvalid := '0';
			v.axi.rvalid := '0';
			v.axi.arready := '1';
			v.ctrl.irq := '0';
			v.ctrl.valid := '0';
			v.fifo.reset := '0';
			v.fifo.we := '0';
			v.fifo.re0 := '0';
			v.fifo.re1 := '0';
			v.fifo.re := '0';
			v.ctrl.irq := '0';
			v.ctrl.state := idle;
		end if;

		rin <= v;
	end process comb;

	-- registers, clocked by s_axi_aclk
	regs : process(s_axi_aclk)
	begin
		if s_axi_aclk'event and s_axi_aclk = '1' then
			r <= rin;
		end if;
	end process regs;

	-- --------------------
	-- drive output signals
	-- --------------------

	-- to external AXI interface
	s_axi_awready <= r.axi.awready;
	s_axi_wready <= r.axi.wready;
	s_axi_bresp <= CST_AXI_RESP_OKAY;
	s_axi_bvalid <= r.axi.bvalid;
	s_axi_arready <= r.axi.arready;
	s_axi_rdata <= r.axi.rdatax;
	s_axi_rresp <= CST_AXI_RESP_OKAY;
	s_axi_rvalid <= r.axi.rvalid;

	-- interrupt
	irq <= r.ctrl.irq;

	-- data & handshake with the external pseudo-random consumer
	dbgptdata <= r.ctrl.dataout;
	dbgptvalid <= r.ctrl.valid;

end architecture rtl;
