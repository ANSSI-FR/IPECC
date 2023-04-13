SHELL := /bin/bash

TEX_FILE=ecc_curve_iram.tex
PDF_FILE=ecc_curve_iram.pdf

# Default target
all:
	# Generate the main tex file to be
	# processed
	@echo "| Process ASM files"
	@rm -f all-progs.tex.pre.0
	@touch all-progs.tex.pre.0
	@for i in $(PFX_SRC_FILES); do \
		echo '\newpage' > $$i.part; \
		echo '\begin{longtable}{lllllll}' >> $$i.part; \
		cat ../$(ASM_SRC)/$$i.s >> $$i.part ; \
		echo '\end{longtable}' >> $$i.part ; \
		cat $$i.part >> all-progs.tex.pre.0 ; \
	done
	# process all-progs.tex.pre.0 so as to tabulate all instructions and their operands
	# (output of awk script is buffered in file all-progs.tex.pre0 which in turn takes
	# the place of input file all-progs.tex.pre)
	@sed -e 's/^[ \t]\{1,\}//' all-progs.tex.pre.0 | awk -f pretexify.awk >|all-progs.tex.pre
	# Remove all the comments which do not start directly from
	# the begining of the line
	@sed -i -e 's/[ \t]\{1,\}#.*$$//' all-progs.tex.pre
	# Generate our texify script
	@echo "| Generate the texify awk script"
	# First generate our assembly.awk.vardefs.
	# For this we parse the CSV to get all our operands
	# addresses
	@cat ../$(ASM_VAR_DEFINITIONS) | sed 's/#.*//g'| sed 's/\([a-zA-Z0-9]*\),\([0-9]*\)/\taddr["\1"] = \2/g' > assembly.awk.vardefs
	# Then concatenate
	@echo "BEGIN {" > texify.awk
	@cat assembly.awk.vardefs texify.awk.end >> texify.awk
	# Now texify it
	@echo "| Texify the source"
	@sed -e 's/_/\\char`_/g' all-progs.tex.pre | awk -f texify.awk >| all-progs.tex
	# Compile
	@echo "| LATEX $(TEX_FILE)"
	@if ! pdflatex -interaction=nonstopmode $(TEX_FILE) >/dev/null 2>&1 ; then \
		rm -f $(PDF_FILE) ; \
		echo "First pass of pdflatex failed... manually type 'pdflatex $(TEX_FILE)' in latex/ folder to discover why" ; \
	else \
		if ! pdflatex -interaction=nonstopmode $(TEX_FILE) >/dev/null 2>&1 ; then \
			rm -f $(PDF_FILE) ; \
			echo "Second pass of pdflatex failed... manually type 'pdflatex $(TEX_FILE)' in latex/ folder to discover why" ; \
     		fi ; \
   	fi

clean:
	@rm -f ecc_curve_iram.log ecc_curve_iram.aux
	@rm -f $(PDF_FILE) *.part
	@rm -f all-progs.tex all-progs.tex.pre texify.awk assembly.awk.vardefs
	@rm -f all-progs.tex.pre.0
