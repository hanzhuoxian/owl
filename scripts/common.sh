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
readonly BUILD_IMAGE_VERSION_BASE="${GIT_VERSION}"
readonly BUILD_IMAGE_VERSION="${BUILD_IMAGE_VERSION_BASE}"
readonly DOCKER_REGISTRY="${DOCKER_REGISTRY:-k8s.gcr.io}"
readonly BASE_IMAGE_REGISTRY="${BASE_IMAGE_REGISTRY:-us.gcr.io/k8s-artifacts-prod/build-image}"
readonly RSYNC_PORT="${RSYNC_PORT:-}"
readonly CONTAINER_RSYNC_PORT=8227

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd -P)
readonly LOCAL_OUTPUT_ROOT="${ROOT_DIR}/${OUTPUT_DIR:-_output}"
readonly LOCAL_OUTPUT_SUBPATH="${LOCAL_OUTPUT_ROOT}/platforms"
readonly LOCAL_OUTPUT_BINPATH="${LOCAL_OUTPUT_SUBPATH}"
readonly LOCAL_OUTPUT_GOPATH="${LOCAL_OUTPUT_SUBPATH}/go"
readonly LOCAL_OUTPUT_IMAGE_STAGING="${LOCAL_OUTPUT_ROOT}/images"

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
  ### in build/BUILD. And golang::server_image_targets
  local targets=(
    "apiserver,${BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "controller-manager,${BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "scheduler,${BASE_IMAGE_REGISTRY}/debian-base-${arch}:${debian_base_version}"
    "proxy,${BASE_IMAGE_REGISTRY}/debian-iptables-${arch}:${debian_iptables_version}"
  )

  echo "${targets[@]}"
}

function build::verify_prereqs() {
  local -r require_docker=${1:-true}
  log::status "Build verifying Prerequisites..."
  build::ensure_tar || return 1
  build::ensure_rsync || return 1
  if ${require_docker}; then
    build::ensure_docker || return 1
    util::ensure_docker_daemon_connectivity || return 1

    if ((VERBOSE > 6)); then
      log::status "Docker version:"
      "${DOCKER[@]}" version | log::info_from_stdin
    fi
  fi

  GIT_BRANCH=$(git symbolic-ref --short -q HEAD 2>/dev/null || true)
  ROOT_HASH=$(build::short_hash ${HOSTNAME:-}${ROOT_DIR}${GIT_BRANCH})
  BUILD_IMAGE_TAG_BASE="build-${ROOT_HASH}"
  BUILD_IMAGE_TAG="${BUILD_IMAGE_TAG_BASE}-${BUILD_IMAGE_VERSION}"
  BUILD_IMAGE="${BUILD_IMAGE_REPO}:${BUILD_IMAGE_TAG}"
  BUILD_CONTAINER_NAME_BASE="build-${ROOT_HASH}"
  RSYNC_CONTAINER_NAME_BASE="rsync-${ROOT_HASH}"
  DATA_CONTAINER_NAME_BASE="data-${ROOT_HASH}"
  LOCAL_OUTPUT_BUILD_CONTEXT="${LOCAL_OUTPUT_IMAGE_STAGING}/${BUILD_IMAGE}"
  version::get_version_vars
  version::save_version_vars "${ROOT_DIR}/.dockerized-version-defs"
}

function build::ensure_tar() {
  if [[ -n "${TAR:-}" ]]; then
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

function build::ensure_rsync() {
  if [[ -z "$(which rsync)" ]]; then
    log::error "Can't find 'rsync' in PATH, please fix and retry."
    return 1
  fi
}

function build::ensure_docker() {
  if [[ -z "$(which docker)" ]]; then
    log::error "Can't find 'docker' in PATH, please fix and retry."
    log::error "See https://docs.docker.com/installation/#installation for installation instructions."
    return 1
  fi
}

function build::short_hash() {
  [[ $# -eq 1 ]] || {
    echo "!!! Internal error.  build::short_hash requires exactly 1 argument." >&2
    exit 2
  }

  local short_hash
  if which md5 >/dev/null 2>&1; then
    short_hash=$(md5 -q -s "$1")
  else
    short_hash=$(echo -n "$1" | md5sum)
  fi
  echo "${short_hash:0:10}"
}

function build::build_image() {
  mkdir -p "${LOCAL_OUTPUT_BUILD_CONTEXT}"
  chown -R "${USER_ID}:${GROUP_ID}" "${LOCAL_OUTPUT_BUILD_CONTEXT}"
  cp /etc/localtime "${LOCAL_OUTPUT_BUILD_CONTEXT}/"

  cp "${ROOT}/build/build-image/Dockerfile" "${LOCAL_OUTPUT_BUILD_CONTEXT}/Dockerfile"
  cp "${ROOT}/build/build-image/rsyncd.sh" "${LOCAL_OUTPUT_BUILD_CONTEXT}/"

  dd if=/dev/urandom bs=512 count=1 2>/dev/null | LC_ALL=C tr -dc 'A-Za-z0-9' | dd bs=32 count=1 2>/dev/null >"${LOCAL_OUTPUT_BUILD_CONTEXT}/rsyncd.password"
  chmod go= "${LOCAL_OUTPUT_BUILD_CONTEXT}/rsyncd.password"

  build::update_dockerfile
  build::set_proxy
  build::docker_build "${BUILD_IMAGE}" "${LOCAL_OUTPUT_BUILD_CONTEXT}" 'false'
  build::clean
  build::ensure_data_container
}

function build::ensure_data_container() {
  # If the data container exists AND exited successfully, we can use it.
  # Otherwise nuke it and start over.
  local ret=0
  local code=0

  code=$(docker inspect \
      -f '{{.State.ExitCode}}' \
      "${DATA_CONTAINER_NAME}" 2>/dev/null) || ret=$?
  if [[ "${ret}" == 0 && "${code}" != 0 ]]; then
    build::destroy_container "${DATA_CONTAINER_NAME}"
    ret=1
  fi
  if [[ "${ret}" != 0 ]]; then
    log::status "Creating data container ${DATA_CONTAINER_NAME}"
    # We have to ensure the directory exists, or else the docker run will
    # create it as root.
    mkdir -p "${LOCAL_OUTPUT_GOPATH}"
    # We want this to run as root to be able to chown, so non-root users can
    # later use the result as a data container.  This run both creates the data
    # container and chowns the GOPATH.
    #
    # The data container creates volumes for all of the directories that store
    # intermediates for the Go build. This enables incremental builds across
    # Docker sessions. The *_cgo paths are re-compiled versions of the go std
    # libraries for true static building.
    local -ra docker_cmd=(
      "${DOCKER[@]}" run
      --volume "${REMOTE_ROOT}"   # white-out the whole output dir
      --volume /usr/local/go/pkg/linux_386_cgo
      --volume /usr/local/go/pkg/linux_amd64_cgo
      --volume /usr/local/go/pkg/linux_arm_cgo
      --volume /usr/local/go/pkg/linux_arm64_cgo
      --volume /usr/local/go/pkg/linux_ppc64le_cgo
      --volume /usr/local/go/pkg/darwin_amd64_cgo
      --volume /usr/local/go/pkg/darwin_386_cgo
      --volume /usr/local/go/pkg/windows_amd64_cgo
      --volume /usr/local/go/pkg/windows_386_cgo
      --name "${DATA_CONTAINER_NAME}"
      --hostname "${HOSTNAME}"
      "${BUILD_IMAGE}"
      chown -R "${USER_ID}":"${GROUP_ID}"
        "${REMOTE_ROOT}"
        /usr/local/go/pkg/
    )
    "${docker_cmd[@]}"
  fi
}

function build::docker_build() {
  local -r image=$1
  local -r context_dir=$2
  local -r pull=${3:-true}
  local -ra build_cmd=("${DOCKER[@]}" build -t "${image}" "--pull=${pull}" "${context_dir}")

  log::status "Building Docker image ${image}"
  local docker_output
  docker_output=$("${build_cmd[@]}" 2>&1) || {
    cat <<EOF >&2
+++ Docker build command failed for ${image}

${docker_output}

To retry manually, run:

${build_cmd[*]}

EOF
    return 1

  }
}

function build::has_docker() {
  which docker &>/dev/null
}

function build::clean() {
  if build::has_docker; then
    build::docker_delete_old_containers "${BUILD_CONTAINER_NAME_BASE}"
    build::docker_delete_old_containers "${RSYNC_CONTAINER_NAME_BASE}"
    build::docker_delete_old_containers "${DATA_CONTAINER_NAME_BASE}"
    build::docker_delete_old_images "${BUILD_IMAGE_REPO}" "${BUILD_IMAGE_TAG_BASE}"
    V=2 log::status "Cleaning all untagged docker images"
    "${DOCKER[@]}" rmi $("${DOCKER[@]}" images -q --filter "dangling=true") 2>/dev/null || true
  fi

  if [[ -d "${LOCAL_OUTPUT_ROOT}" ]]; then
    log::status "Cleaning up ${LOCAL_OUTPUT_ROOT}"
    rm -rf "${LOCAL_OUTPUT_ROOT}"
  fi
}

function build::docker_delete_old_containers() {
  for container in $("${DOCKER[@]}" ps -a | tail -n +2 | awk '{print $NF}'); do
    if [[ "${container}" != "${1}"* ]]; then
      V=3 log::status "keeping container ${container}"
      continue
    fi
    if [[ -z "${2:-}" || "${container}" == "${2}" ]]; then
      V=2 log::status "Removing container ${container}"
      build::destroy_container "${container}"
    fi
  done
}

function build::destroy_container() {
  "${DOCKER[@]}" kill "$1" >/dev/null 2>&1 || true
  "${DOCKER[@]}" wait "$1" >/dev/null 2>&1 || true
  "${DOCKER[@]}" rm -f -v "$1" >/dev/null 2>&1 || true
}

# Delete all images that match a tag prefix except for the "current" version
#
# $1: The image repo/name
# $2: The tag base. We consider any image that matches $2*
# $3: The current image not to delete if provided
function build::docker_delete_old_images() {
  # In Docker 1.12, we can replace this with
  #    docker images "$1" --format "{{.Tag}}"
  for tag in $("${DOCKER[@]}" images "${1}" | tail -n +2 | awk '{print $2}'); do
    if [[ "${tag}" != "${2}"* ]]; then
      V=3 log::status "Keeping image ${1}:${tag}"
      continue
    fi

    if [[ -z "${3:-}" || "${tag}" != "${3}" ]]; then
      V=2 log::status "Deleting image ${1}:${tag}"
      "${DOCKER[@]}" rmi "${1}:${tag}" >/dev/null
    else
      V=3 log::status "Keeping image ${1}:${tag}"
    fi
  done
}

function build::update_dockerfile() {
  if build::is_gnu_sed; then
    sed_opts=(-i)
  else
    sed_opts=(-i '')
  fi
  sed "${sed_opts[@]}" "s/BUILD_IMAGE_CROSS_TAG/${BUILD_IMAGE_CROSS_TAG}/" "${LOCAL_OUTPUT_BUILD_CONTEXT}/Dockerfile"
}

function build::is_gnu_sed() {
  [[ $(sed --version 2>&1) == *GNU* ]]
}

function build::set_proxy() {
  if [[ -n "${RNETES_HTTPS_PROXY:-}" ]]; then
    echo "ENV https_proxy $RNETES_HTTPS_PROXY" >>"${LOCAL_OUTPUT_BUILD_CONTEXT}/Dockerfile"
  fi
  if [[ -n "${RNETES_HTTP_PROXY:-}" ]]; then
    echo "ENV http_proxy $RNETES_HTTP_PROXY" >>"${LOCAL_OUTPUT_BUILD_CONTEXT}/Dockerfile"
  fi
  if [[ -n "${RNETES_NO_PROXY:-}" ]]; then
    echo "ENV no_proxy $RNETES_NO_PROXY" >>"${LOCAL_OUTPUT_BUILD_CONTEXT}/Dockerfile"
  fi
}


function build::build_command() {
  log::status "Running build command..."
  make -C "${ROOT_PATH}" build.multiarch BINS="owl-apiserver owlctl"
}