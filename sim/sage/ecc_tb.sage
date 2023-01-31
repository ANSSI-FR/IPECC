#!/usr/bin/env sage

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


# 160
p_160 = 0xe95e4a5f737059dc60dfc7ad95b3d8139515620f
a_160 = 0x340e7be2a280eb74e2be61bada745d97e8f7c300
b_160 = 0x1e589a8595423412134faa2dbdec95c8d8675e58
q_160 = 0xe95e4a5f737059dc60df5991d45029409e60fc09
Fp_160 = GF(p_160)
E_160 = EllipticCurve(Fp_160, [a_160,b_160])
xPaff_160 = 0xbed5af16ea3f6a4f62938c4631eb5af7bdbcdbc3
yPaff_160 = 0x1667cb477a1a8ec338f94741669c976316da6321
k_160 = 0x5e98fab1e81df9fc17d528542f81c358dc7f91e6
P_160 = E_160(xPaff_160, yPaff_160)
x12Paff_160 = 0x6248702007211c3aaff765138ab609014e3d9614
y12Paff_160 = 0x69298b399fcf1a982e90e5c3fe039f179fdb406a
P_160_12P = E_160(x12Paff_160, y12Paff_160)
print(" __   __   ___  ")
print("/_ | / /  / _ \ ")
print(" | |/ /_ | | | |")
print(" | | '_ \| | | |")
print(" | | (_) | |_| |")
print(" |_|\___/ \___/ ")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_160.hex())
print("    a = 0x" + a_160.hex())
print("    b = 0x" + b_160.hex())
print("    q = 0x" + q_160.hex())
print("  points:")
print("    P = (0x" + xPaff_160.hex() + ",")
print("         0x" + yPaff_160.hex() + ")")
print("    Q = (0x" + x12Paff_160.hex() + ",")
print("         0x" + y12Paff_160.hex() + ")")
print("    (Q = [12]P")
print("  scalar:")
print("    k = 0x" + k_160.hex())
print("outputs:")
print("  [k]P.x    = 0x" + Integer((k_160*P_160)[0]).hex())
print("  [k]P.y    = 0x" + Integer((k_160*P_160)[1]).hex())
print("  (P + Q).x = 0x" + Integer((P_160 + P_160_12P)[0]).hex())
print("  (P + Q).y = 0x" + Integer((P_160 + P_160_12P)[1]).hex())
print("  ([2]Q).x  = 0x" + Integer((2 * P_160_12P)[0]).hex())
print("  ([2]Q).y  = 0x" + Integer((2 * P_160_12P)[1]).hex())
print("  (-Q).x    = 0x" + Integer((-P_160_12P)[0]).hex())
print("  (-Q).y    = 0x" + Integer((-P_160_12P)[1]).hex())

# 192
p_192 = 0xc302f41d932a36cda7a3463093d18db78fce476de1a86297
a_192 = 0x6a91174076b1e0e19c39c031fe8685c1cae040e5c69a28ef
b_192 = 0x469a28ef7c28cca3dc721d044f4496bcca7ef4146fbf25c9
q_192 = 0xc302f41d932a36cda7a3462f9e9e916b5be8f1029ac4acc1
xPaff_192 = 0xc0a0647eaab6a48753b033c56cb0f0900a2f5c4853375fd6
yPaff_192 = 0x14b690866abd5bb88b5f4828c1490002e6773fa2fa299b8f
Fp_192 = GF(p_192)
E_192 = EllipticCurve(Fp_192, [a_192,b_192])
k_192 = 0xe0ed258a2778c759153d6243591938cc0ce6ac65af6ecd3b
P_192 = E_192(xPaff_192, yPaff_192)
print()
print(" __  ___ ___  ")
print("/_ |/ _ \__ \ ")
print(" | | (_) | ) |")
print(" | |\__, |/ / ")
print(" | |  / // /_ ")
print(" |_| /_/|____|")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_192.hex())
print("    a = 0x" + a_192.hex())
print("    b = 0x" + b_192.hex())
print("    q = 0x" + q_192.hex())
print("  point:")
print("    P = (0x" + xPaff_192.hex() + ",")
print("         0x" + yPaff_192.hex() + ")")
print("  scalar:")
print("    k = 0x" + k_192.hex())
print("outputs:")
print(" [k]P.x = 0x", Integer((k_192*P_192)[0]).hex())
print(" [k]P.y = 0x", Integer((k_192*P_192)[1]).hex())

# 224
p_224 = 0xd7c134aa264366862a18302575d1d787b09f075797da89f57ec8c0ff
a_224 = 0x68a5e62ca9ce6c1c299803a6c1530b514e182ad8b0042a59cad29f43
b_224 = 0x2580f63ccfe44138870713b1a92369e33e2135d266dbb372386c400b
q_224 = 0xd7c134aa264366862a18302575d0fb98d116bc4b6ddebca3a5a7939f
xPaff_224 = 0x0d9029ad2c7e5cf4340823b2a87dc68c9e4ce3174c1e6efdee12c07d
yPaff_224 = 0x58aa56f772c0726f24c6b89e4ecdac24354b9e99caa3f6d3761402cd
Fp_224 = GF(p_224)
E_224 = EllipticCurve(Fp_224, [a_224,b_224])
k_224 = 0xeee115c13ee411dfd929705cd83876727fa9c22d315abbc6bcd34576
P_224 = E_224(xPaff_224, yPaff_224)
print()
print(" ___  ___  _  _   ")
print("|__ \|__ \| || |  ")
print("   ) |  ) | || |_ ")
print("  / /  / /|__   _|")
print(" / /_ / /_   | |  ")
print("|____|____|  |_|  ")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_224.hex())
print("    a = 0x" + a_224.hex())
print("    b = 0x" + b_224.hex())
print("    q = 0x" + q_224.hex())
print("  point:")
print("    P = (0x" + xPaff_224.hex() + ",")
print("         0x" + yPaff_224.hex() + ")")
print("  scalar:")
print("    k = 0x" + k_224.hex())
print("outputs:")
print(" [k]P.x = 0x", Integer((k_224*P_224)[0]).hex())
print(" [k]P.y = 0x", Integer((k_224*P_224)[1]).hex())

# 256
p_256 = 0xf1fd178c0b3ad58f10126de8ce42435b3961adbcabc8ca6de8fcf353d86e9c03
a_256 = 0xf1fd178c0b3ad58f10126de8ce42435b3961adbcabc8ca6de8fcf353d86e9c00
b_256 = 0xee353fca5428a9300d4aba754a44c00fdfec0c9ae4b1a1803075ed967b7bb73f
q_256 = 0xf1fd178c0b3ad58f10126de8ce42435b53dc67e140d2bf941ffdd459c6d655e1
xPaff_256 = 0xb6b3d4c356c139eb31183d4749d423958c27d2dcaf98b70164c97a2dd98f5cff
yPaff_256 = 0x6142e0f7c8b204911f9271f0f3ecef8c2701c307e8e4c9e183115a1554062cfb
Fp_256 = GF(p_256)
E_256 = EllipticCurve(Fp_256, [a_256,b_256])
k_256 = 0xf1adb2506355162d0de14468748fb171f730bd40f6595fe1732651df00589fcf
P_256 = E_256(xPaff_256, yPaff_256)
print()
print(" ___  _____   __  ")
print("|__ \| ____| / /  ")
print("   ) | |__  / /_  ")
print("  / /|___ \| '_ \ ")
print(" / /_ ___) | (_) |")
print("|____|____/ \___/ ")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_256.hex())
print("    a = 0x" + a_256.hex())
print("    b = 0x" + b_256.hex())
print("    q = 0x" + q_256.hex())
print("  point:")
print("    P = (0x" + xPaff_256.hex() + ",")
print("         0x" + yPaff_256.hex() + ")")
print("  scalar:")
print("    k = 0x" + k_256.hex())
print("outputs:")
print(" [k]P.x = 0x", Integer((k_256*P_256)[0]).hex())
print(" [k]P.y = 0x", Integer((k_256*P_256)[1]).hex())

# 320
p_320 = 0xd35e472036bc4fb7e13c785ed201e065f98fcfa6f6f40def4f92b9ec7893ec28fcd412b1f1b32e27
a_320 = 0x3ee30b568fbab0f883ccebd46d3f3bb8a2a73513f5eb79da66190eb085ffa9f492f375a97d860eb4
b_320 = 0x520883949dfdbc42d3ad198640688a6fe13f41349554b49acc31dccd884539816f5eb4ac8fb1f1a6
q_320 = 0xd35e472036bc4fb7e13c785ed201e065f98fcfa5b68f12a32d482ec7ee8658e98691555b44c59311
xPaff_320 = 0x43bd7e9afb53d8b85289bcc48ee5bfe6f20137d10a087eb6e7871e2a10a599c710af8d0d39e20611
yPaff_320 = 0x14fdd05545ec1cc8ab4093247f77275e0743ffed117182eaa9c77877aaac6ac7d35245d1692e8ee1
Fp_320 = GF(p_320)
E_320 = EllipticCurve(Fp_320, [a_320,b_320])
k_320 = 0x71f60ecf6f4a75b08022b5cc85deb00b060eb483a06ab83d48a4980f4f8c9f0bdbe646586b834660
P_320 = E_320(xPaff_320, yPaff_320)
print()
print(" ____ ___   ___  ")
print("|___ \__ \ / _ \ ")
print("  __) | ) | | | |")
print(" |__ < / /| | | |")
print(" ___) / /_| |_| |")
print("|____/____|\___/ ")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_320.hex())
print("    a = 0x" + a_320.hex())
print("    b = 0x" + b_320.hex())
print("    q = 0x" + q_320.hex())
print("  point:")
print("    P = (0x" + xPaff_320.hex() + ",")
print("         0x" + yPaff_320.hex() + ")")
print("  scalar:")
print("    k = 0x" + k_320.hex())
print()
print("outputs:")
print(" [k]P.x = 0x", Integer((k_320*P_320)[0]).hex())
print(" [k]P.y = 0x", Integer((k_320*P_320)[1]).hex())

# 384
p_384 = 0x8cb91e82a3386d280f5d6f7e50e641df152f7109ed5456b412b1da197fb71123acd3a729901d1a71874700133107ec53
a_384 = 0x7bc382c63d8c150c3c72080ace05afa0c2bea28e4fb22787139165efba91f90f8aa5814a503ad4eb04a8c7dd22ce2826
b_384 = 0x04a8c7dd22ce28268b39b55416f0447c2fb77de107dcd2a62e880ea53eeb62d57cb4390295dbc9943ab78696fa504c11
q_384 = 0x8cb91e82a3386d280f5d6f7e50e641df152f7109ed5456b31f166e6cac0425a7cf3ab6af6b7fc3103b883202e9046565
xPaff_384 = 0x1d1c64f068cf45ffa2a63a81b7c13f6b8847a3e77ef14fe3db7fcafe0cbd10e8e826e03436d646aaef87b2e247d4af1e
yPaff_384 = 0x8abe1d7520f9c2a45cb1eb8e95cfd55262b70b29feec5864e19c054ff99129280e4646217791811142820341263c5315
Fp_384 = GF(p_384)
E_384 = EllipticCurve(Fp_384, [a_384,b_384])
k_384 = 0x71b91e82a3386d280f5d6f7e50e641df152f7109ed5456b31f166e6cac0425a7cf3ab6af6b7fc3103b883202e9046565
P_384 = E_384(xPaff_384, yPaff_384)
print()
print(" ____   ___  _  _   ")
print("|___ \ / _ \| || |  ")
print("  __) | (_) | || |_ ")
print(" |__ < > _ <|__   _|")
print(" ___) | (_) |  | |  ")
print("|____/ \___/   |_|  ")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_384.hex())
print("    a = 0x" + a_384.hex())
print("    b = 0x" + b_384.hex())
print("    q = 0x" + q_384.hex())
print("  point:")
print("    P = (0x" + xPaff_384.hex() + ",")
print("         0x" + yPaff_384.hex() + ")")
print("  scalar:")
print("    k = 0x" + k_384.hex())
print("outputs:")
print(" [k]P.x = 0x", Integer((k_384*P_384)[0]).hex())
print(" [k]P.y = 0x", Integer((k_384*P_384)[1]).hex())

# 512
p_512 = 0xaadd9db8dbe9c48b3fd4e6ae33c9fc07cb308db3b3c9d20ed6639cca703308717d4d9b009bc66842aecda12ae6a380e62881ff2f2d82c68528aa6056583a48f3
a_512 = 0x7830a3318b603b89e2327145ac234cc594cbdd8d3df91610a83441caea9863bc2ded5d5aa8253aa10a2ef1c98b9ac8b57f1117a72bf2c7b9e7c1ac4d77fc94ca
b_512 = 0x3df91610a83441caea9863bc2ded5d5aa8253aa10a2ef1c98b9ac8b57f1117a72bf2c7b9e7c1ac4d77fc94cadc083e67984050b75ebae5dd2809bd638016f723
q_512 = 0xaadd9db8dbe9c48b3fd4e6ae33c9fc07cb308db3b3c9d20ed6639cca70330870553e5c414ca92619418661197fac10471db1d381085ddaddb58796829ca90069
xPaff_512 = 0x81aee4bdd82ed9645a21322e9c4c6a9385ed9f70b5d916c1b43b62eef4d0098eff3b1f78e2d0d48d50d1687b93b97d5f7c6d5047406a5e688b352209bcb9f822
yPaff_512 = 0x7dde385d566332ecc0eabfa9cf7822fdf209f70024a57b1aa000c55b881f8111b2dcde494a5f485e5bca4bd88a2763aed1ca2b2fa8f0540678cd1e0f3ad80892
Fp_512 = GF(p_512)
E_512 = EllipticCurve(Fp_512, [a_512,b_512])
k_512 = 0xa247dd445f93b085b804f0748493d353a8f51b1922b8ba68df6ce35b00364c0aea25b7d854721594219a259bf66bbca76d7adb6d23262cbdfa51e13602e2113a
P_512 = E_512(xPaff_512, yPaff_512)
print()
print(" _____ __ ___  ")
print("| ____/_ |__ \ ")
print("| |__  | |  ) |")
print("|___ \ | | / / ")
print(" ___) || |/ /_ ")
print("|____/ |_|____|")
print("inputs:")
print("  curve:")
print("    p = 0x" + p_512.hex())
print("    a = 0x" + a_512.hex())
print("    b = 0x" + b_512.hex())
print("    q = 0x" + q_512.hex())
print("  point:")
print("    P = (0x" + xPaff_512.hex())
print("         0x" + yPaff_512.hex())
print("  scalar:")
print("    k = 0x" + k_512.hex())
print("outputs:")
print(" [k]P.x = 0x", Integer((k_512*P_512)[0]).hex())
print(" [k]P.y = 0x", Integer((k_512*P_512)[1]).hex())

