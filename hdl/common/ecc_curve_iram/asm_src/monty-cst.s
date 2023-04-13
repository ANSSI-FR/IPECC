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
.constMTYL:
.constMTY0L:
.constMTYL_export:
# *****************************************************************
# clear both the logical and arithmetical masks (mu0, mu1, m0 & m1).
# If the size of prime p was lowered down since last computation, 
# there may remain pernicious bits in the upper part of the masks
# *****************************************************************
#	BARRIER
	NNCLR			mu0
	NNCLR			mu1
	NNCLR			m0
	NNCLR			m1
	NNCLR			phi0
	NNCLR			phi1
	NNCLR			kb1
# compute quantity 2 times p
	NNADD	p	p	twop
# *****************************************************************
#        C O M P U T E   - (p ^ -1)    m o d   2 ^ (nn + 2)
# *****************************************************************
	BARRIER
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
.constMTY1L:
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
