
.DEFAULT_GOAL := all

.PHONY: all
all: tidy format lint build


ROOT_PACKAGE=github.com/hanzhuoxian/owl

# includes
include scripts/make-rules/common.mk
include scripts/make-rules/go.mk
include scripts/make-rules/tool.mk
include scripts/make-rules/release.mk
include scripts/make-rules/image.mk
include scripts/make-rules/dependencies.mk


## help: Show this help info.
.PHONY: help
help: Makefile
	@echo "\nUsage: make <TARGETS> <OPTIONS> ...\n\nTargets:"
	@sed -n 's/^##//p' $< | column -t -s ':' | sed -e 's/^/ /'
	@echo "$$USAGE_OPTIONS"

.PHONY: build
build:
	@$(MAKE) go.build

## build.multiarch: Build source code for multiple platforms. See option PLATFORMS.
.PHONY: build.multiarch
build.multiarch:
	@$(MAKE) go.build.multiarch

.PHONY: format
format:
	@$(MAKE) go.format

.PHONY: test
test:
	@$(MAKE) go.test

.PHONY: lint
lint:
	@$(MAKE) go.lint

.PHONY: tidy
tidy:
	@$(GO) mod tidy

.PHONY: install
install:
	@$(MAKE) tools.install


.PHONY: clean
clean:
	@$(MAKE) go.clean

.PHONY: dependencies
dependencies:
	@$(MAKE) dependencies.run

# 选项
# ==============================================================================
# Usage

define USAGE_OPTIONS

Options:
  V                Set to 1 enable verbose build. Default is 0.
endef
export USAGE_OPTIONS
