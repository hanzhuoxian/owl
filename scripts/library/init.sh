#!/usr/bin/env bash

set -eu
set -o pipefail

# Default use go modules
export GO111MODULE=on

ROOT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}")/../.. && pwd -P)


source "${ROOT_DIR}/scripts/library/color.sh"
source "${ROOT_DIR}"/scripts/library/util.sh
source "${ROOT_DIR}/scripts/library/logging.sh"

log::install_errexit

source "${ROOT_DIR}/scripts/library/version.sh"
source "${ROOT_DIR}/scripts/library/golang.sh"
