#
# Copyright (C) 2023 - This file is part of IPECC project
#
# Authors:
#     Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
#     Ryad BENADJILA <ryadbenadjila@gmail.com>
#
# Contributors:
#     Adrian THILLARD
#     Emmanuel PROUFF

import re, sys, os, math, random

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


##########################################################
### Montgomery related computation
def egcd(b, n):
    x0, x1, y0, y1 = 1, 0, 0, 1
    while n != 0:
        q, b, n = b // n, n, b % n
        x0, x1 = x1, x0 - q * x1
        y0, y1 = y1, y0 - q * y1
    return  b, x0, y0
def modinv(a, m):   
    g, x, y = egcd(a, m)
    if g != 1:
        raise Exception("Error: modular inverse does not exist")
    else:
        return x % m
def compute_monty_coef(prime, pbitlen):
    """
    Compute montgomery coeff r, r^2 and mpinv. pbitlen is the size
    of p in bits.
    """
    r = (1 << int(pbitlen)) % prime
    r_square = (1 << (2 * int(pbitlen))) % prime
    pinv = (-modinv(p, r)) % r
    return r, r_square, pinv

### Emulation related stuff
class IPECCExecutionContext(object):
    def __init__(self, registers, flags, ip, lrip):
        global OPERANDS_BITS_SIZE
        global BIGNUM_BITS_SIZE
        MEMORY_SIZE = 2**OPERANDS_BITS_SIZE
        self.r = [0] * MEMORY_SIZE
        for (addr, val) in registers:
            if addr > MEMORY_SIZE:
                print_error("Error: ", "@%d exceeds memory capacity of %d" % (addr, MEMORY_SIZE), "(only registers in memory are allowed!)")
                sys.exit(-1)
            self.r[addr] = val
        self.flags = {
            "%mu0"  : 0,      
            "%kb0"  : 0,      
            "%par"  : 0,      
            "%kapP" : 0,      
            "%kap"  : 0,
            # Arithmetic carry flag
            "%Carith"   : 0,
            # Shift carry flag
            "%Cshift"   : 0,
            # Zero flag
            "%Z"    : 0,
            # Strictly negative flag                          
            "%SN"   : 0,                                        
        }
        for (f, val) in flags:
            self.flags[f] = val
        # Instruction pointer
        if ip is not None:
            self.ip = ip
        else:
            self.ip = 0
        # Link register
        if lrip is not None:
            self.lrip = lrip
        else:
            self.lrip = 0
        # p constant cached
        self.p = self.r[0]
        # Executed "line" in textual form
        self.executed_line = None
        # Masking related stuff
        self.s = [0x0, 0x0, 0x0, 0x0]
        #### Patch related stuff
        #### FIXME: this must be implemented!
        #self.do_blinding = 0
        #self.masklsb = 0
        #self.setup = 0
        #self.laststep = 0
        #self.zu = self.zc = 0
        #self.r0z = self.r1z = 0
        #self.patches = {
        #        "p"  : 0,
        #        "as" : 0,
        #        "opa" : { "x0" : 0, "x1" : 0, "y0" : 0, "y1" : 0, "x0next" : 0, "x1next" : 0, "y0next" : 0, "y1next" : 0, "x0det" : 0, "y0det" : 0 },
        #        "opb" : { "x0" : 0, "x1" : 0, "y0" : 0, "y1" : 0, "x0next" : 0, "x1next" : 0, "y0next" : 0, "y1next" : 0, "x0det" : 0, "y0det" : 0 },
        #        "opc" : { "x1" : 0, "y1" : 0, "x0next" : 0, "x1next" : 0, "y0next" : 0, "y1next" : 0, "blvoid" : 0, "copiesopa" : 0, "bl0" : 0, "bl1" : 0 },
        #}
    def __str__(self):
        a = "\t============== IPECC Execution context ==============\n"
        addr = 0
        a += "\tMemory: [ "
        for v in self.r:
            a += "(%d, %s), " % (addr, hex(v))
            addr += 1
        a += " ]\n\tFlags: %s\n\tIP=0x%x\n\tLRIP=0x%x\n" % (self.flags, self.ip, self.lrip)
        if self.executed_line is not None:
            a += "\t==> %s\n" % self.executed_line
        return a

def apply_patch(execution_context, opa, opb, opc, options):
    for o in options:
        patch_num = None
        # Get the patch
        aa = re.search(r"p([0-9]+)", o)
        if aa is not None:
            patch_num = int(aa.group(1))
        if patch_num is None:
            # Nothing to do, return
            return (execution_context, opa, opb, opc)
        else:
            print_error("Error: ", "%s: " % execution_context.executed_line, " patch %d is asked, patches are NOT implemented yet!" % patch_num)
            sys.exit(-1)
    # Nothing to do, return
    return (execution_context, opa, opb, opc)

def update_arith_flags(C, execution_context, Z=False, SN=False, ODD=False):
    if Z is True:
        # Check if we are 0
        execution_context.flags['%Z'] = int(C == 0)
    if SN is True:
        # If we have produced a negative number set the SN
        execution_context.flags['%SN'] = (C >> (BIGNUM_BITS_SIZE - 1)) & 1
    if ODD is True:
        # Check if we are even or odd
        execution_context.flags['%par'] = (C % 2)
    return execution_context

def nop_emulate(ins, execution_context):
    # Nop does nothing except increment the ip
    execution_context.ip += 1
    return execution_context

def nnadd_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Perform our addition modulo
    A = execution_context.r[opa]
    B = execution_context.r[opb]
    C = (A + B)
    # Do we have to add the carry?
    for o in options:
        if (o == 'X') and (execution_context.flags['%Carith'] == 1):
            C += 1
    # If we have produced a carry set the flag
    if C >= (2**BIGNUM_BITS_SIZE):
        execution_context.flags['%Carith'] = 1
    C = (C % (2**BIGNUM_BITS_SIZE))
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True, SN=True)
    # Result
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnsub_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Perform our addition modulo
    A = execution_context.r[opa]
    B = execution_context.r[opb]
    C = (A - B)
    # Do we have to add the carry?
    for o in options:
        if (o == 'X') and (execution_context.flags['%Carith'] == 1):
            C += 1
    # Normalize our number in two's complement
    C = (C % (2**BIGNUM_BITS_SIZE))
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True, SN=True)
    # Result
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnsrl_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    A = execution_context.r[opa]
    # Do we have to add the carry?
    carry = 0
    for o in options:
        if (o == 'X') and (execution_context.flags['%Cshift'] == 1):
            carry = 1
    if (A & 1):
        execution_context.flags['%Cshift'] = 1
    C = (A >> 1) | (carry << (BIGNUM_BITS_SIZE - 1))
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnsll_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    A = execution_context.r[opa]
    # Do we have to add the carry?
    carry = 0
    for o in options:
        if (o == 'X') and (execution_context.flags['%Cshift'] == 1):
            carry = 1
    if (A >> (BIGNUM_BITS_SIZE - 1)) == 1:
        execution_context.flags['%Cshift'] = 1
    C = (A << 1) % (2**BIGNUM_BITS_SIZE)
    C |= carry
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnrnd_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    execution_context.r[opc] = random.randrange(0, 2**BIGNUM_BITS_SIZE)
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def testpars_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    opc_name = abstract_operands[2][1]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Test the parity of opa and update the flag
    A = execution_context.r[opa]
    execution_context.flags[opc_name] = (A % 2)
    # 
    return execution_context

def nnxor_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Perform our addition modulo
    A = execution_context.r[opa]
    B = execution_context.r[opb]
    C = (A ^ B)
    # Result
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def fpredc_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Perform our addition modulo
    A = execution_context.r[opa]
    B = execution_context.r[opb]
    pbitlen = getbitlen(execution_context.p)
    # NOTE: we add 4 bits for the Monty trick using R > 4p
    # for the 0 < u, v, w < 2p invariant
    MontyR = 2**(BIGNUM_BITS_SIZE + 4)
    C = (A * B * modinv(MontyR, execution_context.p)) % execution_context.p
    # Result
    execution_context.r[opc] = C
    # Increment IP
    execution_context.ip += 1
    return execution_context

def testpar_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opc = abstract_operands[2][2]
    opc_name = abstract_operands[2][1]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Test the parity of opa and update the flag
    A = execution_context.r[opa]
    execution_context.flags[opc_name] = (A % 2)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnrndm_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operand
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # NOTE: (BIGNUM_BITS_SIZE - 1) truncation for NNRNDM to
    # ensure the random result is < p
    execution_context.r[opc] = random.randrange(0, 2**(BIGNUM_BITS_SIZE - 1))
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nndiv2_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    A = execution_context.r[opa]
    # Save the sign
    sign = (A >> (BIGNUM_BITS_SIZE - 1)) & 0x1
    C = (A >> 1) | (sign << (BIGNUM_BITS_SIZE - 1))
    execution_context.r[opc] = C
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnrnds_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Generate our mask
    s_num = int(opb)
    execution_context.s[s_num] = random.randrange(0, 2**BIGNUM_BITS_SIZE)
    # Put the mask in the opc operand
    execution_context.r[opc] = execution_context.s[s_num]
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnrndf_emumate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    # Generate our mask
    s_num = int(opb)
    execution_context.s[s_num] = random.randrange(0, 2**BIGNUM_BITS_SIZE)
    # Put the mask in the opc operand
    execution_context.r[opc] = execution_context.s[s_num]
    # Increment IP
    execution_context.ip += 1
    return execution_context

def nnsrls_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Get the operands
    opa = abstract_operands[0][2]
    opb = abstract_operands[1][2]
    opc = abstract_operands[2][2]
    # Apply the possible patches
    execution_context, opa, opb, opc = apply_patch(execution_context, opa, opb, opc, options)
    A = execution_context.r[opa] 
    s_num = int(opb)
    # Unmask our value
    A = (A ^ execution_context.s[s_num])
    # Do we have to add the carry?
    carry = 0
    for o in options:
        if (o == 'X') and (execution_context.flags['%Cshift'] == 1):
            carry = 1
    if (A & 1):
        execution_context.flags['%Cshift'] = (1 ^ (execution_context.s[s_num] & 0x1))
    C = (A >> 1) | (carry << (BIGNUM_BITS_SIZE - 1))
    # Shift our mask
    execution_context.s[s_num] = execution_context.s[s_num] >> 1
    # Mask our result value
    C = (C ^ execution_context.s[s_num])
    execution_context.r[opc] = C
    # Update the arithmetic flags
    execution_context = update_arith_flags(C, execution_context, Z=True)
    # Increment IP
    execution_context.ip += 1
    return execution_context

def j_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump to our target
    imm = abstract_operands[0][2]
    execution_context.ip = imm
    return execution_context

def jz_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump to our target only if '%Z' is set
    if execution_context.flags['%Z'] == 1:
        imm = abstract_operands[0][2]
        execution_context.ip = imm
    else:
        execution_context.ip += 1
    return execution_context

def jsn_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump to our target only if '%SN' is set
    if execution_context.flags['%SN'] == 1:
        imm = abstract_operands[0][2]
        execution_context.ip = imm
    else:
        execution_context.ip += 1
    return execution_context

def jodd_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump to our target only if '%par' is set
    if execution_context.flags['%par'] == 1:
        imm = abstract_operands[0][2]
        execution_context.ip = imm
    else:
        execution_context.ip += 1
    return execution_context

def jkap_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump to our target only if '%kap' is set
    if execution_context.flags['%kap'] == 1:
        imm = abstract_operands[0][2]
        execution_context.ip = imm
    else:
        execution_context.ip += 1
    return execution_context

def jl_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump with link
    imm = abstract_operands[0][2]
    execution_context.lrip = execution_context.ip + 1
    execution_context.ip = imm
    return execution_context

def jlsn_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Jump with link to our target only if 'SN' is set
    if execution_context.flags['%SN'] == 1:
        imm = abstract_operands[0][2]
        execution_context.lrip = execution_context.ip + 1
        execution_context.ip = imm
    else:
        execution_context.ip += 1
    return execution_context

def ret_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Return to lrip
    execution_context.ip = execution_context.lrip
    return execution_context

def barrier_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Nothing to do here, we do not
    # increment ip
    return execution_context

def stop_emulate(ins, execution_context):
    # Unpack values
    addr, instruction, options, abstract_operands, l = ins
    execution_context.executed_line = l
    # Nothing to do here, we do not
    # increment ip
    return execution_context


## VHDL files creation headers and footers
##########################################################
ecc_curve_iram_begin =r"""
-- -------------------------------------------------------
-- This file is automatically generated through scripting
-- -------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_customize.all; -- for debug & nbopcodes parameters
use work.ecc_utils.all; -- for function ge_pow_of_2
use work.ecc_pkg.all; -- for IRAM_ADDR_SZ & OPCODE_SZ parameters

-- code below conforms to Xilinx's synthesis recommandations for
-- VHDL coding style of a simple dual-port BRAM with _two_clocks_
-- (see Vivado Design Suite User Guide, Synthesis, UG901, v2014.1,
--  May 1, 2014, pp. 105-106)
-- except that it describes a two-cycle delay on the read data path.
-- Depending on the FPGA vendor/family device target, an extra-layer of
-- register may be present inside the Block-RAM providing such 2-cycle
-- latency, as it leads to better timing performance (at the cost of
-- a small increase in the Block-RAM area).
-- In this case it is best for area performance to ensure that the
-- extra register layer on the read data path is held back inside
-- the Block-RAM by back-end tools
entity ecc_curve_iram is
	generic(
		rdlat : positive range 1 to 2 := 2);
	port(
		-- port A: write-only interface to AXI-lite interface
		clka : in std_logic;
		rea : in std_logic;
		wea : in std_logic;
		addra : in std_logic_vector(IRAM_ADDR_SZ - 1 downto 0);
		dia : in std_logic_vector (OPCODE_SZ - 1 downto 0);
		doa : out std_logic_vector (OPCODE_SZ - 1 downto 0);
		-- port B: read-only interface to ecc_curve
		clkb : in std_logic;
		reb : in std_logic;
		addrb : in std_logic_vector (IRAM_ADDR_SZ - 1 downto 0);
		dob : out std_logic_vector (OPCODE_SZ - 1 downto 0)
	);
end entity ecc_curve_iram;

architecture syn of ecc_curve_iram is

	subtype std_logic_opcode is std_logic_vector(OPCODE_SZ - 1 downto 0);
	type mem_content_type is array(integer range 0 to ge_pow_of_2(nbopcodes) - 1)
		of std_logic_opcode;
	shared variable mem_content : mem_content_type := (
		-- content of static memory automatically written below through scripting
		--
		--    opcode in binary format            address        opcode in hex
		-- <----------------------------->     <--------->      <---------->
"""

ecc_curve_iram_end = r"""
		others => (others => '0')
	);
	signal predoutb : std_logic_opcode;
	signal predouta : std_logic_opcode;

begin

	-- ---------------------------------------------
	-- Port A (R/W) is only present if in debug mode
	-- ---------------------------------------------
	d0: if debug generate -- statically resolved by synthesizer
		process(clka)
		begin
			if (clka'event and clka = '1') then
				if (wea = '1') then
					mem_content(to_integer(unsigned(addra))) := dia;
				end if;
				if (rea = '1') then
					predouta <= mem_content(to_integer(unsigned(addra)));
				end if;
				doa <= predouta;
			end if;
		end process;
	end generate;

	d1: if not debug generate -- statically resolved by synthesizer
		doa <= (others => '1');
	end generate;	

	-- --------------------------------------------------------------
	-- Port B (R only) is the nominal port used by ecc_curve to fetch
	-- instructions (which makes ecc_curve_iram a ROM when debug mode
	-- is not activated)
	-- --------------------------------------------------------------
	r1 : if rdlat = 1 generate -- statically resolved by synthesizer
		process(clkb)
		begin
			if (clkb'event and clkb = '1') then
				if (reb = '1') then
					dob <= mem_content(to_integer(unsigned(addrb)));
				end if;
			end if;
		end process;
	end generate;

	r2 : if rdlat = 2 generate -- statically resolved by synthesizer
		process(clkb)
		begin
			if (clkb'event and clkb = '1') then
				if (reb = '1') then
					predoutb <= mem_content(to_integer(unsigned(addrb)));
				end if;
				dob <= predoutb;
			end if;
		end process;
	end generate;

end architecture syn;
"""

ecc_addr_begin = r"""
-- -------------------------------------------------------
-- This file is automatically generated through scripting
-- -------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ecc_pkg.all;

package ecc_addr is

"""

ecc_addr_end = r"""

end package ecc_addr;
"""

#####################################################
#####################################################

def key_words_regexp(l):
    ret = ""
    i = 0
    for k in l:
        ret += k
        i += 1
        if i != len(l):
            ret += "|"
    return ret

# Default values, updated when read from
# VHDL files
BIGNUM_BITS_SIZE = 528
OPERANDS_BITS_SIZE = 5
PATCH_BITS_SIZE = 6
IMMEDIATE_BITS_SIZE = 9
CONSTANTS_BITS_SIZE = 2
OPCODE_BITS_SIZE = 4
OPCODE_CLASS_BITS_SIZE = 2
ipecc_operands_dict = {
	"p": "00000",
	"a": "00001",
	"b": "00010",
	"q": "00011",
	"k": "00100",
	"XR1": "00110",
	"YR1": "00111",
	"XR0": "00100",
	"YR0": "00101",
	"ZR01": "11010",
	"one": "11110",
	"zero": "11111",
	"R": "11101",
	"kb0": "00100",
	"kb1": "00101",
	"phi0": "01010",
	"phi1": "01011",
	"kap0": "01100",
	"kap1": "01101",
	"kapP0": "01110",
	"kapP1": "01111",
	"R2modp": "10011",
	"XPBK": "11011",
	"YPBK": "11100",
	"ZPBK": "10110",
	"inverse": "10101",
	"dtmp": "10100",
	"XmXU": "01000",
	"twop": "11000",
	"red": "10110",
	"dy1": "01111",
	"dy2": "10000",
	"dx1": "10111",
	"dx2": "10001",
	"du": "11001",
	"dv": "11010",
	"dx": "11011",
	"dy": "11100",
	"r0": "11001",
	"r1": "11010",
	"two": "10111",
	"pmtwo": "10001",
	"idx": "01111",
	"aX": "01111",
	"right": "01111",
	"mustbezero": "10101",
	"YY": "10000",
	"left": "10000",
	"XX": "10001",
	"XXX": "10001",
	"XR": "10001",
	"R3modp": "10100",
	"mu0": "11010",
	"mu1": "11011",
	"kap0msk": "01000",
	"kap1msk": "01001",
	"kapP0msk": "10000",
	"kapP1msk": "10001",
	"phi0msk": "10100",
	"phi1msk": "10101",
	"qsh0": "01000",
	"qsh1": "01001",
	"btmp0": "01010",
	"btmp1": "01011",
	"alf": "01100",
	"m0": "01010",
	"m1": "01011",
	"alfmsk": "01111",
	"ZZ": "01000",
	"ZZZZ": "01000",
	"aZZZZ": "01000",
	"2YR1": "01000",
	"M": "01001",
	"MpSmT": "01001",
	"Q": "01001",
	"YYYY": "10000",
	"QQ": "10000",
	"S": "10001",
	"SmT": "10001",
	"X1YY": "10010",
	"lambdasq": "10110",
	"MM": "10110",
	"lambda": "10101",
	"lambdacu": "10101",
	"Y1Z1": "10101",
	"A": "01000",
	"BmX": "01000",
	"W": "01000",
	"F": "01000",
	"C": "01001",
	"CmB": "01001",
	"BpC": "01001",
	"H": "01001",
	"J": "01001",
	"YmY": "10000",
	"G": "10100",
	"D": "10001",
	"DmB": "10001",
	"Xtmp": "10100",
	"Ytmp": "10101",
	"XmXC": "10101",
	"YpY": "10100",
	"B": "10111",
	"A1": "11001",
	"CCmB": "11001",
	"XSUB": "01000",
	"YSUB": "10000",
	"XR0tmp": "10000",
	"YR0tmp": "10001",
	"ZPBKsq": "01110",
	"ZPBKcu": "01110",
	"ZR01sq": "10101",
	"ZR01cu": "10101",
	"ZR01END": "11001",
	"XR1tmp": "10110",
	"YR1tmp": "10100",
	"invsq": "01010",
	"invcu": "01011",
	"patchme": "10101",
	"HH": "01010",
	"tHH": "01010",
	"Ia": "01010",
	"I": "01100",
	"Ja": "01001",
	"r": "01011",
	"V": "01010",
	"rsq": "01100",
	"JpV": "01101",
	"Jp2V": "01101",
	"YmJ": "01001",
	"tYmJ": "01001",
	"VmX": "01010",
	"rVmX": "01010",
	"XR0bk": "01110",
	"YR0bk": "01111",
	"XR1bk": "11100",
	"YR1bk": "01100",
    "XADD": "10001",
    "K": "10000",
    "YADD": "10000",
    "Ec": "11001",
    "BmXC": "01000",
    "MD": "01000",
    "Msq": "10101",
    "N": "01000",
    "Nsq": "01000",
    "Nsq0": "10111",
    "E": "01001",
    "L": "10000",
    "XpE": "10100",
    "BpL": "10001",
    "twoB": "10101",
    "threeB": "10111",
    "EpN": "11001",
    "YpZ": "10101",
    "YpZsq": "10101",
    "twoS": "10111",
	"Rmodp": "11101",
    "Qs": "01001",
    "AZ": "01000",
    "KK": "10000",
    "BZ": "10111",
    "BZd": "10111",
    "Xup": "01000",
    "Yup": "01001",
    "Ztmp": "11001",
    "Yopp": "10101",
    "Ykeep": "10000",
    "Xkeep": "10100",
    # "Patch" operand, dummy value
    "patchme": "10101",
    ### Disassembly registers for
    ### recompiling the disassembly
	"disass_r0": "00000",
	"disass_r1": "00001",
	"disass_r2": "00010",
	"disass_r3": "00011",
	"disass_r4": "00100",
	"disass_r5": "00101",
	"disass_r6": "00110",
	"disass_r7": "00111",
	"disass_r8": "01000",
	"disass_r9": "01001",
	"disass_r10": "01010",
	"disass_r11": "01011",
	"disass_r12": "01100",
	"disass_r13": "01101",
	"disass_r14": "01110",
	"disass_r15": "01111",
	"disass_r16": "10000",
	"disass_r17": "10001",
	"disass_r18": "10010",
	"disass_r19": "10011",
	"disass_r20": "10100",
	"disass_r21": "10101",
	"disass_r22": "10110",
	"disass_r23": "10111",
	"disass_r24": "11000",
	"disass_r25": "11001",
	"disass_r26": "11010",
	"disass_r27": "11011",
	"disass_r28": "11100",
	"disass_r29": "11101",
	"disass_r30": "11110",
	"disass_r31": "11111",
}

FLAGS_BITS_SIZE = OPERANDS_BITS_SIZE
ipecc_flags_dict = {
    "%mu0"    : "10000",
    "%kb0"    : "01000",
    "%par"    : "00100",
    "%kap"    : "00010",
    "%kapP"   : "00001",
}

# Internal IPECC flags, *Only* used
# for emulation as they are of no use
# for simple assemby/disassembly
ipecc_internal_flags_dict = {
    # Arithmetic carry flag
    "%Carith"   : None,
    # Shift carry flag
    "%Cshift"   : None,
    # Zero flag
    "%Z"   : None,
    # Strictly negative flag
    "%SN"  : None,
}

# Operands
def ipecc_operand():
    return key_words_regexp(ipecc_operands_dict.keys())
# Flags
def ipecc_flag():
    return key_words_regexp(ipecc_flags_dict.keys())
def ipecc_internal_flag():
    return key_words_regexp(ipecc_internal_flags_dict.keys())
# Numerical constant
def ipecc_const():
    return "[0-9]+|0[x][0-9a-fA-F]+"

ipecc_labels_dict = {
    # This is to be populated by the address resolver
    # pass
}

ipecc_label_ = ""
def ipecc_label():
    global ipecc_labels_dict
    global ipecc_label_
    # Protect the '.'
    a = []
    for k in ipecc_labels_dict.keys():
        if k[0] == r'.':
            # NOTE: 1: to skip the '.', :-1 to remove the
            # final ':'
            a.append(r'\.'+k[1:-1])
    ipecc_label_ = key_words_regexp(a)


ipecc_instructions_dict = {
	# NOP instruction
	"NOP" : ([], "NOP", "0000", None, nop_emulate),
	# arithmetic instructions
	#   values here must match their equivalent ones in ecc_pkg.vhd!
	#   (starting with the string "OPCODE_ARITH_")
	"NNADD" : ([ipecc_operand(), ipecc_operand(), ipecc_operand()], "ARITH", "0001", "ADD", nnadd_emulate),
	"NNSUB" : ([ipecc_operand(), ipecc_operand(), ipecc_operand()], "ARITH", "0010", "SUB", nnsub_emulate),
	"NNSRL" : ([ipecc_operand(), None, ipecc_operand()], "ARITH", "0011", "SRL", nnsrl_emulate),
	"NNSLL" : ([ipecc_operand(), None, ipecc_operand()], "ARITH", "0100", "SLL", nnsll_emulate),
	"NNRND" : ([None, None, ipecc_operand()], "ARITH", "0101", "RND", nnrnd_emulate),
	"TESTPARS" : ([ipecc_operand(), ipecc_const(), ipecc_flag()], "ARITH", "0110", "TSH", testpars_emulate),
	"NNXOR" : ([ipecc_operand(), ipecc_operand(), ipecc_operand()], "ARITH", "0111", "XOR", nnxor_emulate),
	"FPREDC" : ([ipecc_operand(), ipecc_operand(), ipecc_operand()], "ARITH", "1000", "RED", fpredc_emulate),
	"TESTPAR" : ([ipecc_operand(), None, ipecc_flag()], "ARITH", "1001", "TST", testpar_emulate),
	"NNRNDM" : ([None, None, ipecc_operand()], "ARITH", "1010", "RNM", nnrndm_emulate),
	"NNDIV2" : ([ipecc_operand(), None, ipecc_operand()], "ARITH", "1011", "DIV", nndiv2_emulate),
	"NNRNDS" : ([None, ipecc_const(), ipecc_operand()], "ARITH", "1100", "RNH", nnrnds_emulate),
	"NNRNDF" : ([None, ipecc_const(), ipecc_operand()], "ARITH", "1101", "RNF", nnrndf_emumate),
	"NNSRLS" : ([ipecc_operand(), ipecc_const(), ipecc_operand()], "ARITH", "1110", "SRH", nnsrls_emulate),
	# branch instructions, the None is to be updated with a
    # proper label after the fitst pass
	"J"    : ([None], "BRANCH", "0001", "B", j_emulate),
	"JZ"   : ([None], "BRANCH", "0010", "BZ", jz_emulate),
	"JSN"  : ([None], "BRANCH", "0011", "BSN", jsn_emulate),
	"JODD" : ([None], "BRANCH", "0100", "BODD", jodd_emulate),
	"JKAP" : ([None], "BRANCH", "0101", "BKAP", jkap_emulate),
	"JL"   : ([None], "BRANCH", "0110", "CALL", jl_emulate),
	"JLSN" : ([None], "BRANCH", "0111", "CALLSN", jlsn_emulate),
	"RET"  : ([], "BRANCH", "1000", "RET", ret_emulate),
    # "Pseudo" instructions, None encoding means nothing
    # to encode
    "BARRIER" : ([], "PSEUDO", None, None, barrier_emulate),
    "STOP" : ([], "PSEUDO", None, None, stop_emulate),
    # "Aliases": empty encoding means an alias
    "NNCLR"  : ([ipecc_operand()], "ALIAS", "NNADD", ['zero', 'zero', 'OPERAND0'], None),
    "NNMOV"  : ([ipecc_operand(), ipecc_operand()], "ALIAS", "NNADD", ['OPERAND0', 'zero', 'OPERAND1'], None),
    "B"      : ([None], "ALIAS", "J", ['OPERAND0'], None),
    "BZ"     : ([None], "ALIAS", "JZ", ['OPERAND0'], None),
    "BSN"    : ([None], "ALIAS", "JSN", ['OPERAND0'], None),
    "BODD"   : ([None], "ALIAS", "JODD", ['OPERAND0'], None),
    "BKAP"   : ([None], "ALIAS", "JKAP", ['OPERAND0'], None),
    "CALL"   : ([None], "ALIAS", "JL", ['OPERAND0'], None),
    "CALLSN" : ([None], "ALIAS", "JLSN", ['OPERAND0'], None),
}

def ipecc_instruction():
    return key_words_regexp(ipecc_instructions_dict.keys())

# Refresh our instructions dict
def ipecc_instructions_dict_refresh_operands():
    global ipecc_instructions_dict
    for k in ipecc_instructions_dict.keys():
        a = ipecc_instructions_dict[k]
        ops = []
        for op in ipecc_instructions_dict[k][0]:
            if (op is not None) and (op != ipecc_const()) and (op != ipecc_label_) and (op != ipecc_flag()):
                # This is an operand() type, refresh it
                ops.append(ipecc_operand())
            else:
                ops.append(op)
        a = (ops, a[1], a[2], a[3], a[4])
        ipecc_instructions_dict[k] = a


ipecc_instructions_types_dict = {
        "NOP"    : "00",
        "ARITH"  : "01",
        "BRANCH" : "10",
}

##########################################################
def getbitlen(bint):
    """
    Returns the number of bits encoding an integer
    """
    if bint is None:
        return 0
    if bint == 0:
        # Zero is encoded on one bit
        return 1
    return int(bint).bit_length()

# Integer to binay string
def int_to_binstring(a, nbits):
    ret = ""
    for i in range(0, nbits):
        if (a >> (nbits - i - 1)) & 1 == 1:
            ret += "1"
        else:
            ret += "0"
    return ret

# Binay string to integer
def binstring_to_int(b):
    ret = 0
    for i in range(0, len(b)):
        if b[len(b) - i - 1] == "1":
            ret |=(0x1 << i)
    return ret

def term_colors_supported():
    # Only use colors in a real terminal
    return sys.stdout.isatty()

def print_error(err, l, reason):
    if term_colors_supported() is True:
        print(bcolors.FAIL+err+bcolors.ENDC + bcolors.HEADER+l+bcolors.ENDC + bcolors.OKCYAN+reason+bcolors.ENDC)
    else:
        print(err+ l + reason)

def print_warning(err, reason):
    if term_colors_supported() is True:
        print(bcolors.WARNING+err+bcolors.ENDC + bcolors.WARNING+reason+bcolors.ENDC)
    else:
        print(err + reason)

def print_info(inf, msg):
    if term_colors_supported() is True:
        print(bcolors.OKCYAN+inf+bcolors.ENDC + bcolors.OKBLUE+msg+bcolors.ENDC)
    else:
        print(inf + msg)

def print_progress(msg):
    if term_colors_supported() is True:
        print(bcolors.OKGREEN+msg+bcolors.ENDC)
    else:
        print(msg)

##########################################################
# Resolve the labels addresses and populate the
# labels dict
def resolve_labels(asm):
    lines = asm.splitlines()
    address = 0
    for l in lines:
        # Skip comments
        comment = re.search(r"^\s*#", l)
        empty_line = re.search(r"^\s*$", l)
        if (comment is None) and (empty_line is None):
            # Actual label or opcode
            label = re.search(r"^\s*(\.[a-zA-Z0-9].*:)\s*(#.*)*$", l)
            opcode = re.search(r"^\s*("+ipecc_instruction()+r")", l, flags=re.IGNORECASE)
            if label is not None:
                label = label.group(1)
                # We have a new label!
                ipecc_labels_dict[label] = (int_to_binstring(address, IMMEDIATE_BITS_SIZE), hex(address))
            if opcode is not None:
                # If we have a pseudo instruction do not increment,
                # else increment
                opcode = opcode.group(1).upper()
                if ipecc_instructions_dict[opcode][1] != "PSEUDO":
                    # Increment our address count
                    address += 1
    # Update our labels list
    ipecc_label()
    # Update our instructions dictionary
    for k in ipecc_instructions_dict.keys():
        if ipecc_instructions_dict[k][0] == [None]:
            ipecc_instructions_dict[k][0][0] = ipecc_label_

# Encode the opcodes
def encode_opcodes(asm):
    lines = asm.splitlines()
    line_num = 1
    # The encoding
    encoding = ""
    barrier_set = False
    abstract_asm_representation = []
    current_addr = 0
    for l in lines:
        # Local options flags
        OPTIONS = []
        OPERANDS = []
        # Operands for our abstract representation
        ABSTRACT_OPERANDS = [None, None, None]
        # Skip comments, empty lines and labels
        comment = re.search(r"^\s*#", l)
        empty_line = re.search(r"^\s*$", l)
        label = re.search(r"^\s*(\.[a-zA-Z0-9].*:)\s*(#.*)*$", l)
        if (comment is None) and (empty_line is None) and (label is None):
            inst = re.search(r"^\s*("+ipecc_instruction()+r")([,\s]+.*)", l, flags=re.IGNORECASE)
            if inst is None:
                inst = re.search(r"^\s*("+ipecc_instruction()+r")(,.*)", l, flags=re.IGNORECASE)
            if inst is None:
                inst = re.search(r"^\s*("+ipecc_instruction()+r")(#.*)*$(.*)", l, flags=re.IGNORECASE)
            if inst is None:
                print_error("Syntax error line %d: " % line_num,  l, ", unknown instruction")
                sys.exit(-1)
            options = None
            operands = None
            instruction = inst.group(1).upper()
            rest = inst.group(2)
            #################################
            ## Try to get the possible options
            if rest is not None:
                # Now get the possible options
                options = re.search(r"(,p[0-9]+|,X|,M)?(,p[0-9]+|,X|,M)?(,p[0-9]+|,X|,M)?(.*)", rest)
                if options is not None:
                    if options.group(1) is not None:
                        OPTIONS.append(options.group(1)[1:])
                    if options.group(2) is not None:
                        OPTIONS.append(options.group(2)[1:])
                    if options.group(3) is not None:
                        OPTIONS.append(options.group(3)[1:])
                    if options.group(4) is not None:
                        rest = options.group(4)
            # Sanity check on the options
            check = 0
            if 'X' in OPTIONS:
                check += 1
            if 'M' in OPTIONS:
                check += 1
            if len(OPTIONS) > (check + 1):
                print_error("Syntax error line %d: " % line_num, l, ", too many extensions or patches for instruction")
                sys.exit(-1)
            #################################
            # Try to get the operands
            # Get the instruction semantic
            semantic = ipecc_instructions_dict[instruction]
            # Construct our operand pattern from the semantic
            op_re = r"^\s*"
            local_num_operands = 0
            for op in semantic[0]:
                if op is not None:
                    local_num_operands += 1
                    op_re += r"("+op+r")" + r"\s*"
            op_re += r"(#.*)*$"
            if (rest is None) and (local_num_operands > 0):
                print_error("Syntax error line %d: " % line_num, l, ", instruction expects operands")
                sys.exit(-1)
            if rest is not None:
                # If we do not have arguments, check that we have nothing left
                if local_num_operands == 0:
                    op_re_noop = r"^\s*(#.*)*$"
                    check = re.search(op_re_noop, rest)
                    if check is None:
                        print_error("Syntax error line %d: " % line_num, l, ", operands provided for a no-operand instruction")
                        sys.exit(-1)
                operands = re.search(op_re, rest)
                if operands is None:
                    print_error("Syntax error line %d: " % line_num, l, " bad operands")
                    if ipecc_instructions_dict[instruction][1] == "BRANCH":
                        print_info("Hint: ", "this is a branch instruction: have you defined the target label?")
                    else:
                        print_info("Hint: ", "check the operands: are they well defined in the CSV?")
                    sys.exit(-1)
                # Do we have arguments to parse?
                for i in range(0, local_num_operands):
                    if operands.group(i+1) is None:
                        print_error("Syntax error line %d: " % line_num, l, " bad operands")
                        print_info("Hint: ", "check the operands: are they well defined in the CSV?")
                        sys.exit(-1)
                    OPERANDS.append(operands.group(i+1))
            # Handle the ALIASes here
            if ipecc_instructions_dict[instruction][1] == "ALIAS":
                # Get the aliased instruction true semantic
                unaliased_instruction = ipecc_instructions_dict[instruction][2]
                # Get the operands semantic
                sem = ipecc_instructions_dict[instruction][3]
                # Replace our instruction
                instruction = unaliased_instruction
                # Handle our operands
                NEWOPERANDS = []
                for op in sem:
                    aa = re.search(r"OPERAND([0-9]+)", op)
                    if aa is not None:
                        # Original operand
                        op_num = int(aa.group(1))
                        NEWOPERANDS.append(OPERANDS[op_num])
                    else:
                        # External operand
                        NEWOPERANDS.append(op)
                OPERANDS = NEWOPERANDS
            if ipecc_instructions_dict[instruction][1] == "PSEUDO":
                if instruction == "BARRIER":
                    barrier_set = True
                else:
                    barrier_set = False
                if instruction == "STOP":
                    # Patch our "S" bit in the previous instruction
                    encoding = encoding.replace('S', '1')
                else:
                    # Patch our "S" bit in the previous instruction
                    encoding = encoding.replace('S', '0')
            current_encoding = ""
            if ipecc_instructions_dict[instruction][1] != "PSEUDO":
                # Patch our "S" bit in the previous instruction
                encoding = encoding.replace('S', '0')
                # OK, now proceed with the current_encoding of the opcode
                ### Bits 31 and 30 that handle BARRIER and STOP
                # Bit 31 is set if the next instruction is a STOP
                # NOTE => this should be handled in the next loop
                # iteration
                current_encoding += "S" # To be patched
                # BIT 30 is set if the previous instruction is a BARRIER
                if barrier_set is True:
                    current_encoding += "1"
                    barrier_set = False
                else:
                    current_encoding += "0"
                ### Bits 29 downto 28 (either ARITH or BRANCH) & 27 downto 24 (OPCODE)
                current_encoding += ipecc_instructions_types_dict[ipecc_instructions_dict[instruction][1]]
                current_encoding += ipecc_instructions_dict[instruction][2]
                ### Bit 23 encodes the 'X' (eXtended arithmetic)
                if 'X' in OPTIONS:
                    current_encoding += "1"
                else:
                    current_encoding += "0"
                ### Bit 22 downto 16 (bit 22 is set to 1 if there is a patch, 0 otherwise
                ### bits 21 downto 16 encode a 6-bit patch ID if bit 22 is 1)
                PATCH = False
                for p in OPTIONS:
                    aa = re.search(r"p([0-9]+)", p)
                    if aa is not None:
                        patch_num = int(aa.group(1))
                        if patch_num >= 2**PATCH_BITS_SIZE:
                            print_error("Syntax error line %d: " % line_num, l, ", patch number %d exceed %d-bit width" % (patch_num, PATCH_BITS_SIZE))
                            sys.exit(-1)
                        PATCH = True
                        current_encoding += ("1" + int_to_binstring(patch_num, PATCH_BITS_SIZE))
                        break
                if PATCH is False:
                    current_encoding += ("0" + ("0" * PATCH_BITS_SIZE))
                ### Bit 15 is the 'M' flag
                if 'M' in OPTIONS:
                    current_encoding += "1"
                else:
                    current_encoding += "0"
                ### Bit 14 downto 0 are the operands
                if ipecc_instructions_dict[instruction][1] == "NOP":
                    # No operand for NOP
                    current_encoding += "0" * (3 * OPERANDS_BITS_SIZE)
                elif ipecc_instructions_dict[instruction][1] == "ARITH":
                    # Some sanity checks
                    if len(OPERANDS) > 3:
                        print_error("Syntax error line %d: " % line_num, l, ", operands number %d > 3 for ARITH instruction" % (len(OPERANDS)))
                        sys.exit(-1)
                    # Put our operands
                    num_op = 0
                    real_num_op = 0
                    for opn in range(0, 3):
                        if ipecc_instructions_dict[instruction][0][opn] is None:
                            # Skip None operands
                            current_encoding += "0" * OPERANDS_BITS_SIZE
                            real_num_op += 1
                            continue
                        # Do we have flags?
                        if ipecc_instructions_dict[instruction][0][opn] == ipecc_flag():
                            # Extract our flag
                            current_encoding += ((FLAGS_BITS_SIZE -  5) * "0") + ipecc_flags_dict[OPERANDS[num_op]]
                            ABSTRACT_OPERANDS[real_num_op] = ("FLAG", OPERANDS[num_op], binstring_to_int(ipecc_flags_dict[OPERANDS[num_op]]))
                            # Update the abstract representation
                            real_num_op += 1
                            num_op += 1
                        # Do we have a constant?
                        elif ipecc_instructions_dict[instruction][0][opn] == ipecc_const():
                            constant = int(OPERANDS[num_op])
                            if constant > 2**CONSTANTS_BITS_SIZE:
                                print_error("Syntax error line %d: " % line_num, l, ", constant %d exceeds the %d bits size" % (constant, CONSTANTS_BITS_SIZE))
                                sys.exit(-1)
                            # Put it in the LSB of the operand field
                            current_encoding += ((OPERANDS_BITS_SIZE - CONSTANTS_BITS_SIZE) * "0") + int_to_binstring(constant, CONSTANTS_BITS_SIZE)
                            # Update the abstract representation
                            ABSTRACT_OPERANDS[real_num_op] = ("CONST", None, constant)
                            real_num_op += 1
                            num_op += 1
                        # Else we have a regular operand
                        else:
                            # The "patchme" operand is automatically handled here
                            current_encoding += ((OPERANDS_BITS_SIZE -  5) * "0") + ipecc_operands_dict[OPERANDS[num_op]]
                            # Update the abstract representation
                            ABSTRACT_OPERANDS[real_num_op] = ("OP", OPERANDS[num_op], binstring_to_int(ipecc_operands_dict[OPERANDS[num_op]]))
                            num_op += 1
                            real_num_op += 1
                elif ipecc_instructions_dict[instruction][1] == "BRANCH":
                    # Our branch instructions must have at most one operand
                    if len(OPERANDS) > 1:
                        print_error("Syntax error line %d: " % line_num, l, ", operands number %d > 1 for BRANCH instruction" % (len(OPERANDS)))
                        sys.exit(-1)
                    # Extract the immediate
                    if len(OPERANDS) == 1:
                        label = OPERANDS[0]
                        immediate = ipecc_labels_dict[label+":"][0]
                        current_encoding += (((3 * OPERANDS_BITS_SIZE) - IMMEDIATE_BITS_SIZE) * "0") + immediate
                        # Update the abstract representation
                        ABSTRACT_OPERANDS[0] = ("IMM", label, binstring_to_int(immediate))
                    else:
                        current_encoding += (3 * OPERANDS_BITS_SIZE) * "0"
                else:
                    print_error("Syntax error line %d: " % line_num, l, ", unkown instruction type %s" % (ipecc_instructions_dict[instruction][1]))
                    sys.exit(-1)
                ##########
                # Sanity checks on the result
                if len(current_encoding) != (5 + OPCODE_CLASS_BITS_SIZE + OPCODE_BITS_SIZE + PATCH_BITS_SIZE + (3 * OPERANDS_BITS_SIZE)):
                    print_error("Syntax error line %d: " % line_num, l, ", internal error: encoding is %d instead of %d" % (len(current_encoding), (5 + OPCODE_CLASS_BITS_SIZE + OPCODE_BITS_SIZE + PATCH_BITS_SIZE + (3 * OPERANDS_BITS_SIZE))))
                    sys.exit(-1)
                encoding += current_encoding + "\n"
            ### Add the abstract representation
            abstract_asm_representation.append((current_addr, instruction, OPTIONS, ABSTRACT_OPERANDS, l))
            if ipecc_instructions_dict[instruction][1] != "PSEUDO":
                current_addr += 1
        line_num += 1
    # Remove our trailing 'S'
    if 'S' in encoding:
        encoding = encoding.replace('S', '0')
    return (encoding, abstract_asm_representation)

def assemble_file(infile):
    with open(infile, "r") as f:
        asm = f.read()
        # First pass to resolve the labels
        resolve_labels(asm)
        print("    -> First pass for labels resolution done")
        # Second pass for encoding opcodes
        (encoding, abstract_asm) = encode_opcodes(asm)
        print("    -> Second pass for opcode encoding done")
        # Now format our assembly output
        output = ""
        lines = encoding.splitlines()
        line_num = 1
        address = 0
        addr_digits_10 = str(len(str(len(lines))))
        addr_digits_x = str(len(str(hex(len(lines)))) - 2) # -2 to account for initial "0x" added by str on an hex
        for l in lines:
            if len(l) % 8 == 0:
                form = str(2*(len(l) // 8))
            else:
                form = str(2*((len(l) // 8) + 1))
            output += ("\t\t\"%s\", -- 0x%0"+addr_digits_x+"x (%0"+addr_digits_10+"d)\t\t\t(0x%0"+form+"x)") % (l, address // len(l), address // len(l), binstring_to_int(l))
            if line_num != len(lines):
                output += "\n"
            line_num += 1
            address += len(l)
        output = ecc_curve_iram_begin + output + ecc_curve_iram_end
        outfile = os.path.splitext(infile)[0] + ".vhd"
        with open(outfile, "w") as f:
            f.write(output)
        print_progress("[+] Assembling file %s done in %s" % (infile, outfile))
        # Export our symbols in ecc_addr.vhd
        output = ""
        for k in ipecc_labels_dict.keys():
            # If the label is suffixed with "L_export", we have
            # to export it
            check = re.search(r"L_export:", k)
            if check is not None:
                k_ = k.replace(r"L_export:", "")[1:]
                output += "\tconstant ECC_IRAM_"+k_.upper()+"_ADDR : std_logic_vector(IRAM_ADDR_SZ - 1 downto 0) := "
                output += ("\""+ipecc_labels_dict[k][0]+"\"; -- %s\n") % ipecc_labels_dict[k][1]
        output = ecc_addr_begin + output + ecc_addr_end
        outfile = os.path.splitext(infile)[0] + "_addr.vhd"
        with open(outfile, "w") as f:
            f.write(output)
        print_progress("[+] Exported VHDL addresses of %s done in %s" % (infile, outfile))

def get_dec_hexa_bin_value(inval):
    try:
        val = int(inval)
    except:
        val = inval 
        if val[1] == 'x':
            val = int(inval, 16)
        else:
            val = int(inval, 2)
    return val
    
def emulate_file(infile, initial_state):
    # First, interpret our initial state
    initial_state = initial_state.splitlines()
    line_num = 1
    ip = lrip = breakip = verbosity = None
    flags = []
    registers = []
    print("    -> Parsing stding for options")
    for l in initial_state:
        # Skip empty lines and comments
        comment = re.search(r"^\s*#", l)
        empty_line = re.search(r"^\s*$", l)
        if (comment is not None) or (empty_line is not None):
            line_num += 1
            continue
        check = re.search(r"^\s*("+ipecc_operand()+"|"+ipecc_flag()+"|"+ipecc_internal_flag()+"|mem\[([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\]|ip|lrip|breakip|verbose)\s*=\s*([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\s*(#.*)*$", l)
        if check is None:
            print_error("Error line %d: " % line_num, "%s syntax error" % l, " unknown token")
            sys.exit(-1)
        ## Find our initial state, this consists of
        ## Getting registers values and flags
        check = re.search(r"^\s*("+ipecc_operand()+")\s*=\s*([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\s*(#.*)*$", l)
        if check is not None:
            reg = check.group(1)
            val = get_dec_hexa_bin_value(check.group(2))
            if val >= 2**BIGNUM_BITS_SIZE:
                print_error("Error line %d: " % line_num, "%s: register %s has bad value" % (l, reg), " %d exceeds bignum size %d" % (val, BIGNUM_BITS_SIZE))
                sys.exit(-1)
            registers.append((binstring_to_int(ipecc_operands_dict[reg]), val))
        check = re.search(r"^\s*("+ipecc_flag()+"|"+ipecc_internal_flag()+")\s*=\s*([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\s*(#.*)*$", l)
        if check is not None:
            flag = check.group(1)
            val = get_dec_hexa_bin_value(check.group(2))
            flags.append((flag, val))
            if (val != 0) and (val != 1):
                print_error("Error line %d: " % line_num, "%s: flag %s has bad value" % (l, flag), " only 0/1 binary value is allowed")
                sys.exit(-1)
        ## Getting possible ip, lrip, breakip
        check = re.search(r"^\s*(ip|lrip|breakip)\s*=\s*([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\s*(#.*)*$", l)
        if check is not None:
            val = get_dec_hexa_bin_value(check.group(2))
            if val >= 2**IMMEDIATE_BITS_SIZE:
                print_error("Error line %d: " % line_num, "%s: %s has bad value" % (l, check.group(1)), " %d exceeds instruction bus width (%d bits)" % (val, IMMEDIATE_BITS_SIZE))
                sys.exit(-1)
            if check.group(1) == "ip":
                ip = val
            elif check.group(1) == "lrip":
                lrip = val
            elif check.group(1) == "breakip":
                breakip = val
            else:
                print_error("Error line %d: " % line_num, "%s syntax error" % l, " unknown token")
                sys.exit(-1)
        ## Getting verbosity
        check = re.search(r"^\s*(verbose)\s*=\s*([0-9]+|0x[0-9a-fA-F]+|0b[0-1]+)\s*(#.*)*$", l)
        if check is not None:
            verbosity = get_dec_hexa_bin_value(check.group(2))
    ## Initialize our context with proper values
    context = IPECCExecutionContext(registers, flags, ip, lrip)
    with open(infile, "r") as f:
        asm = f.read()
        # First pass to resolve the labels
        resolve_labels(asm)
        print("    -> First pass for labels resolution done")
        # Second pass for encoding opcodes
        (encoding, abstract_asm) = encode_opcodes(asm)
        print("    -> Second pass for opcode encoding done")
        # First, check if the asked address for ip and rip and breakip are indeed in our
        # range and classify our opcodes in an address base dictionnary
        abstract_asm_dict = {}
        for ins in abstract_asm: 
            (current_addr, instruction, OPTIONS, ABSTRACT_OPERANDS, l) = ins
            if current_addr not in abstract_asm_dict.keys():
                abstract_asm_dict[current_addr] = [ ins ]
            else:
                abstract_asm_dict[current_addr].append(ins)
        if (ip is not None):
            if ip not in abstract_asm_dict.keys():
                print_error("Error: ", "bad ip value %d" % ip, " ip not in allowed range for the program")
                sys.exit(-1)
            context.ip = ip
        else:
            context.ip = 0
        if (lrip is not None):
            if lrip not in abstract_asm_dict.keys():
                print_error("Error: ", "bad lrip value %d" % ip, " lrip not in allowed range for the program")
                sys.exit(-1)
            context.lrip = lrip
        if (breakip is not None):
            if breakip not in abstract_asm_dict.keys():
                print_error("Error: ", "bad breakip value %d" % ip, " breakip not in allowed range for the program")
                sys.exit(-1)
            context.breakip = breakip
        # Our execution loop
        stop = False
        while True:
            # Execute in a loop
            all_ins_at_ip = abstract_asm_dict[context.ip]
            for ins in all_ins_at_ip:
                (current_addr, instruction, OPTIONS, ABSTRACT_OPERANDS, l) = ins
                # Get the routine to execute
                emulation_routine = ipecc_instructions_dict[instruction][4]
                context = emulation_routine(ins, context)
                if verbosity is not None:
                    print(context)
                # Do we have to stop ?
                if instruction == "STOP":
                    print_info("Hitting STOP", "")
                    stop = True
                    break
                if context.ip == breakip:
                    stop = True
                    print_info("Hitting breakip: ", "breakip = %d" % breakip)
                    break
            if stop is True:
                break
        print(context)
    return

##########################################################
def disassemble(binary):
    lines = binary.splitlines()
    line_num = 1
    # Compute our instructions size
    instructions_size = (5 + OPCODE_CLASS_BITS_SIZE + OPCODE_BITS_SIZE + PATCH_BITS_SIZE + (3 * OPERANDS_BITS_SIZE))
    disass_output = []
    instructions_num = 0
    jump_targets = []
    for l in lines:
        local_disass_output = ""
        bitstring = l
        if len(bitstring) != instructions_size:
            print_error("Error line %d: " % line_num, "", "instruction size %d != %d mismatch" % (len(bitstring), instructions_size))
            sys.exit(-1)
        # We have our instruction, split it
        pos = 0
        stop = bitstring[pos]
        pos += 1
        barrier = bitstring[pos]
        pos += 1
        instruction_type = bitstring[pos:pos+OPCODE_CLASS_BITS_SIZE]
        pos += OPCODE_CLASS_BITS_SIZE
        instruction_opcode = bitstring[pos:pos+OPCODE_BITS_SIZE]
        pos += OPCODE_BITS_SIZE
        X = bitstring[pos]
        pos += 1
        is_patch = bitstring[pos]
        pos += 1
        patch = bitstring[pos:pos+PATCH_BITS_SIZE]
        pos += PATCH_BITS_SIZE
        M = bitstring[pos]
        pos += 1
        opa = bitstring[pos:pos+OPERANDS_BITS_SIZE]
        pos += OPERANDS_BITS_SIZE
        opb = bitstring[pos:pos+OPERANDS_BITS_SIZE]
        pos += OPERANDS_BITS_SIZE
        opc = bitstring[pos:pos+OPERANDS_BITS_SIZE]
        pos += OPERANDS_BITS_SIZE
        # First we get the instruction type
        # Then the instruction
        found_ins = None
        for ins in ipecc_instructions_dict.keys():
            t = ipecc_instructions_dict[ins][1]
            if t == "PSEUDO" or t == "ALIAS":
                continue
            tt = ipecc_instructions_types_dict[t]
            e = ipecc_instructions_dict[ins][2]
            if (tt == instruction_type) and (e == instruction_opcode):
                found_ins = ins
                break
        if found_ins is None:
            print_error("Error line %d: %s: " % (line_num, l), "", "impossible to disassemble type %s / ins %s (unknown instruction)" % (instruction_type, instruction_opcode))
            sys.exit(-1)
        # Get our semantics
        sem = ipecc_instructions_dict[found_ins][0]
        # Format our operands
        op_num = 0
        op_string = ""
        allops = [opa, opb, opc]
        for op in sem:
            if op == ipecc_operand():
                op_string += "disass_r"+str(binstring_to_int(allops[op_num]))
            if op == ipecc_const():
                op_string += (" "*8)+str(binstring_to_int(allops[op_num]))
            if op == ipecc_flag():
                found_flag = None
                for flag in ipecc_flags_dict.keys():
                    if ipecc_flags_dict[flag] == allops[op_num]:
                        found_flag = flag
                        op_string += flag
                if found_flag is None:
                    print_error("Error line %d: " % (line_num), l, ", flag %s is not known" % (allops[op_num]))
                    sys.exit(-1)
            if (op is None) and (t == "BRANCH"):
                op_string += ".Label"+str(binstring_to_int(opa+opb+opc))+"L"
                # Save all our branches
                jump_targets.append(binstring_to_int(opa+opb+opc))
            if (op is None) and (t != "BRANCH"):
                op_string += "\t"
            op_string += "\t"
            op_num += 1
        # Format the output
        local_disass_output += "\t\t"+found_ins
        # Handle the X and M bits
        if M == "1":
            local_disass_output += ",M"
        if X == "1":
            local_disass_output += ",X"
        if is_patch == "1":
            local_disass_output += ",p"+str(binstring_to_int(patch))
        local_disass_output += (20-len(local_disass_output))*" "
        local_disass_output += "\t"+op_string
        # Formatting
        if t == "BRANCH":
           local_disass_output += "\t"*4 
        if t == "NOP":
           local_disass_output += "\t"*6
        if barrier == "1":
            disass_output.append((None, "\t\tBARRIER"))
        disass_output.append((instructions_num, local_disass_output))
        if stop == "1":
            disass_output.append((None, "\t\tSTOP"))
        instructions_num += 1
        line_num += 1
    #
    disass_output_str = ""
    for (addr, ins) in disass_output:
        # Is our address concerned by a jump?
        if addr in jump_targets:
            # If yes, add a previous label
            disass_output_str += (".Label%dL:\n" % addr)
        disass_output_str += ins
        if addr is not None:
            disass_output_str += "\t"+("# %d" % addr)+"\n"
        else:
            disass_output_str += "\n"
    return disass_output_str

def disassemble_file(infile):
    instructions_size = (5 + OPCODE_CLASS_BITS_SIZE + OPCODE_BITS_SIZE + PATCH_BITS_SIZE + (3 * OPERANDS_BITS_SIZE))
    with open(infile, "r") as f:
        # Parse all the binary strings in that file
        binary = f.read()
        lines = binary.splitlines()
        line_num = 1
        binary = ""
        for l in lines:
            check = re.search(r"\"([01]+)\"", l)
            if check is not None:
                bitstring = check.group(1)
                if len(bitstring) != instructions_size:
                    print_error("Error line %d: " % line_num, "", "instruction size %d != %d mismatch" % (len(bitstring), instructions_size))
                    sys.exit(-1)
                binary += bitstring+"\n"
            line_num += 1
        # Call the raw disassembler
        disass_output = disassemble(binary)
    outfile = os.path.splitext(infile)[0] + "_disass.s"
    with open(outfile, "w") as f:
        f.write("\t\t######################################################################################\n")
        f.write("\t\t# Disassembly automatically generated. For this file to be compiled again, you will  #\n")
        f.write("\t\t# have to specify the operands disass_r0, disass_r1, ... in your variables CSV file. #\n")
        f.write("\t\t# These registers are simply the mapped ones at incremental addresses, meaning that  #\n")
        f.write("\t\t# you should populate your CSV file with lines like:                                 #\n")
        f.write("\t\t#        disass_r0,0                                                                 #\n")
        f.write("\t\t#        disass_r1,1                                                                 #\n")
        f.write("\t\t#        ... and so on                                                               #\n")
        f.write("\t\t#                                                                                    #\n")
        f.write("\t\t# Note that the assembler contains these disassembly registers by default, but if    #\n")
        f.write("\t\t# somehow these have changed (e.g. registers size and so on), an update MUST be      #\n")
        f.write("\t\t# provided in the variables CSV file for the assembler to properly find them.        #\n")
        f.write("\t\t#                                                                                    #\n")
        f.write("\t\t# Also note that instructions with patches could have dummy operands: you will have  #\n")
        f.write("\t\t# to know what the exact patch is doing to interpret the disassembly.                #\n")
        f.write("\t\t######################################################################################\n")
        f.write(disass_output)
    print_progress("[+] Disassembly of %s written in %s" % (infile, outfile))
    return

##########################################################

# Extract from VHDL the information about our constants and instructions
def parse_vhdl(vhdl, vhdl_conf):
    global ipecc_instructions_dict
    global ipecc_instructions_types_dict
    global OPERANDS_BITS_SIZE
    global PATCH_BITS_SIZE
    global IMMEDIATE_BITS_SIZE
    global CONSTANTS_BITS_SIZE
    global OPCODE_BITS_SIZE
    global OPCODE_CLASS_BITS_SIZE
    global BIGNUM_BITS_SIZE
    #
    lines = vhdl.splitlines()
    line_num = 1
    for l in lines:
        ## Opcode classes
        check = re.search(r"constant\s+OPCODE_([A-Z]+)\s*:.*:=\s*\"([01]+)\"", l)
        if check is not None:
            # Extract the values
            opcode_type = check.group(1)
            val = check.group(2)
            if OPCODE_CLASS_BITS_SIZE != len(val):
                print_warning("Warning: ", "%s opcode class bit length mismatches (%d != %d), updating" % (opcode_type, OPCODE_CLASS_BITS_SIZE, len(val)))
                OPCODE_CLASS_BITS_SIZE = len(val)
        ## Opcode values
        check = re.search(r"constant\s+OPCODE_([A-Z]+)_([A-Z]+)\s*:.*\s*:=\s*\"([01]+)\"", l)
        if check is not None:
            # Extract the values
            opcode_type = check.group(1)
            if opcode_type == "BRA":
                opcode_type = "BRANCH"
            opcode = check.group(2)
            val = check.group(3)
            # Find it in our dictionary
            for k in ipecc_instructions_dict.keys():
                if ipecc_instructions_dict[k][1] == "ARITH" or ipecc_instructions_dict[k][1] == "BRANCH":
                    if ipecc_instructions_dict[k][3] == opcode:
                        if opcode_type != ipecc_instructions_dict[k][1]:
                            print_warning("Warning: ", "%s opcode type mismatches (%s != %s), updating" % (opcode, opcode_type, ipecc_instructions_dict[k][1]))
                            ipecc_instructions_dict[k] = (ipecc_instructions_dict[k][0], opcode_type, ipecc_instructions_dict[k][1], ipecc_instructions_dict[k][3])
                        # Check the equality
                        if val != ipecc_instructions_dict[k][2]:
                            print_warning("Warning: ", "%s opcode value mismatches (%s != %s), updating" % (opcode, val, ipecc_instructions_dict[k][2]))
                            ipecc_instructions_dict[k] = (ipecc_instructions_dict[k][0], ipecc_instructions_dict[k][1], val, ipecc_instructions_dict[k][3])
                        # Sanity check
                        if OPCODE_BITS_SIZE != len(val):
                            print_warning("Warning: ", "%s opcode bit length mismatches (%d != %d), updating" % (opcode, OPCODE_BITS_SIZE, len(val)))
                            OPCODE_BITS_SIZE = len(val)
        ## Patch size
        check = re.search(r"OP_PATCH_SZ\s*:\s*integer\s*:=\s*([0-9]+)", l)
        if check is not None:
            val = int(check.group(1))
            if PATCH_BITS_SIZE != val:
                print_warning("Warning: ", "PATCH_BITS_SIZE mismatches (%d != %d), updating" % (OPCODE_BITS_SIZE, val))
                PATCH_BITS_SIZE = val
        ## Branch immediate size
        # This must be equal to IRAM_ADDR_SZ
        check = re.search(r"OP_BR_IMM_SZ\s*:\s*integer\s*:=\s*([A-Z_]+)", l)
        if check is not None:
            val = check.group(1)
            if val != "IRAM_ADDR_SZ":
                print_error("Error: ", "", "apparently OP_BR_IMM_SZ = %s, and not IRAM_ADDR_SZ in VHDL file!" % (val))
                sys.exit(-1)
        check = re.search(r"IRAM_ADDR_SZ\s*:\s*integer\s*:=\s*([0-9]+)", l)
        ## Constants operand size
        check = re.search(r"OP_SHREG_IMM_SZ\s*:\s*positive\s*:=\s*([0-9]+)", l)
        if check is not None:
            val = int(check.group(1))
            if val != CONSTANTS_BITS_SIZE:
                print_warning("Warning: ", "CONSTANTS_BITS_SIZE mismatches (%d != %d), updating" % (CONSTANTS_BITS_SIZE, val))
                CONSTANTS_BITS_SIZE = val
        line_num += 1
    # Handle the operand and bignum size in the configuration package
    lines = vhdl_conf.splitlines()
    line_num = 1
    nblargenb = nbopcodes = None
    for l in lines:
        ## Operand size
        check = re.search(r"constant\s+nblargenb\s*:\s*positive\s*:=\s*([0-9]+)", l)
        if check is not None:
            nblargenb = int(check.group(1))
        ## Opcode size
        check = re.search(r"constant\s+nbopcodes\s*:\s*positive\s*:=\s*([0-9]+)", l)
        if check is not None:
            nbopcodes = int(check.group(1))
        ## Bignum size
        check = re.search(r"constant\s+nn\s*:\s*positive\s*:=\s*([0-9]+)", l)
        if check is not None:
            nnsize = int(check.group(1))
            if BIGNUM_BITS_SIZE != nnsize:
                print_warning("Warning: ", "BIGNUM_BITS_SIZE mismatches (%d != %d), updating" % (BIGNUM_BITS_SIZE, nnsize))
                BIGNUM_BITS_SIZE = nnsize
        line_num += 1
    if (nbopcodes is None) or (nblargenb is None):
        print_error("Error: ", "", "cannot find nbopcodes or nblargenb in the VHDL conf file")
        sys.exit(-1)
    # The operand size is log2(nblargenb)
    if 2**int(math.log2(nblargenb)) != nblargenb:
        print_error("Error: ", "", "nblargenb = %d is weird ... (not a power of 2)" % nblargenb)
        sys.exit(-1)
    if 2**OPERANDS_BITS_SIZE != nblargenb:
        opsize = int(math.log2(nblargenb))
        print_warning("Warning: ", "OPERANDS_BITS_SIZE mismatches (%d != %d), updating" % (OPERANDS_BITS_SIZE, opsize))
        OPERANDS_BITS_SIZE = opsize
    # The immediate branch size should be log2(nbopcodes)
    if 2**int(math.log2(nbopcodes)) != nbopcodes:
        print_error("Error: ", "", "nbopcodes = %d is weird ... (not a power of 2)" % nbopcodes)
        sys.exit(-1)
    if 2**IMMEDIATE_BITS_SIZE != nbopcodes:
        immsize = int(math.log2(nbopcodes))
        print_warning("Warning: ", "IMMEDIATE_BITS_SIZE and nbopcodes mismatch (%d != %d), updating" % (IMMEDIATE_BITS_SIZE, immsize))
        IMMEDIATE_BITS_SIZE = immsize
    print_progress("[+] Parsing of VHDL files done, everything OK")


# Extract from CSV the information about our operand variables mapping
def parse_csv(csv):
    lines = csv.splitlines()
    line_num = 1
    for l in lines:
        # Skip comments and empty lines
        comment = re.search(r"^\s*#", l)
        empty_line = re.search(r"^\s*$", l)
        if (comment is None) and (empty_line is None):
            check = re.search(r"([a-zA-Z0-9_]+),([0-9]+)", l)
            if check is not None:
                op = check.group(1)
                val = int(check.group(2))
                # Check if the operand is in our dictionary and if
                # its address is consistent
                if op in ipecc_operands_dict.keys():
                    addr = ipecc_operands_dict[op]
                    if int_to_binstring(val, OPERANDS_BITS_SIZE) != addr:
                        print_warning("Warning: ", "operand %s from CSV address differs (\"%s\" (@%d) != \"%s\" (@%d)), fixing it" % (op, int_to_binstring(val, OPERANDS_BITS_SIZE), val, addr, binstring_to_int(addr)))
                        ipecc_operands_dict[op] = int_to_binstring(val, OPERANDS_BITS_SIZE)
                else:
                    print_warning("Warning: ", "operand %s (@%d, \"%s\") from CSV missing and added" % (op, val, int_to_binstring(val, OPERANDS_BITS_SIZE)))
                    ipecc_operands_dict[op] = int_to_binstring(val, OPERANDS_BITS_SIZE)
        line_num += 1
    # Refresh our instructions dict with new operands regexps
    ipecc_instructions_dict_refresh_operands()
    print_progress("[+] Parsing of CSV done, everything OK")


## Sanity check and update our dictionaries if asked
if len(sys.argv) > 3:
    if len(sys.argv) != 6:
        print_error("Error: ", "", "expecting -a, -d, or -e the VHDL file as arg3, the VHDL conf as arg4 and the CSV file as arg5!")
        sys.exit(-1)
    print("  -> Parsing %s, %s and %s for checking/updating our constants" % (sys.argv[3], sys.argv[4], sys.argv[5]))
    with open(sys.argv[3], "r") as f1, open(sys.argv[4], "r") as f2 :
        vhdl1 = f1.read()
        vhdl2 = f2.read()
        parse_vhdl(vhdl1, vhdl2)
    with open(sys.argv[5], "r") as f:
        csv = f.read()
        parse_csv(csv)

if len(sys.argv) < 3:
    print_error("Error: ", "", "expecting -a (assemble) or -d (disassemble) or -e (execute) with at least the file")
    sys.exit(-1)

if sys.argv[1] == "-a":
    ## Assembly
    print("  -> Assembling file %s" % sys.argv[2])
    assemble_file(sys.argv[2])
elif sys.argv[1] == "-d":
    ## Disassembly
    print("  -> Disassembling file %s" % sys.argv[2])
    disassemble_file(sys.argv[2])
elif sys.argv[1] == "-e":
    ## Emulation
    # Read stdin
    print("  -> Reading initial state from stdin ...")
    initial_state = sys.stdin.read()
    print("  -> Emulation of file %s" % sys.argv[2])
    emulate_file(sys.argv[2], initial_state)
else:
    print_error("Error: ", "", "unknown option '%s' (-a, -d or -e expected)" % sys.argv[1])
    sys.exit(-1)
