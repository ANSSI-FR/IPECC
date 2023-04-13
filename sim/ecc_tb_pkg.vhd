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

use work.ecc_customize.all;
use work.ecc_utils.all;
use work.ecc_pkg.all;
use work.ecc_vars.all;
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

	-- emulate software driver polling the R_STATUS register until it shows ready
	procedure poll_until_ready(signal clk : in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	-- emulate software driver writing prime size (nn)
	--   (option nn_dynamic = TRUE in ecc_customize.vhd)
	procedure set_nn(signal clk : in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type;
	                 constant valnn : in positive);

	-- emulate software driver writing one large number (but the scalar)
	procedure write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant bignb : in std_logic_vector);

	-- Identical to write_big, except that here debug mode
	-- is assumed, hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we would be creating a deadlock)
	procedure debug_write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant bignb : in std_logic_vector);

	-- emulate software driver configuring shuffle
	procedure configure_shuffle(signal clk: in std_logic;
	                            signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            constant sh : in boolean);

	-- emulate software driver configuring IRQ
	procedure configure_irq(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
	                        constant irq : in boolean);

	-- emulate software driver configuring blinding
	procedure configure_blinding(signal clk: in std_logic;
	                             signal axi: out axi_in_type;
	                             signal axo: in axi_out_type;
	                             constant blind : in boolean;
	                             constant blindbits : in natural);

	-- emulate software driver writing the large number of the scalar
	procedure write_scalar(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant val : in std_logic_vector);

	-- emulate software driver issuing command 'do [k]P-computation'
	procedure run_kp(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type);

	-- emulate software driver writing base-point & scalar
	-- and giving [k]P computation a go
	procedure scalar_mult(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type;
	                      constant valnn : in positive;
	                      constant scalar : in std_logic_vector;
	                      constant xx : in std_logic_vector;
	                      constant yy : in std_logic_vector;
	                      constant z : in boolean);

	-- emulate software driver checking if R0 is the null point
	procedure check_if_r0_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean);

	-- emulate software driver checking if R1 is the null point
	procedure check_if_r1_null(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type;
	                           variable isnull : out boolean);

	-- emulate software driver checking if R0/R1 is pt 0 & display it on console
	procedure check_and_display_if_r0_r1_null(signal clk: in std_logic;
	                                          signal axi: out axi_in_type;
	                                          signal axo: in axi_out_type);

	-- emulate software driver checking if any error & display them on console
	procedure display_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type);

	-- emulate software driver reading one large number
	procedure read_big(signal clk: in std_logic;
	                   signal axi: out axi_in_type;
	                   signal axo: in axi_out_type;
	                   constant valnn: in positive;
	                   constant addr : in natural range 0 to nblargenb - 1;
	                   variable bignb: inout std_logic_vector);

	-- Identical to read_big, except that here debug mode is assumed,
	-- hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we would be creating a deadlock)
	procedure debug_read_big(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type;
	                         constant valnn: in positive;
	                         constant addr : in natural range 0 to nblargenb - 1;
	                         variable bignb: inout std_logic_vector);

	-- emulate software driver reading [k]P result's coordinates
	procedure read_and_display_kp_result(signal clk: in std_logic;
	                                     signal axi: out axi_in_type;
	                                     signal axo: in axi_out_type;
	                                     constant valnn: in positive);

	-- emulate software driver acknowledging all errors
	procedure ack_all_errors(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type);

	-- emulate software driver setting all curve parameters
	procedure set_curve(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant size: in positive;
	                    constant curve: curve_param_type);

	-- emulate software driver setting R0 to be the null point
	procedure set_r0_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type);

	-- emulate software driver setting R0 NOT to be the null point
	procedure set_r0_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type);

	-- emulate software driver setting R1 to be the null point
	procedure set_r1_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type);

	-- emulate software driver setting R1 NOT to be the null point
	procedure set_r1_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type);

	-- emulate software driver issuing command 'do point-addition'
	procedure run_point_add(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type);

	-- emulate software driver writing coords of two points to add
	-- and giving computation a go
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

	-- emulate software driver reading result coords after point-add
	-- & display on console
	procedure read_and_display_ptadd_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);

	-- emulate software driver issuing command 'do point-doubling'
	procedure run_point_double(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	-- emulate software driver writing coords of a point to double
	-- and giving computation a go
	procedure point_double(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant x : in std_logic_vector;
	                       constant y : in std_logic_vector;
	                       constant z : in boolean);

	-- emulate software driver running a point double computation on the
	-- null point, and therefore without setting the coordinates of the
	-- input points
	procedure point_double_zero_without_coords(
	                       signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive);

	-- emulate software driver reading result's coords after point-double
	-- and display on console
	procedure read_and_display_ptdbl_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);
	
	-- emulate software driver issuing command 'do point-negate'
	procedure run_point_negate(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type);

	-- emulate software driver writing coords of point to negate (-P)
	-- and give computation a go
	procedure point_negate(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn: in positive;
	                       constant x: in std_logic_vector;
	                       constant y: in std_logic_vector; 
	                       constant z: in boolean);

	-- emulate software driver reading result coords after point-negate
	-- and display on console
	procedure read_and_display_ptneg_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive);

	-- emulate software driver issuing command 'do P == Q test'
	procedure run_point_test_equal(signal clk: in std_logic;
	                               signal axi: out axi_in_type;
	                               signal axo: in axi_out_type);

	-- emulate software driver writing coords of 2 points to compare (P==Q)
	-- and giving computation a go
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

	-- emulate software driver issuing command 'do P -== Q test'
	procedure run_point_test_opposite(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type);

	-- emulate software driver writing coords of 2 points to test if points
	-- are opposite, and giving computation a go
	procedure point_test_opposite(signal clk: in std_logic;
	                              signal axi: out axi_in_type;
	                              signal axo: in axi_out_type;
	                              constant valnn : positive;
	                              constant x0 : in std_logic_vector;
	                              constant y0 : in std_logic_vector;
	                              constant x1 : in std_logic_vector;
	                              constant y1 : in std_logic_vector;
	                              constant z0 : in boolean;
	                              constant z1 : in boolean);

	-- emulate software driver issuing command 'is P on point test'
	procedure run_point_test_on_curve(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type);

	-- emulate software driver writing coord of a point and test
	-- if it is on curve
	procedure point_test_on_curve(signal clk: in std_logic;
	                              signal axi: out axi_in_type;
	                              signal axo: in axi_out_type;
	                              constant valnn : positive;
	                              constant xx : in std_logic_vector;
	                              constant yy : in std_logic_vector;
	                              constant z : in boolean);

	-- emulate software driver getting answer to a test it's asked on R0 and/or R1
	procedure check_test_answer(signal clk: in std_logic;
                              signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            variable yes_or_no: out boolean;
	                            variable answer_right: out boolean);

	-- Identical to check_test_answer with display on console
	procedure read_and_display_pttest_result(signal clk: in std_logic;
                                           signal axi: out axi_in_type;
	                                         signal axo: in axi_out_type;
	                                         constant valnn: in positive);

	-- emulate software driver setting a breakpoint (debug feature)
	procedure set_one_breakpoint(
	            signal clk: in std_logic;
	            signal axi: out axi_in_type;
	            signal axo: in axi_out_type;
	            constant id: in natural;
	            constant addr: in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
	            constant state: in std_logic_vector(3 downto 0);
	            constant nbbits: in natural);
	
	-- emulate software driver polling R_DBG_STATUS until it shows
	-- IP is halted (debug feat.)
	procedure poll_until_debug_halted(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type);

	-- emulate software driver read of the R_DBG_STATUS and returns the value
	procedure read_dbg_status(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type;
	                          variable dbgstatus : inout std_logic_vector);

	-- emulate software driver resuming execution of microcode (debug feature)
	procedure resume(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type);

	-- emulate software driver asking for execution of a specific number
	-- of opcodes
	procedure run_n_opcodes(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
	                        constant nbop : in natural);

	-- emulate software driver reading of one large number
	-- with display on console
	procedure read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1);

	-- Identical to read_and_display_kp_result, except that here debug mode
	-- is assumed, hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we'd create a deadlock if the IP was halted)
	procedure debug_read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1);

	-- emulate software driver reading both R0 and R1 point coordinate values
	-- (whether or not they are null according to R_STATUS)
	procedure read_and_display_r0_and_r1_coords(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive);

	-- to activate [XY]R[01] coords shuffle
	procedure debug_activate_xyshuf(signal clk: in std_logic;
	                                signal axi: out axi_in_type;
	                                signal axo: in axi_out_type);

	-- to deactivate [XY]R[01] coords shuffle
	procedure debug_deactivate_xyshuf(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type);

	-- emulate software driver reading an opcode value from ecc_curve_iram 
	procedure get_opcode(signal clk: in std_logic;
	                     signal axi: out axi_in_type;
	                     signal axo: in axi_out_type;
	                     constant addr: in natural range 0 to nbopcodes - 1);

end package ecc_tb_pkg;

package body ecc_tb_pkg is

	-- --------------------------------------------------------------------------
	-- emulate software driver polling the R_STATUS register until it shows ready
	-- --------------------------------------------------------------------------
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
	-- emulate software driver writing prime size (nn)
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

	-- -----------------------------------------------------------------
	-- emulate software driver writing one large number (but the scalar)
	-- -----------------------------------------------------------------
	procedure write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant bignb : in std_logic_vector) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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
			axi.wdata <= bignb((AXIDW*i) + AXIDW - 1 downto AXIDW*i);
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		end loop;
	end procedure;

	-- ------------------------------------------------------------------
	-- Identical to write_big, except that here debug mode
	-- is assumed, hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we would be creating a deadlock)
	-- ------------------------------------------------------------------
	procedure debug_write_big(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant valnn : in positive;
	                    constant addr : in natural range 0 to nblargenb - 1;
	                    constant bignb : in std_logic_vector) is
		variable tup, xup : integer;
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
		variable vw : natural := div(valnn + 4, ww);
	begin
		wait until clk'event and clk = '1';
		for limb in 0 to vw - 1 loop
			wait until clk'event and clk = '1';
			-- write W_DBG_FP_WADDR register
			axi.awaddr <= W_DBG_FP_WADDR & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
			dw := (others => '0');
			dw(FP_ADDR - 1 downto 0)
				:= std_logic_vector(to_unsigned((addr * n) + limb, FP_ADDR));
			axi.wdata <= dw;
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
			-- now perform the proper nb of writes of the W_DBG_FP_WDATA register
			wait until clk'event and clk = '1';
			axi.awaddr <= W_DBG_FP_WDATA & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= (others => 'X'); axi.awvalid <= '0';
			if ((limb + 1) * ww) > bignb'length then
				tup := bignb'length - 1;
				xup := (bignb'length mod ww) - 1;
				assert FALSE
					report "ecc_tb_pkg: overflow while debug-write of big number"
						severity WARNING;
			else
				tup := ((limb + 1) * ww) - 1;
				xup := ww - 1;
			end if;
			axi.wdata(xup downto 0) <= bignb(tup downto limb * ww);
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		end loop; -- limbs
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------------------
	-- emulate software driver configuring shuffle
	-- -------------------------------------------
	procedure configure_shuffle(signal clk: in std_logic;
	                            signal axi: out axi_in_type;
	                            signal axo: in axi_out_type;
	                            constant sh : in boolean) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- ---------------------------------------
	-- emulate software driver configuring IRQ
	-- ---------------------------------------
	procedure configure_irq(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
	                        constant irq : in boolean) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- --------------------------------------------
	-- emulate software driver configuring blinding
	-- --------------------------------------------
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

	-- --------------------------------------------------------------
	-- emulate software driver writing the large number of the scalar
	-- --------------------------------------------------------------
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

	-- -------------------------------------------------------------
	-- emulate software driver issuing command 'do [k]P-computation'
	-- -------------------------------------------------------------
	procedure run_kp(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- ---------------------------------------------------
	-- emulate software driver writing base-point & scalar
	-- and give [k]P computation a go
	-- ---------------------------------------------------
	procedure scalar_mult(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type;
	                      constant valnn : in positive;
	                      constant scalar : in std_logic_vector;
	                      constant xx : in std_logic_vector;
	                      constant yy : in std_logic_vector;
												constant z : in boolean) is
	begin
		wait until clk'event and clk = '1';
		-- write base-point's X & Y coordinates
		poll_until_ready(clk, axi, axo);
		write_scalar(clk, axi, axo, valnn, scalar);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, xx);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, yy);
		-- set metavalue of R1
		if z then
			set_r1_null(clk, axi, axo);
		else
			set_r1_non_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give [k]P computation a go
		poll_until_ready(clk, axi, axo);
		run_kp(clk, axi, axo);
	end procedure;

	-- --------------------------------------------------------
	-- emulate software driver checking if R0 is the null point
	-- --------------------------------------------------------
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

	-- --------------------------------------------------------
	-- emulate software driver checking if R1 is the null point
	-- --------------------------------------------------------
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

	-- -------------------------------------------------------------------------
	-- emulate software driver checking if R0/R1 is pt 0 & display it on console
	-- -------------------------------------------------------------------------
	procedure check_and_display_if_r0_r1_null(signal clk: in std_logic;
	                                          signal axi: out axi_in_type;
	                                          signal axo: in axi_out_type) is
		variable vz0, vz1 : boolean;
		variable vz : std_logic_vector(1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------------------
	-- emulate software driver checking if any error & display them on console
	-- -----------------------------------------------------------------------
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

	-- ------------------------------------------------
	-- emulate software driver reading one large number
	-- ------------------------------------------------
	procedure read_big(signal clk: in std_logic;
	                   signal axi: out axi_in_type;
	                   signal axo: in axi_out_type;
	                   constant valnn: in positive;
	                   constant addr : in natural range 0 to nblargenb - 1;
	                   variable bignb: inout std_logic_vector) is
		variable tup, xup : integer;
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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
			if ((i + 1) * AXIDW) > bignb'length then
				tup := bignb'length - 1;
				xup := (bignb'length mod AXIDW) - 1;
				assert FALSE
					report "ecc_tb_pkg: overflow while read of big number"
						severity WARNING;
			else
				tup := ((i + 1) * AXIDW) - 1;
				xup := AXIDW - 1;
			end if;
			bignb(tup downto i * AXIDW) := axo.rdata(xup downto 0);
			axi.rready <= '0';
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------------------------------
	-- Identical to read_big, except that here debug mode is assumed,
	-- hence we do not poll the BUSY bit in R_STATUS register
	-- (otherwise we would be creating a deadlock)
	-- --------------------------------------------------------------
	procedure debug_read_big(signal clk: in std_logic;
	                         signal axi: out axi_in_type;
	                         signal axo: in axi_out_type;
	                         constant valnn: in positive;
	                         constant addr : in natural range 0 to nblargenb - 1;
	                         variable bignb: inout std_logic_vector) is
		variable tup, xup : integer;
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
		variable vw : natural := div(valnn + 4, ww);
	begin
		wait until clk'event and clk = '1';
		for limb in 0 to vw - 1 loop
			-- write W_DBG_FP_RADDR register
			axi.awaddr <= W_DBG_FP_RADDR & "000"; axi.awvalid <= '1';
			wait until clk'event and clk = '1' and axo.awready = '1';
			axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
			dw := (others => '0');
			dw(FP_ADDR - 1 downto 0)
				:= std_logic_vector(to_unsigned((addr * n) + limb, FP_ADDR));
			axi.wdata <= dw;
			axi.wvalid <= '1';
			wait until clk'event and clk = '1' and axo.wready = '1';
			axi.wdata <= (others => 'X'); axi.wvalid <= '0';
			-- poll R_DBG_FP_RDATA_RDY register until it shows data is ready for read
			loop
				wait until clk'event and clk = '1';
				-- read R_DBG_FP_RDATA_RDY register
				axi.araddr <= R_DBG_FP_RDATA_RDY & "000";
				axi.arvalid <= '1';
				wait until clk'event and clk = '1' and axo.arready = '1';
				axi.araddr <= "XXXXXXXX";
				axi.arvalid <= '0';
				axi.rready <= '1';
				wait until clk'event and clk = '1' and axo.rvalid = '1';
				axi.rready <= '0';
				if axo.rdata(0) = '1' then
					-- means bit 'ready' is asserted
					exit;
				end if;
			end loop;
			wait until clk'event and clk = '1';
			-- now perform one read on the R_DBG_FP_RDATA register
			axi.araddr <= R_DBG_FP_RDATA & "000"; axi.arvalid <= '1';
			wait until clk'event and clk = '1' and axo.arready = '1';
			axi.araddr <= "XXXXXXXX"; axi.arvalid <= '0'; axi.rready <= '1';
			wait until clk'event and clk = '1' and axo.rvalid = '1';
			if ((limb + 1) * ww) > bignb'length then
				tup := bignb'length - 1;
				xup := (bignb'length mod ww) - 1;
				assert FALSE
					report "ecc_tb_pkg: overflow while debug-read of big number"
						severity WARNING;
			else
				tup := ((limb + 1) * ww) - 1;
				xup := ww - 1;
			end if;
			bignb(tup downto limb * ww) := axo.rdata(xup downto 0);
			axi.rready <= '0';
			wait until clk'event and clk = '1';
		end loop; -- ww-bit limbs
	end procedure;

	-- ---------------------------------------------------------
	-- emulate software driver reading [k]P result's coordinates
	-- ---------------------------------------------------------
	procedure read_and_display_kp_result(signal clk: in std_logic;
	                                     signal axi: out axi_in_type;
	                                     signal axo: in axi_out_type;
	                                     constant valnn: in positive) is
		variable kpx : std_logic512 := (others => '0');
		variable kpy : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
	begin
		wait until clk'event and clk = '1';
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

	-- ------------------------------------------------
	-- emulate software driver acknowledging all errors
	-- ------------------------------------------------
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

	-- ----------------------------------------------------
	-- emulate software driver setting all curve parameters
	-- ----------------------------------------------------
	procedure set_curve(signal clk: in std_logic;
	                    signal axi: out axi_in_type;
	                    signal axo: in axi_out_type;
	                    constant size: in positive;
	                    constant curve: curve_param_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		for i in 0 to 3 loop
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, size, CURVE_PARAM_ADDR(i), curve(i));
		end loop;
	end procedure;

	-- -------------------------------------------------------
	-- emulate software driver setting R0 to be the null point
	-- -------------------------------------------------------
	procedure set_r0_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver setting R0 NOT to be the null point
	-- -----------------------------------------------------------
	procedure set_r0_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -------------------------------------------------------
	-- emulate software driver setting R1 to be the null point
	-- -------------------------------------------------------
	procedure set_r1_null(signal clk: in std_logic;
	                      signal axi: out axi_in_type;
	                      signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver setting R1 NOT to be the null point
	-- -----------------------------------------------------------
	procedure set_r1_non_null(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver issuing command 'do point-addition'
	-- -----------------------------------------------------------
	procedure run_point_add(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver writing coords of two points to add
	-- and giving computation a go
	-- -----------------------------------------------------------
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
		wait until clk'event and clk = '1';
		-- write two points' X & Y coordinates
		if not z0 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, x0);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, y0);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		if not z1 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, x1);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, y1);
			poll_until_ready(clk, axi, axo);
			set_r1_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r1_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give P + Q computation a go
		poll_until_ready(clk, axi, axo);
		run_point_add(clk, axi, axo);
	end procedure;

	-- -------------------------------------------------------------
	-- emulate software driver reading result coords after point-add
	-- with display on console
	-- -------------------------------------------------------------
	procedure read_and_display_ptadd_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		wait until clk'event and clk = '1';
		check_if_r1_null(clk, axi, axo, vz1);
		if vz1 then
			echol("ECC_TB: P+Q = 0");
		else
			-- read back the coordinates of result point (R1)
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
			--assert (xmsb > 0)
			--	report "X-coordinate of point-addition result seems to equal 0"
			--		severity WARNING;
			if (xmsb <= 0) then xmsb := valnn - 1; end if;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			--assert (ymsb > 0)
			--	report "Y-coordinate of point-addition result seems to equal 0"
			--		severity WARNING;
			if (ymsb <= 0) then ymsb := valnn - 1; end if;
			echo("ECC_TB: read-back on AXI interface: (P+Q).x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: (P+Q).y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if; -- vz1
		-- do the same thing with R0 point (must have been preserved)
		pax := (others => '0');
		pay := (others => '0');
		read_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, pax);
		read_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, pay);
		xmsb := pax'high;
		for i in pax'high downto 0 loop
			if pax(i) /= '0' then
				exit;
			end if;
			xmsb := xmsb - 1;
		end loop;
		--assert (xmsb > 0)
		--	report "X-coordinate of point R0 seems to have been reset to 0"
		--		severity WARNING;
		if (xmsb <= 0) then xmsb := valnn - 1; end if;
		ymsb := pay'high;
		for i in pay'high downto 0 loop
			if pay(i) /= '0' then
				exit;
			end if;
			ymsb := ymsb - 1;
		end loop;
		--assert (ymsb > 0)
		--	report "Y-coordinate of point R0 seems to have been reset to 0"
		--		severity WARNING;
		if (ymsb <= 0) then ymsb := valnn - 1; end if;
		echo("ECC_TB: read-back on AXI interface: R0.x = 0x");
		hex_echol(pax(max(xmsb, ymsb) downto 0));
		echo("ECC_TB: read-back on AXI interface: R0.y = 0x");
		hex_echol(pay(max(xmsb, ymsb) downto 0));
	end procedure;

	-- -----------------------------------------------------------
	-- emulate software driver issuing command 'do point-doubling'
	-- -----------------------------------------------------------
	procedure run_point_double(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver writing coords of a point to double
	-- and giving computation a go
	-- -----------------------------------------------------------
	procedure point_double(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn : in positive;
	                       constant x : in std_logic_vector;
	                       constant y : in std_logic_vector;
	                       constant z : in boolean) is
	begin
		wait until clk'event and clk = '1';
		-- write point's X & Y coordinates
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, x);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, y);
		poll_until_ready(clk, axi, axo);
		if z then
			set_r0_null(clk, axi, axo);
		else
			set_r0_non_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give [2]P computation a go
		poll_until_ready(clk, axi, axo);
		run_point_double(clk, axi, axo);
	end procedure;

	-- -----------------------------------------------------------------
	-- emulate software driver running a point double computation on the
	-- null point, and therefore without setting the coordinates of the
	-- input points
	-- -----------------------------------------------------------------
	procedure point_double_zero_without_coords(
	                       signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
												 constant valnn : in positive) is
	begin
		wait until clk'event and clk = '1';
		-- set R0 to be the 0 point
		set_r0_null(clk, axi, axo);
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give [2]P computation a go
		poll_until_ready(clk, axi, axo);
		run_point_double(clk, axi, axo);
	end procedure;

	-- ------------------------------------------------------------------
	-- emulate software driver reading result's coords after point-double
	-- with display on console
	-- ------------------------------------------------------------------
	procedure read_and_display_ptdbl_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		wait until clk'event and clk = '1';
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
			--assert (xmsb > 0)
			--	report "X-coordinate of point-doubling result seems to equal 0"
			--		severity WARNING;
			if (xmsb <= 0) then xmsb := valnn - 1; end if;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			--assert (ymsb > 0)
			--	report "Y-coordinate of point-doubling result seems to equal 0"
			--		severity WARNING;
			if (ymsb <= 0) then ymsb := valnn - 1; end if;
			echo("ECC_TB: read-back on AXI interface: [2]P.x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: [2]P.y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if;
	end procedure;

	-- ---------------------------------------------------------
	-- emulate software driver issuing command 'do point-negate'
	-- ---------------------------------------------------------
	procedure run_point_negate(signal clk: in std_logic;
	                           signal axi: out axi_in_type;
	                           signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- --------------------------------------------------------------
	-- emulate software driver writing coords of point to negate (-P)
	-- and giving computation a go
	-- --------------------------------------------------------------
	procedure point_negate(signal clk: in std_logic;
	                       signal axi: out axi_in_type;
	                       signal axo: in axi_out_type;
	                       constant valnn: in positive;
	                       constant x: in std_logic_vector;
	                       constant y: in std_logic_vector; 
	                       constant z: in boolean) is
	begin
		wait until clk'event and clk = '1';
		-- write point's X & Y coordinates
		if not z then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, x);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, y);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give -P computation a go
		poll_until_ready(clk, axi, axo);
		run_point_negate(clk, axi, axo);
	end procedure;

	-- ----------------------------------------------------------------
	-- emulate software driver reading result coords after point-negate
	-- with display on console
	-- ----------------------------------------------------------------
	procedure read_and_display_ptneg_result(signal clk: in std_logic;
	                                        signal axi: out axi_in_type;
	                                        signal axo: in axi_out_type;
	                                        constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
		variable vz1 : boolean;
	begin
		wait until clk'event and clk = '1';
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
			--assert (xmsb > 0)
			--	report "X-coordinate of opposite-point result seems to equal 0"
			--		severity WARNING;
			if (xmsb <= 0) then xmsb := valnn - 1; end if;
			ymsb := pay'high;
			for i in pay'high downto 0 loop
				if pay(i) /= '0' then
					exit;
				end if;
				ymsb := ymsb - 1;
			end loop;
			--assert (ymsb > 0)
			--	report "Y-coordinate of opposite-point result seems to equal 0"
			--		severity WARNING;
			if (ymsb <= 0) then ymsb := valnn - 1; end if;
			echo("ECC_TB: read-back on AXI interface: (-P).x = 0x");
			hex_echol(pax(max(xmsb, ymsb) downto 0));
			echo("ECC_TB: read-back on AXI interface: (-P).y = 0x");
			hex_echol(pay(max(xmsb, ymsb) downto 0));
		end if;
	end procedure;

	-- --------------------------------------------------------
	-- emulate software driver issuing command 'do P == Q test'
	-- --------------------------------------------------------
	procedure run_point_test_equal(signal clk: in std_logic;
	                               signal axi: out axi_in_type;
	                               signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
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

	-- --------------------------------------------------------------------
	-- emulate software driver writing coords of 2 points to compare (P==Q)
	-- and giving computation a go
	-- --------------------------------------------------------------------
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
		wait until clk'event and clk = '1';
		-- write point's X & Y coordinates
		if not z0 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, x0);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, y0);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		if not z1 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, x1);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, y1);
			poll_until_ready(clk, axi, axo);
			set_r1_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r1_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give P==Q test computation a go
		poll_until_ready(clk, axi, axo);
		run_point_test_equal(clk, axi, axo);
	end procedure;

	-- ---------------------------------------------------------
	-- emulate software driver issuing command 'do P -== Q test'
	-- ---------------------------------------------------------
	procedure run_point_test_opposite(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
																		signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_OPP) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------------------------------------
	-- emulate software driver writing coords of 2 points to test if points
	-- are opposite, and giving computation a go
	-- --------------------------------------------------------------------
	procedure point_test_opposite(signal clk: in std_logic;
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
		wait until clk'event and clk = '1';
		-- write point's X & Y coordinates
		if not z0 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, x0);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, y0);
			poll_until_ready(clk, axi, axo);
			set_r0_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r0_null(clk, axi, axo);
		end if;
		if not z1 then
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_XR1_ADDR, x1);
			poll_until_ready(clk, axi, axo);
			write_big(clk, axi, axo, valnn, LARGE_NB_YR1_ADDR, y1);
			poll_until_ready(clk, axi, axo);
			set_r1_non_null(clk, axi, axo);
		else
			poll_until_ready(clk, axi, axo);
			set_r1_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give P-==Q test computation a go
		poll_until_ready(clk, axi, axo);
		run_point_test_opposite(clk, axi, axo);
	end procedure;

	-- ------------------------------------------------------------
	-- emulate software driver issuing command 'is P on point test'
	-- ------------------------------------------------------------
	procedure run_point_test_on_curve(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
																		signal axo: in axi_out_type) is
		variable dw : std_logic_vector(AXIDW - 1 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_CTRL register
		axi.awaddr <= W_CTRL & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		dw := (others => '0');
		dw(CTRL_PT_CHK) := '1';
		axi.wdata <= dw;
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ---------------------------------------------------------
	-- emulate software driver writing coord of a point and test
	-- if it is on curve
	-- ---------------------------------------------------------
	procedure point_test_on_curve(signal clk: in std_logic;
	                              signal axi: out axi_in_type;
	                              signal axo: in axi_out_type;
	                              constant valnn : positive;
	                              constant xx : in std_logic_vector;
	                              constant yy : in std_logic_vector;
																constant z : in boolean) is
	begin
		wait until clk'event and clk = '1';
		-- write point's X & Y coordinate into R0
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, xx);
		poll_until_ready(clk, axi, axo);
		write_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, yy);
		poll_until_ready(clk, axi, axo);
		if z then
			set_r0_null(clk, axi, axo);
		else
			set_r0_non_null(clk, axi, axo);
		end if;
		-- display R0 & R1 coordinate values before computation
		echol("ECC_TB: R0 & R1 coord values before computation:");
		check_and_display_if_r0_r1_null(clk, axi, axo);
		read_and_display_r0_and_r1_coords(clk, axi, axo, valnn);
		-- give 'is on curve' test computation a go
		poll_until_ready(clk, axi, axo);
		run_point_test_on_curve(clk, axi, axo);
	end procedure;

	-- ---------------------------------------------------------------------------
	-- emulate software driver getting answer to a test it's asked on R0 and/or R1
	-- ---------------------------------------------------------------------------
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

	-- ------------------------------------------------------
	-- Identical to check_test_answer with display on console
	-- ------------------------------------------------------
	procedure read_and_display_pttest_result(signal clk: in std_logic;
                                           signal axi: out axi_in_type;
	                                         signal axo: in axi_out_type;
	                                         constant valnn: in positive) is
		variable yes_or_no, answer_right : boolean;
	begin
		wait until clk'event and clk = '1';
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

	-- ------------------------------------------------------------
	-- emulate software driver setting a breakpoint (debug feature)
	-- ------------------------------------------------------------
	procedure set_one_breakpoint(
	            signal clk: in std_logic;
		          signal axi: out axi_in_type;
		          signal axo: in axi_out_type;
		          constant id: in natural;
		          constant addr: in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		          constant state: in std_logic_vector(3 downto 0);
							constant nbbits: in natural) is
	begin
		wait until clk'event and clk = '1';
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

	-- -----------------------------------------------------------
	-- emulate software driver polling R_DBG_STATUS until it shows
	-- IP is halted (debug feat.)
	-- -----------------------------------------------------------
	procedure poll_until_debug_halted(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type) is
		variable tmp : integer;
	begin
		wait until clk'event and clk = '1';
		loop
			wait until clk'event and clk = '1';
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
			---- wait a little bit between each polling read (say 1 us, like software)
			--wait for 1 us;
			wait until clk'event and clk = '1';
		end loop;
		wait until clk'event and clk = '1';
	end procedure;

	-- ----------------------------------------------------------------------
	-- emulate software driver read of the R_DBG_STATUS and returns the value
	-- ----------------------------------------------------------------------
	procedure read_dbg_status(signal clk: in std_logic;
	                          signal axi: out axi_in_type;
	                          signal axo: in axi_out_type;
													  variable dbgstatus : inout std_logic_vector) is
	begin
		wait until clk'event and clk = '1';
		-- read R_DBG_STATUS register
		axi.araddr <= R_DBG_STATUS & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		dbgstatus := axo.rdata;
		wait until clk'event and clk = '1';
	end procedure;

	-- -----------------------------------------------------------------------
	-- emulate software driver resuming execution of microcode (debug feature)
	-- -----------------------------------------------------------------------
	procedure resume(signal clk: in std_logic;
	                 signal axi: out axi_in_type;
	                 signal axo: in axi_out_type) is
	begin
		wait until clk'event and clk = '1';
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
	-- emulate software driver asking for execution of a specific number
	-- of opcodes
	-- -----------------------------------------------------------------
	procedure run_n_opcodes(signal clk: in std_logic;
	                        signal axi: out axi_in_type;
	                        signal axo: in axi_out_type;
													constant nbop : in natural) is
		variable vnbop : std_logic_vector(15 downto 0);
	begin
		wait until clk'event and clk = '1';
		-- write W_DBG_STEPS register
		axi.awaddr <= W_DBG_STEPS & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		vnbop := std_nat(nbop, 16);
		axi.wdata <= x"00" & vnbop & x"01"; axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- ---------------------------------------------------
	-- emulate software driver reading of one large number
	-- and its display with console
	-- ---------------------------------------------------
	procedure read_and_display_one_large_nb(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
	                constant valnn: in positive;
	                constant addr: in natural range 0 to nblargenb - 1) is
		variable lgnb: std_logic512 := (others => '0');
	begin
		wait until clk'event and clk = '1';
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
		wait until clk'event and clk = '1';
		lgnb := (others => '0');
		debug_read_big(clk, axi, axo, valnn, addr, lgnb);
		echo("ECC_TB: read-back on AXI interface: @" & integer'image(addr)
		     & " = 0x");
		hex_echol(lgnb(valnn - 1 downto 0));
	end procedure;

	-- ----------------------------------------------------------------------
	-- emulate software driver reading both R0 and R1 point coordinate values
	-- (whether or not they are null according to R_STATUS)
	-- ----------------------------------------------------------------------
	procedure read_and_display_r0_and_r1_coords(
	                signal clk: in std_logic;
	                signal axi: out axi_in_type;
	                signal axo: in axi_out_type;
									constant valnn: in positive) is
		variable pax : std_logic512 := (others => '0');
		variable pay : std_logic512 := (others => '0');
		variable xmsb, ymsb : integer;
	begin
		wait until clk'event and clk = '1';
		-- read back the coordinates of R0
		pax := (others => '0');
		pay := (others => '0');
		read_big(clk, axi, axo, valnn, LARGE_NB_XR0_ADDR, pax);
		read_big(clk, axi, axo, valnn, LARGE_NB_YR0_ADDR, pay);
		xmsb := pax'high;
		for i in pax'high downto 0 loop
			if pax(i) /= '0' then
				exit;
			end if;
			xmsb := xmsb - 1;
		end loop;
		--assert (xmsb > 0)
		--	report "X-coordinate of R0 seems to equal 0"
		--		severity WARNING;
		if (xmsb <= 0) then xmsb := valnn - 1; end if;
		ymsb := pay'high;
		for i in pay'high downto 0 loop
			if pay(i) /= '0' then
				exit;
			end if;
			ymsb := ymsb - 1;
		end loop;
		--assert (ymsb > 0)
		--	report "Y-coordinate of R0 seems to equal 0"
		--		severity WARNING;
		if (ymsb <= 0) then ymsb := valnn - 1; end if;
		echo("ECC_TB: read-back on AXI interface: (R0).x = 0x");
		hex_echol(pax(max(xmsb, ymsb) downto 0));
		echo("ECC_TB: read-back on AXI interface: (R0).y = 0x");
		hex_echol(pay(max(xmsb, ymsb) downto 0));
		-- read back the coordinates of R1
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
		--assert (xmsb > 0)
		--	report "X-coordinate of R1 seems to equal 0"
		--		severity WARNING;
		if (xmsb <= 0) then xmsb := valnn - 1; end if;
		ymsb := pay'high;
		for i in pay'high downto 0 loop
			if pay(i) /= '0' then
				exit;
			end if;
			ymsb := ymsb - 1;
		end loop;
		--assert (ymsb > 0)
		--	report "Y-coordinate of R1 seems to equal 0"
		--		severity WARNING;
		if (ymsb <= 0) then ymsb := valnn - 1; end if;
		echo("ECC_TB: read-back on AXI interface: (R1).x = 0x");
		hex_echol(pax(max(xmsb, ymsb) downto 0));
		echo("ECC_TB: read-back on AXI interface: (R1).y = 0x");
		hex_echol(pay(max(xmsb, ymsb) downto 0));
	end procedure;

	-- ------------------------------------
	-- to activate [XY]R[01] coords shuffle
	-- ------------------------------------
	procedure debug_activate_xyshuf(signal clk: in std_logic;
	                                signal axi: out axi_in_type;
	                                signal axo: in axi_out_type) is
	begin
		wait until clk'event and clk = '1';
		-- write W_DBG_CFG_NOXYSHUF register
		axi.awaddr <= W_DBG_CFG_NOXYSHUF & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		axi.wdata <= (others => '0'); axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- --------------------------------------
	-- to deactivate [XY]R[01] coords shuffle
	-- --------------------------------------
	procedure debug_deactivate_xyshuf(signal clk: in std_logic;
	                                  signal axi: out axi_in_type;
	                                  signal axo: in axi_out_type) is
	begin
		wait until clk'event and clk = '1';
		-- write W_DBG_CFG_NOXYSHUF register
		axi.awaddr <= W_DBG_CFG_NOXYSHUF & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		axi.wdata <= (0 => '1', others => '0'); axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
	end procedure;

	-- -------------------------------------------------------------------
	-- emulate software driver reading an opcode value from ecc_curve_iram 
	-- -------------------------------------------------------------------
	procedure get_opcode(signal clk: in std_logic;
	                     signal axi: out axi_in_type;
	                     signal axo: in axi_out_type;
											 constant addr: in natural range 0 to nbopcodes - 1) is
	begin
		wait until clk'event and clk = '1';
		-- write W_DBG_OP_ADDR register
		axi.awaddr <= W_DBG_OP_ADDR & "000"; axi.awvalid <= '1';
		wait until clk'event and clk = '1' and axo.awready = '1';
		axi.awaddr <= "XXXXXXXX"; axi.awvalid <= '0';
		axi.wdata <= std_logic_vector(to_unsigned(addr, AXIDW));
		axi.wvalid <= '1';
		wait until clk'event and clk = '1' and axo.wready = '1';
		axi.wdata <= (others => 'X'); axi.wvalid <= '0';
		wait until clk'event and clk = '1';
		--wait until clk'event and clk = '1';
		--wait until clk'event and clk = '1';
		-- read R_DBG_RD_OPCODE register
		axi.araddr <= R_DBG_RD_OPCODE & "000";
		axi.arvalid <= '1';
		wait until clk'event and clk = '1' and axo.arready = '1';
		axi.araddr <= "XXXXXXXX";
		axi.arvalid <= '0';
		axi.rready <= '1';
		wait until clk'event and clk = '1' and axo.rvalid = '1';
		axi.rready <= '0';
		echo("ECC_TB: opcode at 0x");
		hex_echo(std_logic_vector(to_unsigned(addr, OPCODE_SZ)));
		echo(" = 0x");
		hex_echol(axo.rdata);
		wait until clk'event and clk = '1';
	end procedure;

end package body;
