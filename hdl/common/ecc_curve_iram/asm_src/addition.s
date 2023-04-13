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
# Doing so we invert R0 & R1 to comply with the way zadduL routine
# interprets its two input points - only one of them being updated
# (and therefore preserved) while the other one is clobbered with
# the result of the addition
	FPREDC	XR0bk	R2modp	XR1
	FPREDC	YR0bk	R2modp	YR1
	FPREDC	XR1bk	R2modp	XR0
	FPREDC	YR1bk	R2modp	YR0
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
	JL	.normalizeL
# call routine to exit XR1 & YR1 out of Montgomery domain
	JL	.exitMontyL
# do the same thing (normalize + Mont. out) for R0
	NNMOV	XR1		XR1bk
	NNMOV	YR1		YR1bk
	NNMOV	XR0		XR1
	NNMOV	YR0		YR1
# normalize coordinates
	JL	.normalizeL
# leave Montgomery domain
	JL	.exitMontyL
#	NNMOV	XR1		XR0
#	NNMOV	YR1		YR0
# restore R1
	NNMOV,p42	XR1bk		XR0
	NNMOV,p43	YR1bk		YR0
	STOP
