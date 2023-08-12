#
#  Copyright (C) 2023 - This file is part of IPECC project
#
#  Authors:
#      Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
#      Ryad BENADJILA <ryadbenadjila@gmail.com>
#
#  Contributors:
#      Adrian THILLARD
#      Emmanuel PROUFF
#
#  This software is licensed under GPL v2 license.
#  See LICENSE file at the root folder of the project.
#

from kpsage import main

# #############################################
# A few definitions (curve, poinr, scalar, etc)
# #############################################
#
# Curve definition
#
nn=
p=0x
a=0x
b=0x
q=0x
#
# point definition
#
Px=0x
Py=0x
P_is_null=0
#
# scalar
#
k=0x
#
# random used for:
#   blinding:
#
alpha0=0x
nbblindbits=
mu0=0x
mu1=0x
#   ADPA:
phi0=0x
phi1=0x
#   z-masking:
lambd=0x
#
# hardware format definition (used for Montgomery mult. emulation)
#
ww=
bb=2**ww

# #############################################################
# Now call program main() defined in Python script <kp.sage.py>
# #############################################################
#
# The Python script <kp.sage.py> is built from the SageMath script
# <kp.sage> by using the '--preparse' switch of SageMath, like this:

# [shell]$ sage --preparse kp.sage  # This will produce a local kp.sage.py file
#                                   # whose objects you can now import in any
#                                   # other Python script (like the present one)
#                                   # for instance the main function.
main(nn, p, a, b, q, Px, Py, P_is_null, k, alpha0, nbblindbits, mu0, mu1, phi0, phi1, lambd, ww, bb)
