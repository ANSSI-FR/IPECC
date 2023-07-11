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
#   R E - R A N D O M I Z E   R 0   &   R 1   C O O R D I N A T E S
#                U S I N G   F R E S H   R A N D O M
#####################################################################
.ZremaskL:
.ZremaskL_export:
# the fresh random is assumed to be buffered into 'lambda' variable
	BARRIER
	JL .r1zmultL
# Back from .r1zmultL, the job is done for R1. We also beed to do it
# for R0
# Now we also need to update R0 coordinates
	FPREDC,p46	XR0	lambdasq	XR0
	FPREDC,p47	YR0	lambdacu	YR0
	BARRIER
	NOP
	STOP
