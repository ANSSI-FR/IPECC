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
#                             E X I T
#####################################################################
.exitL:
.exitL_export:
# *****************************************************************
# convert projective coordinates back to affine ones
# *****************************************************************
.proj2affL:
	BARRIER
# *****************************************************************
# do some cleaning up
# Note that kb1 is not cleared here as this is already done in adpa.s.
# Masks mu0, mu1, m0 & m1 are cleared in monty-cst.s
# *****************************************************************
	NNCLR			phi0
	NNCLR			phi1
	NNCLR			kap0
	NNCLR			kap1
	NNCLR			kapP0
	NNCLR			kapP1
# *****************************************************************
# result [k]P is in R1
# we need to invert ZR01 so we call .modinvL which will perform
# inversion with a modular fast exponentiation (ZR01 is exponen-
# tiated to power p - 2) so that inversion is in constant time
# *****************************************************************
	NNMOV	ZR01		dx
	JL	.modinvL
# call routine to normalize XR1 and YR1 coordinates
	JL	.normalizeL
# call routine to exit XR1 & YR1 out of Montgomery domain
	JL	.exitMontyL
# restore intial value of R
# (this is necessary for the computation of Montgomery constants
# to work properly next time the software will send a new value of p)
	NNADD	Rmodp	twop	R
	NNADD	R	twop	R
	NNADD	R	twop	R
	NNADD	R	p	R
# ****************************************************************
# finally call routine to check that point (XR1:YR1) is actually
# on the curve
# ****************************************************************
	JL	.chkcurveL
	NOP
	STOP
.normalizeL:
# *****************************************************************
# Back from inversion routine, inverse contains (1/ZR01 mod p)
# and  0 <= 1/ZR01 < p
# Now renormalize XR1 and YR1 by multiplying:
#   - XR1 by (1/ZR0 mod p)^2
#   - YR1 by (1/ZR0 mod p)^3
# *****************************************************************
	BARRIER
	NNSUB	inverse	p	red
	NNADD,p4	red	patchme	inverse
	FPREDC	inverse	inverse	invsq
	BARRIER
	FPREDC	XR1	invsq	XR1
	FPREDC	invsq	inverse	invcu
	BARRIER
	FPREDC	YR1	invcu	YR1
	RET
.exitMontyL:
# ****************************************************************
# leave Montgomery domain
# ****************************************************************
	BARRIER
	FPREDC	XR1	one	XR1
	FPREDC	YR1	one	YR1
# *****************************************************************
# reduce XR1 and YR1
# *****************************************************************
	BARRIER
	NNSUB	XR1	p	red
	NNADD,p4	red	patchme	XR1
	NNSUB	YR1	p	red
	NNADD,p4	red	patchme	YR1
	RET
