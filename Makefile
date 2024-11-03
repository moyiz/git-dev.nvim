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

LATEST_TAG := $(shell git tag --list | tail -1)

.PHONY: all doc version test panvimdoc-build tag

all: version doc

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

version:
	@echo ---
	@$(NVIM) --version | awk 'NR==1||NR==3{print}'
	@echo ---

panvimdoc-build:
	@if [[ $(PANVIMDOC_USE_DOCKER) == true ]]; then \
		if [[ $(PANVIMDOC_IMAGE_EXISTS) != 0 ]]; then \
			echo "Could not find local panvimdoc image, building..."; \
			DIR=$(shell mktemp -d); \
			pushd $$DIR; \
			git clone $(PANVIMDOC_GIT) .; \
			docker build -t $(PANVIMDOC_IMAGE) .; \
			popd; \
			echo rm -rf $$DIR; \
			echo Done; \
		else \
			echo "Found panvimdoc image, proceeding."; \
		fi; \
	else \
		echo "Not using docker"; \
	fi

test:
	nvim --headless --clean -c 'set runtimepath+=.' -c 'luafile tests/runner.lua' -c qa

tag:
	@echo Last tag: $(LATEST_TAG);
	@if [[ -n "$(TAG)" ]]; then \
		echo Creating a tag: ${TAG}; \
		MSG_FILE=$(shell mktemp); \
		echo Release $(TAG) | tee $$MSG_FILE; \
		echo | tee -a $$MSG_FILE; \
		git log --pretty=format:%s --invert-grep --grep doc:* $(LATEST_TAG)..HEAD | tee -a $$MSG_FILE; \
		echo; \
		echo git tag -a $(TAG) -F $$MSG_FILE; \
	else \
		echo "Missing TAG definition."; \
	fi


# vim: ft=make ts=4 noexpandtab
