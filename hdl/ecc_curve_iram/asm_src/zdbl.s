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
#               C O Z   D O U B L E   &   U P D A T E
#####################################################################
.zdblL:
.zdblL_export:
# ****************************************************************
# compute ( R0)     ([2]R1)
#         ( R1)z -> (   R1)z'
# ****************************************************************
	BARRIER
# preamble *******************************************************
	NNMOV,p53	patchme		Xup
	NNMOV,p54	patchme		Yup
	NNMOV	Xup		XR1
	NNMOV	Yup		YR1
# test if point is of 2-torsion
	NNSUB	YR1	twop	red
	NNADD,p5	red	patchme	YR1
# we need to test if YR1 == 0 so reduce YR1 in [0, p-1[
	NNSUB	YR1	p	red
	NNADD,p56	red	patchme	YR1
	BARRIER
# main common instructions ***************************************
	FPREDC	ZR01	ZR01	N
	FPREDC	YR1	YR1	E
	BARRIER
	FPREDC	E	E	L
	FPREDC	XR1	XR1	B
	NNADD	XR1	E	XpE
	NNSUB	XpE	twop	red
	NNADD,p5	red	patchme	XpE
	NNADD	B	L	BpL
	NNSUB	BpL	twop	red
	NNADD,p5	red	patchme	BpL
	FPREDC	XpE	XpE	XpE
	FPREDC	N	N	Nsq
	NNADD	B	B	twoB
	NNSUB	twoB	twop	red
	NNADD,p5	red	patchme	twoB
	NNADD	twoB	B	threeB
	NNSUB	threeB	twop	red
	NNADD,p5	red	patchme	threeB
	NNADD	E	N	EpN
	NNSUB	EpN	twop	red
	NNADD,p5	red	patchme	EpN
	NNADD	YR1	ZR01	YpZ
	NNSUB	YpZ	twop	red
	NNADD,p5	red	patchme	YpZ
	FPREDC	YpZ	YpZ	YpZsq
	BARRIER
	FPREDC	a	Nsq	Nsq
	NNADD	L	L	L
	NNSUB	L	twop	red
	NNADD,p5	red	patchme	L
# we need to test if L == 0 so reduce L in [0, p-1[
#	NNSUB	L	p	red
#	NNADD,p56	red	patchme	L
	NNADD	L	L	L
	NNSUB	L	twop	red
	NNADD,p5	red	patchme	L
	NNADD,p22	L	L	YR1
	NNSUB	YR1	twop	red
	NNADD,p5	red	patchme	YR1
	BARRIER
	NNSUB	XpE	BpL	XpE
	NNADD,p5	XpE	patchme	XpE
	NNADD	XpE	XpE	S
	NNSUB	S	twop	red
	NNADD,p5	red	patchme	S
	NNMOV,p23	S		XR1
	BARRIER
	NNSUB	YpZsq	EpN	Ztmp
	NNADD,p5	Ztmp	patchme	Ztmp
	NNMOV,p61	Ztmp		ZR01
	NNADD	B	Nsq	MD
	NNSUB	MD	twop	red
	NNADD,p5	red	patchme	MD
	FPREDC	MD	MD	Msq
	NNADD	S	S	twoS
	NNSUB	twoS	twop	red
	NNADD,p5	red	patchme	twoS
	BARRIER
	NNSUB	Msq	twoS	XR0
	NNADD,p5	XR0	patchme	XR0
	BARRIER
	NNSUB	S	XR0	S
	NNADD,p5	S	patchme	S
	FPREDC	S	MD	S
	BARRIER
	NNSUB	S	YR1	YR0
	NNADD,p5	YR0	patchme	YR0
# postamble ******************************************************
#   R0 = double
# & R1 = update (of what was doubled)
	NNMOV	XR0		XR0tmp
	NNMOV	YR0		YR0tmp
	NNMOV	XR1		XR1tmp
	NNMOV	YR1		YR1tmp
# set updated point
	NNMOV,p57	XR1tmp		patchme
	NNMOV,p58	YR1tmp		patchme
# set result of double
	NNMOV,p59	XR0tmp		patchme
	NNMOV,p60	YR0tmp		patchme
	STOP
