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
#   C o - Z   C O N J U G A T E   A D D I T I O N   ( Z A D D C )
#
#  Computes:
#             | R0|z                      | R0|z' <- R0|z + R1|z
#             |        --------------->   | 
#             | R1|z                      | R1|z' <- R0|z - R1|z
#
#        or:
#
#             | R0|z                      | R0|z' <- R0|z - R1|z
#             |        --------------->   | 
#             | R1|z                      | R1|z' <- R0|z + R1|z
#
#  depending on the value of Kappa_i
#####################################################################
.pre_zaddcL:
.pre_zaddcL_export:
	BARRIER
# Compute difference of X coords & detect possible equality
	NNSUB,p29	XR1	XR0	XmXC
	NNADD,p5	XmXC	patchme	XmXC
# we need to test if XR0 == XR1 (i.e XmXC == 0) so reduce XmXC in [0, p-1[
	NNSUB	XmXC	p	red
	NNADD,p48	red	patchme	XmXC
# Compute difference of Y coords & detect possible equality
	NNSUB,p30	YR1	YR0	YmY
	NNADD,p5	YmY	patchme	YmY
# we need to test if YR0 == YR1 (i.e YmY == 0) so reduce YmY in [0, p-1[
	NNSUB	YmY	p	red
	NNADD,p49	red	patchme	YmY
# Compute addition of Y coords & detect possible opposite
	NNADD,p31	YR0	YR1	G
	NNSUB	G	twop	red
	NNADD,p5	red	patchme	G
	NOP
	STOP

.zaddcL:
.zaddcL_export:
	BARRIER
	FPREDC	XmXC	XmXC	AZ
	FPREDC	YmY	YmY	D
	BARRIER
	FPREDC,p32	XR0	AZ	BZ
	FPREDC,p33	XR1	AZ	C
	BARRIER
	NNSUB	C	BZ	CCmB
	NNADD,p5	CCmB	patchme	CCmB
	FPREDC,p34	YR0	CCmB	Ec
	NNADD	BZ	C	BpC
	NNSUB	BpC	twop	red
	NNADD,p5	red	patchme	BpC
	NNSUB	D	BpC	XADD
	NNADD,p5	XADD	patchme	XADD
	NNMOV,p13	XADD		XR0
	NNSUB,p14	BZ	XR0	BmXC
	NNADD,p5	BmXC	patchme	BmXC
	FPREDC	YmY	BmXC	KK
	BARRIER
	FPREDC	G	G	F
	NNSUB	KK	Ec	YADD
	NNADD,p5	YADD	patchme	YADD
	NNMOV,p15	YADD		YR0
	BARRIER
	NNSUB	F	BpC	XSUB
	NNADD,p5	XSUB	patchme	XSUB
	NNMOV,p0	XSUB		XR1
	NNSUB	XSUB	BZ	H
	NNADD,p5	H	patchme	H
	FPREDC	G	H	J
	FPREDC,p2	XmXC	ZR01	ZR01
	BARRIER
	NNSUB	J	Ec	YSUB
	NNADD,p5	YSUB	patchme	YSUB
	NNMOV,p1	YSUB		YR1
	NOP
	STOP
