#!/usr/bin/env bash

ROOT_PATH=$(dirname "${BASH_SOURCE[0]}")/..

source "${ROOT_PATH}"/scripts/common.sh
source "${ROOT_PATH}"/scripts/library/release.sh

RELEASE_RUN_TESTS=${RELEASE_RUN_TESTS-y}

golang::setup_env
build::ensure_tar
release::package_src_tarball
