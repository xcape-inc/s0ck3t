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

if [ 'false' = "${DO_IMAGE_BUILD:-}" ]; then
  :;
else
  cp -a "${SCRIPT_DIR}"/../go.mod "${SCRIPT_DIR}"/../go.sum "${SCRIPT_DIR}"/
  DOCKER_SERVICES="devcontainer" LOCAL_BUILD=true "${SCRIPT_DIR}"/build_docker_images.sh
fi

mkdir -p ~/.ssh
mkdir -p ~/.github
pwd

if [ ! -e ~/.github/github_credentials ]; then
  cp github_credentials ~/.github/github_credentials
fi
