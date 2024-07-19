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
#                C H E C K   R1   O N   C U R V E
#####################################################################
.chkcurveL:
.chkcurveL_export:
.chkcurve_op1L_dbg:
	BARRIER
	JL	.dochkcurveL
	Jz  .pt_is_on_curveL
.pt_is_not_on_curveL:
	NNSUB	zero	one      XR1
	NNSUB zero	one      YR1
	NNSUB zero	one      XR0
# The last opcode in particular must be set to a non-zero value
# to preserve the state of the icc flag Z (it was set by the
# instruction "NNSUB left right mustbezero" which was the last
# of routine .dochkcurveL)
	NNSUB zero	one      YR0
.pt_is_on_curveL:
.chkcurve_oplastL_dbg:
	NOP
	STOP
# ****************************************************************
# We need to check equation Y^2 =  X^3 + a.X + b  (in affine coord.)
# with (X:Y) = (XR1:YR1) and using the only multiplication hardware
# which is at our disposal, that is REDC(x,y) which does not compute
# x-times-y, but x-times-y-divided-by-R instead.
#
# Now, we have the following equivalences (with r(x,y) being an ab-
# breviated notation for the REDC(x,y) operation):
#
#           Y^2      =           X^3             +   a.X    +   b
#
# <=>   r(Y,Y) * R   =    r(r(X,X),X) * R^2      + r(aR,X)  +   b
#
# <=>  r(r(Y,Y),R^2) =    r(r(r(X,X),X),R^3)     + r(aR,X)  +   b
#
# <=>  r(r(Y,Y),R^2) = r(r(r(X,X),X),r(R^2,R^2)) + r(aR,X)  +   b
#
# with R^2 = R^2 mod p
#       aR = redc(a,R^2) = Montgomery representation of 'a',
# the two of which have been precalculated by routine located
# in .constMTYL
#
# Hence we can check the curve equation using 8 REDC operations,
# 2 additions and 1 substraction (along with necessary reductions
# modulo p)
# ****************************************************************
.dochkcurveL:
.chkcurve_op2L_dbg:
	BARRIER
	FPREDC	XR1	XR1	XX
	FPREDC	YR1	YR1	YY
	BARRIER
	FPREDC	a	XR1	aX
	FPREDC	R2modp	R2modp	R3modp
	BARRIER
	FPREDC	XX	XR1	XXX
	FPREDC	YY	R2modp	left
	NNSUB	aX	twop	red
	NNADD,p5	red	patchme	aX
	BARRIER
	FPREDC	XXX	R3modp	XR
	NNADD	aX	b	right
	NNSUB	right	twop	red
	NNADD,p5	red	patchme	right
	NNSUB	left	twop	red
	NNADD,p5	red	patchme	left
	BARRIER
	NNSUB	XR	twop	red
	NNADD,p5	red	patchme	XR
	NNADD	right	XR	right
	NNSUB	right	twop	red
	NNADD,p5	red	patchme	right
# ****************************************************************
# in order to compare 'left' and 'right' terms, we first need to
# reduce them into [0:p[ interval
# ****************************************************************
	NNSUB	left	p	red
	NNADD,p4	red	patchme	left
	NNSUB	right	p	red
	NNADD,p4	red	patchme	right
	NNSUB	left	right	mustbezero
	RET
