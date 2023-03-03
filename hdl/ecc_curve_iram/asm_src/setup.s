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
#                            S E T U P
#####################################################################
.setupL:
.setupL_export:
# *****************************************************************
# start by reducing R mod p
# Since R is the power-of-2 strictly greater than p, we have
# R = p + eps with R < 8p which means eps < 7p. Therefore to
# reduce R mod p we simply need to subtract 7 times value of p
# *****************************************************************
	BARRIER
	NNSUB	R	twop	R
	NNSUB	R	twop	R
	NNSUB	R	twop	R
	NNSUB	R	p	Rmodp
# ****************************************************************
# switch to Montgomery representation
# ****************************************************************
	BARRIER
	FPREDC	XR1	R2modp	XR1
	FPREDC	YR1	R2modp	YR1
# ****************************************************************
# back-up the 2 coordinates of P (in Montgomery form)
# ****************************************************************
	BARRIER
	NNMOV	XR1		XPBK
	NNMOV	YR1		YPBK
# ****************************************************************
# initialize Z coordinate to 1 (& enter Montgomery domain)
# ****************************************************************
	BARRIER
	FPREDC	one	R2modp	ZR01
# ****************************************************************
# randomize coordinates (Z-masking aka point blinding)
# ****************************************************************
.drawZL:
	NNRNDm			lambda
	NNSUB	lambda	p	red
	NNADD,p4	red	patchme	lambda
	FPREDC	lambda	R2modp	lambda
	BARRIER
	FPREDC	ZR01	lambda	ZR01
	FPREDC	lambda	lambda	lambdasq
	BARRIER
	FPREDC	XR1	lambdasq	XR1
	FPREDC	lambdasq	lambda	lambdacu
	BARRIER
	FPREDC	YR1	lambdacu	YR1
# back-up Z of point P in case it is of order 2, because in this
# case ZR01 is about to be clobbered by the computation of [2]P
	NNMOV	ZR01		Zsav
# ****************************************************************
# compute R0 <- [2]P
# ****************************************************************
	JL	.dblL
# ****************************************************************
# Is point P of order 2?
# If it is, then ZR01 was clobbered, and we need to restore it
# ****************************************************************
	NNMOV,p51	Zsav		ZR01
.x1y1cozL:
# ****************************************************************
# now update XR1 and YR1 so that R1 (contains P) is now Co-Z to
# R0 (which now contains [2]P)
# ****************************************************************
	BARRIER
	NNADD	YR1	YR1	2YR1
	NNSUB	2YR1	twop	red
	NNADD,p5	red	patchme	2YR1
	FPREDC	2YR1	2YR1	Qs
	BARRIER
	FPREDC	Qs	2YR1	QQ
	FPREDC,p52	Qs	XR1	XR1
	BARRIER
	FPREDC,p52	QQ	YR1	YR1
	BARRIER
# ****************************************************************
# branch to .pre_zadduL
# This call won't return
# ****************************************************************
	J	.pre_zadduL

.setup_endL:
.setup_endL_export:
# ****************************************************************
# we compute the new common Z of [3]P and P in advance (before
# branching to .zadduL (which, after computing [3]P and updating
# P with the same Z, won't return as it ends with a STOP instruc-
# tion)
# ****************************************************************
#	FPREDC,p62	ZR01	XmXU	ZR01
	BARRIER
	J	.zadduL
	NOP
