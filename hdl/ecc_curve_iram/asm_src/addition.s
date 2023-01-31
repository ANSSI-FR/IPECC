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
.additionL:
.additionL_export:
# ******************************************************************
# compute R1 <- R0 + R1
# see e.g 'add-2007-bl' formulae on hyperelliptic.org
#         (http://www.hyperelliptic.org/EFD/g1p/ ...
#           ... auto-shortw-jacobian.html#addition-mmadd-2007-bl
#          note that elementary operations commented in the assembly
#          code below are excerpts from that URL link)
# POINTS ARE ASSUMED TO BE GIVEN IN AFFINE FORM (Z0 = Z1 = 1 = ZR01)
# result is available in R1
# ******************************************************************
	BARRIER
# back-up R0 & R1 coordinates
	NNMOV	XR0		XR0bk
	NNMOV	YR0		YR0bk
	NNMOV	XR1		XR1bk
	NNMOV	YR1		YR1bk
# Enter XR0, YR0, XR1 & YR1 in Montgomery domain
	FPREDC	XR0	R2modp	XR0
	FPREDC	YR0	R2modp	YR0
	FPREDC	XR1	R2modp	XR1
	FPREDC	YR1	R2modp	YR1
	BARRIER
# H = X2 - X1
	NNSUB	XR1	XR0	H
	NNADD,p5	H	patchme	H
# we need to test if X1 == X2 (i.e H == 0) so reduce H in [0, p-1[
	NNSUB	H	p	red
	NNADD,p42	red	patchme	H
# HH = H**2
	FPREDC	H	H	HH
	BARRIER
# I = 4 * HH
	NNADD	HH	HH	tHH
	NNSUB	tHH	twop	red
	NNADD,p5	red	patchme	tHH
	NNADD	tHH	tHH	Ia
	NNSUB	Ia	twop	red
	NNADD,p5	red	patchme	Ia
# Z3 = 2*H (reduced later)
	NNADD	H	H	ZR01
	NNSUB	ZR01	twop	red
	NNADD,p5	red	patchme	ZR01
# J = H * I
	FPREDC	H	Ia	Ja
# V = X1 * I
	FPREDC	XR0	Ia	V
# r =	 2 * (Y2 - Y1)
	NNSUB	YR1	YR0	YmY
	NNADD,p5	YmY	patchme	YmY
# we need to test if Y1 == Y2 (i.e H == 0) so reduce YmY in [0, p-1[
	NNSUB	YmY	p	red
	NNADD,p43	red	patchme	YmY
# we also need to test if Y1 == -Y2 so compute Y1 + Y2 and reduce it
# in [0, p-1[
	NNADD	YR0	YR1	YpY
	NNSUB	YpY	twop	red
	NNADD,p5	red	patchme	YpY
	NNSUB	YpY	p	red
	NNADD,p44	red	patchme	YpY
# resume computation of r = 2 * (Y2 - Y1)
	NNADD	YmY	YmY	r
	NNSUB	r	twop	red
	NNADD,p5	red	patchme	r
	BARRIER
# X3 = r**2 - J - 2*V
	FPREDC	r	r	rsq
	NNADD	Ja	V	JpV
	NNSUB	JpV	twop	red
	NNADD,p5	red	patchme	JpV
	NNADD	JpV	V	Jp2V
	NNSUB	Jp2V	twop	red
	NNADD,p5	red	patchme	Jp2V
	BARRIER
	NNSUB	rsq	Jp2V	XR1
	NNADD,p5	XR1	patchme	XR1
# reduce XR1 between 0 and p - 1
	NNSUB	XR1	p	red
	NNADD,p4	red	patchme	XR1
# Y3 = r*(V - X3) - 2*Y1*J
	FPREDC	YR0	Ja	YmJ
	BARRIER
	NNADD	YmJ	YmJ	tYmJ
	NNSUB	tYmJ	twop	red
	NNADD,p5	red	patchme	tYmJ
	NNSUB	V	XR1	VmX
	NNADD,p5	VmX	patchme	VmX
	FPREDC	r	VmX	rVmX
	BARRIER
	NNSUB	rVmX	tYmJ	YR1
	NNADD,p5	YR1	patchme	YR1
# reduce YR1 between 0 and p - 1
	NNSUB	YR1	p	red
	NNADD,p4	red	patchme	YR1
# reduce ZR01 between 0 and p - 1
	NNSUB	ZR01	p	red
	NNADD,p4	red	patchme	ZR01
# Now invert ZR01
	NNMOV	ZR01		dx
	JL	.modinvL
# call routine to normalize XR1 and YR1 coordinates
	JL	.normalizeL
# call routine to exit XR1 & YR1 out of Montgomery domain
	JL	.exitMontyL
# restore R0 coordinates
	NNMOV	XR0bk		XR0
	NNMOV	YR0bk		YR0
# set R1 coordinates using w/ patching mechanism
	NNMOV,p45	XR1bk		XR1bk
	NNMOV,p46	YR1bk		YR1bk
	STOP

