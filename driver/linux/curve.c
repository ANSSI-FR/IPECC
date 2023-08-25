/*
 *  Copyright (C) 2023 - This file is part of IPECC project
 *
 *  Authors:
 *      Karim KHALFALLAH <karim.khalfallah@ssi.gouv.fr>
 *      Ryad BENADJILA <ryadbenadjila@gmail.com>
 *
 *  Contributors:
 *      Adrian THILLARD
 *      Emmanuel PROUFF
 *
 *  This software is licensed under GPL v2 license.
 *  See LICENSE file at the root folder of the project.
 */

#include "../hw_accelerator_driver.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "ecc-test-linux.h"

int ip_set_curve(curve_t* crv)
{
	/*
	 * Sanity check.
	 * Verify that curve is set.
	 * Verify that all large numbers (paremeters of the curve) are set.
	 * Verify that each one is below or equal in size to curve's parameter 'nn'.
	 */
	if (crv->valid == false) {
		printf("%sError: Can't set hardware with curve (incomplete description).%s\n", KERR, KNRM);
		goto err;
	}
	if (crv->p.valid == false) {
		printf("%sError: Can't set hardware with curve, parameter 'p' missing.%s\n", KERR, KNRM);
		goto err;
	}
	if (crv->a.valid == false) {
		printf("%sError: Can't set hardware with curve, parameter 'a' missing.%s\n", KERR, KNRM);
		goto err;
	}
	if (crv->b.valid == false) {
		printf("%sError: Can't set hardware with curve, parameter 'b' missing.%s\n", KERR, KNRM);
		goto err;
	}
	if (crv->q.valid == false) {
		printf("%sError: Can't set hardware with curve, parameter 'q' missing.%s\n", KERR, KNRM);
		goto err;
	}
	if ((crv->p.sz) > (NN_SZ(crv->nn))) {
		printf("%sError: Can't set hardware with curve, parameter 'p' larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((crv->a.sz) > (NN_SZ(crv->nn))) {
		printf("%sError: Can't set hardware with curve, parameter 'a' larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((crv->b.sz) > (NN_SZ(crv->nn))) {
		printf("%sError: Can't set hardware with curve, parameter 'b' larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}
	if ((crv->q.sz) > (NN_SZ(crv->nn))) {
		printf("%sError: Can't set hardware with curve, parameter 'q' larger than current curve size set in hardware.%s\n", KERR, KNRM);
		goto err;
	}

	/*
	 * Transfer curve parameters to the IP through driver API.
	 */
	if (hw_driver_set_curve(crv->a.val, crv->a.sz, crv->b.val, crv->b.sz,
				crv->p.val, crv->p.sz, crv->q.val, crv->q.sz))
	{
		printf("%sError: transmitting curve parameters to the hardware triggered an error.%s\n", KERR, KNRM);
		goto err;
	}

	/* Tag the curve as transmitted to the hardware alright. */
	crv->set_in_hw = true;

	return 0;
err:
	return  -1;
}

