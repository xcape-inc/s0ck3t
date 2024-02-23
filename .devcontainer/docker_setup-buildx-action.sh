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

# docker/setup-buildx-action
docker version
docker info
# download buildx
if docker buildx version; then
    echo "** Docker buildx plugin already installed"
else
    echo "** Installing Docker buildx plugin"
    #DOCKER_PLUGIN_PATH=/usr/lib/docker/cli-plugins
    #DOCKER_PLUGIN_PATH=/usr/libexec/docker/cli-plugins
    DOCKER_PLUGIN_PATH=~/.docker/cli-plugins
    mkdir -p "${DOCKER_PLUGIN_PATH}"
    export BUILDX_VERSION=$(curl -fSL https://api.github.com/repos/docker/buildx/releases/latest | grep tag_name | cut -d '"' -f 4)
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
    export BUILDX_ARCH=linux-${architecture}
    export BUILDX_PLUGIN_URI="https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${BUILDX_ARCH}"
    echo "Buildx dl url - ${BUILDX_PLUGIN_URI}"
    curl -fSL "${BUILDX_PLUGIN_URI}" -o "${DOCKER_PLUGIN_PATH}/docker-buildx"
    chmod a+x "${DOCKER_PLUGIN_PATH}/docker-buildx"
fi
docker buildx version

export DOCKER_BUILDER_UUID="$(cat /proc/sys/kernel/random/uuid)"
export BUILDX_BUILDER="${BUILDX_BUILDER:-buildx-builder-${DOCKER_BUILDER_UUID}}"
(docker buildx inspect "${BUILDX_BUILDER}" > /dev/null) || docker buildx create --name "${BUILDX_BUILDER}" ${DOCKER_CONTEXT:-}
docker buildx inspect "${BUILDX_BUILDER}" --bootstrap
if [ 'true' = "${USE_BUILDX_BUILDER:-}" ]; then
  docker buildx use "${BUILDX_BUILDER}"
fi
docker buildx inspect
