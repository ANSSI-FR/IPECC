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
.drawZL:
.drawZL_export:
# ****************************************************************
# generate lambda random value (Z-mask)
# ****************************************************************
	BARRIER
.random_lambdaL:
.random_lambdaL_export:
	NNRNDm			lambda
	NNSUB	lambda	p	red
	NNADD,p4	red	patchme	lambda
.random_lambdaL_dbg:
	NOP
	STOP

.setupL:
.setupL_export:
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
# randomize coordinates (Z-masking aka point blinding) w/ lambda
# ****************************************************************
	JL	.r1zmultL
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

.r1zmultL:
	FPREDC	lambda	R2modp	lambda
	BARRIER
	FPREDC	ZR01	lambda	ZR01
	FPREDC	lambda	lambda	lambdasq
	BARRIER
	FPREDC,p44	XR1	lambdasq	XR1
	FPREDC	lambdasq	lambda	lambdacu
	BARRIER
	FPREDC,p45	YR1	lambdacu	YR1
	RET

