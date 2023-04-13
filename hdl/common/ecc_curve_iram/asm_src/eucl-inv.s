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
#               E U C L I D I A N   I N V E R S I O N
#
# For the description of the binary extended gcd algorithm, see e.g:
#  - ["Guide to Elliptic Curve Cryptography", D. Hankerson,
#      A. Menezes & S. Vanstone, Springer-Verlag, 2004],
#      Chap 2.2.5, p. 40, algo 2.19
#  - ["Handbook of Applied Cryptography", A. Menezes,
#      P. van Oorschot & S. Vanstone, CRC Press, 1996],
#      Chap 14, p.608, algo 14.61
#  - ["Handbook of elliptic and hyperelliptic curve cryptography",
#      H. Cohen & G. Frey, Chapman & Hall/CRC, 2006]
#      Chap 10.6.3, p. 194, algo 10.49
#####################################################################

.eucinvL:
.eucinvL_export:
# *****************************************************************
# Init:  u <- x,  v <- y,  x1 <- 1,  x2 <- 0,  y1 <- 0,  y2 <- 1
# *****************************************************************
	BARRIER
	NNMOV	dx		du
	NNMOV	dy		dv
	NNMOV	one		dx1
	NNCLR			dx2
	NNCLR			dy1
	NNMOV	one		dy2
.divloopL:
# *****************************************************************
# If either u or v == 1, job is done
# *****************************************************************
	NNSUB	du	one	dtmp
	Jz	.mloopendL
	NNSUB	dv	one	dtmp
	Jz	.mloopendL
# *****************************************************************
# As long as u is even, divide it by 2 (w/ update of x1 and y1)
# *****************************************************************
.UL:
.tstUparL:
	TESTPAR	du		%par
	Jodd	.VL
.UevenL:
	NNDIV2	du		du
.tstx1parL:
	TESTPAR	dx1		%par
	Jodd	.x1y1oddL
.x1evenL:
	TESTPAR	dy1		%par
	Jodd	.x1y1oddL
.x1y1div2L:
	NNDIV2	dx1		dx1
	NNDIV2	dy1		dy1
	J	.tstUparL
.x1y1oddL:
	NNADD	dx1	dy	dx1
	NNSUB	dy1	dx	dy1
	J	.x1y1div2L
# *****************************************************************
# As long as v is even, divide it by 2 (w/ update of x2 and y2)
# *****************************************************************
.VL:
.tstVparL:
	TESTPAR	dv		%par
	Jodd	.UVcmpL
.VevenL:
	NNDIV2	dv		dv
.tstx2parL:
	TESTPAR	dx2		%par
	Jodd	.x2y2oddL
.x2evenL:
	TESTPAR	dy2		%par
	Jodd	.x2y2oddL
.x2y2div2L:
	NNDIV2	dx2		dx2
	NNDIV2	dy2		dy2
	J	.tstVparL
.x2y2oddL:
	NNADD	dx2	dy	dx2
	NNSUB	dy2	dx	dy2
	J	.x2y2div2L
# *****************************************************************
# compare u and v & update (u, x1, y1) or (v, x2, y2) accordingly
# *****************************************************************
.UVcmpL:
	NNSUB	du	dv	dtmp
	Jsn	.UltVL
	NNMOV	dtmp		du
	NNSUB	dx1	dx2	dx1
	NNSUB	dy1	dy2	dy1
	J	.divloopL
.UltVL:
	NNSUB	dv	du	dv
	NNSUB	dx2	dx1	dx2
	NNSUB	dy2	dy1	dy2
	J	.divloopL
.mloopendL:
# *****************************************************************
# modular inverse (dx^-1 mod dy) is computed, it's either in x1 or x2
# *****************************************************************
	NNSUB	du	one	dtmp
	Jz	.Ueq1L
# *****************************************************************
# result is in x2, so reduce x2
# *****************************************************************
.Veq1L:
	NNSUB	dx2	zero	dtmp
	Jsn	.x2negL
.x2posL:
	NNSUB	dx2	dy	dtmp
	Jsn	.x2zr0L
.x2gtpL:
	NNSUB	dx2	dy	dx2
	Jsn	.x2negL
	J	.x2gtpL
.x2negL:
	NNADD	dx2	dy	dx2
	Jsn	.x2negL
.x2zr0L:
	NNMOV	dx2		inverse
	RET
# *****************************************************************
# result is in x1, so reduce x1
# (save program's space w/ x2 <- x1 & calling x2 reduction routine)
# *****************************************************************
.Ueq1L:
	NNMOV	dx1		dx2
	J	.Veq1L
