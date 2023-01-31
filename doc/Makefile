TARGETS = pdf html
all: $(TARGETS)

.PHONY: pdf html
basename=README

pdf: $(basename).pdf

html: $(basename).html

%.html: %.md
	pandoc --standalone $< --to html5 --output $@ \
	       --toc --toc-depth 2 --section-divs \
	       --css style.css --mathml

%.tex: %.md
	pandoc --standalone $< --to latex --output $@

%.pdf: %.tex
	pdflatex $<

clean:
	@rm -f $(basename).{aux,log,out,tex}
	@rm -f $(basename).pdf $(basename).html
