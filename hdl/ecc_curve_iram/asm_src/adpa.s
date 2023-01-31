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
#           A N T I   -   A D D R E S S   B I T   D P A
#####################################################################
.adpaL:
.adpaL_export:
# *******************************************************************
# generate random mask (variable 'phi' in memory)
# *******************************************************************
	BARRIER
	NNCLR			alf
	NNRND			phi0
	NNRND			phi1
.savekb0L:
# *******************************************************************
# save kb0 (LSB of kb) as it will be required in the end to condition-
# naly subtract P to the result
# *******************************************************************
	TESTPAR	kb0		%kb0
.phimskL:
# *******************************************************************
# compute 2 masked versions of kb: kap and kapP
# *******************************************************************
# First, lose the LSbit of kb (this is kb_0, assumed to be 1)
	NNSRL	kb1		kb1
	NNSRL,X	kb0		kb0
# Compute Kappa <- kb (+) Phi
# Note the LSbit of Phi is considered to be Phi_1
	NNXOR	kb0	phi0	kap0
	NNXOR	kb1	phi1	kap1
# Left-shift Phi to get Phi'
	NNSLL	phi0		phi0
	NNSLL,X	phi1		phi1
# Compute Kappa' <- kb (+) Phi'
	NNXOR	kb0	phi0	kapP0
	NNXOR	kb1	phi1	kapP1
# Right-shift back, restoring Phi initial value
	NNSRL	phi1		phi1
	NNSRL,X	phi0		phi0
# Lose LSbit of logical mask (mu0 and mu1)
	NNSRL	mu1		mu1
	NNSRL,X	mu0		mu0
# Unmask Kappa (kap0 and kap1) from logical mask 'mu'
	NNXOR	kap0	mu0	kap0
	NNXOR	kap1	mu1	kap1
# Unmask Kappa' (kapP0 and kapP1) from logical mask 'mu'
	NNXOR	kapP0	mu0	kapP0
	NNXOR	kapP1	mu1	kapP1
# Generate shift-register masks for kap0 and kap1
	NNRNDs		1	kap0msk
	NNRNDf		1	kap1msk
	NNXOR	kap0	kap0msk	kap0
	NNXOR	kap1	kap1msk	kap1
	NNCLR			kap0msk
	NNCLR			kap1msk
# Generate shift-register masks for kapP0 and kapP1
	NNRNDs		2	kapP0msk
	NNRNDf		2	kapP1msk
	NNXOR	kapP0	kapP0msk	kapP0
	NNXOR	kapP1	kapP1msk	kapP1
	NNCLR			kapP0msk
	NNCLR			kapP1msk
# Generate shift-register masks for phi0 and phi1
	NNRNDs		3	phi0msk
	NNRNDf		3	phi1msk
	NNXOR	phi0	phi0msk	phi0
	NNXOR	phi1	phi1msk	phi1
	NNCLR			phi0msk
	NNCLR			phi1msk
# remove the logical masks
	NNCLR			mu0
	NNCLR			mu1
# Sample LSbit of Kappa, which is Kappa_1 (this bit will
# be used later by .switch3PL to possibly switch P and [3]P)
	TESTPARs	kap0	1	%kap
# Erase scalar (only Kappa & Kappa' masked versions remain)
	NNCLR			kb0
	NNCLR			kb1
	STOP

