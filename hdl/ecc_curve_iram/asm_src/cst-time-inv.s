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
#    C O N S T A N T   T I M E   M O D U L A R   I N V E R S I O N
#               U S I N G   x ^ - 1 = x ^ (p - 2)
#         ( J O Y E   D O U B L E - A N D - A D D   L O O P )
#####################################################################
.modinvL:
.modinvL_export:
	NNADD	one	one	two
	NNSUB	p	two	pmtwo
	NNMOV	one		r0
# shift r0 (= 1) into Montgomery domain
	FPREDC	r0	R2modp	r0
	BARRIER
# dx is assumed to be in the Montgomery domain already!
	NNMOV	dx		r1
.loopbeginL:
	TESTPAR	pmtwo		%par
	Jodd	.pm2bitis1L
	J	.pm2bitis0L
.pm2bitis1L:
# *****************************************************************
# compute r0 <- r0 * r1
# *****************************************************************
	FPREDC	r0	r1	r0
.pm2bitis0L:
# *****************************************************************
# always compute r1 <- r1 * r1
# *****************************************************************
	FPREDC	r1	r1	r1
	BARRIER
	NNSRL	pmtwo		pmtwo
	Jz	.modinvendL
	J	.loopbeginL
.modinvendL:
	NNMOV	r0		inverse
	RET
