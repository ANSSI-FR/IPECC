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
#         P O S S I B L Y   S W I T C H   R 0   A N D   R 1
#####################################################################
.switch3PL:
.switch3PL_export:
# ****************************************************************
# conditional patch based on bit of weight 1 of Kappa
# (this bit was sampled by the last TESTPAR instruction in adpa.s)
#
# if bit Kappa_1 = 0, then we need to switch R0 and R1
# so that to ensure:  R_\{Kappa_1\}     (= R_0) <- P
#                     R_\{1 - Kappa_1\} (= R_1) <- [3]P
#   (in this case:
#      - patching p18 will set 'patchme' field to XR0
#      - patching p19 will set 'patchme' field to YR0)
#
# otherwise (Kappa_1 = 1) there is nothing to do
# as we already have: R_\{Kappa_1\}     (= R_1)  = P
#                     R_\{1 - Kappa_1\} (= R_0)  = [3]P
#   (in this case:
#      - patching p18 will set 'patchme' field to XR1
#      - patching p19 will set 'patchme' field to YR1)
#
#                NOTE: THIS IS NOW OBSOLETE
#
# The switch between R0 and R1 points is now handled by
# program .setupL (in state ssetup) when it calls the
# .zadduL routine.
# The switch between R0 and R1 is thus absorbed within the
# countermeasure consisting in randomizing the addresses
# in ecc_fp_dram of xr0, yr0, xr1 & yr1.
#
# Program .switch3PL and state switch3p are simply kept
# for practical & compatibility reasons.
# ****************************************************************
	BARRIER
	NOP
	STOP

