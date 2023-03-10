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

#####################################################################
#               C O Z   D O U B L E   &   U P D A T E
#####################################################################
.zdblL:
.zdblL_export:
# ****************************************************************
# compute ( R0)     ([2]R1)
#         ( R1)z -> (   R1)z'
# ****************************************************************
	BARRIER
# preamble *******************************************************
# In the 4 following opcodes, using buffers Xup & Yup for the coordinates
# to retain is necessary before writing them into XR1 & YR1, otherwise
# some coordinates might be clobbered (actually, only one patch could be
# used here instead of two, as the risk is only to clobber the Y-coordi-
# nate - but whatever)
	NNMOV,p53	patchme		Xup        # necessary (otherwise not of 
	NNMOV,p54	patchme		Yup
	NNMOV	Xup		XR1                # XR1 <- X of pt to be doubled
	NNMOV	Yup		YR1                # YR1 <- Y of pt to be doubled
# test if point is of 2-torsion
	NNSUB	YR1	twop	red
	NNADD,p5	red	patchme	YR1
# we need to test if YR1 == 0 so reduce YR1 in [0, p-1[
	NNSUB	YR1	p	red
	NNADD,p56	red	patchme	YR1
	BARRIER
# main common instructions ***************************************
	FPREDC	ZR01	ZR01	N          # N(8) <- Z²
	FPREDC	YR1	YR1	E              # E(9) <- Y²
	BARRIER
	FPREDC	E	E	L                  # L(16) <- E²
	FPREDC	XR1	XR1	B              # B(23) <- X²
	NNADD	XR1	E	XpE                # XpE(20) <- X + E
	NNSUB	XpE	twop	red            #
	NNADD,p5	red	patchme	XpE      # 
	BARRIER
	NNADD	B	L	BpL                  # BpL(17) <- B + L
	NNSUB	BpL	twop	red
	NNADD,p5	red	patchme	BpL
	FPREDC	XpE	XpE	XpE            # XpE(20) <- (X + E)² (clobbers previous X + E)
	FPREDC	N	N	Nsq                # Nsq(18) <- N²
	NNADD	B	B	twoB                 # twoB(21) <- 2B
	NNSUB	twoB	twop	red
	NNADD,p5	red	patchme	twoB
	NNADD	twoB	B	threeB           # threeB(23) <- 3B
	NNSUB	threeB	twop	red
	NNADD,p5	red	patchme	threeB
	NNADD	E	N	EpN                  # EpN(25) <- E + N
	NNSUB	EpN	twop	red
	NNADD,p5	red	patchme	EpN
	NNADD	YR1	ZR01	YpZ            # YpZ(21) <- Y + Z  (clobbers twoB)
	NNSUB	YpZ	twop	red
	NNADD,p5	red	patchme	YpZ
	FPREDC	YpZ	YpZ	YpZsq          # YpZsq(21) <- (Y + Z)²
	BARRIER
	FPREDC	a	Nsq	Nsq              # Nsq(18) <- aN²  (clobbers previous N²)
	NNADD	L	L	L                    # L(16) <- 2E² (clobbers previous E²)
	NNSUB	L	twop	red
	NNADD,p5	red	patchme	L
# we need to test if L == 0 so reduce L in [0, p-1[
#	NNSUB	L	p	red
#	NNADD,p56	red	patchme	L
	NNADD	L	L	L                    # L(16) <- 4E² (clobbers previous 2E²)
	NNSUB	L	twop	red
	NNADD,p5	red	patchme	L
	NNADD,p22	L	L	YR1              # YR1(7) <- 8E² (clobbers previous Y!)    __Y_OF_UPDATE__
	NNSUB	YR1	twop	red
	NNADD,p5	red	patchme	YR1
	BARRIER
	NNSUB	XpE	BpL	XpE              # XpE(20) <- (X + E)² - B - L (clobbers previous (X + E)²)
	NNADD,p5	XpE	patchme	XpE
	NNADD	XpE	XpE	S                # S(17) <- 2((X + E)² - B - L) (clobbers previous B + L)
	NNSUB	S	twop	red
	NNADD,p5	red	patchme	S
	NNMOV,p23	S		XR1              # XR1 <- S = 2((X + E)² - B - L)          __X_OF_UPDATE__
	BARRIER
	NNSUB	YpZsq	EpN	Ztmp           # Ztmp(25) <- (Y + Z)² - E - N
	NNADD,p5	Ztmp	patchme	Ztmp
	NNMOV,p61	Ztmp		ZR01         # ZR01(26) <- (Y + Z)² - E - N si pt pas de 2-torsion
	NNADD	B	Nsq	MD                 # M(8) <- 3B + aN² (clobbers N=Z²)
	NNSUB	MD	twop	red
	NNADD,p5	red	patchme	MD
	FPREDC	MD	MD	Msq            # Msq(21) <- (3B + aN²)² (clobbers YpZsq = (Y + Z)²)
	NNADD	S	S	twoS                 # twoS(18) <- 2S (clobbers Nsq = aN²)
	NNSUB	twoS	twop	red
	NNADD,p5	red	patchme	twoS
	BARRIER
	NNSUB	Msq	twoS	XR0            # XR0(4) <- = M² - 2S = (3B + aN²)² - 2S  __X_OF_DOUBLE__
	NNADD,p5	XR0	patchme	XR0      # detection = 0 par ,p55 supprimé : seul compte Y = 0 pour détecter DBL=0
	BARRIER
	NNSUB	S	XR0	S                  # S(17) <- S - XR0 (clobbers previous 2((X + E)² - B - L))
	NNADD,p5	S	patchme	S
	FPREDC	S	MD	S                # S(17) <- M(S - XR0) (clobbers previous S - XR0)
	BARRIER
	NNSUB	S	YR1	YR0                # YR0(5) <- M(S - XR0) - 8E²              __Y_OF_DOUBLE__
	NNADD,p5	YR0	patchme	YR0      # ,p56 supprimé ici : detection of a null double done above
# postamble ******************************************************
#   R0 = double
# & R1 = update (of what was doubled)
	NNMOV	XR0		XR0tmp
	NNMOV	YR0		YR0tmp
	NNMOV	XR1		XR1tmp
	NNMOV	YR1		YR1tmp
# set updated point
	NNMOV,p57	XR1tmp		patchme
	NNMOV,p58	YR1tmp		patchme
# set result of double
	NNMOV,p59	XR0tmp		patchme
	NNMOV,p60	YR0tmp		patchme
	STOP
