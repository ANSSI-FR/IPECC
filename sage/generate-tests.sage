#!/usr/bin/env sage

import random
import sys
from os.path import getsize

def toss_a_coin():
	coin = random.randint(1, 2)
	if coin == 1:
		return 1
	else:
		return 0

# to generate a safe prime
def rdp(nbits=256):
	while True:
		p = random_prime(2^nbits-1, false, 2^(nbits-1))
		if ZZ((p-1)/2).is_prime():
			return p


# ############################ CONFIGURATION ###############################
# On 7-series (Zynq) imposes value of ww                                   #
ww = 16                                                                    #
#                                                                          #
# nnmin is the first admissible value for nn (ensure that                  #
# w >= 2 where w = ceil((nn + 4) / ww) which is equivalent                 #
# to ( (nn + 4) / ww ) > 1 and therefore nn > ww - 4 which                 #
# gives the minimum ww - 4 + 1 for nn                                      #
nnmin = ww - 4 + 1                                                         #
nnminmax = 256                                                             #
#                                                                          #
# nnmaxabsolute is the largest admissible value of nn                      #
# nnmax is the instant-time maximum randomly generate value of nn          #
nnmaxabsolute = 384 # otherwise computation of curve order is too slow     #
nnmax = 64 # for start (it will increase and plateau to absolute max)      #
#                                                                          #
nn_constant = 0                                                            #
only_kp_and_no_blinding = False                                            #
# ##########################################################################

nbcurv = 0
nbtest = 0

# set NBCURV to 0 to generate an endless test loop
#NBCURV = 100000
NBCURV = 0
NBKP = 100
NBADD = 50
NBDBL = 50
NBNEG = 50
NBCHK = 50
NBEQU = 50
NBOPP = 50

KNRM="\x1B[0m"
KRED="\x1B[31m"
KYEL="\x1B[33m"
KWHT="\x1B[37m"

NN_LIMIT_COMPUTE_Q = 192

def div(i, s):
    if ((i % s) == 0):
        return (i // s)
    else:
        return (i // s) + 1;


sys.stderr.write(KWHT + "generating curves from nn = " + str(nnmin) + " to " + str(nnmax) + KNRM + "\n")

# infinite loop
while (nbcurv < NBCURV) or (NBCURV == 0):
    if (nn_constant != 0):
        nn = nn_constant
    else:
        new_min_or_max = False
        if (nbcurv % 100) == 99:
            nnmax = nnmax + 3;
            if nnmax > nnmaxabsolute:
                nnmax = nnmaxabsolute
            new_min_or_max = True
        if (nbcurv % 200) == 199:
            nnmin = nnmin + 1;
            if nnmin > nnminmax:
                nnmin = nnminmax
            new_min_or_max = True
        if new_min_or_max:
            sys.stderr.write(KWHT + "generating curves from nn = "
                    + str(nnmin) + " to " + str(nnmax) + KNRM + "\n")
        # generate a random prime size (nn)
        nn = random.randint(nnmin, nnmax)
    # generate a random prime (p)
    while True:
        p = rdp(nn)
        if (is_prime(p) == True):
            break
    # algebraic definitions, field & curve
    Fp = GF(p)
    disc = 0
    while disc == 0:
        # generate value of a
        a = Fp.random_element()
        # generate value of b
        b = Fp.random_element()
        # check curve discriminant condition
        disc = -16 * ( (4 * (a**3)) + (27 * (b**2)) )
    EE = EllipticCurve(Fp, [a,b])
    # compute value of q (order of the curve)
    #   but only if nn < 256 (or equal) otherwise Sage computation is
    #   too long (only if we do compute q do we also generate tests with
    #   blinding)
    if nn > NN_LIMIT_COMPUTE_Q:
        q = 1
    else:
        q = EE.order()
    # nn might need to be adjusted to get into account the size of q
    # as nn must be equal to max(log2(p), log2(q))
    nn = max(nn, ceil(RR(log(q, 2))))
    if (nn > nnmaxabsolute):
        sys.stderr.write("met size of q > nnmaxabsolute\n")
        continue
    sys.stderr.write("curve #" + str(nbcurv) + " (nn = " + str(nn) + ")\n")
    # print (on standard output) the algebraic & curve parameters
    print("NEW CURVE #" + str(nbcurv))
    print("nn=" + str(nn))
    print("p=0x%0*x" % (int(div(nn, 4)), p))
    print("a=0x%0*x" % (int(div(nn, 4)), a))
    print("b=0x%0*x" % (int(div(nn, 4)), b))
    print("q=0x%0*x" % (int(div(nn, 4)), q))
    # #############################################################
    #                  REGULAR TESTS (NO EXCEPTION)
    # #############################################################
    #
    # TEST : [k]P computation
    #
    for i in range(0, NBKP):
        # generate a random point on curve
        P = EE.random_element()
        xP = P[0]
        yP = P[1]
        # generate random value of scalar
        k = Integer(random.randint(0, (2**nn) - 1))
        # compute [k]P
        kP = k * P
        # print test informations
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        if not only_kp_and_no_blinding:
            if nn <= NN_LIMIT_COMPUTE_Q:
                if toss_a_coin() == 1:
                    nbbld = random.randint(1, nn - 1)
                    print("nbbld=%d" % nbbld)
        if (kP != 0):
            print("kPx=0x%0*x" % (int(div(nn, 4)), Integer(kP[0])))
            print("kPy=0x%0*x" % (int(div(nn, 4)), Integer(kP[1])))
        else:
            print("kP=0")
        nbtest+=1
    if only_kp_and_no_blinding:
        nbcurv+=1
        continue
    #
    # TEST : P + Q
    #
    for i in range(0, NBADD):
        # generate a random point on curve
        P = EE.random_element()
        xP = P[0]
        yP = P[1]
        # generate a second random point on curve
        Q = EE.random_element()
        xQ = Q[0]
        yQ = Q[1]
        # compute P + Q
        PplusQ = P + Q
        # print test informations
        print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        if Q == 0:
            print("Q=0")
        else:
            print("Qx=0x%0*x" % (int(div(nn, 4)), xQ))
            print("Qy=0x%0*x" % (int(div(nn, 4)), yQ))
        if (PplusQ == 0):
            print("PplusQ=0")
        else:
            print("PplusQx=0x%0*x" % (int(div(nn, 4)), Integer(PplusQ[0])))
            print("PplusQy=0x%0*x" % (int(div(nn, 4)), Integer(PplusQ[1])))
        nbtest+=1
    #
    # TEST : [2]P
    #
    for i in range(0, NBDBL):
        # generate a random point on curve
        P = EE.random_element()
        xP = P[0]
        yP = P[1]
        # compute [2]P
        twoP = 2 * P
        # print test informations
        print("== TEST [2]P #%d.%d" % (nbcurv, nbtest))
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        if (twoP == 0):
            print("twoP=0")
        else:
            print("twoPx=0x%0*x" % (int(div(nn, 4)), Integer(twoP[0])))
            print("twoPy=0x%0*x" % (int(div(nn, 4)), Integer(twoP[1])))
        nbtest+=1
    #
    # TEST : -P
    #
    for i in range(0, NBNEG):
        # generate a random point on curve
        P = EE.random_element()
        xP = P[0]
        yP = P[1]
        # compute -P
        negP = -P
        # print test informations
        print("== TEST -P #%d.%d" % (nbcurv, nbtest))
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        if (negP == 0):
            print("negP=0")
        else:
            print("negPx=0x%0*x" % (int(div(nn, 4)), Integer(negP[0])))
            print("negPy=0x%0*x" % (int(div(nn, 4)), Integer(negP[1])))
        nbtest+=1
    #
    # TEST : is P on curve
    #
    for i in range(0, NBCHK):
        print("== TEST isPoncurve #%d.%d" % (nbcurv, nbtest))
        if toss_a_coin() == 1:
            # generate a random point on curve
            P = EE.random_element()
            xP = P[0]
            yP = P[1]
            # print test informations
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            print("true")
        else:
            # create a false point (one that is not on curve)
            xP = Fp.random_element()
            yP = Fp.random_element()
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            # check that the 2-uple (xP, yP) is not a point
            if (yP**2) == (xP**3) + (a * xP) + b:
                # P can't be the null point
                print("true")
            else:
                print("false")
        nbtest+=1
    #
    # TEST : P == Q
    #
    for i in range(0, NBEQU):
        print("== TEST isP==Q #%d.%d" % (nbcurv, nbtest))
        if toss_a_coin() == 1:
            # generate a random point on curve
            P = EE.random_element()
            xP = P[0]
            yP = P[1]
            # generate a second random point on curve
            Q = EE.random_element()
            xQ = Q[0]
            yQ = Q[1]
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            if Q == 0:
                print("Q=0")
            else:
                print("Qx=0x%0*x" % (int(div(nn, 4)), xQ))
                print("Qy=0x%0*x" % (int(div(nn, 4)), yQ))
            if (P == Q):
                print("true")
            else:
                print("false")
        else:
            # generate a random point on curve
            P = EE.random_element()
            xP = P[0]
            yP = P[1]
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            if P == 0:
                print("Q=0")
            else:
                print("Qx=0x%0*x" % (int(div(nn, 4)), xP))
                print("Qy=0x%0*x" % (int(div(nn, 4)), yP))
            print("true")
        nbtest+=1
    #
    # TEST : P == -Q
    #
    for i in range(0, NBEQU):
        print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
        if toss_a_coin() == 1:
            # generate a random point on curve
            P = EE.random_element()
            xP = P[0]
            yP = P[1]
            # generate a second random point on curve
            Q = EE.random_element()
            xQ = Q[0]
            yQ = Q[1]
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            if Q == 0:
                print("Q=0")
            else:
                print("Qx=0x%0*x" % (int(div(nn, 4)), xQ))
                print("Qy=0x%0*x" % (int(div(nn, 4)), yQ))
            if (P == -Q):
                print("true")
            else:
                print("false")
        else:
            # generate a random point on curve
            P = EE.random_element()
            xP = P[0]
            yP = P[1]
            # Compute -P
            mP = -P
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            if P == 0:
                print("Q=0")
            else:
                print("Qx=0x%0*x" % (int(div(nn, 4)), mP[0]))
                print("Qy=0x%0*x" % (int(div(nn, 4)), mP[1]))
            print("true")
        nbtest+=1
    # #############################################################
    #                    [k]P EXCEPTION TESTS
    # #############################################################
    #
    # Generate a random point on this curve
    #
    P = EE.random_element()
    xP = P[0]
    yP = P[1]
    if nn <= NN_LIMIT_COMPUTE_Q:
        #
        # TEST: [k]P computation with exception: k = q
        #
        k = q
        # compute [k]P
        kP = k * P
        # print test informations
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: k = q")
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        if nn <= NN_LIMIT_COMPUTE_Q:
            if toss_a_coin() == 1:
                nbbld = random.randint(1, nn - 1)
                print("nbbld=%d" % nbbld)
        # [k]P = 0 necessarily
        print("kP=0")
        nbtest+=1
        #
        # TEST: [k]P computation with exception: k = q + 1
        #
        # we need to test if adding 1 to q will possibly add a bit
        # of dynamic to the scalar as compared to nn - this happens
        # when q is of the form (2**nn - 1) which can happen from
        # time to time on very small random curves
        if (q != (2**nn) - 1):
            k = q + 1
            # compute [k]P
            kP = k * P
            # print test informations
            print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
            print("# EXCEPTION: k = q + 1" )
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), xP))
                print("Py=0x%0*x" % (int(div(nn, 4)), yP))
            print("k=0x%0*x" % (int(div(nn, 4)), k))
            if nn <= NN_LIMIT_COMPUTE_Q:
                if toss_a_coin() == 1:
                    nbbld = random.randint(1, nn - 1)
                    print("nbbld=%d" % nbbld)
            if kP == 0:
                print("kP=0")
            else:
                print("kPx=0x%0*x" % (int(div(nn, 4)), kP[0]))
                print("kPy=0x%0*x" % (int(div(nn, 4)), kP[1]))
            nbtest+=1
        #
        # TEST: [k]P computation with exception: k = q - 1
        #
        k = q - 1
        # compute [k]P
        kP = k * P
        # print test informations
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: k = q - 1" )
        if P == 0:
            print("P=0")
        else:
            print("Px=0x%0*x" % (int(div(nn, 4)), xP))
            print("Py=0x%0*x" % (int(div(nn, 4)), yP))
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        if nn <= NN_LIMIT_COMPUTE_Q:
            if toss_a_coin() == 1:
                nbbld = random.randint(1, nn - 1)
                print("nbbld=%d" % nbbld)
        if kP == 0:
            print("kP=0")
        else:
            print("kPx=0x%0*x" % (int(div(nn, 4)), kP[0]))
            print("kPy=0x%0*x" % (int(div(nn, 4)), kP[1]))
        nbtest+=1
    #
    # TEST: [k]P with exception: k = a factor of P.order()
    #       (implying: result should be the null point)
    #
    if nn <= NN_LIMIT_COMPUTE_Q:
        # compute order of point P
        o = P.order()
        # factor order of P
        facs = list(factor(o))
        # fiter out the cases where order is prime (on the other hand cases where
        # the order is a power of a prime are accepted)
        if len(facs) == 1 and facs[0][1] == 1:
            nbcurv+=1
            continue
        # parse all factors or P's order
        for fac in facs:
            k = fac[0]
            # create the point associated to that factor
            # (it is the point f * P, where f is the product of all factors
            # other than the current considered one)
            fs = 1
            for f in facs:
                if f[0] != fac[0]:
                    fs = fs * (f[0]**f[1])
            if fac[1] > 1:
                fs = fs * (fac[0]**(fac[1] - 1))
            fsP = fs * P
            # print test informations
            print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
            print("# EXCEPTION: k = a factor of P's order")
            if P == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Py=0x%0*x" % (int(div(nn, 4)), fsP[1]))
            # no blinding
            #   (it would taint the test by creating a different scalar,
            #   for which the null point wouldn't be met anymore)
            print("k=0x%0*x" % (int(div(nn, 4)), k))
            # [k]P = 0 necessarily
            print("kP=0")
            nbtest+=1
        #
        # TEST: [k]P with exception: k = a factor of P's order + a multiple
        #       of the next power-of-2
        #       (meaning: point 0 will be met however it shouldn't be the
        #        final result)
        #
        # parse all factors or P's order
        for fac in facs:
            k = fac[0]
            # create the point associated to that factor
            # (it is the point f * P, where f is the product of all factors
            # other than the current considered one)
            fs = 1
            for f in facs:
                if f[0] != fac[0]:
                    fs = fs * (f[0]**f[1])
            if fac[1] > 1:
                fs = fs * (fac[0]**(fac[1] - 1))
            fsP = fs * P
            # form k based on fac[0]
            #   compute nb of bits to encode k
            # print test informations
            print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
            print("# EXCEPTION: k = a factor of P's order + a nb aligned on a " +
                "higher power-of-2")
            nbits_fac = ceil(RR(log(fac[0])/log(2)))
            if nbits_fac == RR(log(fac[0])/log(2)):
                nbits_fac = nbits_fac + 1
            #   generate a random number formed of nn bits - the nb of bits to encode k
            #cpl = Integer(random.randint(2**nbits_fac, (2**nn) - 1))
            cpl = Integer(
                    random.randint(0, (2**(nn - nbits_fac)) - 1)) * (2**nbits_fac)
            print("#    factor = 0x%0*x (%d bits)" % (int(div(nn, 4)),
                Integer(fac[0]), nbits_fac))
            print("#complement = 0x%0*x" % (int(div(nn, 4)), Integer(cpl)))
            k = fac[0] + cpl
            print("#         k = 0x%0*x" % (int(div(nn, 4)), k))
            if fsP == 0:
                print("P=0")
            else:
                print("Px=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Py=0x%0*x" % (int(div(nn, 4)), fsP[1]))
            print("k=0x%0*x" % (int(div(nn, 4)), k))
            # Compute [k]P by Sage
            kP = k * fsP
            if (kP != 0):
                print("kPx=0x%0*x" % (int(div(nn, 4)), Integer(kP[0])))
                print("kPy=0x%0*x" % (int(div(nn, 4)), Integer(kP[1])))
            else:
                print("kP=0")
            nbtest+=1
            #
            # TEST: a second test if the currect factor is a multi-factor
            #
            if (fac[1] > 1) and (fac[0] > 2):
                fs = Integer(fs / (fac[0]**(fac[1] - 1)))
                ff = fac[0]**fac[1]
                fP = fs * P
                #fsP = fs * P
                # form k based on fac[0]
                #   compute nb of bits to encode k
                # print test informations
                print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
                print("# EXCEPTION: k = a factor of P's order + a nb aligned on a " +
                    "higher power-of-2")
                nbits_fac = ceil(RR(log(ff)/log(2)))
                if nbits_fac == RR(log(ff)/log(2)):
                    nbits_fac = nbits_fac + 1
                #   generate a random number of {nn bits - the nb of bits to encode k}
                #cpl = Integer(random.randint(2**nbits_fac, (2**nn) - 1))
                cpl = Integer(
                        random.randint(0, (2**(nn - nbits_fac)) - 1)) * (2**nbits_fac)
                print("#    factor = 0x%0*x (%d bits)" % (int(div(nn, 4)),
                    Integer(ff), nbits_fac))
                print("#complement = 0x%0*x" % (int(div(nn, 4)), Integer(cpl)))
                k = (ff) + cpl
                print("#         k = 0x%0*x" % (int(div(nn, 4)), k))
                if fP == 0:
                    print("P=0")
                else:
                    print("Px=0x%0*x" % (int(div(nn, 4)), fP[0]))
                    print("Py=0x%0*x" % (int(div(nn, 4)), fP[1]))
                print("k=0x%0*x" % (int(div(nn, 4)), k))
                # Compute [k]P by Sage
                kP = k * fP
                if (kP != 0):
                    print("kPx=0x%0*x" % (int(div(nn, 4)), Integer(kP[0])))
                    print("kPy=0x%0*x" % (int(div(nn, 4)), Integer(kP[1])))
                else:
                    print("kP=0")
                nbtest+=1
    dice = random.randint(1, 16)
    if dice == 16:
        #
        # TEST: [k]P with k = 0
        #
        k = 0
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: k = 0")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        print("kP=0")
        nbtest+=1
    dice = random.randint(1, 16)
    if dice == 16:
        #
        # TEST: [k]P with P = 0
        #
        k = random.randint(1, 2**(nn - 1))
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = 0")
        print("P=0")
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        print("kP=0")
        nbtest+=1
    dice = random.randint(1, 16)
    if dice == 16:
        #
        # TEST: [k]P with k = 0 and P = 0
        #
        k = 0
        print("== TEST [k]P #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: k = 0 and P = 0")
        print("P=0")
        print("k=0x%0*x" % (int(div(nn, 4)), k))
        print("kP=0")
        nbtest+=1
    # #############################################################
    #         EXCEPTION TESTS ON POINT OPS (OTHER THAN [k]P)
    # #############################################################
    #
    # EXCEPTIONS FOR PT_ADD (P + Q)
    #
    #   P = Q
    if P != 0:
        print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = Q")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Qx=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), P[1]))
        # have Sage compute P + Q = [2]P here
        twoP = 2 * P
        if twoP == 0:
            print("PplusQx=0")
        else:
            print("PplusQx=0x%0*x" % (int(div(nn, 4)), twoP[0]))
            print("PplusQy=0x%0*x" % (int(div(nn, 4)), twoP[1]))
        nbtest+=1
    #   P = -Q
    if P != 0:
        print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = -Q")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Qx=0x%0*x" % (int(div(nn, 4)), (-P)[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), (-P)[1]))
        print("PplusQ=0")
        nbtest+=1
    #   P = 0 (Q != 0)
    print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = 0, Q /= 0")
    print("P=0")
    print("Qx=0x%0*x" % (int(div(nn, 4)), P[0]))
    print("Qy=0x%0*x" % (int(div(nn, 4)), P[1]))
    print("PplusQx=0x%0*x" % (int(div(nn, 4)), P[0]))
    print("PplusQy=0x%0*x" % (int(div(nn, 4)), P[1]))
    nbtest+=1
    #   Q = 0 (P != 0)
    print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: Q = 0, P /= 0")
    print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
    print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
    print("Q=0")
    print("PplusQx=0x%0*x" % (int(div(nn, 4)), P[0]))
    print("PplusQy=0x%0*x" % (int(div(nn, 4)), P[1]))
    nbtest+=1
    #   P = Q = 0
    print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = Q = 0")
    print("P=0")
    print("Q=0")
    print("PplusQ=0")
    nbtest+=1
    #   Q = [2]P and P is of order 3
    #   (this is actually already covered by P + Q test with P = -Q)
    #
    # EXCEPTIONS FOR PT_DBL ([2]P)
    #
    #   P = 0
    print("== TEST [2]P #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = 0")
    print("P=0")
    print("twoP=0")
    nbtest+=1
    #
    #   P of order 2 (aka 2-torsion)
    if nn <= NN_LIMIT_COMPUTE_Q:
        for fac in facs:
            if fac[0] == 2:
                # the order has 2 as a factor (possibly as a multifactor,
                # i.e with a height > 1)
                # compute the product of all other factors except this one
                # if it has a weight of 1, otherwise including it with an
                # exponent equal to its weight minus 1
                fs = 1
                for f in facs:
                    if f[0] != fac[0]:
                        fs = fs * (f[0]**f[1])
                # the line below is correct even if fac[1] == 1
                fs = fs * (2 ** (fac[1] - 1))
                # point fsP on line below is a point of order 2 (aka of 2-torsion)
                fsP = fs * P
                print("== TEST [2]P #%d.%d" % (nbcurv, nbtest))
                print("# EXCEPTION: P = 2-torsion")
                print("Px=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Py=0x%0*x" % (int(div(nn, 4)), fsP[1]))
                print("twoP=0")
                nbtest+=1
                # create a second test for exception of P + Q, w/ P = Q = 2-torsion
                print("== TEST P+Q #%d.%d" % (nbcurv, nbtest))
                print("# EXCEPTION: P = Q = 2-torsion")
                print("Px=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Py=0x%0*x" % (int(div(nn, 4)), fsP[1]))
                print("Qx=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Qy=0x%0*x" % (int(div(nn, 4)), fsP[1]))
                print("PplusQ=0")
                nbtest+=1
                # create a third test for exception of isP==-Q w/ P = Q = 2-torsion
                print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
                print("# EXCEPTION: P = Q = 2-torsion")
                print("Px=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Py=0x%0*x" % (int(div(nn, 4)), fsP[1]))
                print("Qx=0x%0*x" % (int(div(nn, 4)), fsP[0]))
                print("Qy=0x%0*x" % (int(div(nn, 4)), fsP[1]))
                print("true")
                nbtest+=1
    #
    # EXCEPTIONS FOR PT_EQU (P == Q)
    #
    #   P = Q
    #   (this is actually already tested above)
    #
    #   P != Q
    #   (this is actually already tested above)
    #
    #   P = -Q
    print("== TEST isP==Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = -Q")
    if P == 0:
        print("P=0")
    else:
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
    if P == 0:
        print("Q=0")
    else:
        print("Qx=0x%0*x" % (int(div(nn, 4)), (-P)[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), (-P)[1]))
    if P == -P:
        print("true")
    else:
        print("false")
    nbtest+=1
    #   P = 0 (Q != 0)
    if P != 0:
        print("== TEST isP==Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = 0, Q != 0")
        print("P=0")
        print("Qx=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("false")
        nbtest+=1
    #   Q = 0 (P != 0)
    if P != 0:
        print("== TEST isP==Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P != 0, Q = 0")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Q=0")
        print("false")
        nbtest+=1
    #   P = Q = 0
    print("== TEST isP==Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = Q = 0")
    print("P=0")
    print("Q=0")
    print("true")
    nbtest+=1
    #
    # EXCEPTIONS FOR PT_OPP (P == -Q)
    #
    #   P = Q & P != -Q
    if P != 0 and P != -P:
        print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = Q & P != -Q")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Qx=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("false")
        nbtest+=1
    #   P = -Q  & P != Q
    if P != 0 and P != -P:
        print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = -Q & P != Q")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Qx=0x%0*x" % (int(div(nn, 4)), (-P)[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), (-P)[1]))
        print("true")
        nbtest+=1
    #   P = Q & P = -Q   (means 2-torsion point)
    #   (this is actually already tested above)
    #
    #   P = 0 (Q != 0)
    if P != 0:
        print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P = 0, Q != 0")
        print("P=0")
        print("Qx=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Qy=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("false")
        nbtest+=1
    #   Q = 0 (P != 0)
    if P != 0:
        print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
        print("# EXCEPTION: P != 0, Q = 0")
        print("Px=0x%0*x" % (int(div(nn, 4)), P[0]))
        print("Py=0x%0*x" % (int(div(nn, 4)), P[1]))
        print("Q=0")
        print("false")
        nbtest+=1
    #   P = Q = 0
    print("== TEST isP==-Q #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = Q = 0")
    print("P=0")
    print("Q=0")
    print("true")
    nbtest+=1
    #
    # EXCEPTIONS FOR PT_NEG (-P)
    #
    #   P = 0
    print("== TEST -P #%d.%d" % (nbcurv, nbtest))
    print("# EXCEPTION: P = 0")
    print("P=0")
    print("negP=0")
    nbtest+=1
    # increment the nb of generated curves for test
    nbcurv+=1
