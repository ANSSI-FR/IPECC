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
# back-up R0 coordinates
	NNMOV	XR0		XR0bk
	NNMOV	YR0		YR0bk
# enter Montgomery domain
	FPREDC	XR0	R2modp	XR1
	FPREDC	YR0	R2modp	YR1
	FPREDC	one	R2modp	ZR01
	BARRIER
	JL	.dozdblL
# back from .dozdblL routine we need to invert Z coordinate
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
# restore R0 coordinates
	NNMOV	XR0bk		XR0
	NNMOV	YR0bk		YR0
	STOP
