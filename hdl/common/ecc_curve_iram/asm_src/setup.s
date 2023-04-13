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
	NNMOV	XR1		XR0
	BARRIER
	NNMOV	YR1		YR0
# ****************************************************************
# compute R0 <- [2]P
# ****************************************************************
	JL	.dozdblL
.x1y1cozL:
# ****************************************************************
# branch to .pre_zadduL
# This call won't return
# ****************************************************************
	J	.pre_zadduL

.setup_endL:
.setup_endL_export:
# ****************************************************************
# Branch to .zadduL to compute [3]P and update P with the same Z
# This call won't return
# ****************************************************************
	BARRIER
	J	.zadduL
