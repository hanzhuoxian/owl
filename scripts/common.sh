#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

USER_ID=$(id -u)
GROUP_ID=$(id -g)

DOCKER_OPTS=${DOCKER_OPTS:-""}
DOCKER_HOST=${DOCKER_HOST:-""}
DOCKER_MECHINE_NAME=${DOCKER_MECHINE_NAME:-"owl-dev"}

readonly DOCKER_MECHINE_DRIVER=${DOCKER_MECHINE_DRIVER:-"virtualbox --virtualbox-cpu-count -1"}
readonly BUILD_IMAGE_REPO=owl-build
readonly DOCKER_REGISTRY="${DOCKER_REGISTRY:-k8s.gcr.io}"
readonly BASE_IMAGE_REGISTRY="${BASE_IMAGE_REGISTRY:-us.gcr.io/k8s-artifacts-prod/build-image}"
readonly RSYNC_PORT="${RSYNC_PORT:-}"
readonly CONTAINER_RSYNC_PORT=8227

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd -P)
readonly LOCAL_OUTPUT_ROOT="${ROOT_DIR}/${OUTPUT_DIR:-_output}"
readonly LOCAL_OUTPUT_SUBPATH="${LOCAL_OUTPUT_ROOT}/platforms"
readonly LOCAL_OUTPUT_BINPATH="${LOCAL_OUTPUT_SUBPATH}"
readonly LOCAL_OUTPUT_GOPATH="${LOCAL_OUTPUT_SUBPATH}/go"
readonly LOCAL_IMAGE_OUTPUT_STAGING="${LOCAL_OUTPUT_ROOT}/images"

source "${ROOT_DIR}/scripts/library/init.sh"

# Get the set of master binaries that run in Docker (on Linux)
# Entry format is "<name-of-binary>,<base-image>".
# Binaries are placed in /usr/local/bin inside the image.
#
# $1 - server architecture
function build::get_docker_wrapped_binaries() {
  local arch=$1
  local debian_base_version=v2.1.0
  local debian_iptables_version=v12.1.0
  ### If you change any of these lists, please also update DOCKERIZED_BINARIES
  ### in build/BUILD. And iam::golang::server_image_targets
  local targets=(
    "iam-apiserver,${IAM_BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "iam-controller-manager,${IAM_BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "iam-scheduler,${IAM_BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "iam-proxy,${IAM_BASE_IMAGE_REGISTRY}/debian-iptables-${arch}:${debian_iptables_version}"
  )

  echo "${targets[@]}"
}

function build::verify_prereqs() {
  local -r require_docker=${1:-true}
  log:status "Verifying Prerequisites..."

}

function build::ensure_tar() {
  if [[ -n "${TAR:-}" ]];then
    return
  fi

  TAR=tar
  if which gtar &>/dev/null; then
    TAR=gtar
  else
    if which gnutar &>/dev/null; then
      TAR=gnutar
    fi
  fi
  
  if ! "${TAR}" --version | grep -q 'tar'; then
    log:error "tar is required to build the release. Please install it."
    return 1
  fi
}