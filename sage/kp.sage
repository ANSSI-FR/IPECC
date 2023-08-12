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

import sys
from helper import redc,disp,is_affine_point_on_curve,is_jacobian_point_on_curve,jacob2affine,redsub2p,redadd2p,reducep

#function prezaddU_kapp0
def prezaddU_kapp0(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXU, YmY
    # compute & reduce completely XmXU (mod p, not only 2p)
    XmXU = redsub2p(XR0, XR1, p)
    XmXU = reducep(XmXU, p)
    # compute & reduce completely YmY (mod p, not only 2p)
    YmY = redsub2p(YR0, YR1, p)
    YmY = reducep(YmY, p)

#function zaddU_kapp0
def zaddU_kapp0(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXU, YmY, ZR01
    Az = redc(XmXU, XmXU, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    C = redc(XR0, Az, p, R, ppr)
    Xtmp = XR1
    Ytmp = YR1
    XR0 = redc(Xtmp, Az, p, R, ppr)
    DmB = redsub2p(D, XR0, p)
    XR1 = redsub2p(DmB, C, p)
    CmB = redsub2p(C, XR0, p)
    YR0 = redc(Ytmp, CmB, p, R, ppr)
    BmX = redsub2p(XR0, XR1, p)
    YR1 = redc(YmY, BmX, p, R, ppr)
    ZR01 = redc(XmXU, ZR01, p, R, ppr)
    YR1 = redsub2p(YR1, YR0, p)

#function prezaddU_kapp1
def prezaddU_kapp1(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXU, YmY
    # compute & reduce completely XmXU (mod p, not only 2p)
    XmXU = redsub2p(XR1, XR0, p)
    XmXU = reducep(XmXU, p)
    # compute & reduce completely YmY (mod p, not only 2p)
    YmY = redsub2p(YR1, YR0, p)
    YmY = reducep(YmY, p)

#function zaddU_kapp1
def zaddU_kapp1(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXU, YmY, ZR01
    Az = redc(XmXU, XmXU, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    C = redc(XR1, Az, p, R, ppr)
    Xtmp = XR0
    Ytmp = YR0
    XR1 = redc(Xtmp, Az, p, R, ppr)
    DmB = redsub2p(D, XR1, p)
    XR0 = redsub2p(DmB, C, p)
    CmB = redsub2p(C, XR1, p)
    YR1 = redc(Ytmp, CmB, p, R, ppr)
    BmX = redsub2p(XR1, XR0, p)
    YR0 = redc(YmY, BmX, p, R, ppr)
    ZR01 = redc(XmXU, ZR01, p, R, ppr)
    YR0 = redsub2p(YR0, YR1, p)

#function prezaddC_kapp0
def prezaddC_kapp0(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G
    # compute & reduce completely XmXC (mod p, not only 2p)
    XmXC = redsub2p(XR0, XR1, p)
    XmXC = reducep(XmXC, p)
    # compute & reduce completely YmY (mod p, not only 2p)
    YmY = redsub2p(YR0, YR1, p)
    YmY = reducep(YmY, p)
    # compute G (="YpY")
    G = redadd2p(YR1, YR0, p)

#function prezaddC_kapp1
def prezaddC_kapp1(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G
    # compute & reduce completely XmXC (mod p, not only 2p)
    XmXC = redsub2p(XR1, XR0, p)
    XmXC = reducep(XmXC, p)
    # compute & reduce completely YmY (mod p, not only 2p)
    YmY = redsub2p(YR1, YR0, p)
    YmY = reducep(YmY, p)
    # compute G (="YpY")
    G = redadd2p(YR0, YR1, p)

#function zaddC_kap0_kapp0
def zaddC_kap0_kapp0(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G, ZR01
    # part specific to kap' = 0
    Az = redc(XmXC, XmXC, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    Bz = redc(XR1, Az, p, R, ppr)
    C = redc(XR0, Az, p, R, ppr)
    CCmB = redsub2p(C, Bz, p)
    Ec = redc(YR1, CCmB, p, R, ppr)
    # part specific to kap = 0
    BpC = redadd2p(Bz, C, p)
    XADD = redsub2p(D, BpC, p)
    XR1 = XADD
    BmXC = redsub2p(Bz, XR1, p)
    K = redc(YmY, BmXC, p, R, ppr)
    F = redc(G, G, p, R, ppr)
    YADD = redsub2p(K, Ec, p)
    YR1 = YADD
    XSUB = redsub2p(F, BpC, p)
    XR0 = XSUB
    H = redsub2p(XSUB, Bz, p)
    J = redc(G, H, p, R, ppr)
    ZR01 = redc(XmXC, ZR01, p, R, ppr)
    YSUB = redsub2p(J, Ec, p)
    YR0 = YSUB
    
#function zaddC_kap0_kapp1
def zaddC_kap0_kapp1(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G, ZR01
    # part specific to kap' = 1
    Az = redc(XmXC, XmXC, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    Bz = redc(XR0, Az, p, R, ppr)
    C = redc(XR1, Az, p, R, ppr)
    CCmB = redsub2p(C, Bz, p)
    Ec = redc(YR0, CCmB, p, R, ppr)
    # part specific to kap = 0
    BpC = redadd2p(Bz, C, p)
    XADD = redsub2p(D, BpC, p)
    XR1 = XADD
    BmXC = redsub2p(Bz, XR1, p)
    K = redc(YmY, BmXC, p, R, ppr)
    F = redc(G, G, p, R, ppr)
    YADD = redsub2p(K, Ec, p)
    YR1 = YADD
    XSUB = redsub2p(F, BpC, p)
    XR0 = XSUB
    H = redsub2p(XSUB, Bz, p)
    J = redc(G, H, p, R, ppr)
    ZR01 = redc(XmXC, ZR01, p, R, ppr)
    YSUB = redsub2p(J, Ec, p)
    YR0 = YSUB

#function zaddC_kap1_kapp0
def zaddC_kap1_kapp0(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G, ZR01
    # part specific to kap' = 0
    Az = redc(XmXC, XmXC, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    Bz = redc(XR1, Az, p, R, ppr)
    C = redc(XR0, Az, p, R, ppr)
    CCmB = redsub2p(C, Bz, p)
    Ec = redc(YR1, CCmB, p, R, ppr)
    # part specific to kap = 1
    BpC = redadd2p(Bz, C, p)
    XADD = redsub2p(D, BpC, p)
    XR0 = XADD
    BmXC = redsub2p(Bz, XR0, p)
    K = redc(YmY, BmXC, p, R, ppr)
    F = redc(G, G, p, R, ppr)
    YADD = redsub2p(K, Ec, p)
    YR0 = YADD
    XSUB = redsub2p(F, BpC, p)
    XR1 = XSUB
    H = redsub2p(XSUB, Bz, p)
    J = redc(G, H, p, R, ppr)
    ZR01 = redc(XmXC, ZR01, p, R, ppr)
    YSUB = redsub2p(J, Ec, p)
    YR1 = YSUB

#function zaddC_kap1_kapp1
def zaddC_kap1_kapp1(p, R, ppr):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G, ZR01
    # part specific to kap' = 1
    Az = redc(XmXC, XmXC, p, R, ppr)
    D = redc(YmY, YmY, p, R, ppr)
    Bz = redc(XR0, Az, p, R, ppr)
    C = redc(XR1, Az, p, R, ppr)
    CCmB = redsub2p(C, Bz, p)
    Ec = redc(YR0, CCmB, p, R, ppr)
    # part specific to kap = 1
    BpC = redadd2p(Bz, C, p)
    XADD = redsub2p(D, BpC, p)
    XR0 = XADD
    BmXC = redsub2p(Bz, XR0, p)
    K = redc(YmY, BmXC, p, R, ppr)
    F = redc(G, G, p, R, ppr)
    YADD = redsub2p(K, Ec, p)
    YR0 = YADD
    XSUB = redsub2p(F, BpC, p)
    XR1 = XSUB
    H = redsub2p(XSUB, Bz, p)
    J = redc(G, H, p, R, ppr)
    ZR01 = redc(XmXC, ZR01, p, R, ppr)
    YSUB = redsub2p(J, Ec, p)
    YR1 = YSUB

def ge_pow_of_2(nb):
    tmp = 1
    while tmp < nb:
        tmp = tmp * 2
    return tmp

# function zdbl
# implements:   -  -> [2]R1|z'
#             R1|z ->    R1|z'
def zdbl(x1, y1, zz, p, R, ppr):
    global aR
    # if input point is detected to be a 2-torsion point, then:
    #   - xupdate, yupdate & zcommon (resp.) will simply copy the
    #     inputs x1, y1 & zz (resp.)
    #   - xdouble & ydouble will be set with new values (related
    #     to intermediate variables below) but without any meaning
    #     since the result of the double by definition is 0 (the
    #     hardware proceeds the same way)
    y1 = reducep(y1, p)
    if y1 == 0:
        torsion2 = 1
    else:
        torsion2 = 0
    N = redc(zz, zz, p, R, ppr)
    E = redc(y1, y1, p, R, ppr)
    L = redc(E, E, p, R, ppr)
    Bz = redc(x1, x1, p, R, ppr)
    XpE = redadd2p(x1, E, p)
    BpL = redadd2p(Bz, L, p)
    XpEsq = redc(XpE, XpE, p, R, ppr)
    Nsq = redc(N, N, p, R, ppr)
    twoB = redadd2p(Bz, Bz, p)
    threeB = redadd2p(twoB, Bz, p)
    EpN = redadd2p(E, N, p)
    YpZ = redadd2p(y1, zz, p)
    YpZsq = redc(YpZ, YpZ, p, R, ppr)
    aNsq = redc(aR, Nsq, p, R, ppr)
    twoL = redadd2p(L, L, p)
    fourL = redadd2p(twoL, twoL, p)
    if torsion2 == 1:
        yupdate = 0 # = input y1 (2-torsion point <=> y1 = 0)
    else:
        yupdate = redadd2p(fourL, fourL, p)
    XpEmBpL = redsub2p(XpEsq, BpL, p)
    S = redadd2p(XpEmBpL, XpEmBpL, p)
    if torsion2 == 1:
        xupdate = x1 # input x1
    else:
        xupdate = S
    Ztmp = redsub2p(YpZsq, EpN, p)
    if torsion2 == 1:
        zcommon = zz # input zz
    else:
        zcommon = Ztmp
    MD = redadd2p(threeB, aNsq, p)
    Msq = redc(MD, MD, p, R, ppr)
    twoS = redadd2p(S, S, p)
    if torsion2 == 1:
        xdouble = 0
    else:
        xdouble = redsub2p(Msq, twoS, p)
    SmX = redsub2p(S, xdouble, p)
    SmXtMD = redc(SmX, MD, p, R, ppr)
    if torsion2 == 1:
        ydouble = 0
    else:
        ydouble = redsub2p(SmXtMD, yupdate, p)
    return (xdouble, ydouble, xupdate, yupdate, zcommon)

def display_coord_of_R0_and_R1(msg, XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, end):
    print("[VHD-CMP-SAGE] " + msg)
    if end == 0:
        if r0z == 1:
            print("[VHD-CMP-SAGE]     @ 4   XR0 = " +
                    f"{Integer(XR0):#0{padd}x}" + " but R0 = 0")
            print("[VHD-CMP-SAGE]     @ 5   YR0 = " +
                    f"{Integer(YR0):#0{padd}x}" + " but R0 = 0")
        else:
            print("[VHD-CMP-SAGE]     @ 4   XR0 = " +
                    f"{Integer(XR0):#0{padd}x}")
            print("[VHD-CMP-SAGE]     @ 5   YR0 = " +
                    f"{Integer(YR0):#0{padd}x}")
    if r1z == 1:
        print("[VHD-CMP-SAGE]     @ 6   XR1 = " +
                f"{Integer(XR1):#0{padd}x}" + " but R1 = 0")
        print("[VHD-CMP-SAGE]     @ 7   YR1 = " +
                f"{Integer(YR1):#0{padd}x}" + " but R1 = 0")
    else:
        print("[VHD-CMP-SAGE]     @ 6   XR1 = " +
                f"{Integer(XR1):#0{padd}x}")
        print("[VHD-CMP-SAGE]     @ 7   YR1 = " +
                f"{Integer(YR1):#0{padd}x}")
    if end == 0:
        print("[VHD-CMP-SAGE]     @ 26 ZR01 = " +
                f"{Integer(ZR01):#0{padd}x}")

################
# main program #
################

def main(nn, p, a, b, q, Px, Py, P_is_null, k, alpha0, nbblindbits,
        mu0, mu1, phi0, phi1, lambd, ww, bb):
    global XR0, YR0, XR1, YR1, XmXC, YmY, G, ZR01, aR, bR
    # prime field definition
    Fp = GF(p)
    # curve definition
    EE = EllipticCurve(Fp, [a,b])
    # point definition
    P = EE(Px, Py)
    # scalar
    ksav = k
    # Compute R
    R = 2**(nn + 2);
    R2modp = Integer(mod(R**2, p))
    ppr = Integer(inverse_mod(-p, R))
    # Rm4p = R - (4*p) # that's how hardware computes R mod p
    # to comply with the patch done in redpit.c to bypass the Rmodp negative
    # bug in the microcode, we replace temporarily Rm4p by Rmodp
    Rmodp = (R % p)
    # for proper comparison of VHDL simu & Sage log files, hexadecimal values
    # must be padded w/ the same number of 0s, so compute variable 'padd' used
    # below in log of points coordinates
    # first compute w:
    if (nn + 4) % ww == 0:
        w = (nn + 4) // ww
    else:
        w = ((nn + 4) // ww) + 1
    # now compute n (greater or equal power-of-2 of w)
    n = ge_pow_of_2(w)
    # then compute padd (note the +2 is to account for the string "0x"
    padd = ( (w * ww) // 4 ) + 2
    # print scalar
    print("")
    print("   k = 0x", Integer(k).hex())
    print("")
    # ###################################################
    #                switch to Montg. domain
    # ###################################################
    print("  Before Montgomery:")
    print("  Px = 0x", Integer(Px).hex())
    print("  Py = 0x", Integer(Py).hex())
    ##
    ## Blinding
    ##
    if nbblindbits > 0:
        alpha = alpha0 % (2**nbblindbits)
        print("")
        print("#### BLINDING")
        print("")
        kb = k + (alpha * q)
        bits_of_kb = nn + nbblindbits
        print("  kb         = 0x", Integer(kb).hex())
        mu = mu0 + ((2**(ww*(ceil((nn+4)/ww)))) * mu1)
        kb = kb.__xor__(Integer(mu))
        print("")
        print("  After boolean masking:")
        print("  mu         = 0x", Integer(mu).hex())
        print("  kb         = 0x", Integer(kb).hex())
    else:
        kb = k
        bits_of_kb = nn;
    # ###################################################
    #                         ADPA
    # ###################################################
    print("")
    print("#### ADPA")
    phi = phi0 + ((2**(ww*(ceil((nn+4)/ww)))) * phi1)
    kb0 = (kb % 2)
    # compute 2 masked versions of kb: kappa and kappaprime
    kb = kb // 2
    kappa = kb.__xor__(Integer(phi))
    kappaprime = kb.__xor__(Integer(phi * 2))
    print("")
    print("  phi        = 0x", Integer(phi).hex())
    print("  Kappa      = 0x", Integer(kappa).hex())
    print("  Kappaprime = 0x", Integer(kappaprime).hex())
    if nbblindbits > 0:
        print("")
        print("  After boolean UNmasking of Kappa & Kappa':")
        mu = mu // 2
        kappa = kappa.__xor__(Integer(mu))
        kappaprime = kappaprime.__xor__(Integer(mu))
        print("  Kappa      = 0x", Integer(kappa).hex())
        print("  Kappaprime = 0x", Integer(kappaprime).hex())
        print("")
    # ###################################################
    #                         setup
    # ###################################################
    print("")
    print("#### Setup")
    # Enter coordinates into Montg. domain
    XR1_ = redc(Px, R2modp, p, R, ppr)
    YR1_ = redc(Py, R2modp, p, R, ppr)
    ZR01_ = redc(1, R2modp, p, R, ppr)
    # back-up coordinates of P (in their Montg. form, not yet "Z-masked")
    XPBK = XR1_
    YPBK = YR1_
    # Enter curve parameters a & b into Montg. domain
    aR = redc(a, R2modp, p, R, ppr)
    bR = redc(b, R2modp, p, R, ppr)
    print("")
    print("  After Montgomery:")
    print("  XR1_    = 0x", Integer(XR1_).hex())
    print("  YR1_    = 0x", Integer(YR1_).hex())
    print("  ZR01_   = 0x", Integer(ZR01_).hex())
    print("  aR      = 0x", Integer(aR).hex())
    # randomize coordinates (Z-masking)
    l = Integer(lambd % p)
    L = redc(l, R2modp, p, R, ppr)
    LL = redc(L, L, p, R, ppr)
    LLL = redc(LL, L, p, R, ppr)
    ZR01 = redc(ZR01_, L, p, R, ppr)
    XR1 = redc(XR1_, LL, p, R, ppr)
    YR1 = redc(YR1_, LLL, p, R, ppr)
    print("  After x lambda:")
    print("  XR1     = 0x", Integer(XR1).hex())
    print("  YR1     = 0x", Integer(YR1).hex())
    print("  ZR01    = 0x", Integer(ZR01).hex())
    print("  lambda0 = 0x", Integer(lambd).hex())
    print("  lambda  = 0x", Integer(l).hex())
    print("          = 0x", Integer(L).hex(), "in Mont. domain")
    # ###################################################
    #                   compute R0 <- [2]P
    # ###################################################
    XR0 = XR1
    YR0 = YR1
    # save coordinates of P (it is in both R0 & R1) in case P is
    # a 2-torsion point
    XPs = XR1
    YPs = YR1
    ZPs = ZR01
    (XR0, YR0, XR1, YR1, ZR01) = zdbl(XR1, YR1, ZR01, p, R, ppr)
    print("")
    print("  R0 <- [2]P  (and R1 Co-Z to R0):")
    print("      XR0 = 0x", Integer(XR0).hex())
    print("      YR0 = 0x", Integer(YR0).hex())
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    print("     ZR01 = 0x", Integer(ZR01).hex())
    if P_is_null == 1: # P was null to begin with
        r0z = 1
        r1z = 1
    elif Py == 0: # P is a 2-torsion point
        r0z = 1 # [2]P = 0
        r1z = 0
        XR0 = 0
        YR0 = 0
        XR1 = XPs
        YR1 = YPs
        ZR01 = ZPs
    else:
        r0z = 0
        r1z = 0
    display_coord_of_R0_and_R1("R0/R1 coordinates (first part of setup, " +
            "R0 <- [2]P), R1 <- [P])",
            XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 0)
    # Perform ZADDU-1 on (R1, R0) that is:
    #   R0.z' <- R0.z + R1.z   = [3]P
    #   R1.z' <- R1.z          = P
    # invert R0 <-> R1
    XR0n = XR0
    YR0n = YR0
    XR0 = XR1
    YR0 = YR1
    XR1 = XR0n
    YR1 = YR0n
    prezaddU_kapp1(p, R, ppr)
    points_are_equal = 0
    points_are_opposite = 0
    if XmXU == 0:
        if YmY == 0:
            # [2]P = P, hence P = 0, so either P_is_null == 0 and the calling script
            # gave us a null point without telling us so (which does not make sense
            # because the null point has no affine representation and the calling
            # interface uses affine coordinates only) or it actually told us so,
            # in which case both R0 & R1 are to be marked as null
            if P_is_null == 0:
                sys.exit("ERROR: detected [2]P == P but P was not given as the null point")
            else:
                r0z = 1
                r1z = 1
        else:
            points_are_equal = 0
            points_are_opposite = 1
    # call zaddU_kapp1
    kappaP1 = kappaprime % 2
    # Save coordinates of R0 (= P) in case point is 3-torsion
    XPs = XR0
    YPs = YR0
    ZPs = ZR01
    zaddU_kapp1(p, R, ppr)
    if r0z == 0 and r1z == 0:
        if points_are_opposite == 1:
            r0z = 1 # [2]P = -P  =>  [3]P = 0 (3-torsion point P)
            XR0 = 0
            YR0 = 0
            r1z = 0 # R1 contains initial point P coZ-updated (and it's not null)
            XR1 = redc(XPs, Rmodp, p, R, ppr)
            YR1 = redc(YPs, Rmodp, p, R, ppr)
            ZR01 = ZPs
    elif r0z == 1 and r1z == 0:
        # this means [2]P = 0 (P is a 2-torsion point) therefore [3]P = P is not null
        r0z = 0
        r1z = 0
        XR0 = redc(XPs, Rmodp, p, R, ppr)
        YR0 = redc(YPs, Rmodp, p, R, ppr)
        XR1 = XR0
        YR1 = YR0
        ZR01 = ZPs
    elif r0z == 0 and r1z == 1:
        sys.exit("ERROR: [3]P is neccessarily null if P is")
    print("")
    print("  After ZADDU-0:")
    print("      XR0 = 0x", Integer(XR0).hex())
    print("      YR0 = 0x", Integer(YR0).hex())
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    print("     ZR01 = 0x", Integer(ZR01).hex())
    # ###################################################
    #                     switch R0/R1
    # ###################################################
    print("")
    print("#### Switch R0 & R1")
    print("")
    kappa1 = kappa % 2
    if kappa1 == 0:
        # Switch R0 and R1
        XR0tmp = XR1
        YR0tmp = YR1
        XR1 = XR0
        YR1 = YR0
        XR0 = XR0tmp
        YR0 = YR0tmp
        print("  performed R0 <-> R1 as kappa_1 = 0")
        print("")
        print("    After R0 <-> R1:")
        print("      XR0 = 0x", Integer(XR0).hex())
        print("      YR0 = 0x", Integer(YR0).hex())
        print("      XR1 = 0x", Integer(XR1).hex())
        print("      YR1 = 0x", Integer(YR1).hex())
        print("     ZR01 = 0x", Integer(ZR01).hex())
        # also swith the state of R0 & R1
        r0ztmp = r0z
        r0z = r1z
        r1z = r0ztmp
    else:
        print("  did not perform R0 & R1 switch as kappa_1 = 1")
        print("")
        print("      XR0 = 0x", Integer(XR0).hex())
        print("      YR0 = 0x", Integer(YR0).hex())
        print("      XR1 = 0x", Integer(XR1).hex())
        print("      YR1 = 0x", Integer(YR1).hex())
        print("     ZR01 = 0x", Integer(ZR01).hex())
    display_coord_of_R0_and_R1("R0/R1 coordinates (second part of setup, " +
            "[3]P <- [2]P + P by ZADDU completed)",
            XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 0)
    # ###################################################
    #                    Joye main loop
    # ###################################################
    print("")
    print("#### JOYE LOOP")
    nbbits = bits_of_kb
    for i in range(nbbits-3+1):
        # sample kappas
        kappa = kappa // 2
        kappaprime = kappaprime // 2
        kappa_i = kappa % 2
        kappaprime_i = kappaprime % 2
        phi = phi // 2
        print("")
        # #################################################################
        #                         prezaddU & zaddU
        # #################################################################
        # prezaddU
        if kappaprime_i == 0:
            prezaddU_kapp0(p, R, ppr)
        else:
            prezaddU_kapp1(p, R, ppr)
        # Compare coordinates to detect & handle exceptions
        if (r0z == 1 and r1z == 0) or (r0z == 0 and r1z == 1):
            points_are_equal = 0
            points_are_opposite = 0
        elif (r0z == 1) and (r1z == 1):
            points_are_equal = 1 # actually it won't matter anymore
            points_are_opposite = 1 # actually it won't matter anymore
        else:
            if XmXU == 0:
                if YmY == 0:
                    points_are_equal = 1;
                else:
                    points_are_opposite = 1;
            else:
                points_are_equal = 0
                points_are_opposite = 0
        if points_are_equal == 1:
            print("R0 and R1 are equal")
        elif points_are_opposite == 1:
            print("R0 and R1 are opposite")
        # zaddU
        if (r0z == 1) and (r1z == 1):
            if kappaprime_i == 0:
                zaddU_kapp0(p, R, ppr)
            else:
                zaddU_kapp1(p, R, ppr)
            # R0 and R1 stay 0
            r0z = 1
            r1z = 1
        elif (r0z == 1) and (r1z == 0):
            # R0|i+1 <- R1|i
            if kappaprime_i == 0:
                # R1|i+1 <= R1|i (nothing to do)
                XR0 = XR1
                YR0 = YR1
                XR1 = redc(XR1, Rmodp, p, R, ppr)
                YR1 = redc(YR1, Rmodp, p, R, ppr)
                # R1 stays not 0
                r1z = 0
            else:
                XR0 = redc(XR1, Rmodp, p, R, ppr)
                YR0 = redc(YR1, Rmodp, p, R, ppr)
                XR1 = XR0
                YR1 = YR0
                # R1 is now 0
                r1z = 1
            # R0 is not 0 anymore
            r0z = 0
        elif (r0z == 0) and (r1z == 1):
            if kappaprime_i == 0:
                # R1|i+1 <- R0|i
                XR1 = redc(XR0, Rmodp, p, R, ppr)
                YR1 = redc(YR0, Rmodp, p, R, ppr)
                XR0 = XR1
                YR0 = YR1
                # R0 is now 0
                r0z = 1
            else:
                XR1 = XR0
                YR1 = YR0
                # R0|i+1 <= R0|i (nothing to do)
                XR0 = redc(XR0, Rmodp, p, R, ppr)
                YR0 = redc(YR0, Rmodp, p, R, ppr)
                # R0 stays not 0
                r0z = 0
            # R1 is not 0 anymore
            r1z = 0
        elif (r0z == 0) and (r1z == 0):
            if (points_are_equal == 1):
                if kappaprime_i == 0:
                    # R0|i+1 <- R1|i
                    # R0 stays not 0
                    # R1|i+1 <- [2]R0|i (or [2]R1|i since R0|i = R1|i)
                    #   if R0|i (= R1|i) is a 2-torsion pt then R1 becomes null
                    (XR1, YR1, XR0, YR0, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                    if YR0 == 0:
                        # R1 is now 0
                        r1z = 1
                else:
                    # R0|i+1 <- [2]R1|i (or [2]R0|i since R0|i = R1|i)
                    #   if R1|i (= R0|i) is a 2-torsion pt then R0 becomes null
                    (XR0, YR0, XR1, YR1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                    if YR1 == 0:
                        # R0 is now 0
                        r0z = 1
                    # R1 stays not 0
            elif (points_are_opposite == 1):
                if kappaprime_i == 0:
                    # R0|i+1 <- R1|i
                    XR1s = XR1; YR1s = YR1
                    zaddU_kapp0(p, R, ppr)
                    XR0 = redc(XR1s, Rmodp, p, R, ppr)
                    YR0 = redc(YR1s, Rmodp, p, R, ppr)
                    # R0 stays not 0
                    # R1 is now 0
                    r1z = 1
                else:
                    # R1|i+1 <- R0|i
                    XR0s = XR0; YR0s = YR0
                    zaddU_kapp0(p, R, ppr)
                    XR1 = redc(XR0s, Rmodp, p, R, ppr)
                    YR1 = redc(YR0s, Rmodp, p, R, ppr)
                    # R0 is now 0
                    r0z = 1
            else:
                # Nominal case
                if kappaprime_i == 0:
                    zaddU_kapp0(p, R, ppr)
                else:
                    zaddU_kapp1(p, R, ppr)
        display_coord_of_R0_and_R1("R0/R1 coordinates after ZADDU of BIT "
           + str(i + 2) + " (kap" + str(i + 2) + " = " + str(kappa_i)
           + ",  kap'" + str(i + 2) + " = " + str(kappaprime_i)
           + ")", XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 0)
        # #################################################################
        #                         prezaddC & zaddC
        # #################################################################
        # prezaddC
        if kappaprime_i == 0:
            prezaddC_kapp0(p, R, ppr)
        else:
            prezaddC_kapp1(p, R, ppr)
        # Compare coordinates to detect & handle exceptions
        if (r0z == 1 and r1z == 0) or (r0z == 0 and r1z == 1):
            points_are_equal = 0
            points_are_opposite = 0
        elif (r0z == 1) and (r1z == 1):
            points_are_equal = 1 # actually it won't matter anymore
            points_are_opposite = 1 # actually it won't matter anymore
        else:
            if XmXC == 0:
                if YmY == 0:
                    points_are_equal = 1
                    points_are_opposite = 0
                else:
                    points_are_opposite = 1
                    points_are_equal = 0
            else:
                points_are_equal = 0
                points_are_opposite = 0
        if points_are_equal == 1:
            print("R0 and R1 are equal")
        elif points_are_opposite == 1:
            print("R0 and R1 are opposite")
        # zaddC
        if (r0z == 1) and (r1z == 1):
            # R0 and R1 stay 0
            r0z = 1
            r1z = 1
        elif (r0z == 1) and (r1z == 0):
            if kappaprime_i == 0:
                # R0|i+1 <- R1|i
                XR0 = XR1
                YR0 = YR1
                # R0 is not 0 anymore
                r0z = 0
                # R1|i+1 <- R1|i
                # R1 stays not 0
            else:
                if kappa_i == 0:
                    # R0|i+1 <- -R1|i
                    XR0 = XR1
                    YR0 = redsub2p(p, YR1, p)
                    # R0 is not 0 anymore
                    r0z = 0
                    # R1|i+1 <- R1|i
                    # R1 stays not 0
                else:
                    # R0|i+1 <- R1|i
                    XR0 = XR1
                    YR0 = YR1
                    # R0 is not 0 anymore
                    r0z = 0
                    # R1|i+1 <- -R1|i
                    YR1 = redsub2p(p, YR1, p)
                    # R1 stays not 0
        elif (r0z == 0) and (r1z == 1):
            # R1 is not null anymore
            r1z = 0
            if kappaprime_i == 0:
                if kappa_i == 0:
                    YR0s = YR0
                    # R0|i+1 <- -R0|i
                    YR0 = redsub2p(p, YR0, p)
                    # R0 stays not 0
                    # R1|i+1 <- R0|i
                    XR1 = XR0
                    YR1 = YR0s
                else:
                    # R0|i+1 <- R0|i
                    # R0 stays not 0
                    # R1|i+1 <- -R0|i
                    XR1 = XR0
                    YR1 = redsub2p(p, YR0, p)
            else:
                # R0|i+1 <- R0|i
                # R0 stays not 0
                # R1|i+1 <- R0|i
                XR1 = XR0
                YR1 = YR0
        elif (r0z == 0) and (r1z == 0):
            if (points_are_equal == 1):
                if kappa_i == 0:
                    # R0 becomes 0
                    r0z = 1
                    # R1|i+1 <- [2]R0|i (or [2]R1|i since R0|i = R1|i)
                    #   if R0|i (= R1|i) is a 2-torsion pt then R1 becomes null
                    (XR1, YR1, XR0, YR0, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                    if YR0 == 0:
                        # R1 is now 0
                        r1z = 1
                else:
                    # R1 becomes 0
                    r1z = 1
                    # R0|i+1 <- [2]R1|i (or [2]R0|i since R0|i = R1|i)
                    #   if R1|i (= R0|i) is a 2-torsion pt then R0 becomes null
                    (XR0, YR0, XR1, YR1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                    if YR1 == 0:
                        # R0 is now 0
                        r0z = 1
            elif (points_are_opposite == 1):
                if kappa_i == 0:
                    if kappaprime_i == 0:
                        # R0|i+1 <- [2]R1|i (NOT [2]R0|i since R0|i = -R1|i)
                        #   if R1|i is a 2-torsion pt then R0 becomes null
                        (XR0, YR0, XR1, YR1, ZR01) = zdbl(XR1, YR1, ZR01, p, R, ppr)
                        if YR1 == 0:
                            r0z = 1
                    else:
                        # R0|i+1 <- [2]R0|i (NOT [2]R1|i since R0|i = - R1|i)
                        #   if R0|i is a 2-torsion pt then R0 becomes null
                        (XR0, YR0, XR1, YR1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr) # ICI
                        if YR0 == 0:
                            r0z = 1
                    # R1 is now 0
                    r1z = 1
                else:
                    # R0 is now 0
                    r0z = 1
                    if kappaprime_i == 0:
                        # R1|i+1 <- [2]R1|i (NOT [2]R0|i since R0|i = - R1|i)
                        #   if R1|i is a 2-torsion point then R1 becomes null
                        (XR1, YR1, XR0, YR0, ZR01) = zdbl(XR1, YR1, ZR01, p, R, ppr)
                        if YR1 == 0:
                            r1z = 1
                    else:
                        # R1|i+1 <- [2]R0|i (NOT [2]R1|i since R0|i = - R1|i)
                        #   if R0|i is a 2-torsion point then R1 becomes null
                        (XR1, YR1, XR0, YR0, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                        if YR0 == 0:
                            r1z = 1
            else:
                # Nominal case
                if kappa_i == 0:
                    if kappaprime_i == 0:
                        zaddC_kap0_kapp0(p, R, ppr)
                    else:
                        zaddC_kap0_kapp1(p, R, ppr)
                else:
                    if kappaprime_i == 0:
                        zaddC_kap1_kapp0(p, R, ppr)
                    else:
                        zaddC_kap1_kapp1(p, R, ppr)
        display_coord_of_R0_and_R1("R0/R1 coordinates after ZADDC of BIT "
                + str(i + 2) + " (kap" + str(i + 2) + " = " + str(kappa_i)
                + ",  kap'" + str(i + 2) + " = " + str(kappaprime_i)
                + ")", XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 0)
    print("")
    print("  ## end of JOYE LOOP")
    # ###########################################################################
    #                        conditional subtraction of P
    # ###########################################################################
    print("")
    print("#### SUBTRACT P")
    # cond. copy of R1 into R0
    print("")
    if (phi % 2) == 1:
        XR0 = XR1
        YR0 = YR1
        print("  Last phi (phi_" + str(nbbits-1) + ") = 1 so we copy R0 <- R1")
        print("    After that:")
        print("      XR0 = 0x", Integer(XR0).hex())
        print("      YR0 = 0x", Integer(YR0).hex())
        # if R1 was null, then R0 is now
        r0z = r1z
    else:
        print("  Last phi (phi_" + str(nbbits-1) + ") = 0 so we did NOT copy "
                + "R0 <- R1")
        # r1z stays what it was
    # at this point, R0 = [k + 1 - (k%2)]P  (whatever the value of last phi is)
    # copy R1 <- P
    print("")
    print("  copy R1 <- P (= XPBK:YPBK[:ZPBK]) backed-up in setup.s")
    XR1 = XPBK
    YR1 = YPBK
    # R1 might be null if initial point P was null
    r1z = P_is_null
    print("")
    print("    After that:")
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    # set R0 & R1 to be Co-Z
    ZPBK = redc(1, R2modp, p, R, ppr)
    ZR01END = redc(ZR01, ZPBK, p, R, ppr)
    ZPBKsq = redc(ZPBK,ZPBK, p, R, ppr)
    XR0 = redc(XR0, ZPBKsq, p, R, ppr)
    ZPBKcu = redc(ZPBKsq, ZPBK, p, R, ppr)
    YR0 = redc(YR0, ZPBKcu, p, R, ppr)
    ZR01sq = redc(ZR01, ZR01, p, R, ppr)
    XR1 = redc(XPBK, ZR01sq, p, R, ppr)
    ZR01cu = redc(ZR01sq, ZR01, p, R, ppr)
    YR1 = redc(YPBK, ZR01cu, p, R, ppr)
    ZR01 = ZR01END
    print("")
    print("  After setting CoZ R0 & R1 (resp. Joye-loop final result & initial "
            + "point P):")
    print("")
    print("      XR0 = 0x", Integer(XR0).hex())
    print("      YR0 = 0x", Integer(YR0).hex())
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    print("     ZR01 = 0x", Integer(ZR01).hex())
    display_coord_of_R0_and_R1("R0/R1 coordinates (first part "
        + "of subtractP, [k + 1 - (k mod 2)]P & P made Co-Z)",
        XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 0)
    # prezaddC
    # we call the same version of prezaddc as for kappa'_i = 1 (this is
    # prezaddC_kapp1 so as to compute point R0 - R1 (not R1 - R0) which is
    # (using notation k' = k + 1 - (k%2))  point  [k']P - P  (not P - [k']P)
    prezaddC_kapp1(p, R, ppr)
    # Conditional subtraction of P by zaddc, zdblc or znegc
    r1z = P_is_null
    if r0z == 1 and r1z == 0: # (mind that r1z is given by P_is_null)
        # point [k + 1 - k%2]P is null but initial point P is not
        points_are_equal = 0
        points_are_opposite = 0
        # here hardware executes .znegcL to return:
        #   - if the scalar is odd:
        #       XR0 = YR0 = 0
        #       XR1 = YR1 = 0
        #   - if the scalar is even:
        #       XR0 = YR0 = 0
        #       R1 <- -R1 (i.e XR1 <- XR1 & YR1 <- -YR1)
        if kb0 == 1:
            XR0 = 0
            YR0 = 0
            XR1 = 0
            YR1 = 0
            r1z = 1 # R1 is null
            # R0 stays null
        else:
            XR0 = 0
            YR0 = 0
            XR1 = XR1
            YR1 = redsub2p(p, YR1, p) 
            r1z = 0 # R1 is not null
            # R0 stays null
    elif r0z == 0 and r1z == 0: # (mind that r1z is given by P_is_null)
        # neither R0 (= [k + 1 - k%2]P) nor R1 (= P) is null
        # we can use the values of global variables XmXC and YmY
        # assigned by the call we made to prezaddC_kapp1() in
        # order to detect if R0 and R1 might be equal or opposite
        if XmXC == 0 and YmY == 0:
            # points are equal [k + 1 - k%2]P = P (and both non null)
            points_are_equal = 1
            points_are_opposite = 0
            # here hardware executes .zdblL to return:
            #   - if the scalar is odd:
            #       XR0 = YR0 = 0
            #       R1 <- R0 (i.e XR1 <- XR0 & YR1 <- YR0)
            #   - if the scalar is even:
            #       XR0 = YR0 = 0
            #       XR1 = YR1 = 0
            if kb0 == 1:
                # R0 <- (0,0)
                # R1 <- R0    with z update
                (dummy0, dummy1, XR1, YR1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                XR0 = 0
                YR0 = 0
                r1z = 0 # R1 is not null
            else:
                # R0 <- (0,0)
                # R1 <- (0,0) with z update
                (dummy0, dummy1, dummy2, dummy3, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                XR0 = 0
                YR0 = 0
                XR1 = 0
                YR1 = 0
                r1z = 1 # R1 is null
        elif XmXC == 0 and YmY != 0:
            # points are opposite [k + 1 - k%2]P = -P (and both non null)
            points_are_equal = 0
            points_are_opposite = 1
            # here hardware executes .zdblL to return:
            #   - if the scalar is odd:
            #       XR0 = YR0 = 0
            #       R1 <- R0 (i.e XR1 <- XR0 & YR1 <- YR0)
            #   - if the scalar is even:
            #       XR0 = YR0 = 0
            #       R1 <- [2]R0
            if kb0 == 1:
                # R0 <- (0,0)
                # R1 <- R0    with Z update
                (dummy0, dummy1, XR1, YR1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                XR0 = 0
                YR0 = 0
                r1z = 0 # R1 is not null
            else:
                # R0 <- (0,0)
                # R1 <- [2]R0   with Z update
                # if R0 ( = [k + 1 - k%2]P ) is a 2-torsion point, then R1 becomes null
                if YR0 == 0:
                    r1z = 1 # R1 is null
                else:
                    r1z = 0 # R1 is not null
                (XR1, YR1, dummy0, dummy1, ZR01) = zdbl(XR0, YR0, ZR01, p, R, ppr)
                XR0 = 0
                YR0 = 0
        else: # XmXC != 0 and YmY != 0:
            # this is the nominal case (nor R0 nor R1 is null and they are
            # nor equal nor opposite)
            points_are_equal = 0
            points_are_opposite = 0
            # here hardware executes .zaddcL to return:
            #   - if the scalar is odd:
            #       - R0 is unchanged
            #       - R1 <- R0 ( = [k + 1 - k%2]P = [k]P)
            #       - with unchanged Z coordinate
            #   - if the scalar is even:
            #       - R1 <- R0 - R1 ( = [k + 1 - k%2]P - P = [k]P )
            #       - R0 <- R0 + R1 (that's the hardware does due to kappa_i=1
            #                        however it is useless here)
            #       - Z coordinate is updated: ZR01 <- redc(ZR01, XmXC)
            if kb0 == 1:
                XR1 = XR0
                YR1 = YR0
            else:
                zaddC_kap1_kapp1(p, R, ppr)
            # nor R0 nor R1 is the null point
            r0z = 0
            r1z = 0
    if kb0 == 1:
        print("")
        print("  kb0 = 1, so did NOT subtract P & instead copied R1 <- R0 "
                + "(= Joye-loop final result)")
        print("      XR0 = 0x", Integer(XR0).hex())
        print("      YR0 = 0x", Integer(YR0).hex())
        print("      XR1 = 0x", Integer(XR1).hex())
        print("      YR1 = 0x", Integer(YR1).hex())
        print("     ZR01 = 0x", Integer(ZR01).hex())
    else:
        print("")
        print("  kb0 = 0, so we subtract P from final Joye-loop result "
                + "(using ZADDC1)")
        print("")
        print("  After this subtraction:")
        print("      XR0 = 0x", Integer(XR0).hex())
        print("      YR0 = 0x", Integer(YR0).hex())
        print("      XR1 = 0x", Integer(XR1).hex())
        print("      YR1 = 0x", Integer(YR1).hex())
        print("     ZR01 = 0x", Integer(ZR01).hex())
    display_coord_of_R0_and_R1("R1 coordinates (second part of subtractP, "
        + "cond. sub. [k + 1 - (k mod 2)]P - P completed)",
        XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 1)
    ##
    ## Exit
    ##
    print("")
    print("#### EXIT")
    print("")
    print("########## STARTING INVERSION USING ZR01 ^(p - 2)")
    print("")
    r0 = redc(1, R2modp, p, R, ppr)
    r1 = ZR01
    print("   init (r1 <- Z, r0 <- 1 in Montgomery domain):")
    print("")
    print("       r0 = 0x", Integer(r0).hex())
    print("       r1 = 0x", Integer(r1).hex())
    pm2 = p - 2
    i = 0
    while pm2 >= 1:
        print("")
        print("#### bit ",i)
        print("")
        if (pm2 % 2) == 0:
            print("   pm2 is even: r1 <- r1 * r1")
            r1 = redc(r1, r1, p, R, ppr)
            print("       r0 = 0x", Integer(r0).hex())
            print("       r1 = 0x", Integer(r1).hex())
            pm2 = pm2 // 2
        else:
            print("   pm2 is ODD:  r1 <- r1 * r1  AND  r0 <- r0 * r1")
            r0 = redc(r0, r1, p, R, ppr)
            r1 = redc(r1, r1, p, R, ppr)
            print("       r0 = 0x", Integer(r0).hex())
            print("       r1 = 0x", Integer(r1).hex())
            pm2 = (pm2 - 1) // 2
        i+=1
    print("")
    print("########## END OF ZR01 INVERSION")
    print("")
    print("  ZR01 <- r0")
    print("")
    ZR01 = reducep(r0, p)
    print("     ZR01 = 0x", Integer(ZR01).hex())
    print("")
    print("  Normalizing XR1 and YR1 : XR1 <- XR1 * (ZR01 ^ 2)")
    print("                            YR1 <- YR1 * (ZR01 ^ 3)")
    XR1 = redc(XR1, redc(ZR01, ZR01, p, R, ppr), p, R, ppr)
    YR1 = redc(YR1, redc(
        redc(ZR01, ZR01, p, R, ppr), ZR01, p, R, ppr), p, R, ppr)
    print("    (XR1 & YR1 still in Montgomery domain)")
    print("")
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    XR1 = redc(1, XR1, p, R, ppr)
    YR1 = redc(1, YR1, p, R, ppr)
    print("")
    print("    (XR1 & YR1 OUT OF Montgomery domain)")
    print("")
    print("      XR1 = 0x", Integer(XR1).hex())
    print("      YR1 = 0x", Integer(YR1).hex())
    print("")
    print("########## R E S U L T")
    if is_affine_point_on_curve(XR1, YR1, p, a, b) or r1z == 1:
        print("")
        print("  Point IS on curve")
        print("")
        print(" [k]P.x = XR1 = 0x", Integer(XR1).hex())
        print(" [k]P.y = YR1 = 0x", Integer(YR1).hex())
        display_coord_of_R0_and_R1("R1 coordinates (after exit routine, "
            + "end of computation, result is in R1 if not null)",
            XR0, YR0, XR1, YR1, ZR01, r0z, r1z, padd, 1)
    else:
        print("")
        print("  Point IS NOT on curve")
        print("          XR1 = 0x", Integer(XR1).hex())
        print("          YR1 = 0x", Integer(YR1).hex())
    print("")
    print("  (from direct API of Sage for elliptic curve computations: ")
    print("")
    print("            x = 0x", (Integer((ksav*P)[0])).hex())
    print("            y = 0x", (Integer((ksav*P)[1])).hex(), ")")
    print("")

