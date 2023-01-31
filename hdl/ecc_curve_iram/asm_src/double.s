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
#                      P O I N T   D O U B L I N G
#####################################################################
.doubleL:
.doubleL_export:
# **************************************************************
# when caling .doubleL, POINTS ARE ASSUMED TO BE GIVEN IN AFFINE
# FORM (Z = 1)
# **************************************************************
	BARRIER
# enter Montgomery domain
	FPREDC	XR0	R2modp	XR1
	FPREDC	YR0	R2modp	YR1
	FPREDC	one	R2modp	ZR01
	BARRIER
	JL	.dblL
# back from .dblL routine we need to invert Z coordinate
	NNMOV	ZR01		dx
	JL	.modinvL
# back from .modinvL routine we need to renormalize X & Y
# coordinates, so we call .normalizeL routine, but after
# copying R0 into R1 (as .normalizeL works on R1)
	NNMOV	XR0		XR1
	NNMOV	YR0		YR1
# call routine to normalize XR1 and YR1 coordinates
	JL	.normalizeL
# call routine to exit XR1 & YR1 out of Montgomery domain
	JL	.exitMontyL
	NOP
	STOP
.dblL:
.dblL_export:
# ****************************************************************
# compute R0 <- [2]R1
# We use ["Efficient elliptic curve exponentiation using mixed
#          coordinates", Cohen-Miyaji-Ono, 1998]
# see e.g 'doubling-dbl-1998-cmo-2' formulae on hyperelliptic.org
#         (http://www.hyperelliptic.org/EFD/g1p/ ...
#           ... auto-shortw-jacobian.html#doubling-dbl-1998-cmo-2)
# HERE POINT R1 IS ASSUMED TO BE GIVEN IN PROJECTIVE-JACOBIAN FORM
# ****************************************************************
	BARRIER
	FPREDC	XR1	XR1	XX
	FPREDC	YR1	YR1	YY
	BARRIER
	FPREDC	ZR01	ZR01	ZZ
	BARRIER
	FPREDC	XR1	YY	X1YY
	FPREDC	ZZ	ZZ	ZZZZ
	NNADD	XX	XX	M
	NNSUB	M	twop	red
	NNADD,p5	red	patchme	M
	NNADD	M	XX	M
	NNSUB	M	twop	red
	NNADD,p5	red	patchme	M
	BARRIER
	FPREDC	ZZZZ	a	aZZZZ
	FPREDC	YY	YY	YYYY
	NNADD	X1YY	X1YY	S
	NNSUB	S	twop	red
	NNADD,p5	red	patchme	S
	NNADD	S	S	S
	NNSUB	S	twop	red
	NNADD,p5	red	patchme	S
	BARRIER
	FPREDC	YR1	ZR01	Y1Z1
	NNADD	M	aZZZZ	M
	NNSUB	M	twop	red
	NNADD,p5	red	patchme	M
	FPREDC	M	M	MM
	BARRIER
	NNSUB	MM	S	XR0
	NNADD,p5	XR0	patchme	XR0
	NNSUB	XR0	S	XR0
	NNADD,p5	XR0	patchme	XR0
	NNSUB	S	XR0	SmT
	NNADD,p5	SmT	patchme	SmT
	FPREDC	M	SmT	MpSmT
	NNADD	YYYY	YYYY	YYYY
	NNSUB	YYYY	twop	red
	NNADD,p5	red	patchme	YYYY
# we need to test if YYYY == 0 so reduce YYYY in [0, p-1[
	NNSUB	YYYY	p	red
	NNADD,p47	red	patchme	YYYY
	NNADD	YYYY	YYYY	YYYY
	NNSUB	YYYY	twop	red
	NNADD,p5	red	patchme	YYYY
	NNADD	YYYY	YYYY	YYYY
	NNSUB	YYYY	twop	red
	NNADD,p5	red	patchme	YYYY
	BARRIER
	NNSUB	MpSmT	twop	red
	NNADD,p5	red	patchme	MpSmT
	NNSUB	MpSmT	YYYY	YR0
	NNADD,p5	YR0	patchme	YR0
	NNADD	Y1Z1	Y1Z1	ZR01
	NNSUB	ZR01	twop	red
	NNADD,p5	red	patchme	ZR01
	RET
