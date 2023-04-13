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
#                     P O I N T   O P E R A T I O N S
#####################################################################
.negativeL:
.negativeL_export:
# ******************************************************************
# compute R1 <- -R0
# It doesn't matter if input point is given in affine form or projec-
# tive form, as the opposite is simply obtained by taking the Fp-oppo-
# site of the Y coordinate.
# Likewise, the coordinates can be given in Montgomery form or in
# natural (non Montgomery) form.
# Result is available in R1
# ******************************************************************
	BARRIER
# for X coord, simply move XR0 into XR1
	NNMOV	XR0		XR1
# for Y coord, we need to take the field opposite
# so compute YR1 <- (p - YR0) mod p
	NNSUB	p	YR0	YR1
# and reduce YR1 between 0 and p - 1
	NNSUB	YR1	p	red
	NNADD,p4	red	patchme	YR1
	STOP

.equalXL:
.equalXL_export:
# ******************************************************************
# test if coordinates XR0 & XR1 are equal modulo p
# ******************************************************************
	BARRIER
# reduce XR0 between 0 and p - 1
	NNSUB	XR0	p	red
	NNADD,p4	red	patchme	XR0
# reduce XR1 between 0 and p - 1
	NNSUB	XR1	p	red
	NNADD,p4	red	patchme	XR1
# compute XR0 - XR1
	NNSUB	XR0	XR1	Xtmp
	STOP

.equalYL:
.equalYL_export:
# ******************************************************************
# test if coordinates YR0 & YR1 are equal modulo p
# ******************************************************************
	BARRIER
# reduce YR0 between 0 and p - 1
	NNSUB	YR0	p	red
	NNADD,p4	red	patchme	YR0
# reduce YR1 between 0 and p - 1
	NNSUB	YR1	p	red
	NNADD,p4	red	patchme	YR1
# compute YR0 - YR1
	NNSUB	YR1	YR0	Ytmp
	STOP

.oppositeYL:
.oppositeYL_export:
# ******************************************************************
# test if coordinates YR0 & YR1 are opposite modulo p
# ******************************************************************
	BARRIER
# reduce YR0 between 0 and p - 1
	NNSUB	YR0	p	red
	NNADD,p4	red	patchme	YR0
# reduce YR1 between 0 and p - 1
	NNSUB	YR1	p	red
	NNADD,p4	red	patchme	YR1
# compute YR0 + YR1
	NNADD	YR0	YR1	Ytmp
	NNSUB	Ytmp	p	Ytmp
	STOP

.is_on_curveL:
.is_on_curveL_export:
# ******************************************************************
# test if R0 is on curve
# ******************************************************************
# we simply need to transfer R0 coordinates into those of R1 and call
# .chkcurveL (which already performs the test on R1 coordinates)
	BARRIER
	NNMOV	XR1		XR1bk
	NNMOV	YR1		YR1bk
	NNMOV	XR0		XR1
	NNMOV	YR0		YR1
	JL	.dochkcurveL
# restore point R1
	NNMOV	XR1bk		XR1
	NNMOV	YR1bk		YR1
# move mustbezero to itself so that Z flag is correctly set
# at the end of test (this flag is what ecc_scalar needs to
# know if the test is positive or negative)
	NNMOV	mustbezero		mustbezero
	STOP
