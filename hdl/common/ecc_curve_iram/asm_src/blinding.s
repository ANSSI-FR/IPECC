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
#                        B L I N D I N G
#####################################################################
.blindstartL_export:
# *****************************************************************
# Blinding init (execute once)
# *****************************************************************
	BARRIER
	NNMOV	kb0		kb0
	NNMOV	kb1		kb1
.random_alphaL:
.random_alphaL_export:
	NNRND			alf
	NNMOV	q		qsh0
	NNCLR			qsh1
	NNRNDf		0	alfmsk
	NNXOR	alf	alfmsk	alf
	NNCLR			alfmsk
	STOP

# *****************************************************************
# Main loop of blinding
# (must be executed as many times as blinding bits in 'alf')
# *****************************************************************
.blnbitL_export:
	BARRIER
	TESTPARs	alf	0	%par
	NNADD,p16	qsh0	kb0	patchme
	NNADD,X,p17	qsh1	kb1	patchme
# right-shift alpha
	NNSRLs	alf	0	alf
# left-shift q so as to multiply it by 2
	NNSLL	qsh0		qsh0
	NNSLL,X	qsh1		qsh1
	STOP

# *****************************************************************
# After the main blinding loop, a last computation is required,
# which consists in subtracting the random value that ecc_axi used
# to arithmetically mask the scalar at the time it transferred it
# in ecc_fp_dram memory
# *****************************************************************
.blindstopL_export:
	BARRIER
	NNSUB	kb0	m0	kb0
	NNSUB,X	kb1	m1	kb1
# remove the arithmetical masks
	NNCLR			m0
	NNCLR			m1
# switch to a logical mask
.random_muL:
.random_muL_export:
	NNRND			mu0
	TESTPAR	mu0		%mu0
	NNRND			mu1
	NNXOR	kb0	mu0	kb0
	NNXOR	kb1	mu1	kb1
	STOP
