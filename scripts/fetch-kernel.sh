#!/usr/bin/env bash
# scripts/fetch-kernel.sh: Fetch upstream linux-6.18.y stable branch.
set -euo pipefail

REPO_URL="${REPO_URL:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
BRANCH="${BRANCH:-linux-6.18.y}"
TARGET_DIR="${TARGET_DIR:-src/linux-6.18}"
TAG="${TAG:-}"

mkdir -p "$(dirname "${TARGET_DIR}")"

if [ -d "${TARGET_DIR}/.git" ]; then
    echo "==> Existing repository found at ${TARGET_DIR}. Updating remote refs..."
    git -C "${TARGET_DIR}" remote set-url origin "${REPO_URL}"
    git -C "${TARGET_DIR}" fetch --tags origin "${BRANCH}"
else
    echo "==> Cloning branch ${BRANCH} from ${REPO_URL} into ${TARGET_DIR}..."
    if [ -n "${TAG}" ]; then
        git clone --depth 1 --branch "${TAG}" "${REPO_URL}" "${TARGET_DIR}"
    else
        git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TARGET_DIR}"
    fi
fi

if [ -n "${TAG}" ]; then
    echo "==> Checking out tag ${TAG}..."
    git -C "${TARGET_DIR}" checkout "tags/${TAG}"
else
    echo "==> Checking out latest tip of ${BRANCH}..."
    git -C "${TARGET_DIR}" checkout "${BRANCH}"
    git -C "${TARGET_DIR}" pull --ff-only origin "${BRANCH}" || true
fi

CURRENT_VER=$(git -C "${TARGET_DIR}" describe --tags --always)
echo "==> Ready. Source tree is at ${CURRENT_VER} in ${TARGET_DIR}"
