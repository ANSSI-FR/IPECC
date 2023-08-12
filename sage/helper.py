#
#  Copyright (C) 2023 - This file is part of IPECC project
#
#  Authors:
#      Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
#      Ryad BENADJILA <ryadbenadjila@gmail.com>
#
#  Contributors:
#      Adrian THILLARD
#      Emmanuel PROUFF
#
#  This software is licensed under GPL v2 license.
#  See LICENSE file at the root folder of the project.
#

####################
# Helper functions #
####################

# function to REDCify
# requires globals: p (prime)
#                   R = 2^(nn+2)
def redc(x, y, p, R, ppr):
    sr = x * y
    tr = (sr * ppr) % R
    vr = sr + (tr * p)
    wr = vr / R
    return wr

# function to display split bit words of a big number
# (no global required)
def disp(x, base):
    tmp = Integer(x)
    ndx = 0
    while (tmp != 0):
        print(ndx,(tmp % 2**base).hex())
        tmp = tmp // 2**base
        ndx+=1

# function to say if a point is on curve
# requires globals: p, a, b (not in Montg. repres.)
# assumes: input (x,y,z) in normal repres. (not Montg.) and in affine form
def is_affine_point_on_curve(x, y, p, a, b):
    if ( ((y**2) % p) == (((x**3) + (a*x) + b) % p) ):
        return 1
    else:
        return 0

# function to say if a point is on curve
# requires globals: p (prime)
#                   a, b (params of the curve)
#                   redc (routine)
# assumes: input (x,y,z) in Montg. repres. and in Jacobian form
def is_jacobian_point_on_curve(x, y, z, p, R, ppr):
    # leave Montgomery domain
    xx = redc(1, x, p, R, ppr)
    yy = redc(1, y, p, R, ppr)
    zz = redc(1, z, p, R, ppr)
    # return to affine coordinates
    xxx = (xx/(zz**2)) % p
    yyy = (yy/(zz**3)) % p
    if ( ((yyy**2) % p) == (((xxx**3) + (a*xxx) + b) % p) ):
        return 1
    else:
        return 0

# function to compute affine coordinates of a point given
# requires globals: p (prime)
#                   a, b (params of the curve)
#                   redc (routine)
# assumes: input (x,y,z) in Montg. repres. and in Jacobian form
def jacob2affine(x, y, z):
    # leave Montgomery domain
    xx = redc(1, x, p, R, ppr)
    yy = redc(1, y, p, R, ppr)
    zz = redc(1, z, p, R, ppr)
    # return to affine coordinates
    xxx = (xx/(zz**2)) % p
    yyy = (yy/(zz**3)) % p
    return (xxx, yyy)

# reduction modulo 2p after subtraction
def redsub2p(x, y, p):
    z = x - y
    if z < 0:
        return z + (2*p)
    else:
        return z

# reduction modulo 2p after addition
def redadd2p(x, y, p):
    z = x + y
    if z > (2*p):
        return z - (2*p)
    else:
        return z

# reduction modulo p
def reducep(z, p):
    if z - p < 0:
        return z
    else:
        return z - p

