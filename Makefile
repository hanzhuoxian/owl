
# includes
include scripts/make-rules/common.mk
include scripts/make-rules/go.mk
include scripts/make-rules/tool.mk

.PHONY: all
all: objects := $(addsuffix .c, c a b)
all:
	@echo $(origin <)


## help: Show this help info.
.PHONY: help
help: Makefile
	@echo "\nUsage: make <TARGETS> <OPTIONS> ...\n\nTargets:"
	@sed -n 's/^##//p' $< | column -t -s ':' | sed -e 's/^/ /'
	@echo "$$USAGE_OPTIONS"

.PHONY: build
build:
	@$(MAKE) go.build


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

# 选项
# ==============================================================================
# Usage

define USAGE_OPTIONS

Options:
  V                Set to 1 enable verbose build. Default is 0.
endef
export USAGE_OPTIONS