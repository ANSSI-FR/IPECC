# IPECC, an open-source VHDL IP for generic elliptic curve cryptography over finite field, with emphasis on side-channel resistance

Copyright (C) 2023

**Authors**: Karim KHALFALLAH (<mailto:karim.khalfallah@ssi.gou.fr>), Ryad BENADJILA (<mailto:ryadbenadjila@gmail.com>)

**Contributors**: Adrian THILLARD, Emmanuel PROUFF

## Introduction

IPECC is a hardware IP block performing the computation of scalar multiplication $[k]P$ over elliptic curves defined in short Weierstrass form on a finite field of charasteristic $p > 3$. IPECC has been developped mainly for SRAM-based FPGAs (both Xilinx and Intel-Altera) but it should also be usable as input to an ASIC flow without any kind of restriction.

The size of prime $p$, denoted ``nn`` in the code and in the remainder of this document, defines the level of cryptographic security. By definition all large numbers used for cryptographic computations are ``nn``-bit long. Parameter ``nn`` is statically defined by the designer at synthesis time and can be chosen to be any integer value. All you need for that is to edit the value of a unique HDL constant. The limitation only comes from the logical and memory ressources of your target circuit/part, as the amount of logic and memory consumed by the IP will obviously increase with the value of ``nn``. An optional feature, named *dynamic prime size* feature, allows to dynamically set the size of big numbers, provided they stay below the value statically set to parameter ``nn`` (which in this case simply becomes the maximal size allowed).

IPECC is intended for production purpose as well as academic research.

* While targeting an end product, it will exhibit very good performance as it relies on *Co-Z* arithmetic to reduce the area of logic by a factor of almost two without impacting throughput nor latency. Countermeasures against side-channel attacks have been designed with a *defense-in-depth* state of mind, meaning that security does not rely on one unique countermeasure but in the contrary should be based on the application of several layers of defense. Thus every countermeasure can be hardware-locked at synthesis time to enforce a hardened, secure implementation, or left software-disengageable by designer instead. Available side-channel countermeasures are: **double-and-add-always**, **address-masking of $\mathcal{R}_0/\mathcal{R}_1$ points** (aka anti address-bit DPA or ADPA), **address-shuffling** of the sensitive intermediate point coordinates, **blinding** (randomization of the private exponent), **Z-masking** (randomized projective coordinates) and **curve isomorphic randomization**.
Scalar multiplication is guaranteed to be **constant-time** as long as no exceptions is met during computation (like intermediate points turning to be equal or opposite when performing a point addition). IPECC comes with its own TRNG.

* For academic research purpose, IPECC provides a powerful and versatile testbed to analyze side-channel and fault attacks's practicability and efficiency. All countermeasures then become optional and can be engaged or fully removed from the design, either at synthesis time or dynamically %(i.e at runtime) through software configuration. Conversely, it is straightforward to force usage of part or all of the countermeasures to allow for leak measure and detection, signal-to-noise ratio measures, or active stress testing/perturbation. Debug features allow breakpoint setting and step-by-step execution. Along with trigger-out signal generation to remote instruments (e.g oscilloscopes/EM injection probes) they allow for clear isolation of specific instruction, operation or computation, pattern detection and step-by-step leak detection.

IPECC architecture is very simple and allows for partial reprogrammation, as it is partially based on microcode execution of embedded software routines which can be easily edited if one wants to implement a new countermeasure or test a new attack scenario.

IPECC is written in fully synthesizable VHDL. A high-level description approach has been adopted, with no explicit instanciation of any vendor dependent hardware macro, with the sole exception of multiplier-accumulators which use black-box instanciations of FPGAs' so-called *DSP blocks*.

IPECC comes wrapped up as an AXI-lite interface (both 32-bit/64-bit compatible) allowing easy plug-&-play integration inside any ARM or RISC-V ecosystem, e.g in SoC-FPGA designs or for ASIC prototyping. It is easily programmed through a small set of control and status registers plus optional asynchronous interrupt generation. Pre-computations involved in Montgomery representation are automatically performed by hardware upon transmission of a new value of the field prime $p$, and do not involve further operation whatsoever from software.

A software driver is provided to hook-up IPECC with the **libecc** software library project (available from [github.com/libecc/libecc](https://github.com/libecc/libecc)). Together with libecc  project, for which it provides a hardware accelerator of all point level computations, IPECC provides a comprehensive and highly secured solution to implement ECC protocols like EC\*DSA or ECDH for SoC prototyping and design.

IPECC is licensed in GPLv2 and available for download from ANSSI's GitHub at ``https://github.com/ANSSI-FR/IPECC``.

## Highlights

The main features of IPECC are:

1. Fully synthesizable, fully compatible with all FPGA vendors/parts, as well as ASIC

2. No limit to security size except that of your hardware ressources

3. Very simple AXI-lite interface compatible to all AMBA-based systems

4. Available countermeasures:

    1. Built-in

        1. Point verification as very first and very last operations

        2. Anti-address bit DPA, with extra layer of shuffling on intermediate point coordinates

        4. Coordinates masking (Z-masking)

        5. Constant time (if no exception met)

    2. Optional

        1. Scalar blinding ( $k' = k + \alpha \times q$ ) with configurable size of $\alpha$ (up to ``nn``)

        2. Memory shuffling between each scalar bit processing

        3. Curve isomorphic randomization

5. Reduced silicon area thanks to Co-Z arithmetic

6. Customizable number of Montgomery multipliers

7. Customizable number of multiplier-accumulators per Montgomery multiplier

8. Built-in TRNG design (ES-TRNG from [KU-Leuven, CHES'2018](https://tches.iacr.org/index.php/TCHES/article/view/7276))

9. Automatic computation of Montgomery constants

10. Optional dynamically changeable size of large numbers/security parameter

11. Optional GALS (Montgomery multipliers with their own sped-up clock domain)

## Hardware

This section will be completed with more information about the hardware architecture,
targets and VHDL synthesis.

## Software

### The IPECC driver

The software accompanying IPECC is mainly made of a driver in the [driver](driver) folder.
The main driver is in [driver/hw_accelerator_driver_ipecc.c](driver/hw_accelerator_driver_ipecc.c),
and it exposes APIs in [driver/hw_accelerator_driver.h](driver/hw_accelerator_driver.h) consisting
of setting curve parameters, points doubling, addition, negation, scalar multiplication, comparison, etc.

The [driver/hw_accelerator_driver_ipecc_platform.c](driver/hw_accelerator_driver_ipecc_platform.c) contains
the platform adherence: the driver can be compiled for a standalone mode (i.e. direct mapping of the IP
to a physical address), or a Linux compatible mode using `DEVMEM` (`/dev/mem`) mappings or `UIO` mappings (see [here](https://www.kernel.org/doc/html/v4.12/driver-api/uio-howto.html)
for more information on the User IO interface).

The [driver/test_driver.c](driver/test_driver.c) file contains basic tests of the IP for the various
APIs. In order to compile this use the `make` command (you will need `arm-linux-gnueabihf-gcc` or equivalent
for targeting the Zynq platform, use the `ARM_CC` environment variable to modify your compiler).
This should compile three binaries `test_standalone`, `test_devmem` and `test_uio` for each platform.

Finally, we also provide an emulation driver in [driver/hw_accelerator_driver_socket_emul.c](driver/hw_accelerator_driver_socket_emul.c).
This software layer communicates using TCP sockets with a Python server that provides an emulation of
the APIs offered by the "real hardware", namely point operations. The idea is to have a simple way
to implement and debug programs that use the hardware API without having the hardware at hand.
The Python server is in [driver/emulator_server/hw_driver_socket_emul_server.py](driver/emulator_server/hw_driver_socket_emul_server.py)
and can be directly launched on the command line:

```
$ python3 driver/emulator_server/hw_driver_socket_emul_server.py 
[+] IPECC hardware emulator started, listening on 127.0.0.1:8080
...
```

This will open a socket in listen mode on `localhost:8080` and will
wait for a "client" connection. It is possible to compile the [driver/test_driver.c](driver/test_driver.c)
test file in emulation mode using the `make emulator` target: this will compile the
`test_emul` binary that can be executed as the server client on a regular PC:

```
./test_emul 
Welcome to the driver test!
```

**NOTE1**: although the driver is ready for production use with IPECC, the debug features
are still a work in progress as we have mainly focused on the core functionalities.
More specifically, breakpoints and IP internal memory dumping as well
as TRNG debugging are not fully implemented nor tested: this will be integrated in future
updates.

**NOTE2**: the driver has been fully tested in 32-bit mode with a 32-bit IP on Zynq 32-bit
platforms. Other modes (in the matrix of 32-bit or 64-bit software with 32-bit or 64-bit IP)
are a work in progress: although the software and hardware are ready to be compiled in each mode, some
dependencies with the AXI interface bus width must be taken into consideration (this is related to how
the bus controller splits memory accesses). The IPECC repository will be updated when all the test cases
are covered and validated.


### The IPECC integration with libecc

IPECC and its driver have been integrated to the [libecc](https://github.com/libecc/libecc)
project where all the curve operations have been replaced with hardware
acceleration. This showcases the usage of hardware acceleration in a full fledged
ECC library supporting various elliptic curves based signature schemes and ECDH.

In order to test IPECC with libecc, please clone the repository and **checkout the dedicated IPECC branch**:

```
$ git clone https://github.com/libecc/libecc
$ git checkout -b IPECC
```

Then fetch the driver (this will clone the current repository and place the IPECC drivers in
the `src/curve` folder):

```
$ make install_hw_driver
```

Then, you can compile the library with hardware acceleration by selecting the underlying platform:

```
$ make clean && CC=arm-linux-gnueabihf-gcc \
EXTRA_CFLAGS="-Wall -Wextra -O3 -g3 -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -static" \
VERBOSE=1 USE_EC_HW=1 USE_EC_HW_DEVMEM=1 USE_EC_HW_LOCKING=1 BLINDING=1 make
```

Please note that `USE_EC_HW=1` selects the hardware accelerator (this is mandatory to activate the hardware acceleration backend in libecc),
and `USE_EC_HW_DEVMEM=1` selects the DEVMEM backend (you can use `USE_EC_HW_STANDALONE=1`
for the standalone mode, `USE_EC_HW_UIO=1` for UIO, and `USE_EC_HW_SOCKET_EMUL=1` for the socket emulation using the Python server).
We also override the `CC` compiler to `arm-linux-gnueabihf-gcc` for the Zynq platform (adapt at your will depending on your
target), and add some necessary extra CFLAGS for the platform (as well as a `-static` binary compilation to avoid library dependency issues).
Finally, `USE_EC_HW_LOCKING=1` is used here for thread safety during hardware access: this flag is necessary for multi-threading.

You can then copy the produced binaries `build/ec_self_tests` and `build/ec_utils` on the target platform and execute them.

As we can see below, the performance benchmark shows a **factor 6** on average between the pure software version
and the hardware accelerated one. The benchmarks have been performed on a [Zynq Arty Z7](https://digilent.com/reference/programmable-logic/arty-z7/start) board.

```
az7-ecc-axi:/home/petalinux# ./ec_self_tests_sw perf
======= Performance test ========================
[+]          ECDSA-SHA224/FRP256V1 perf: 6 sign/s and 6 verif/s
[+]         ECDSA-SHA224/SECP192R1 perf: 9 sign/s and 9 verif/s
[+]         ECDSA-SHA224/SECP224R1 perf: 7 sign/s and 7 verif/s
[+]         ECDSA-SHA224/SECP256R1 perf: 6 sign/s and 6 verif/s
...

az7-ecc-axi:/home/petalinux# ./ec_self_tests_hw perf
======= Performance test ========================
[+]          ECDSA-SHA224/FRP256V1 perf: 34 sign/s and 32 verif/s
[+]         ECDSA-SHA224/SECP192R1 perf: 57 sign/s and 52 verif/s
[+]         ECDSA-SHA224/SECP224R1 perf: 44 sign/s and 39 verif/s
[+]         ECDSA-SHA224/SECP256R1 perf: 34 sign/s and 32 verif/s
[+]         ECDSA-SHA224/SECP384R1 perf: 16 sign/s and 15 verif/s
[+]         ECDSA-SHA224/SECP521R1 perf: 8 sign/s and 8 verif/s
[+]   ECDSA-SHA224/BRAINPOOLP192R1 perf: 57 sign/s and 52 verif/s
[+]   ECDSA-SHA224/BRAINPOOLP224R1 perf: 44 sign/s and 40 verif/s 
```
