#!/usr/bin/env bash

# This is where the final release artifacts are created locally
readonly RELEASE_STAGE="${LOCAL_OUTPUT_ROOT}/release-stage"
readonly RELEASE_TARS="${LOCAL_OUTPUT_ROOT}/release-tars"
readonly RELEASE_IMAGES="${LOCAL_OUTPUT_ROOT}/release-images"

# github account info
readonly GITHUB_ORG=hanzhuoxian
readonly GITHUB_REPO=owl

# The version of the release
readonly ARTIFACT=owl.tar.gz
readonly CHECKSUM=${ARTIFACT}.sha1sum

BUILD_CONFORMANCE=${BUILD_CONFORMANCE:-y}
BUILD_PULL_LATEST_IMAGES=${BUILD_PULL_LATEST_IMAGES:-y}

function release::parse_and_validate_ci_version() {
  # Accept things like "v1.2.3-alpha.4.56+abcdef12345678" or "v1.2.3-beta.4"
  local -r version_regex="^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)-([a-zA-Z0-9]+)\\.(0|[1-9][0-9]*)(\\.(0|[1-9][0-9]*)\\+[0-9a-f]{7,40})?$"
  local -r version="${1-}"
  [[ "${version}" =~ ${version_regex} ]] || {
    log::error "Invalid ci version: '${version}', must match regex ${version_regex}"
    return 1
  }

  VERSION_MAJOR="${BASH_REMATCH[1]}"
  VERSION_MINOR="${BASH_REMATCH[2]}"
  VERSION_PATCH="${BASH_REMATCH[3]}"
  VERSION_PRERELEASE="${BASH_REMATCH[4]}"
  VERSION_PRERELEASE_REV="${BASH_REMATCH[5]}"
  VERSION_BUILD_INFO="${BASH_REMATCH[6]}"
  VERSION_COMMITS="${BASH_REMATCH[7]}"
}

# ---------------------------------------------------------------------------
# Build final release artifacts
function release::clean_cruft() {
  # Clean out cruft
  find "${RELEASE_STAGE}" -name '*~' -exec rm {} \;
  find "${RELEASE_STAGE}" -name '#*#' -exec rm {} \;
  find "${RELEASE_STAGE}" -name '.DS*' -exec rm {} \;
}

function release::package_src_tarball() {
  local -r src_tarball="${RELEASE_TARS}""${ARTIFACT}"
  log::status "Building tarball: src"
  if [[ "${GIT_TREE_STATE-}" = 'clean' ]]; then
    git archive -o "${src_tarball}" HEAD
  else
    find "${ROOT_PATH}" -mindepth 1 -maxdepth 1 \
      ! \( \
      \( -path "${ROOT_PATH}"/_\* -o \
      -path "${ROOT_PATH}"/.git\* -o \
      -path "${ROOT_PATH}"/.gitignore\* -o \
      -path "${ROOT_PATH}"/.gsemver.yaml\* -o \
      -path "${ROOT_PATH}"/.config\* -o \
      -path "${ROOT_PATH}"/.chglog\* -o \
      -path "${ROOT_PATH}"/.gitlint -o \
      -path "${ROOT_PATH}"/.golangci.yaml -o \
      -path "${ROOT_PATH}"/.goreleaser.yml -o \
      -path "${ROOT_PATH}"/.note.md -o \
      -path "${ROOT_PATH}"/.todo.md \
      \) -prune \
      \) -print0 |
      "${TAR}" czf "${src_tarball}" --null -T -
  fi
}

function release::package_tarball() {
 echo ""
}
