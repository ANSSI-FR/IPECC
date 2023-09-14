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
#                   I T O H   f o r   1   B I T
#####################################################################
.itohL:
.itohL_export:
.itohL_dbg:
# *****************************************************************
# test LSbit of kap and kapP (resp.) and save them into %kap and
# %kapP (resp.)
# *****************************************************************
	BARRIER
	NNSRLs	kap1	1	kap1
	NNSRL,X	kap0		kap0
	NNSRLs	kapP1	2	kapP1
	NNSRL,X	kapP0		kapP0
	TESTPARs	kap0	1	%kap
	TESTPARs	kapP0	2	%kapP
	NNSRLs	phi1	3	phi1
	NNSRL,X	phi0		phi0
	STOP

