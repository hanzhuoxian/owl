#!/usr/bin/env bash

ROOT_PATH=$(dirname "${BASH_SOURCE[0]}")/..

source "${ROOT_PATH}"/scripts/common.sh
source "${ROOT_PATH}"/scripts/library/release.sh

golang::setup_env
build::verify_prereqs
release::verify_prereqs
# build::build_image
build::build_command
release::package_tarballs
# git push origin "${VERSION:-}"
# release::github_release
# release::generate_changelog

