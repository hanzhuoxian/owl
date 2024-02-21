#!/usr/bin/env bash

# shellcheck disable=SC2034 # Variables sourced in other scripts.

# The server platform we are building on.
readonly SUPPORTED_SERVER_PLATFORMS=(
  linux/amd64
  linux/arm64
)

# If we update this we should also update the set of platforms whose standard
# library is precompiled for in build/build-image/cross/Dockerfile
readonly SUPPORTED_CLIENT_PLATFORMS=(
  linux/amd64
  linux/arm64
)

# The set of server targets that we are only building for Linux
# If you update this list, please also update build/BUILD.
function golang::server_targets() {
  local targets=(
    owl-apiserver
  )
  echo "${targets[@]}"
}

IFS=" " read -ra SERVER_TARGETS <<< "$(golang::server_targets)"
readonly SERVER_TARGETS
readonly SERVER_BINARIES=("${SERVER_TARGETS[@]##*/}")

# The set of server targets we build docker images for
function golang::server_image_targets() {
  # NOTE: this contains cmd targets for build::get_docker_wrapped_binaries
  local targets=(
    cmd/owl-apiserver
  )
  echo "${targets[@]}"
}

IFS=" " read -ra SERVER_IMAGE_TARGETS <<< "$(golang::server_image_targets)"
readonly SERVER_IMAGE_TARGETS
readonly SERVER_IMAGE_BINARIES=("${SERVER_IMAGE_TARGETS[@]##*/}")

# ------------
# NOTE: All functions that return lists should use newlines.
# bash functions can't return arrays, and spaces are tricky, so newline
# separators are the preferred pattern.
# To transform a string of newline-separated items to an array, use util::read-array:
# util::read-array FOO < <(golang::dups a b c a)
#
# ALWAYS remember to quote your subshells. Not doing so will break in
# bash 4.3, and potentially cause other issues.
# ------------

# Returns a sorted newline-separated list containing only duplicated items.
function golang::dups() {
  # We use printf to insert newlines, which are required by sort.
  printf "%s\n" "$@" | sort | uniq -d
}

# Returns a sorted newline-separated list with duplicated items removed.
function golang::dedup() {
  # We use printf to insert newlines, which are required by sort.
  printf "%s\n" "$@" | sort -u
}

# Depends on values of user-facing BUILD_PLATFORMS, FASTBUILD,
# and BUILDER_OS.
# Configures SERVER_PLATFORMS and CLIENT_PLATFORMS, then sets them
# to readonly.
# The configured vars will only contain platforms allowed by the
# SUPPORTED* vars at the top of this file.
declare -a SERVER_PLATFORMS
declare -a CLIENT_PLATFORMS
function golang::setup_platforms() {
  if [[ -n "${BUILD_PLATFORMS:-}" ]]; then
    # BUILD_PLATFORMS needs to be read into an array before the next
    # step, or quoting treats it all as one element.
    local -a platforms
    IFS=" " read -ra platforms <<< "${BUILD_PLATFORMS}"

    # Deduplicate to ensure the intersection trick with golang::dups
    # is not defeated by duplicates in user input.
    util::read-array platforms < <(golang::dedup "${platforms[@]}")

    # Use golang::dups to restrict the builds to the platforms in
    # SUPPORTED_*_PLATFORMS. Items should only appear at most once in each
    # set, so if they appear twice after the merge they are in the intersection.
    util::read-array SERVER_PLATFORMS < <(golang::dups \
        "${platforms[@]}" \
        "${SUPPORTED_SERVER_PLATFORMS[@]}" \
      )

    util::read-array CLIENT_PLATFORMS < <(golang::dups \
        "${platforms[@]}" \
        "${SUPPORTED_CLIENT_PLATFORMS[@]}" \
      )
    readonly CLIENT_PLATFORMS

  elif [[ "${FASTBUILD:-}" == "true" ]]; then
    SERVER_PLATFORMS=(linux/amd64)
    CLIENT_PLATFORMS=(linux/amd64)
  else
    SERVER_PLATFORMS=("${SUPPORTED_SERVER_PLATFORMS[@]}")

    CLIENT_PLATFORMS=("${SUPPORTED_CLIENT_PLATFORMS[@]}")
  fi
}

golang::setup_platforms

# The set of client targets that we are building for all platforms
# If you update this list, please also update build/BUILD.
readonly CLIENT_TARGETS=(
  iamctl
)
readonly CLIENT_BINARIES=("${CLIENT_TARGETS[@]##*/}")

readonly ALL_TARGETS=(
  "${SERVER_TARGETS[@]}"
  "${CLIENT_TARGETS[@]}"
)
readonly ALL_BINARIES=("${ALL_TARGETS[@]##*/}")

# Asks golang what it thinks the host platform is. The go tool chain does some
# slightly different things when the target platform matches the host platform.
function golang::host_platform() {
  echo "$(go env GOHOSTOS)/$(go env GOHOSTARCH)"
}

# Ensure the go tool exists and is a viable version.
function golang::verify_go_version() {
  if [[ -z "$(command -v go)" ]]; then
    log::usage_from_stdin <<EOF
Can't find 'go' in PATH, please fix and retry.
See http://golang.org/doc/install for installation instructions.
EOF
    return 2
  fi

  local go_version
  IFS=" " read -ra go_version <<< "$(go version)"
  local minimum_go_version
  minimum_go_version=go1.13.4
  if [[ "${minimum_go_version}" != $(echo -e "${minimum_go_version}\n${go_version[2]}" | sort -s -t. -k 1,1 -k 2,2n -k 3,3n | head -n1) && "${go_version[2]}" != "devel" ]]; then
    log::usage_from_stdin <<EOF
Detected go version: ${go_version[*]}.
requires ${minimum_go_version} or greater.
Please install ${minimum_go_version} or later.
EOF
    return 2
  fi
}

# golang::setup_env will check that the `go` commands is available in
# ${PATH}. It will also check that the Go version is good enough for the
# IAM build.
#
# Outputs:
#   env-var GOBIN is unset (we want binaries in a predictable place)
#   env-var GO15VENDOREXPERIMENT=1
#   env-var GO111MODULE=on
function golang::setup_env() {
  golang::verify_go_version

  # Unset GOBIN in case it already exists in the current session.
  unset GOBIN

  # This seems to matter to some tools
  export GO15VENDOREXPERIMENT=1

  # Open go module feature
  export GO111MODULE=on

  # This is for sanity.  Without it, user umasks leak through into release
  # artifacts.
  umask 0022
}
