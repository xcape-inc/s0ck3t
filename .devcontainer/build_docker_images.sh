#!/bin/bash
if [[ 'true' != "${SOURCING}" ]]; then
  set -e
  trap 'catch $? $LINENO' ERR
  catch() {
    echo "Error $1 occurred on $2" >&2
  }
  set -euo pipefail
else
  echo "SOURCING"
fi

SCRIPT_PATH=$0
ORIG_DIR=$(pwd)

if [[ "$OSTYPE" == "darwin"* ]]; then
  # MacOS equivalent of readlink -f

  cd $(dirname "${SCRIPT_PATH}")
  SCRIPT_BASE_NAME=$(basename "${SCRIPT_PATH}")

  # Iterate down a (possible) chain of symlinks
  CUR_TARGET=${SCRIPT_BASE_NAME}
  while [ -L "${SCRIPT_BASE_NAME}" ]
  do
      CUR_TARGET=$(readlink "${CUR_TARGET}")
      cd $(dirname "${CUR_TARGET}")
      CUR_TARGET=$(basename "${CUR_TARGET}")
  done

  # Compute the canonicalized name by finding the physical path 
  # for the directory we're in and appending the target file.
  SCRIPT_DIR=$(pwd -P)
  REAL_SCRIPT_PATH="${SCRIPT_DIR}/${CUR_TARGET}"
  cd "${ORIG_DIR}"
else
  REAL_SCRIPT_PATH=$(readlink -f "${SCRIPT_PATH}")
  SCRIPT_DIR=$(dirname "${REAL_SCRIPT_PATH}")
fi

# TODO: add a mechanism to skip rebuilding when all we wanted was a startup
#if [[ 'true' = "${LOCAL_BUILD:-}" && some_command_that_finds_the_instance_of_the_dev_container ]]
#  echo "Skipping rebuild as the container already exists"
#else
  # Set the variables that would be avaiilable to CI if we are on local
  if [ 'true' = "${LOCAL_BUILD:-}" ]; then
      . "${SCRIPT_DIR}"/get_versions.sh
      export CI_PROJECT_NAMESPACE=xcape-inc
      export CI_PROJECT_NAME=s0ck3t
      export CI_PROJECT_DESCRIPTION=""
      export CI_PROJECT_URL="https://github.com/${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}.git"
      export CI_COMMIT_REF_SLUG=local
      export CI_COMMIT_SHA="$(git log --pretty=format:'%H' -n 1)"
      export CI_COMMIT_BRANCH=$(git branch --show-current)
      export CI_REGISTRY_IMAGE=ghcr.io/${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME} 
      export CI_COMMIT_REF_NAME=$(git branch --show-current)
      export BUILDX_BUILDER=buildx-builder
      export CI_RUNNER_ID=localhost
      echo "CI_REGISTRY_IMAGE=${CI_REGISTRY_IMAGE}" > "${SCRIPT_DIR}"/.env
  else
    > "${SCRIPT_DIR}"/.env
  fi
  echo "DOCKER_TAG=${DOCKER_TAG:-${CI_COMMIT_REF_SLUG}}" >> "${SCRIPT_DIR}"/.env

  "${SCRIPT_DIR}"/docker_setup-buildx-action.sh

  DOCKER_SERVICES=( ${DOCKER_SERVICES:-${CI_PROJECT_NAME}} )

  for cur_service in "${DOCKER_SERVICES[@]}"; do
    if [ 'true' = "${LOCAL_BUILD:-}" ]; then
        export TAGS='"'"${CI_REGISTRY_IMAGE}/devcontainer"':local"'
    fi
    DOCKER_SERVICE="${cur_service}" "${SCRIPT_DIR}"/docker_metadata-action.sh
  done

  PLATFORM_ARCH=${PLATFORM_ARCH:-$(uname -m)}
  case "${PLATFORM_ARCH}" in
      i386) PLATFORM_ARCH="386" ;;
      i686) PLATFORM_ARCH="386" ;;
      x86_64) PLATFORM_ARCH="amd64" ;;
      #arm) dpkg --print-architecture | grep -q "arm64" && PLATFORM_ARCH="arm64" || PLATFORM_ARCH="arm" ;;
      armv6l) PLATFORM_ARCH="arm/v6" ;;
      armv7l) PLATFORM_ARCH="arm/v7" ;;
      aarch64) PLATFORM_ARCH="arm64" ;;
  esac

  "${SCRIPT_DIR}"/fix_copied_file_permissions.sh

  # TODO: capture the old image hash; force delete it after success to clean up cruft
  DOCKER_SERVICES="${DOCKER_SERVICES[*]}" PLATFORM_ARCH=${PLATFORM_ARCH} "${SCRIPT_DIR}"/docker_bake-action.sh
#fi
