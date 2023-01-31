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
#                      F_p   o p e r a t i o n s
#####################################################################
.fpaddL:
.fpaddL_export:
# XR1 <- XR0 + XR1 (mod p)
	BARRIER
	NNADD	XR0	XR1	XR1
	NNSUB	XR1	p	red
	NNADD,p5	red	patchme	XR1
	STOP
.fpsubL:
.fpsubL_export:
# XR1 <- XR0 - XR1 (mod p)
	BARRIER
	NNSUB	XR0	XR1	XR1
	NNADD,p5	XR1	patchme	XR1
	STOP
.fpmultL:
.fpmultL_export:
# XR1 <- REDC(XR0, XR1) = R0.R1/R mod p
	BARRIER
	NNMOV	XR0		XR0bk
	FPREDC	XR0	R2modp	XR0
	FPREDC	XR1	R2modp	XR1
	BARRIER
	FPREDC	XR0	XR1	XR1
	BARRIER
	FPREDC	XR1	one	XR1
	BARRIER
	NNSUB	XR1	p	red
	NNADD,p5	red	patchme	XR1
	NNMOV	XR0bk		XR0
	STOP
.fpinvL:
.fpinvL_export:
# XR1 <- XR1 ** -1 (mod p)
	BARRIER
	NNMOV	XR1		dx
	NNMOV	p		dy
	JL	.eucinvL
	NNMOV	inverse		XR1
	STOP
.fpinvexpL:
.fpinvexpL_export:
# XR1 <- XR1 ** -1 (mod p) in constant time, w/ XR1 ** (p-2)
	BARRIER
	NNMOV	XR1		dx
	JL	.modinvL
	NNMOV	inverse		XR1
	NNSUB	XR1	p	red
	NNADD,p5	red	patchme	XR1
	STOP

