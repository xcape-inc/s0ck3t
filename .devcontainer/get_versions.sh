#!/bin/sh
set -e

SCRIPT_PATH=$0
ORIG_DIR=$(pwd)

if [ "$OSTYPE" = "darwin"* ]; then
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

if [ ! -e '.git/ci-tools' ]; then
  git clone https://github.com/xcape-inc/ci-tools.git --branch main --single-branch .git/ci-tools
fi
bash -c '. .git/ci-tools/get_tag_from_git.sh > /dev/null; echo "#!/bin/sh" && echo "export CUR_VERSION=${CUR_VERSION}" && echo "export LONG_FORM_CUR_VERSION=${LONG_FORM_CUR_VERSION}"' > /tmp/tags_from_git
chmod +x /tmp/tags_from_git
cat /tmp/tags_from_git
. /tmp/tags_from_git
rm /tmp/tags_from_git
export BUILD_VER=$(printf '%s' "${CUR_VERSION}" | sed "s/^v\\([0-9.]*\\)\\(.*\\)/\\1-\\2/" | sed "s/\\(\\.*\\)-\$//")

# TODO: set the tag or branch stuff if we are doing a local build
if [ 'true' = "${LOCAL_BUILD:-}" ]; then
  PATTERN_MATCHED=$(printf '%s' "${BUILD_VER}" | sed -En "s/^([0-9]+\\.[0-9]+\\.[0-9]+)?.*\$/\\1/p")
  if [ "${BUILD_VER}" = "${PATTERN_MATCHED}" ]; then
    CI_COMMIT_TAG="${CUR_VERSION}"
  fi
  CI_COMMIT_BRANCH=$(git branch --show-current)
fi
##########

# Set the git ref
if [ -n "${CI_COMMIT_BRANCH:-}" ]; then
  CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME:-${CI_COMMIT_BRANCH}}"
  export GIT_REF='ref/heads/'"${CI_COMMIT_REF_NAME}"
  if [ 'true' != "${LOCAL_BUILD:-}" ]; then
    git checkout "${CI_COMMIT_REF_NAME}"
  fi
elif [ -n "${CI_COMMIT_TAG:-}" ]; then
  CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME:-${CI_COMMIT_TAG}}"
  export GIT_REF='ref/tags/'"${CI_COMMIT_REF_NAME}"
fi

# display the detected version info
echo 'Short version:'" ${CUR_VERSION}"
echo 'Long version:'" ${LONG_FORM_CUR_VERSION}"
echo 'Build version:'" ${BUILD_VER}"
echo 'Git ref:'" ${GIT_REF}"
