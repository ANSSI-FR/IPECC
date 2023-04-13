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
#                          C O Z   N E G A T E
#####################################################################
.znegcL:
.znegcL_export:
# simply copy from current address to new ones the coordinates
# that are not to change
	BARRIER
	NNMOV,p6	patchme		Ykeep
	NNMOV,p9	patchme		Xkeep
# take the opposite of the Y coordinate of the point we need to take
# the opposite of, and set it to the new coordinate of destination point
	NNSUB	p	Ykeep	Yopp
	NNADD,p5	Yopp	patchme	Yopp
# now transfer coordinates to the new destination
	NNMOV,p18	Yopp		patchme
	NNMOV,p19	Ykeep		patchme
	NNMOV,p55	Ykeep		patchme
	NNMOV,p20	Xkeep		XR0
	NNMOV,p21	Xkeep		XR1
	STOP
