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
#      C O N D I T I O N A L   S U B T R A C T I O N   O F   P
#####################################################################
.subtractPL:
.subtractPL_export:
	BARRIER
# *****************************************************************
# conditional patch based on the last (MSB) bit of phi
#   - if phi_MSB = 0 then the correct point value is in R0
#   - if phi_MSB = 1 it is in R1
# The aim here is to write into R0 the current "good" point
# so that remaining computations can continue deterministically
# *****************************************************************
	TESTPARs	phi0	3	%par
# *****************************************************************
# set R0 and R1 to the same Z coordinate
# (also copy P into R1, was backed-up in (XPBK:YPBK) by <setup.s>)
# *****************************************************************
.coZR0R1L:
	FPREDC	one	R2modp	ZPBK
	BARRIER
	FPREDC	ZR01	ZPBK	ZR01END
	FPREDC	ZPBK	ZPBK	ZPBKsq
	BARRIER
	FPREDC,p40	XR0	ZPBKsq	XR0tmp
	FPREDC	ZPBKsq	ZPBK	ZPBKcu
	BARRIER
	FPREDC,p41	YR0	ZPBKcu	YR0tmp
	FPREDC	ZR01	ZR01	ZR01sq
	BARRIER
	FPREDC	XPBK	ZR01sq	XR1tmp
	FPREDC	ZR01sq	ZR01	ZR01cu
	BARRIER
	FPREDC	YPBK	ZR01cu	YR1tmp
	NNMOV	ZR01END		ZR01
	NNMOV	XR0tmp		XR0
	NNMOV	YR0tmp		YR0
	NNMOV	XR1tmp		XR1
	BARRIER
	NNMOV	YR1tmp		YR1
# *****************************************************************
# call ZADDC routine, some instructions of which will be patched
# against the value of %kb0 (those writing the coordinates of
# the last point value, namely R0 - R1, into ecc-fp-dram)
# Also the instruction in ZADDC that computes the new-Z-value-
# of-R0-and-R1-after-ZADDU (because it is better, for performance
# reason, that this multiplication be parallelized with the one
# computing the new-Z-value-of-R0-and-R1-after-ZADDC), this
# instruction shall not be executed when we are dealing with the
# conditional removal of P
# The call won't return
# *****************************************************************
	BARRIER
	J	.pre_zaddcL

