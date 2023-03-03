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
#   C o - Z   A D D I T I O N   A N D   U P D A T E   ( Z A D D U )
#
#  Computes:
#             | R0|z                      | R0|z' <- R0|z + R1|z
#             |        --------------->   | 
#             | R1|z                      | R1|z' <- R1|z
#
#        or:
#
#             | R0|z                      | R0|z' <- R0|z + R1|z
#             |        --------------->   | 
#             | R1|z                      | R1|z' <- R0|z
#
#  depending on the value of Kappa'_i
#####################################################################
.pre_zadduL:
.pre_zadduL_export:
	BARRIER
	NNSUB,p7	XR0	XR1	XmXU
	NNADD,p5	XmXU	patchme	XmXU
# we need to test if XR0 == XR1 (i.e XmXU == 0) so reduce XmXU in [0, p-1[
	NNSUB	XmXU	p	red
	NNADD,p48	red	patchme	XmXU
	NNSUB,p8	YR0	YR1	YmY
	NNADD,p5	YmY	patchme	YmY
# we need to test if YR0 == YR1 (i.e YmY == 0) so reduce YmY in [0, p-1[
	NNSUB	YmY	p	red
	NNADD,p49	red	patchme	YmY
	STOP

.zadduL:
.zadduL_export:
	FPREDC	XmXU	XmXU	AZ
	FPREDC	YmY	YmY	D
	BARRIER
	FPREDC,p10	XR0	AZ	C
	NNMOV,p36	XR1		Xtmp
	NNMOV,p35	YR1		Ytmp
	FPREDC,p11	Xtmp	AZ	XR1
	BARRIER
	NNSUB,p37	D	XR1	DmB
	NNADD,p5	DmB	patchme	DmB
	NNSUB,p24	DmB	C	XR0
	NNADD,p38	XR0	patchme	XR0
	NNSUB,p25	C	XR1	CmB
	NNADD,p5	CmB	patchme	CmB
	FPREDC,p12	Ytmp	CmB	YR1
	NNSUB,p26	XR1	XR0	BmX
	NNADD,p5	BmX	patchme	BmX
	FPREDC,p27	YmY	BmX	YR0
	BARRIER
	FPREDC,p63	XmXU	ZR01	ZR01
	NNSUB,p28	YR0	YR1	YR0
	BARRIER
	NNADD,p39	YR0	patchme	YR0
	STOP

