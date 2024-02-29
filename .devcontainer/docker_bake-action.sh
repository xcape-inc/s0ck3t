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

architecture=$(uname -m)
case "${architecture}" in
    i386) architecture="386" ;;
    i686) architecture="386" ;;
    x86_64) architecture="amd64" ;;
    #arm) dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
    armv6l) architecture="arm/v6" ;;
    armv7l) architecture="arm/v7" ;;
    aarch64) architecture="arm64" ;;
esac

PLATFORM_ARCH=${PLATFORM_ARCH:-${architecture}}
case "${PLATFORM_ARCH}" in
    i386) PLATFORM_ARCH="386" ;;
    i686) PLATFORM_ARCH="386" ;;
    x86_64) PLATFORM_ARCH="amd64" ;;
    #arm) dpkg --print-architecture | grep -q "arm64" && PLATFORM_ARCH="arm64" || PLATFORM_ARCH="arm" ;;
    armv6l) PLATFORM_ARCH="arm/v6" ;;
    armv7l) PLATFORM_ARCH="arm/v7" ;;
    aarch64) PLATFORM_ARCH="arm64" ;;
esac

# Optionally install qemu with the target arch if it doesnt match the machine arch
if [ "${architecture}" != "${PLATFORM_ARCH}" ]; then
  PLATFORM_ARCH=${PLATFORM_ARCH} .devcontainer/docker_setup-qemu-action.sh
fi

DOCKER_SERVICES=( ${DOCKER_SERVICES:-${CI_PROJECT_NAME}} )
DOCKER_SERVICE_COUNT=${#DOCKER_SERVICES[@]}
if [ 1 -le "${DOCKER_SERVICE_COUNT}" ]; then
  echo "** Build kit progress set to plain for single image generation"
  BUILDKIT_PROGRESS_FLAG=plain
else
  echo "** Build kit progress left as default due to multiple image generation"
fi

for cur_service in "${DOCKER_SERVICES[@]}"; do
  DOCKER_SERVICES_W_META+=("${cur_service}-with-metadata")
done

if [ 'true' = "${PULL_IMAGES:-}" ]; then
  PULL_FLAG='--pull'
fi

if [ 'true' = "${PUSH_IMAGE:-}" ]; then
  # Note: the annotation-index entries are only for multi-arch manifests
  OUTPUT_SETTINGS="--set "'*'".output=type=registry,annotation-manifest-descriptor.org.opencontainers.image.title=${CI_PROJECT_NAME},annotation-manifest-descriptor.org.opencontainers.image.description=${CI_PROJECT_DESCRIPTION},annotation.org.opencontainers.image.title=${CI_PROJECT_NAME},annotation.org.opencontainers.image.description=${CI_PROJECT_DESCRIPTION}" #,annotation-index.org.opencontainers.image.title=${CI_PROJECT_NAME},annotation-index.org.opencontainers.image.description=${CI_PROJECT_DESCRIPTION}"
  if [ 'true' = "${SET_PROVENANCE:-}" ]; then
    PROVENANCE_FLAG="--provenance mode=min,inline-only=true,builder-id=${CI_RUNNER_ID}"
  else
    PROVENANCE_FLAG="--provenance=false"
  fi
else
  OUTPUT_SETTINGS="--load"
fi

if [ 'true' = "${PUSH_BUILD_CACHE:-}" ]; then
  PUSH_CACHE_FLAG="--set "'*'".cache-to=type=registry,ref=${CI_REGISTRY_IMAGE}/devcontainer:cache-linux-${PLATFORM_ARCH},mode=max"
fi

ARCH_FLAG="--set "'*'".platform=linux/${PLATFORM_ARCH}"
cd "${SCRIPT_DIR}"
# TODO: may have to make the .hcl target dynamically generate so container names in docker-compose match
# TODO: need to build everything in parallel for multiple images (local builds need that, though ci does not. how would you store on github though?)
BUILDKIT_PROGRESS=${BUILDKIT_PROGRESS_FLAG:-} VERSION="${CUR_VERSION}" LONG_FORM_VERSION="${LONG_FORM_CUR_VERSION}" docker buildx bake --file *bake.metadata-merger.hcl --file docker-compose.yml --file docker-compose.build.yml --file *docker-metadata-action-bake.json ${PUSH_CACHE_FLAG:-} ${ARCH_FLAG} ${OUTPUT_SETTINGS:-} --metadata-file metadata-file ${PROVENANCE_FLAG:-} ${PULL_FLAG:-} --print ${DOCKER_SERVICES_W_META[*]}
BUILDKIT_PROGRESS=${BUILDKIT_PROGRESS_FLAG:-} VERSION="${CUR_VERSION}" LONG_FORM_VERSION="${LONG_FORM_CUR_VERSION}" docker buildx bake --file *bake.metadata-merger.hcl --file docker-compose.yml --file docker-compose.build.yml --file *docker-metadata-action-bake.json ${PUSH_CACHE_FLAG:-} ${ARCH_FLAG} ${OUTPUT_SETTINGS:-} --metadata-file metadata-file ${PROVENANCE_FLAG:-} ${PULL_FLAG:-} ${DOCKER_SERVICES_W_META[*]}
