EMACS = emacs

.PHONY: build
build:
	$(EMACS) -Q --batch --script publish.el
