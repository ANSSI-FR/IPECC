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
#      C O M P U T E   M O N T G O M E R Y   C O N S T A N T S
#####################################################################
.constMTY0L:
.constMTY0L_export:
	NNMOV	one		R
	STOP

.constMTY1L:
.constMTY1L_export:
	NNSLL	R		R
	STOP

.constMTY2L:
.constMTY2L_export:
# compute quantity 2 times p
	NNADD	p	p	twop
# *****************************************************************
#        C O M P U T E   - (p ^ -1)    m o d   2 ^ (nn + 2)
# *****************************************************************
# *****************************************************************
# call euclidian division with: dx  <-  p
#                               dy  assumed to hold R = 2**(nn+2)
# *****************************************************************
	NNMOV	p		dx
	NNMOV	R		dy
	JL	.eucinvL
# *****************************************************************
# finally take the opposite modulo R of result 'inverse'
# *****************************************************************
	NNSUB,M	dy	inverse	inverse
# *****************************************************************
#                C O M P U T E   ( R ^ 2 )   m o d   p
# *****************************************************************
	BARRIER
# *****************************************************************
# call euclidian division with: dx  <-  1 / R^2  mod  p
#                               dy  <-  p
# *****************************************************************
	FPREDC	one	one	dx
	BARRIER
	FPREDC	dx	one	dx
	BARRIER
	NNMOV	p		dy
	JL	.eucinvL
# *****************************************************************
# back from euclidian division, copy result into R2modp (after
# using that result to enter constant a into Montgomery space)
# *****************************************************************
	NNMOV	inverse		R2modp
	NNSUB	R2modp	twop	red
	NNADD,p5	red	patchme	R2modp
.computeRL:
# *****************************************************************
# reduce R mod p
# *****************************************************************
# we have:
#   4p < R = 2^(nn+2) < 8p
# hence we subtract three times quantity 2p to R to get R - 6p with:
#  -2p <    R - 6p    < 2p
# we then ensure that the result is not negative, adding back the qty
# 2p to it in case it is, see patch p5 below
	NNSUB	R	twop	R
	NNSUB	R	twop	R
	NNSUB	R	twop	red
# if the result of last NNSUB is negative, patch p5 on line below will
# replace virtual operand patchme with address of variable twop, hence
# restoring a positive value. It the result is positive, effect of patch
# is to replace patchme with the address of variable zero
	NNADD,p5	red	patchme	Rmodp
	STOP

.aMontyL:
.aMontyL_export:
# *****************************************************************
# switching 'a' curve parameter into Montgomery representation
# *****************************************************************
	BARRIER
	FPREDC	a	R2modp	a
	BARRIER
	NOP
	STOP
