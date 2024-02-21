#!/usr/bin/env bash

# This is where the final release artifacts are created locally
readonly RELEASE_STAGE="${LOCAL_OUTPUT_ROOT}/release-stage"
readonly RELEASE_TARS="${LOCAL_OUTPUT_ROOT}/release-tars"
readonly RELEASE_IMAGES="${LOCAL_OUTPUT_ROOT}/release-images"

# github account info
readonly GITHUB_ORG=hanzhuoxian
readonly GITHUB_REPO=owl

# The version of the release
readonly ARTIFACT="${GITHUB_REPO}".tar.gz
readonly CHECKSUM=${ARTIFACT}.sha1sum

BUILD_CONFORMANCE=${BUILD_CONFORMANCE:-y}
BUILD_PULL_LATEST_IMAGES=${BUILD_PULL_LATEST_IMAGES:-y}

# Parse and validate the ci version
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

# ---------------------------------------------------------------------------
# Build src artifacts
function release::package_src_tarballs() {
  local -r src_tarball="${RELEASE_TARS}/${ARTIFACT}"
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

function release::package_tarballs() {
  rm -rf "${RELEASE_STAGE}" "${RELEASE_TARS}" "${RELEASE_IMAGES}" || true
  mkdir -p "${RELEASE_STAGE}" "${RELEASE_TARS}" "${RELEASE_IMAGES}" || true
  release::package_src_tarballs &
  release::package_client_tarballs &
  # release::package_manifests_tarballs &
  release::package_server_tarballs &

  util::wait-for-jobs || {
    log::error "previous tarball phase failed"
    return 1
  }

  release::package_final_tarballs &
  util::wait-for-jobs || {
    log::error "previous tarball phase failed"
    return 1
  }
}

function release::package_final_tarballs() {
  log::status "Building tarball: final tarballs"
}

function release::verify_prereqs() {
  log::status "Release verifying Prerequisites..."
  if [ -z "$(which github-release 2>/dev/null)" ]; then
    log::info "'github-release' tool not installed, try to install it."

    if ! release::install_github_release; then
      log::error "failed to install 'github-release'"
      return 1
    fi
  fi

  if [ -z "$(which git-chglog 2>/dev/null)" ]; then
    log::info "'git-chglog' tool not installed, try to install it."

    if ! go install github.com/git-chglog/git-chglog/cmd/git-chglog@latest &>/dev/null; then
      log::error "failed to install 'git-chglog'"
      return 1
    fi
  fi

  if [ -z "$(which gsemver 2>/dev/null)" ]; then
    log::info "'gsemver' tool not installed, try to install it."

    if ! go install github.com/arnaud-deprez/gsemver@latest &>/dev/null; then
      log::error "failed to install 'gsemver'"
      return 1
    fi
  fi
}

function release::package_client_tarballs() {
  local long_platforms=("${LOCAL_OUTPUT_BINPATH}"/*/*)
  if [[ -n ${BUILD_PLATFORMS-} ]]; then
    read -ra long_platforms <<<"${BUILD_PLATFORMS}"
  fi

  for p in "${long_platforms[@]}"; do
    local platform
    local platform_tag
    platform=${p##"${LOCAL_OUTPUT_BINPATH}"/}
    platform_tag=${platform//\//-}
    log::status "Starting tarball: client for ${platform_tag}"

    (
      local release_stage="${RELEASE_STAGE}/client/${platform_tag}"
      rm -rf "${release_stage}"
      mkdir -p "${release_stage}/client/bin" "${RELEASE_TARS}"

      local client_bins=("${CLIENT_BINARIES[@]}")
      cp "${client_bins[@]/#/${LOCAL_OUTPUT_BINPATH}/${platform}/}" \
        "${release_stage}/client/bin/"
      release::clean_cruft

      local package_name="${RELEASE_TARS}/${GITHUB_REPO}-client-${platform_tag}.tar.gz"
      release::create_tarball "${package_name}" "${release_stage}/client/bin/"
    ) &

  done
}

function release::create_tarball() {
  build::ensure_tar

  local tarfile=$1
  local stagingdir=$2

  "${TAR}" -czf "${tarfile}" -C "${stagingdir}" . --owner=0 --group=0

}

function release::package_manifests_tarballs() {
  log::status "Building tarball: manifests"

  local src_dir="${ROOT_PATH}/deployments"
  local release_stage="${RELEASE_STAGE}/manifests"
  rm -rf "${release_stage}"
  local dst_dir="${release_stage}"
  mkdir -p "${dst_dir}"
  cp -r "${src_dir}/*" "${dst_dir}"

  release::clean_cruft
  local package_name="${RELEASE_TARS}/manifests.tar.gz"
  release::create_tarball "${package_name}" "${release_stage}/.."
}

function release::package_server_tarballs() {
  local long_platforms=("${LOCAL_OUTPUT_BINPATH}"/*/*)
  if [[ -n ${BUILD_PLATFORMS-} ]]; then
    read -ra long_platforms <<<"${BUILD_PLATFORMS}"
  fi

  for p in "${long_platforms[@]}"; do
    local platform
    local platform_tag
    platform=${p##"${LOCAL_OUTPUT_BINPATH}"/}
    platform_tag=${platform/\//-}
    log::status "Starting tarball: server for ${platform_tag}"
    (
      local release_stage="${RELEASE_STAGE}/server/${platform_tag}"
      rm -rf "${release_stage}"
      mkdir -p "${release_stage}/server/bin"
      local server_bins=("${SERVER_BINARIES[@]}")
      cp "${server_bins[@]/#/${LOCAL_OUTPUT_BINPATH}/${platform}/}" \
        "${release_stage}/server/bin/"

      release::clean_cruft
      local package_name="${RELEASE_TARS}/${GITHUB_REPO}-server-${platform_tag}.tar.gz"
      release::create_tarball "${package_name}" "${release_stage}/server/bin/"
    ) &
  done
}

function release::github_release() {
  log::info "Create a new github release with tag ${GIT_VERSION}"
  github-release release \
    --user "${GITHUB_ORG}" \
    --repo "${GITHUB_REPO}" \
    --tag "${GIT_VERSION}" \
    --description "" \
    --pre-release

  log::info "upload ${ARTIFACT} to release ${GIT_VERSION}"
  github-release upload \
    --user "${GITHUB_ORG}" \
    --repo "${GITHUB_REPO}" \
    --tag "${GIT_VERSION}" \
    --name "${ARTIFACT}" \
    --file "${RELEASE_TARS}/${ARTIFACT}"

  log::info "upload ${GITHUB_REPO}-src.tar.gz to release ${GIT_VERSION}"
  github-release upload \
    --user "${GITHUB_ORG}" \
    --repo "${GITHUB_REPO}" \
    --tag "${GIT_VERSION}" \
    --name "${GITHUB_REPO}-src.tar.gz" \
    --file "${RELEASE_TARS}/${GITHUB_REPO}-src.tar.gz"
}

function release::generate_changelog() {
  log::info "generate CHANGELOG-${GIT_VERSION#v}.md and commit it"
  cd "${ROOT_PATH}"
  echo  "${ROOT_PATH}"/CHANGELOG/CHANGELOG-"${GIT_VERSION#v}".md
  git-chglog "${GIT_VERSION}" > "${ROOT_PATH}"/CHANGELOG/CHANGELOG-"${GIT_VERSION#v}".md

  set +o errexit
  git add "${ROOT_PATH}"/CHANGELOG/CHANGELOG-"${GIT_VERSION#v}".md
  git commit -a -m "docs(changelog): add CHANGELOG-"${GIT_VERSION#v}".md"
  git push -f origin main
}

function release::install_github_release() {
  GO111MODULE=on go install github.com/github-release/github-release@latest
}
