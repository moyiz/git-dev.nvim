SHELL = /bin/bash
NVIM ?= nvim
PANVIMDOC_USE_DOCKER ?= true

ifeq ($(PANVIMDOC_USE_DOCKER), true)
	PANVIMDOC_CMD := docker run --rm -v .:/data panvimdoc:latest
else
	PANVIMDOC_CMD := ./panvimdoc.sh
endif

PANVIMDOC_IMAGE ?= panvimdoc:latest
PANVIMDOC_GIT ?= https://github.com/kdheepak/panvimdoc.git 
PANVIMDOC_IMAGE_EXISTS := $(shell docker inspect $(PANVIMDOC_IMAGE) > /dev/null 2>&1; echo $$?)

.PHONY: all
all: version doc


.PHONY: doc
doc: version panvimdoc-build
	@# For mini.doc:
	@# $(NVIM) --headless --noplugin -u ./scripts/doc_init.lua -c 'lua require("mini.doc").generate()' -c qa
	@# @echo
	@# For EmmyLua:
	@# lemmy-help -l default --expand-opt lua/git-dev/init.lua > doc/git-dev.txt
	@# For panvimdoc:
	@echo Generating docs...
	@$(PANVIMDOC_CMD) --project-name git-dev --input-file README.md --toc true \
		--vim-version "Neovim version 0.9" --description "" --demojify true \
		--treesitter true --shift-heading-level-by -1 --doc-mapping true
	@echo Generating tags...
	@$(NVIM) --headless --clean -c "helptags doc/" -c qa
	@echo Done.

.PHONY: version
version:
	@echo ---
	@$(NVIM) --version | awk 'NR==1||NR==3{print}'
	@echo ---

panvimdoc-build: 
	@if [[ $(PANVIMDOC_USE_DOCKER) == true ]]; then \
		if [[ $(PANVIMDOC_IMAGE_EXISTS) != 0 ]]; then \
			echo "Could not find local panvimdoc image, building..."; \
			DIR=$(shell mktemp -d); \
			cd $$DIR; \
			git clone $(PANVIMDOC_GIT) .; \
			docker build -t $(PANVIMDOC_IMAGE) .; \
			cd -; \
			echo rm -rf $$DIR; \
			echo Done; \
		else \
			echo "Found panvimdoc image, proceeding."; \
		fi; \
	else \
		echo "Not using docker"; \
	fi

# vim: ft=make ts=4 noexpandtab
