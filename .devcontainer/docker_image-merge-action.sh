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

echo '*** Pulling images to be added to the manifest ***'

CI_REGISTRY_IMAGE_TAGGED="${CI_REGISTRY_IMAGE_TAGGED:-${CI_REGISTRY_IMAGE}/devcontainer:${DOCKER_TAG}}"
for cur_arch in ${TARGET_ARCHITECTURES}; do
  case "${cur_arch}" in
      i386) cur_arch="386" ;;
      i686) cur_arch="386" ;;
      x86_64) cur_arch="amd64" ;;
      #arm) dpkg --print-architecture | grep -q "arm64" && cur_arch="arm64" || cur_arch="arm" ;;
      armv6l) cur_arch="arm/v6" ;;
      armv7l) cur_arch="arm/v7" ;;
      aarch64) cur_arch="arm64" ;;
  esac
  CUR_IMAGE="${CI_REGISTRY_IMAGE_TAGGED}-linux-${cur_arch}"
  echo '  * '"${CUR_IMAGE}"
  docker pull --platform "linux/${cur_arch}" "${CUR_IMAGE}"
  IMAGES_TO_COMBINE+=("${CUR_IMAGE}")
done

echo '*** Dry-run examining new docker manifest with architectures '"${TARGET_ARCHITECTURES}"' for '"${CI_REGISTRY_IMAGE_TAGGED}"' ***'
docker buildx imagetools create \
  --dry-run \
  -t "${CI_REGISTRY_IMAGE_TAGGED}" \
  "${IMAGES_TO_COMBINE[@]}"

echo '*** Creating new docker manifest with architectures '"${TARGET_ARCHITECTURES}"' for '"${CI_REGISTRY_IMAGE_TAGGED}"' ***'
exec docker buildx imagetools create \
  -t "${CI_REGISTRY_IMAGE_TAGGED}" \
  "${IMAGES_TO_COMBINE[@]}"
