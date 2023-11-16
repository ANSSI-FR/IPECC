##############
# Main targets (phony ones to compile & elab.)
##############

.PHONY: workdir compile elaborate

all: elaborate
	
elaborate: compile
	@echo [GHDL-LLVM] -e ecc_tb
	@ghdl-llvm -e -fsynopsys --workdir=work ecc_tb && \
	  echo -e "\033[33;1m" ; \
	  echo "  Compilation & Elaboration completed." ; \
	  echo "  You can now run the simulation with this command line:" ; \
		echo ; \
	  echo "    $$ ghdl-llvm -r ecc_tb --ieee-asserts=disable" ; \
	  echo -e "\e[0m"

compile: workdir work/ecc_tb.o

workdir:
	@if [ ! -d ./work ] ; then mkdir work ; fi

clean:
	rm -Rf work ./ecc_tb

##############################################################
# Dependencies of each object (%.o) as regard to its own %.vhd
##############################################################

work/%.o :: %.vhd
	@echo "[GHDL-LLVM] $<"
	@ghdl-llvm -a --std=93c -fsynopsys --warn-no-hide --workdir=work $<

work/%.o :: ../hdl/common/%.vhd
	@echo "[GHDL-LLVM] $<"
	@ghdl-llvm -a --std=93c -fsynopsys --warn-no-hide --workdir=work $<

work/%.o :: ../hdl/common/ecc_trng/%.vhd
	@echo "[GHDL-LLVM] $<"
	@ghdl-llvm -a --std=93c -fsynopsys --warn-no-hide --workdir=work $<

work/%.o :: ../hdl/techno-specific/asic/%.vhd
	@echo "[GHDL-LLVM] $<"
	@ghdl-llvm -a --std=93c -fsynopsys --warn-no-hide --workdir=work $<

##############################################################
# Dependencies of objects between them
##############################################################

work/ecc_utils.o: work/ecc_customize.o

work/ecc_pkg.o: work/ecc_customize.o work/ecc_utils.o work/ecc_vars.o work/ecc_log.o

work/ecc_addr.o: work/ecc_pkg.o

#work/ecc_log.o:

#work/ecc_vars.o:

work/ecc_shuffle_pkg.o: work/ecc_customize.o work/ecc_pkg.o

work/mm_ndsp_pkg.o: work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o work/ecc_log.o

work/ecc_software.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/ecc_trng_pkg.o

work/ecc_shuffle_pkg.o: work/ecc_customize.o work/ecc_pkg.o

work/ecc_axi.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/ecc_vars.o work/ecc_software.o work/mm_ndsp_pkg.o work/ecc_trng_pkg.o

work/ecc_curve.o: work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o

work/ecc_curve_iram.o: work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o

work/ecc_fp.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/ecc_vars.o work/ecc_shuffle_pkg.o work/ecc_addr.o work/large_shr_asic.o

work/ecc_fp_dram.o: work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o work/ecc_vars.o

work/ecc_fp_dram_sh_fishy.o: work/ecc_pkg.o work/ecc_utils.o work/ecc_log.o work/ecc_customize.o work/ecc_trng_pkg.o work/ecc_shuffle_pkg.o work/ecc_fp_dram.o work/virt_to_phys_ram.o

work/ecc_fp_dram_sh_fishy_nb.o: work/ecc_pkg.o work/ecc_utils.o work/ecc_customize.o work/ecc_trng_pkg.o work/ecc_shuffle_pkg.o work/ecc_log.o work/ecc_fp_dram.o work/virt_to_phys_ram_async.o

work/ecc_fp_dram_sh_linear.o: work/ecc_customize.o work/ecc_trng_pkg.o work/ecc_utils.o work/ecc_pkg.o work/ecc_fp_dram.o

work/ecc_scalar.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/ecc_addr.o

work/ecc_trng_pkg.o: work/ecc_utils.o work/ecc_customize.o work/ecc_pkg.o

work/ecc_trng.o: work/ecc_customize.o work/ecc_log.o work/ecc_utils.o work/ecc_pkg.o work/ecc_trng_pkg.o work/es_trng_sim.o work/ecc_trng_pp.o work/ecc_trng_srv.o

work/ecc_trng_pp.o: work/ecc_customize.o work/ecc_log.o work/ecc_utils.o work/ecc_pkg.o work/ecc_trng_pkg.o

work/ecc_trng_srv.o: work/ecc_pkg.o work/ecc_log.o work/ecc_customize.o work/ecc_utils.o work/ecc_trng_pkg.o work/fifo.o

work/es_trng_sim.o: work/ecc_pkg.o work/ecc_log.o work/ecc_customize.o work/ecc_trng_pkg.o

#work/es_trng.o: work/ecc_pkg.o work/ecc_log.o work/ecc_customize.o work/ecc_utils.o work/ecc_trng_pkg.o work/es_trng_bitctrl.o work/es_trng_aggreg.o

#work/es_trng_aggreg.o: work/ecc_customize.o

#work/es_trng_bitctrl.o: work/ecc_customize.o work/es_trng_bit.o

work/es_trng_stub.o: work/ecc_pkg.o work/ecc_customize.o work/ecc_utils.o work/ecc_trng_pkg.o

work/fifo.o: work/ecc_log.o work/syncram_sdp.o

work/mm_ndsp.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/mm_ndsp_pkg.o work/maccx_asic.o work/sync2ram_sdp.o

work/sync2ram_sdp.o: work/ecc_log.o work/ecc_pkg.o work/ecc_customize.o

work/syncram_sdp.o: work/ecc_log.o

work/virt_to_phys_ram.o: work/ecc_pkg.o work/ecc_utils.o work/ecc_log.o work/ecc_customize.o work/ecc_shuffle_pkg.o

work/virt_to_phys_ram_async.o: work/ecc_log.o work/ecc_pkg.o work/ecc_customize.o work/ecc_shuffle_pkg.o

work/ecc.o: work/ecc_customize.o work/ecc_utils.o work/ecc_log.o work/ecc_pkg.o work/mm_ndsp_pkg.o work/ecc_trng_pkg.o work/ecc_shuffle_pkg.o work/ecc_axi.o work/ecc_scalar.o work/ecc_curve.o work/ecc_curve_iram.o work/ecc_fp.o work/ecc_trng.o work/ecc_fp_dram.o work/ecc_fp_dram_sh_linear.o work/ecc_fp_dram_sh_fishy_nb.o work/ecc_fp_dram_sh_fishy.o work/mm_ndsp.o

work/large_shr_asic.o: work/ecc_pkg.o

work/macc_asic.o: work/ecc_log.o work/ecc_pkg.o work/mm_ndsp_pkg.o

work/maccx_asic.o: work/ecc_log.o work/ecc_pkg.o work/mm_ndsp_pkg.o work/macc_asic.o

work/ecc_tb_vec.o: work/ecc_utils.o

work/ecc_tb_pkg.o: work/ecc_software.o work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o work/ecc_vars.o work/ecc_tb_vec.o

work/ecc_tb.o: work/ecc_customize.o work/ecc_utils.o work/ecc_pkg.o work/ecc_tb_pkg.o work/ecc_tb_vec.o work/ecc_vars.o work/ecc_software.o work/ecc.o
