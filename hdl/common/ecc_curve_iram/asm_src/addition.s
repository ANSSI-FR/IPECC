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
#                     P O I N T   A D D I T I O N
#####################################################################
.addition_beginL:
.addition_beginL_export:
# ******************************************************************
# compute R1 <- R0 + R1
# POINTS ARE ASSUMED TO BE GIVEN IN AFFINE FORM (Z0 = Z1 = 1 = ZR01)
# result is available in R1
# ******************************************************************
	BARRIER
# back-up R0 & R1 coordinates
	NNMOV	XR0		XR0bk
	NNMOV	YR0		YR0bk
	NNMOV	XR1		XR1bk
	NNMOV	YR1		YR1bk
# Enter XR0, YR0, XR1 & YR1 in Montgomery domain.
	FPREDC	XR0bk	R2modp	XR0
	FPREDC	YR0bk	R2modp	YR0
	FPREDC	XR1bk	R2modp	XR1
	FPREDC	YR1bk	R2modp	YR1
	FPREDC	one	R2modp	ZR01
	BARRIER
# this call won't return
	J	.pre_zadduL

.addition_endL:
.addition_endL_export:
# back from .zadduL routine we need to invert Z coordinate
	NNMOV	ZR01		dx
	JL	.modinvL
# call routine to normalize XR1 and YR1 coordinates
# the barrier is important so that computations made in .modinvL
# are over by the time we call .normalizeL
	BARRIER
	JL	.normalizeL
# call routine to exit XR1 & YR1 out of Montgomery domain
# the barrier is important so that computations made in .normalizeL
# are over by the time we call .exitMontyL
	BARRIER
	JL	.exitMontyL
# restore R0 (it is never affected by point addition operation)
# (and even if .zdblL was called, instead of .zadduL, to perform
# the addition, the code of .zdblL does not modify XR0bk nor YR0bk)
	BARRIER
	NNMOV	XR0bk		XR0
	NNMOV	YR0bk		YR0
# patch mechanism ensures that these two lasts will only have
# effect in specific exception situations
	NNMOV,p42	XR1bk		XR1
	NNMOV,p43	YR1bk		YR1
	STOP

.zdbl_swL:
.zdbl_swL_export:
	BARRIER
	JL	.dozdblL
# back from .dozdblL routine, we must switch R0 & R1 points
# because for point addition operation software expects result
# in R1 but .dozdblL sets its result in R0
	NNMOV	XR1		XR1bk
	NNMOV	YR1		YR1bk
	NNMOV	XR0		XR1
	NNMOV	YR0		YR1
	NNMOV	XR1bk		XR0
	NNMOV	YR1bk		YR0
	STOP
