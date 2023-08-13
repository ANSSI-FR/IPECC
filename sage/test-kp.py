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

################################################################################
# Add your definitions here (curve, point, scalar, and so on).                 #
#                                                                              #
# Note: all variables in the frame below MUST be defined.                      #
################################################################################
#                                                                              #
# Curve definition                                                             #
# ################                                                             #
nn=                                                                            #
p=0x                                                                           #
a=0x                                                                           #
b=0x                                                                           #
q=0x                                                                           #
#                                                                              #
# Point definition                                                             #
# ################                                                             #
#                                                                              #
Px=0x                                                                          #
Py=0x                                                                          #
P_is_null=0     # By default (set to 1 if your point is the one at infinity)   #
#                                                                              #
# Scalar                                                                       #
#                                                                              #
k=0x                                                                           #
#                                                                              #
# Random used for:                                                             #
# ################                                                             #
#                                                                              #
#   ## 1/ Blinding                                                             #
alpha0=0x                                                                      #
nbbld=          # Set to 0 to disable blinding                                 #
mu0=0x                                                                         #
mu1=0x                                                                         #
#                                                                              #
#   ## 2/ ADPA                                                                 #
phi0=0x                                                                        #
phi1=0x                                                                        #
#                                                                              #
#   ## 3/ Initial Z-masking:                                                   #
lambd=0x                                                                       #
#                                                                              #
# Hardware format definition                                                   #
# ##########################                                                   #
# (required for proper emulation of Montgomery  multipication)                 #
# ww is the bitwidth of limbs (whose large numbers in the IP                   #
# internal memory are made of).                                                #
#                                                                              #
ww=             # (16 for all Xilinx devices)                                  #
################################################################################

# ############################################################
# Now call program main() defined in Python script <kpsage.py>
# ############################################################
#
# The Python script <kp.sage.py> is built from the SageMath script
# <kp.sage> by using the '--preparse' switch of SageMath, e.g:
#
# [shell]$ sage --preparse kp.sage  # This will produce a local <kp.sage.py> file
#
# Then we need to rename <kp.sage.py> into <kpsage.py> to make it possible to
# import the objects of this file from an other Python script, like the present
# one (this is because kp.sage.py is not a valid name for a Python module).
main(nn, p, a, b, q, Px, Py, P_is_null, k, alpha0, nbbld, mu0, mu1, phi0, phi1, lambd, ww)
#
#
