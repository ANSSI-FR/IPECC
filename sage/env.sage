Fp = GF(p)
EE = EllipticCurve(Fp, [a,b])
P = EE(Px, Py)
R = 2**(nn+2)
R2modp = (R**2) % p
ppr = inverse_mod(-p, R)
AR = redc(a, R2modp, p, R, ppr)
BR = redc(b, R2modp, p, R, ppr)
