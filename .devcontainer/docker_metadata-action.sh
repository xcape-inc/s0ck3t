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

rm -f "${SCRIPT_DIR}"/*bake.metadata-merger.hcl
rm -f "${SCRIPT_DIR}"/*docker-metadata-action-bake.json
if [ -z "${DOCKER_SERVICE:-}" ]; then
  (echo "DOCKER_SERVICE is required" >&2) && false
else
  DOCKER_SERVICE_PREFIX="${DOCKER_SERVICE}-"
  DOCKER_SERVICE_POSTFIX="/${DOCKER_SERVICE}"

  # create metadata file from template using docker_service value
  sed "s/\"app/\"${DOCKER_SERVICE}/g" "${SCRIPT_DIR}"/bake.metadata-merger.hcl.template > "${SCRIPT_DIR}"/${DOCKER_SERVICE_PREFIX}bake.metadata-merger.hcl
  #"app
fi
echo '{
    "target": {
        "'"${DOCKER_SERVICE_PREFIX:-}"'docker-metadata-action": {
            "tags": [],
            "labels": {
                "org.opencontainers.image.title": "'"${CI_PROJECT_NAME}"'",
                "org.opencontainers.image.description": "'"${CI_PROJECT_DESCRIPTION}"'",
                "org.opencontainers.image.url": "'"${CI_PROJECT_URL}"'",
                "org.opencontainers.image.source": "'"${CI_PROJECT_URL}"'",
                "org.opencontainers.image.version": "'"${CI_COMMIT_REF_SLUG}"'",
                "org.opencontainers.image.created": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
                "org.opencontainers.image.revision": "'"${CI_COMMIT_SHA}"'",
                "org.opencontainers.image.ref.name": "'"${GIT_REF}"'"
            },
            "args": {
                "DOCKER_META_IMAGES": "'"${CI_REGISTRY_IMAGE}${DOCKER_SERVICE_POSTFIX}"'",
                "DOCKER_META_VERSION": "'"${CI_COMMIT_REF_SLUG}"'"
            }
        }
    }
}' >> "${SCRIPT_DIR}"/${DOCKER_SERVICE_PREFIX:-}docker-metadata-action-bake.json

# Add tags if we have any
if [ -n "${TAGS:-}" ]; then
    sed -i.bak -e  's|"tags": '"\\"'['"\\"'],|"tags": ['"\\"'n                "'"${TAGS}"'"'"\\"'n            ],|' "${SCRIPT_DIR}"/${DOCKER_SERVICE_PREFIX:-}docker-metadata-action-bake.json
    rm -f "${SCRIPT_DIR}"/${DOCKER_SERVICE_PREFIX:-}docker-metadata-action-bake.json.bak
fi

cat "${SCRIPT_DIR}"/${DOCKER_SERVICE_PREFIX:-}docker-metadata-action-bake.json
