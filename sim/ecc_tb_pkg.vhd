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
use work.ecc_tb_vec.all; -- for 'curve_param_type'

use std.textio.all;

package ecc_tb_pkg is

	-- width of AXI data buses
	constant AXIDW : integer := 32;

	type axi_in_type is record
		-- in
		aclk :  std_logic;
		aresetn : std_logic; -- asyn asserted, syn deasserted, active low
		awaddr : std_logic_vector(AXIAW - 1 downto 0);
		awprot : std_logic_vector(2 downto 0); -- ignored
		awvalid : std_logic;
		wdata : std_logic_vector(AXIDW - 1 downto 0);
		wstrb : std_logic_vector((AXIDW / 8) - 1 downto 0);
		wvalid : std_logic;
		bready : std_logic;
		araddr : std_logic_vector(AXIAW - 1 downto 0);
		arprot : std_logic_vector(2 downto 0); -- ignored
		arvalid : std_logic;
		rready : std_logic;
	end record;
	type axi_out_type is record
		-- out
		awready : std_logic;
		wready : std_logic;
		bresp : std_logic_vector(1 downto 0);
		bvalid : std_logic;
		arready : std_logic;
		rdata : std_logic_vector(AXIDW - 1 downto 0);
		rresp : std_logic_vector(1 downto 0);
		rvalid : std_logic;
	end record;

	type curve_param_addr_type is
		array(integer range 0 to 3) of integer;
	constant CURVE_PARAM_ADDR : curve_param_addr_type :=
		(0 => LARGE_NB_P_ADDR,
		 1 => LARGE_NB_A_ADDR,
		 2 => LARGE_NB_B_ADDR,
		 3 => LARGE_NB_Q_ADDR);

	procedure poll_until_ready(signal clk : in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	procedure set_nn(signal clk : in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type;
	                 constant valnn : in positive);

	procedure write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant val : in std_logic_vector);

	procedure debug_write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant val : in std_logic_vector);

	procedure configure_shuffle(signal clk: in std_logic;
	                            signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            constant sh : in boolean);

	procedure configure_irq(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
	                        constant irq : in boolean);

	procedure configure_blinding(signal clk: in std_logic;
	                             signal axi: out axi_in_type;
	                             signal axo: in axi_out_type;
	                             constant blind : in boolean;
	                             constant blindbits : in natural);

	procedure write_scalar(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant val : in std_logic_vector);

	procedure run_kp(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type);

	procedure scalar_mult(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type;
	                      constant valnn : in positive;
	                      constant scalar : in std_logic_vector;
	                      constant xx : in std_logic_vector;
	                      constant yy : in std_logic_vector);

	procedure check_if_r0_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean);

	procedure check_if_r1_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean);

	procedure check_and_display_if_r0_r1_null(signal clk: in std_logic;
	                                          signal axi: out axi_in_type;
	                                          signal axo: in axi_out_type);

	procedure display_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type);

	procedure read_big(signal clk: in std_logic;
	                   signal axi: out axi_in_type;
	                   signal axo: in axi_out_type;
	                   constant valnn: in positive;
	                   constant addr : in natural range 0 to nblargenb - 1;
	                   variable bignb: inout std_logic_vector);

	procedure debug_read_big(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type;
	                         constant valnn: in positive;
	                         constant addr : in natural range 0 to nblargenb - 1;
	                         variable bignb: inout std_logic_vector);

	procedure read_and_display_kp_result(signal clk: in std_logic;
	                                     signal axi: out axi_in_type;
	                                     signal axo: in axi_out_type;
	                                     constant valnn: in positive);

	procedure ack_all_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type);

	procedure set_curve(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant size: in positive;
	                    constant curve: curve_param_type);

	procedure set_r0_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type);

	procedure set_r0_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type);

	procedure set_r1_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type);

	procedure set_r1_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type);

	procedure run_point_add(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type);

	procedure point_add(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : positive;
	                    constant x0 : in std_logic_vector;
	                    constant y0 : in std_logic_vector;
	                    constant x1 : in std_logic_vector;
	                    constant y1 : in std_logic_vector;
	                    constant z0 : in boolean;
	                    constant z1 : in boolean);

	procedure read_and_display_ptadd_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);

	procedure run_point_double(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	procedure point_double(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant x : in std_logic_vector;
	                       constant y : in std_logic_vector;
	                       constant z : in boolean);

	procedure read_and_display_ptdbl_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);
	
	procedure run_point_negate(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	procedure point_negate(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn: in positive;
	                       constant x: in std_logic_vector;
	                       constant y: in std_logic_vector; 
	                       constant z: in boolean);

	procedure read_and_display_ptneg_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);

	procedure run_point_test_equal(signal clk: in std_logic;
	                               signal axi: out axi_in_type;
	                               signal axo: in axi_out_type);

	procedure point_test_equal(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           constant valnn : positive;
	                           constant x0 : in std_logic_vector;
	                           constant y0 : in std_logic_vector;
	                           constant x1 : in std_logic_vector;
	                           constant y1 : in std_logic_vector;
	                           constant z0 : in boolean;
	                           constant z1 : in boolean);

	procedure check_test_answer(signal clk: in std_logic;
                              signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            variable yes_or_no: out boolean;
	                            variable answer_right: out boolean);

	procedure read_and_display_pttest_result(signal clk: in std_logic;
                                           signal axi: out axi_in_type;
	                                         signal axo: in axi_out_type;
	                                         constant valnn: in positive);

	procedure set_one_breakpoint(signal clk: in std_logic;
                               signal axi: out axi_in_type;
	                             signal axo: in axi_out_type;
	                             constant id: in natural;
	                             constant addr: in std_logic_vector(8 downto 0);
	                             constant state: in std_logic_vector(3 downto 0);
	                             constant nbbits: in natural);
	
	procedure poll_until_debug_halted(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type);

	procedure resume(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type);

	procedure read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1);

	procedure debug_read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1);

end package ecc_tb_pkg;

package body ecc_tb_pkg is

	-- -------------------------------------------------------------
	-- emulate SW polling the R_STATUS register until it shows ready
	-- -------------------------------------------------------------
	procedure poll_until_ready(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type) is
	begin
		loop
			wait until clk'event and clk = '1';
			-- read R_STATUS register
			axi.araddr <= R_STATUS & "000";
			axi.arvalid <= '1';
			wait until clk'event and clk = '1' and axo.arready = '1';
			axi.araddr <= "XXXXXXXX";
			axi.arvalid <= '0';
			axi.rready <= '1';
			wait until clk'event and clk = '1' and axo.rvalid = '1';
			axi.rready <= '0';
			if axo.rdata(STATUS_BUSY) = '0' then
				-- means bit 'busy' is deasserted
				exit;
			end if;
		end loop;
	end procedure;

	-- -------------------------------------------------
	-- emulate SW writing prime size (nn)
	--   (option nn_dynamic = TRUE in ecc_customize.vhd)
	-- -------------------------------------------------
	procedure set_nn(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type;
	                 constant valnn : in positive) is
	begin
		wait until clk'event and clk = '1';
		-- write W_PRIME_SIZE register
		axi.awaddr <= W_PRIME_SIZE & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		axi.wdata <= std_logic_vector(to_unsigned(valnn, AXIDW));
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -----------------------------------
	-- emulate SW writing one large number (but the scalar)
	-- -----------------------------------
	procedure write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant val : in std_logic_vector) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		poll_until_ready(clk, axi, axo);
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_WRITE_NB) := '1';
		dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
			:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X');
		axi.wvalid <= '0';
		-- now perform the proper nb of writes of the W_WRITE_DATA register
		for i in 0 to div(valnn,AXIDW) - 1 loop
			poll_until_ready(clk, axi, axo);
			axi.awaddr <= W_WRITE_DATA & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
			axi.wdata <= val((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		end loop;
	end procedure;

	-- ------------------------------------------------------------------
	-- Identical to write_big, except that here debug mode
	-- is assumed, hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we'd create a deadlock if the IP was halted)
	-- ------------------------------------------------------------------
	procedure debug_write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant val : in std_logic_vector) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_WRITE_NB) := '1';
		dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
			:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X');
		axi.wvalid <= '0';
		-- now perform the proper nb of writes of the W_WRITE_DATA register
		for i in 0 to div(valnn,AXIDW) - 1 loop
			wait until clk'event and clk = '1';
			axi.awaddr <= W_WRITE_DATA & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
			axi.wdata <= val((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		end loop;
	end procedure;
	-- ------------------------------
	-- emulate SW configuring shuffle
	-- ------------------------------
	procedure configure_shuffle(signal clk: in std_logic;
	                            signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            constant sh : in boolean) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		axi.awaddr <= W_SHUFFLE & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		if sh then dw(SHF_EN) := '1'; end if;
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------
	-- emulate SW configuring IRQ
	-- --------------------------
	procedure configure_irq(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
	                        constant irq : in boolean) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		axi.awaddr <= W_IRQ & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		if irq then dw(IRQ_EN) := '1'; end if;
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------
	-- emulate SW configuring blinding
	-- -------------------------------
	procedure configure_blinding(signal clk: in std_logic;
	                             signal axi: out axi_in_type;
	                             signal axo: in axi_out_type;
	                             constant blind : in boolean;
	                             constant blindbits : in natural) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_BLINDING register
		axi.awaddr <= W_BLINDING & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		if blind then dw(BLD_EN) := '1'; end if;
		assert (blindbits <= nn)
			report "nb of blinding bits to large"
				severity FAILURE;
		dw(BLD_BITS_MSB downto BLD_BITS_LSB) := std_logic_vector(
			to_unsigned(blindbits, log2(nn)));
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------------------------
	-- emulate SW writing the large number of the scalar
	-- -------------------------------------------------
	procedure write_scalar(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant val : in std_logic_vector) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_WRITE_NB) := '1';
		dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB) := CST_ADDR_K;
		dw(CTRL_WRITE_K) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		-- now perform the proper nb of writes of the DATA register
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		for i in 0 to div(valnn,AXIDW) - 1 loop
			for j in 0 to 63 loop
				wait until clk'event and clk = '1';
			end loop;
			axi.awaddr <= W_WRITE_DATA & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
			axi.wdata <= val((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- ------------------------------------------------
	-- emulate SW issuing command 'do [k]P-computation'
	-- ------------------------------------------------
	procedure run_kp(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_KP) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ---------------------------------------------------------------------
	-- emulate SW writing base-point & scalar and give [k]P computation a go
	-- ---------------------------------------------------------------------
	procedure scalar_mult(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type;
	                      constant valnn : in positive;
	                      constant scalar : in std_logic_vector;
	                      constant xx : in std_logic_vector;
	                      constant yy : in std_logic_vector) is
	begin
		-- write base-point's X & Y coordinates
		poll_until_ready(clk, axi, axo);
		write_scalar(clk, axi, axo, valnn, scalar);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, 6, xx);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, 7, yy);
		-- give [k]P computation a go
		poll_until_ready(clk, axi, axo);
		run_kp(clk, axi, axo);
	end procedure;

	-- -------------------------------------------
	-- emulate SW checking if R0 is the null point
	-- -------------------------------------------
	procedure check_if_r0_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean) is
	begin
		wait until clk'event and clk = '1';
		-- read R_STATUS register
		axi.araddr <= R_STATUS & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		-- decode content of R_STATUS register
		if axo.rdata(STATUS_R0_IS_NULL) = '1' then
			isnull := TRUE;
		elsif axo.rdata(STATUS_R0_IS_NULL) = '0' then
			isnull := FALSE;
		else
			report "invalid state for R0 point"
				severity FAILURE;
		end if;
	end procedure;

	-- -------------------------------------------
	-- emulate SW checking if R1 is the null point
	-- -------------------------------------------
	procedure check_if_r1_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean) is
	begin
		wait until clk'event and clk = '1';
		-- read R_STATUS register
		axi.araddr <= R_STATUS & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		-- decode content of R_STATUS register
		if axo.rdata(STATUS_R1_IS_NULL) = '1' then
			isnull := TRUE;
		elsif axo.rdata(STATUS_R1_IS_NULL) = '0' then
			isnull := FALSE;
		else
			report "invalid state for R1 point"
				severity FAILURE;
		end if;
	end procedure;

	-- ------------------------------------------------------------
	-- emulate SW checking if R0/R1 is pt 0 & display it on console
	-- ------------------------------------------------------------
	procedure check_and_display_if_r0_r1_null(signal clk: in std_logic;
	                                          signal axi: out axi_in_type;
	                                          signal axo: in axi_out_type) is
		variable vz0, vz1 : boolean;
		variable vz : std_logic_vector(1 downto 0);
	begin
		check_if_r0_null(clk, axi, axo, vz0);
		if vz0 then
			vz(0) := '1';
		else
			vz(0) := '0';
		end if;
		check_if_r1_null(clk, axi, axo, vz1);
		if vz1 then
			vz(1) := '1';
		else
			vz(1) := '0';
		end if;
		case vz is
			when "00" => echol("ECC_TB: (R0,R1) = (not0, not0)");
			when "01" => echol("ECC_TB: (R0,R1) = (0, not0)");
			when "10" => echol("ECC_TB: (R0,R1) = (not0, 0)");
			when "11" => echol("ECC_TB: (R0,R1) = (0, 0)");
			when others =>
				echol(string'("ECC_TB: undefined state for R0 or R1" &
							" in R_STATUS register"));
		end case;
	end procedure;

	-- ----------------------------------------------------------
	-- emulate SW checking if any error & display them on console
	-- ----------------------------------------------------------
	procedure display_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type) is
	begin
		wait until clk'event and clk = '1';
		-- read R_STATUS register
		axi.araddr <= R_STATUS & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		if axo.rdata(STATUS_ERR_COMP) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_COMP error");
		end if;
		if axo.rdata(STATUS_ERR_WREG_FBD) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_WREG_FBD error");
		end if;
		if axo.rdata(STATUS_ERR_KP_FBD) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_KP_FBD error");
		end if;
		if axo.rdata(STATUS_ERR_NNDYN) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_NNDYN error");
		end if;
		if axo.rdata(STATUS_ERR_POP_FBD) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_POP_FBD error");
		end if;
		if axo.rdata(STATUS_ERR_RDNB_FBD) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_RDNB_FBD error");
		end if;
		if axo.rdata(STATUS_ERR_BLN) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_BLN error");
		end if;
		if axo.rdata(STATUS_ERR_UNKNOWN_REG) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_UNKNOWN_REG error");
		end if;
		if axo.rdata(STATUS_ERR_IN_PT_NOT_ON_CURVE) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_IN_PT_NOT_ON_CURVE error");
		end if;
		if axo.rdata(STATUS_ERR_OUT_PT_NOT_ON_CURVE) = '1' then
			echol("ECC_TB: R_STATUS shows STATUS_ERR_OUT_PT_NOT_ON_CURVE error");
		end if;
		wait until clk'event and clk = '1';
	end procedure;

	-- -----------------------------------
	-- emulate SW reading one large number
	-- -----------------------------------
	procedure read_big(signal clk: in std_logic;
	                   signal axi: out axi_in_type;
	                   signal axo: in axi_out_type;
	                   constant valnn: in positive;
	                   constant addr : in natural range 0 to nblargenb - 1;
	                   variable bignb: inout std_logic_vector) is
		variable tup, xup : integer;
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		poll_until_ready(clk, axi, axo);
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_READ_NB) := '1';
		dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
			:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		-- now perform the exact required nb of reads of the DATA register
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		for i in 0 to div(valnn,AXIDW) - 1 loop
			axi.araddr <= R_READ_DATA & "000"; axi.arvalid <= '1';
			wait until clk'event and clk = '1' and axo.arready = '1';
			axi.araddr <= "XXXXXXXX"; axi.arvalid <= '0'; axi.rready <= '1';
			wait until clk'event and clk = '1' and axo.rvalid = '1';
			if ((i+1) * AXIDW) > bignb'length then
				tup := bignb'length - 1;
				xup := bignb'length mod AXIDW - 1;
				assert FALSE
					report "ecc_tb: error while reading back big number"
						severity WARNING;
			else
				tup := ((i+1) * AXIDW) - 1;
				xup := AXIDW - 1;
			end if;
			bignb(tup downto i * AXIDW) := axo.rdata(xup downto 0);
			axi.rready <= '0';
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- ------------------------------------------------------------------
	-- Identical to read_big, except that here debug mode is assumed,
	-- hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we'd create a deadlock if the IP was halted)
	-- ------------------------------------------------------------------
	procedure debug_read_big(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type;
	                         constant valnn: in positive;
	                         constant addr : in natural range 0 to nblargenb - 1;
	                         variable bignb: inout std_logic_vector) is
		variable tup, xup : integer;
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_READ_NB) := '1';
		dw(CTRL_NBADDR_LSB + FP_ADDR_MSB - 1 downto CTRL_NBADDR_LSB)
			:= std_logic_vector(to_unsigned(addr, FP_ADDR_MSB));
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		-- now perform the exact required nb of reads of the DATA register
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		for i in 0 to div(valnn,AXIDW) - 1 loop
			axi.araddr <= R_READ_DATA & "000"; axi.arvalid <= '1';
			wait until clk'event and clk = '1' and axo.arready = '1';
			axi.araddr <= "XXXXXXXX"; axi.arvalid <= '0'; axi.rready <= '1';
			wait until clk'event and clk = '1' and axo.rvalid = '1';
			if ((i+1) * AXIDW) > bignb'length then
				tup := bignb'length - 1;
				xup := bignb'length mod AXIDW - 1;
				assert FALSE
					report "ecc_tb: error while reading back big number"
						severity WARNING;
			else
				tup := ((i+1) * AXIDW) - 1;
				xup := AXIDW - 1;
			end if;
			bignb(tup downto i * AXIDW) := axo.rdata(xup downto 0);
			axi.rready <= '0';
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------------
	-- emulate SW reading [k]P result's coordinates
	-- --------------------------------------------
	procedure read_and_display_kp_result(signal clk: in std_logic;
	                                     signal axi: out axi_in_type;
	                                     signal axo: in axi_out_type;
	                                     constant valnn: in positive) is
		variable kpx : std_logic512 := (others => '0');
		variable kpy : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
	begin
		kpx := (others => '0');
		kpy := (others => '0');
		read_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, kpx);
		read_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, kpy);
		xmsb := kpx'high;
		for i in kpx'high downto 0 loop
			if kpx(i) /= '0' then
				exit;
			end if;
			xmsb := xmsb - 1;
		end loop;
		if xmsb <= 0 then
			echol("ECC_TB: found no high bit in [k]P.x");
			xmsb := valnn;
		end if;
		ymsb := kpy'high;
		for i in kpy'high downto 0 loop
			if kpy(i) /= '0' then
				exit;
			end if;
			ymsb := ymsb - 1;
		end loop;
		if ymsb <= 0 then
			echol("ECC_TB: found no high bit in [k]P.y");
			ymsb := valnn;
		end if;
		echo("ECC_TB: read-back on AXI interface: [k]P.x = 0x");
		hex_echol(kpx(max(xmsb, ymsb) downto 0));
		echo("ECC_TB: read-back on AXI interface: [k]P.y = 0x");
		hex_echol(kpy(max(xmsb, ymsb) downto 0));
	end procedure;

	-- -----------------------------------
	-- emulate SW acknowledging all errors
	-- -----------------------------------
	procedure ack_all_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_ERR_ACK register
		axi.awaddr <= W_ERR_ACK & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
		dw := (others => '0');
		dw(31 downto STATUS_ERR_COMP) := (others => '1');
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X');
		axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ---------------------------------------
	-- emulate SW setting all curve parameters
	-- ---------------------------------------
	procedure set_curve(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant size: in positive;
	                    constant curve: curve_param_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		for i in 0 to 3 loop
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, size, CURVE_PARAM_ADDR(i), curve(i));
		end loop;
	end procedure;

	-- -----------------------------------------
	-- emulate SW setting R0 to be the null point
	-- -----------------------------------------
	procedure set_r0_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_R0_NULL register
		axi.awaddr <= W_R0_NULL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(WR0_IS_NULL) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ----------------------------------------------
	-- emulate SW setting R0 NOT to be the null point
	-- ----------------------------------------------
	procedure set_r0_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_R0_NULL register
		axi.awaddr <= W_R0_NULL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(WR0_IS_NULL) := '0';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ------------------------------------------
	-- emulate SW setting R1 to be the null point
	-- ------------------------------------------
	procedure set_r1_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_R1_NULL register
		axi.awaddr <= W_R1_NULL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(WR1_IS_NULL) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ----------------------------------------------
	-- emulate SW setting R1 NOT to be the null point
	-- ----------------------------------------------
	procedure set_r1_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_R1_NULL register
		axi.awaddr <= W_R1_NULL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(WR1_IS_NULL) := '0';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ----------------------------------------------
	-- emulate SW issuing command 'do point-addition'
	-- ----------------------------------------------
	procedure run_point_add(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_ADD) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------------------------------------------
	-- emulate SW writing coords of two points to add and giving computation a go
	-- --------------------------------------------------------------------------
	procedure point_add(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
		                  constant valnn : in positive;
		                  constant x0 : in std_logic_vector;
	                    constant y0 : in std_logic_vector;
		                  constant x1 : in std_logic_vector;
	                    constant y1 : in std_logic_vector;
		                  constant z0 : in boolean;
	                    constant z1 : in boolean) is
	begin
		-- write two points' X & Y coordinates
		if not z0 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 4, x0);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 5, y0);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		if not z1 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 6, x1);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 7, y1);
			poll_until_ready(clk, axi, axo);
			set_r1_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r1_null(clk, axi, axo);
		end if;
		-- give P + Q computation a go
		poll_until_ready(clk, axi, axo);
		run_point_add(clk, axi, axo);
	end procedure;

	-- ---------------------------------------------------------------------
	-- emulate SW reading result coords after point-add & display on console
	-- ---------------------------------------------------------------------
	procedure read_and_display_ptadd_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		check_if_r1_null(clk, axi, axo, vz1);
		if vz1 then
			echol("ECC_TB: P+Q = 0");
		else
			pax := (others => '0');
			pay := (others => '0');
			read_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, pax);
			read_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, pay);
			xmsb := pax'high;
			for i in pax'high downto 0 loop
				if pax(i) /= '0' then
					exit;
				end if;
				xmsb := xmsb - 1;
			end loop;
			assert (xmsb > 0)
				report "X-coordinate of point-addition result seems to equal 0"
					severity WARNING;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			assert (ymsb > 0)
				report "Y-coordinate of point-addition result seems to equal 0"
					severity WARNING;
			echo("ECC_TB: read-back on AXI interface: (P+Q).x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: (P+Q).y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if;
	end procedure;

	-- ----------------------------------------------
	-- emulate SW issuing command 'do point-doubling'
	-- ----------------------------------------------
	procedure run_point_double(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_DBL) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------------------------------------------
	-- emulate SW writing coords of a point to double and giving computation a go
	-- --------------------------------------------------------------------------
	procedure point_double(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant x : in std_logic_vector;
	                       constant y : in std_logic_vector;
	                       constant z : in boolean) is
	begin
		-- write point's X & Y coordinates
		if not z then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 4, x);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 5, y);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		-- give [2]P computation a go
		poll_until_ready(clk, axi, axo);
		run_point_double(clk, axi, axo);
	end procedure;

	-- --------------------------------------------------------------------------
	-- emulate SW reading result's coords after point-double & display on console
	-- --------------------------------------------------------------------------
	procedure read_and_display_ptdbl_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		check_if_r1_null(clk, axi, axo, vz1);
		if vz1 then
			echol("ECC_TB: [2]P = 0");
		else
			pax := (others => '0');
			pay := (others => '0');
			read_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, pax);
			read_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, pay);
			xmsb := pax'high;
			for i in pax'high downto 0 loop
				if pax(i) /= '0' then
					exit;
				end if;
				xmsb := xmsb - 1;
			end loop;
			assert (xmsb > 0)
				report "X-coordinate of point-doubling result seems to equal 0"
					severity WARNING;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			assert (ymsb > 0)
				report "Y-coordinate of point-doubling result seems to equal 0"
					severity WARNING;
			echo("ECC_TB: read-back on AXI interface: [2]P.x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: [2]P.y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if;
	end procedure;

	-- --------------------------------------------
	-- emulate SW issuing command 'do point-negate'
	-- --------------------------------------------
	procedure run_point_negate(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_NEG) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ---------------------------------------------------------------------------
	-- emulate SW writing coords of point to negate (-P) and give computation a go
	-- ---------------------------------------------------------------------------
	procedure point_negate(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn: in positive;
	                       constant x: in std_logic_vector;
	                       constant y: in std_logic_vector; 
	                       constant z: in boolean) is
	begin
		-- write point's X & Y coordinates
		if not z then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 4, x);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 5, y);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		-- give -P computation a go
		poll_until_ready(clk, axi, axo);
		run_point_negate(clk, axi, axo);
	end procedure;

	-- ------------------------------------------------------------------------
	-- emulate SW reading result coords after point-negate & display on console
	-- ------------------------------------------------------------------------
	procedure read_and_display_ptneg_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		check_if_r1_null(clk, axi, axo, vz1);
		if vz1 then
			echol("ECC_TB: -P = 0");
		else
			pax := (others => '0');
			pay := (others => '0');
			read_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, pax);
			read_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, pay);
			xmsb := pax'high;
			for i in pax'high downto 0 loop
				if pax(i) /= '0' then
					exit;
				end if;
				xmsb := xmsb - 1;
			end loop;
			assert (xmsb > 0)
				report "X-coordinate of opposite-point result seems to equal 0"
					severity WARNING;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			assert (ymsb > 0)
				report "Y-coordinate of opposite-point result seems to equal 0"
					severity WARNING;
			echo("ECC_TB: read-back on AXI interface: (-P).x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: (-P).y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if;
	end procedure;

	-- -------------------------------------------
	-- emulate SW issuing command 'do P == Q test'
	-- -------------------------------------------
	procedure run_point_test_equal(signal clk: in std_logic;
	                               signal axi: out axi_in_type;
	                               signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_EQU) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------------------------------
	-- emulate SW writing coords of 2 points to compare (P==Q)
	-- and giving computation a go
	-- -------------------------------------------------------
	procedure point_test_equal(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           constant valnn : positive;
	                           constant x0 : in std_logic_vector;
	                           constant y0 : in std_logic_vector;
	                           constant x1 : in std_logic_vector;
	                           constant y1 : in std_logic_vector;
	                           constant z0 : in boolean;
	                           constant z1 : in boolean) is
	begin
		-- write point's X & Y coordinates
		if not z0 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 4, x0);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 5, y0);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		if not z1 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 6, x1);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, 7, y1);
			poll_until_ready(clk, axi, axo);
			set_r1_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r1_null(clk, axi, axo);
		end if;
		-- give P==Q test computation a go
		poll_until_ready(clk, axi, axo);
		run_point_test_equal(clk, axi, axo);
	end procedure;

	-- --------------------------------------------------------------
	-- emulate SW getting answer to a test it's asked on R0 and/or R1
	-- --------------------------------------------------------------
	procedure check_test_answer(signal clk: in std_logic;
                              signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            variable yes_or_no: out boolean;
	                            variable answer_right: out boolean) is
	begin
		wait until clk'event and clk = '1';
		-- read R_STATUS register
		axi.araddr <= R_STATUS & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		if axo.rdata(STATUS_YES) = '1' then
			yes_or_no := TRUE;
		else
			yes_or_no := FALSE;
		end if;
		answer_right := TRUE;
	end procedure;

	-- ----------------------------------
	-- same thing with display on console
	-- ----------------------------------
	procedure read_and_display_pttest_result(signal clk: in std_logic;
                                           signal axi: out axi_in_type;
	                                         signal axo: in axi_out_type;
	                                         constant valnn: in positive) is
		variable yes_or_no, answer_right : boolean;
	begin
		check_test_answer(clk, axi, axo, yes_or_no, answer_right);
		if answer_right then
			if yes_or_no then
				echol("ECC_TB: answer is YES");
			else
				echol("ECC_TB: answer is NO");
			end if;
		else
			echol("ECC_TB: no answer :/");
		end if;
	end procedure;

	-- -------------------------------
	-- emulate SW setting a breakpoint (debug feature)
	-- -------------------------------
	procedure set_one_breakpoint(signal clk: in std_logic;
                               signal axi: out axi_in_type;
	                             signal axo: in axi_out_type;
	                             constant id: in natural;
	                             constant addr: in std_logic_vector(8 downto 0);
	                             constant state: in std_logic_vector(3 downto 0);
	                             constant nbbits: in natural) is
	begin
		-- write W_DBG_BKPT register
		axi.awaddr <= W_DBG_BKPT & "000";
		axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX";
		axi.awvalid <= '0';
		axi.wdata(31 downto 28) <= state(3 downto 0);
		axi.wdata(27 downto 16) <= std_logic_vector(to_unsigned(nbbits, 12));
		axi.wdata(15 downto 13) <= "000";
		axi.wdata(12 downto 4) <= addr(8 downto 0);
		axi.wdata(3) <= '0';
		axi.wdata(2 downto 1) <= std_logic_vector(to_unsigned(id, 2));
		axi.wdata(0) <= '1';
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X');
		axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------------------------------------------------
	-- emulate SW polling R_DBG_STATUS until it shows IP is halted (debug feat.)
	-- -------------------------------------------------------------------------
	procedure poll_until_debug_halted(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type) is
		variable tmp : integer;
	begin
		loop
			-- read R_DBG_STATUS register
			axi.araddr <= R_DBG_STATUS & "000";
			axi.arvalid <= '1';
			wait until clk'event and clk = '1' and axo.arready = '1';
			axi.araddr <= "XXXXXXXX";
			axi.arvalid <= '0';
			axi.rready <= '1';
			wait until clk'event and clk = '1' and axo.rvalid = '1';
			axi.rready <= '0';
			if axo.rdata(0) = '1' then
				echo("ECC_TB: IP halted: PC=0x");
				hex_echo(axo.rdata(12 downto 4));
				echo(" [bkpt #");
				tmp := to_integer(unsigned(axo.rdata(2 downto 1)));
				echo(integer'image(tmp));
				echo(", state = 0x");
				hex_echo(axo.rdata(31 downto 28));
				echo(", nbbits = ");
				tmp := to_integer(unsigned(axo.rdata(27 downto 16)));
				echo(integer'image(tmp));
				echol("] (" & time'image(now) & ")");
				exit;
			end if;
			-- wait a little bit between each polling read (say 1 us, like software)
			wait for 1 us;
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- ------------------------------------------
	-- emulate SW resuming execution of microcode (debug feature)
	-- ------------------------------------------
	procedure resume(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type) is
	begin
		-- write W_DBG_STEPS register
		axi.awaddr <= W_DBG_STEPS & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		axi.wdata <= "0001" & x"0000000"; axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -----------------------------------------------------------------
	-- emulate SW reading of one large number & its display with console
	-- -----------------------------------------------------------------
	procedure read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1) is
		variable lgnb: std_logic512 := (others => '0');
	begin
		lgnb := (others => '0');
		read_big(clk, axi, axo, valnn, addr, lgnb);
		echo("ECC_TB: read-back on AXI interface: @" & integer'image(addr)
		     & " = 0x");
		hex_echol(lgnb(valnn - 1 downto 0));
	end procedure;

	-- --------------------------------------------------------------------
	-- Identical to read_and_display_kp_result, except that here debug mode
	-- is assumed, hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we'd create a deadlock if the IP was halted)
	-- --------------------------------------------------------------------
	procedure debug_read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1) is
		variable lgnb: std_logic512 := (others => '0');
	begin
		lgnb := (others => '0');
		debug_read_big(clk, axi, axo, valnn, addr, lgnb);
		echo("ECC_TB: read-back on AXI interface: @" & integer'image(addr)
		     & " = 0x");
		hex_echol(lgnb(valnn - 1 downto 0));
	end procedure;

end package body;
