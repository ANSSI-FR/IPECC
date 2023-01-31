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

# This software is licensed under GPL v2 license.
# See LICENSE file at the root folder of the project.


from expand_libecc import *
from struct import *
import socket
import binascii
import sys

###### Low level receive and send on the socket
def recv_data(s):
    # Receive size on 4 bytes
    sz = s.recv(4)
    if len(sz) == 0:
        # Client disconnected
        raise Exception("Client disconnected!")
    sz = unpack('>I', sz)[0]
    if sz == 0:
        return b""
    # Receive data
    data = s.recv(sz)
    if len(data) == 0:
        # Client disconnected
        raise Exception("Client disconnected!")
    return data

def send_data(s, data):
    # Send size on 4 bytes
    sz = s.send(pack('>I', len(data)))
    if sz != 4:
        # Client disconnected
        raise Exception("Client disconnected!")
    if len(data) == 0:
        return True
    # Send data
    sz = s.send(data)
    if sz != len(data):
        # Client disconnected
        raise Exception("Client disconnected!")
    return True

###### The internal state emulating the hardware
current_curve = None
blinding = 0
nn_size = 0
small_scalar_size = 0
# Flags handling points at infinity
zero1 = 0
zero2 = 0

###### Integer conversion function
def buff_to_integer(a):
    # The received big int are in big endian format
    return stringtoint(a.decode('latin-1'))

def integer_to_buff(a, sz=None):
    # Serialize the big int in big endian format
    out = inttostring(a)
    if sz is None:
        return out.encode('latin-1')
    if len(out) >= sz:
        return out[(len(out)-sz):].encode('latin-1')
    else:
        return (('\x00'*(sz-len(out)))+out).encode('latin-1')

###### Helpers
# Set the infinity points according to the zero flags
def set_input_zero_flags(x1, y1, x2, y2):
    global zero1, zero2
    if (x1, y1) != (None, None):
        if (zero1 == 1):
            x1, y1 = None, None
    if (x2, y2) != (None, None):
        if (zero2 == 1):
            x2, y2 = None, None
    return (x1, y1, x2, y2)
    
def set_zero_flags(P1, P2):
    global current_curve, zero1, zero2
    (a, b, p, q) = current_curve
    if P1 is not None:
        if (P1.x is None) and (P1.y is None):
            zero1 = 1
            # In case of infinity point, put dummy data
            # in the coordinates
            P1.x = getrandomint(p)
            P1.y = getrandomint(p)
        else:
            zero1 = 0
    if P2 is not None:
        if (P2.x is None) and (P2.y is None):
            zero2 = 1
            # In case of infinity point, put dummy data
            # in the coordinates
            P2.x = getrandomint(p)
            P2.y = getrandomint(p)
        else:
            zero2 = 0
    return (P1, P2)

def set_zero_flags_hw(idx):
    global zero1, zero2
    if idx == 0:
        zero1 = 1
    elif idx == 1:
        zero2 = 1
    else:
        raise Exception("Bad idx %d > 2 for zero flags!" % idx)
    return

def unset_zero_flags_hw(idx):
    global zero1, zero2
    if idx == 0:
        zero1 = 0
    elif idx == 1:
        zero2 = 0
    else:
        raise Exception("Bad idx %d > 2 for zero flags!" % idx)
    return

def check_zero_flags(idx):
    global zero1, zero2
    if idx == 0:
        return zero1
    elif idx == 1:
        return zero2
    else:
        raise Exception("Bad idx %d > 2 for zero flags!" % idx)
    return

###### All the main commands
def set_blinding(s, cmd):
    global blinding
    print(cmd)
    # Get the blinding
    bld = recv_data(s)
    bld = unpack('>I', bld)[0]
    blinding = bld
    return

def set_curve(s, cmd):
    global current_curve, zero1, zero2, small_scalar_size
    small_scalar_size = 0
    print(cmd)
    # Get the curve parameters
    a = buff_to_integer(recv_data(s))
    b = buff_to_integer(recv_data(s))
    p = buff_to_integer(recv_data(s))
    q = buff_to_integer(recv_data(s))
    current_curve = (a, b, p, q)
    # Reset the zero flags
    zero1 = zero2 = 0
    return

def is_on_curve(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the point to check
    x = buff_to_integer(recv_data(s))
    y = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x, y, _, _) = set_input_zero_flags(x, y, None, None)
    # Compute the point
    try:
        P = Point(curve, x, y)
    except:
        # The point is not on the curve, return 0
        send_data(s, integer_to_buff(0, sz=1))
        return
    # The point is on the curve, return 1
    send_data(s, integer_to_buff(1, sz=1))
    return

def equal(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the points to check
    x1 = buff_to_integer(recv_data(s))
    y1 = buff_to_integer(recv_data(s))
    x2 = buff_to_integer(recv_data(s))
    y2 = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x1, y1, x2, y2) = set_input_zero_flags(x1, y1, x2, y2)
    # Compute the points
    try:
        P1 = Point(curve, x1, y1)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P1 is not on the curve!")
    try:
        P2 = Point(curve, x2, y2)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P2 is not on the curve!")
    # Check equality
    if P1 == P2:
        check = 1
    else:
        check = 0
    # Return the result
    send_data(s, integer_to_buff(check, sz=1))
    return

def opposite(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the points to check
    x1 = buff_to_integer(recv_data(s))
    y1 = buff_to_integer(recv_data(s))
    x2 = buff_to_integer(recv_data(s))
    y2 = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x1, y1, x2, y2) = set_input_zero_flags(x1, y1, x2, y2)
    # Compute the points
    try:
        P1 = Point(curve, x1, y1)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P1 is not on the curve!")
    try:
        P2 = Point(curve, x2, y2)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P2 is not on the curve!")
    # Check opposition
    if P1 == -P2:
        check = 1
    else:
        check = 0
    # Return the result
    send_data(s, integer_to_buff(check, sz=1))
    return

def is_zero(s, cmd):
    print(cmd)
    # Get the index
    idx = buff_to_integer(recv_data(s))
    # Check and return the current zero flag
    iszero = check_zero_flags(idx)
    send_data(s, integer_to_buff(iszero, sz=1))
    return

def zero(s, cmd):
    print(cmd)
    # Get the index
    idx = buff_to_integer(recv_data(s))
    if idx > 2:
        raise Exception(cmd+": index %d > 2 for zero flag!" % idx)
    # Set the flag for the given index 
    set_zero_flags_hw(idx)
    return

def unzero(s, cmd):
    print(cmd)
    # Get the index
    idx = buff_to_integer(recv_data(s))
    if idx > 2:
        raise Exception(cmd+": index %d > 2 for zero flag!" % idx)
    # Set the flag for the given index 
    unset_zero_flags_hw(idx)
    return

def negate(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the point to negare
    x = buff_to_integer(recv_data(s))
    y = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x, y, _, _) = set_input_zero_flags(x, y, None, None)
    # Compute the points
    try:
        P = Point(curve, x, y)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point is not on the curve!")
    # Compute the opposite
    Q = -P
    # Set the zero flag if necessary
    (_, Q) = set_zero_flags(P, Q)
    # Return the result
    send_data(s, integer_to_buff(Q.x))
    send_data(s, integer_to_buff(Q.y))
    return

def double(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the point to double
    x = buff_to_integer(recv_data(s))
    y = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x, y, _, _) = set_input_zero_flags(x, y, None, None)
    # Compute the points
    try:
        P = Point(curve, x, y)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point is not on the curve!")
    # Compute the scalar multiplication
    Q = 2 * P
    # Set the zero flag if necessary
    (_, Q) = set_zero_flags(P, Q)
    # Return the result
    send_data(s, integer_to_buff(Q.x))
    send_data(s, integer_to_buff(Q.y))
    return

def add(s, cmd):
    global current_curve, small_scalar_size
    small_scalar_size = 0
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the points to add
    x1 = buff_to_integer(recv_data(s))
    y1 = buff_to_integer(recv_data(s))
    x2 = buff_to_integer(recv_data(s))
    y2 = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (x1, y1, x2, y2) = set_input_zero_flags(x1, y1, x2, y2)
    # Compute the points
    try:
        P1 = Point(curve, x1, y1)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P1 is not on the curve!")
    try:
        P2 = Point(curve, x2, y2)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point P2 is not on the curve!")
    # Compute the scalar multiplication
    Q = P1 + P2
    # Set the zero flag if necessary
    (_, Q) = set_zero_flags(P1, Q)
    # Return the result
    send_data(s, integer_to_buff(Q.x))
    send_data(s, integer_to_buff(Q.y))
    return

def scalar_mult(s, cmd):
    global current_curve, small_scalar_size
    (a, b, p, q) = current_curve
    curve = Curve(a, b, p, q, 1, None, None, q, "", None)
    print(cmd)
    # Get the point to multiply
    x = buff_to_integer(recv_data(s))
    y = buff_to_integer(recv_data(s))
    # Replace possible points at infinity depending on flags
    (_, _, x, y) = set_input_zero_flags(None, None, x, y)
    # Get the scalar
    scalar = buff_to_integer(recv_data(s))
    # Compute the point
    try:
        P = Point(curve, x, y)
    except:
        # Point is not on the curve
        raise Exception(cmd+": Point is not on the curve!")
    # Compute the scalar multiplication
    if small_scalar_size != 0:
        mask = (2**small_scalar_size) - 1
        Q = (scalar & mask) * P
    else:
        Q = scalar * P
    small_scalar_size = 0
    # Set the zero flag if necessary
    (_, Q) = set_zero_flags(P, Q)
    # Return the result
    send_data(s, integer_to_buff(Q.x))
    send_data(s, integer_to_buff(Q.y))
    return

def set_small_scalar_sz(s, cmd):
    global small_scalar_size
    print(cmd)
    # Get the size
    sz = recv_data(s)
    sz = unpack('>I', sz)[0]
    small_scalar_size = sz
    return

def hw_reset(s, cmd):
    global small_scalar_size, zero1, zero2, blinding, nn_size, current_curve
    print(cmd)
    # Emulate hardware reset
    zero1 = zero2 = 0
    blinding = nn_size = small_scalar_size = 0
    current_curve = None
    return

commands = [("SET_CURVE", set_curve), ("SET_BLINDING", set_blinding), ("IS_ON_CURVE", is_on_curve), ("EQ", equal), ("OPP", opposite), ("ISZERO", is_zero), ("ZERO", zero), ("UNZERO", unzero), ("NEG", negate), ("DBL", double), ("ADD", add), ("SCAL_MUL", scalar_mult), ("SET_SMALL_SCALAR_SZ", set_small_scalar_sz), ("HW_RESET", hw_reset)]

####### The main handler
def handle_cmd(s):
    # Receive the command
    cmd = None
    try:
        cmd = recv_data(s)
        cmd, execute_fn = commands[int(cmd[0])]
    except:
        # Uknown command or client disconnected!
        pass
    if cmd is not None:
        execute_fn(s, cmd)
        return cmd
    else:
        return None
    
socket_listen = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
socket_listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
socket_listen.bind(('127.0.0.1', 8080))

print("[+] IPECC hardware emulator started, listening on 127.0.0.1:8080")

while True:
    socket_listen.listen(1)
    client, address = socket_listen.accept()
    print("[+] Client %s:%d accepted" % (address[0], address[1]))
    while True:
        try:
            cmd = handle_cmd(client)
            if cmd is None:
                break
        except:
            break
