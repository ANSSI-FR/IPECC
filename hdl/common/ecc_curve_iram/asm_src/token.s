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
#                  T O K E N   G E N E R A T I O N
#####################################################################
.get_tokenL:
.get_tokenL_export:
# ******************************************************************
# generate the token, an nn-bit random for software to mask the next
# scalar it'll provide with
# ******************************************************************
	BARRIER
	NNRND	          token
	STOP

.token_kP_maskL:
.token_kP_maskL_export:
# mask the final [k]P result's coordinates with the same random token
# that software was served with before launching the computation.
	BARRIER
	NNXOR	XR1	 token	XR1
	NNXOR	YR1	 token	YR1
# clear the token as it is of no use anymore
	NNCLR	          token
	STOP
