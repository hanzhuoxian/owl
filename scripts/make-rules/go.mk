GO := go

COMMANDS ?= $(filter-out %.md, $(wildcard ${ROOT_DIR}/cmd/*))
BINS ?= $(foreach cmd, ${COMMANDS}, $(notdir ${cmd}))
## go.build: build go binary
.PHONY: go.build
go.build:
	@echo $(BINS)
	@echo ${OUTPUT_DIR}

go.build.%:
	@echo "go.build.$*"