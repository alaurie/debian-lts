#!/usr/bin/env bash
# scripts/check-upstream.sh: Track and compare upstream Linux 6.18 LTS releases.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${ROOT_DIR}/src/linux-6.18"

SHOW_SUMMARY=0
OUTPUT_JSON=0

while [ $# -gt 0 ]; do
    case "$1" in
        --summary) SHOW_SUMMARY=1; shift ;;
        --json)    OUTPUT_JSON=1; shift ;;
        *)         shift ;;
    esac
done

# 1. Fetch upstream data from canonical kernel.org API
API_URL="https://www.kernel.org/releases.json"
RELEASE_DATA=$(curl -s --connect-timeout 10 "${API_URL}")

UPSTREAM_VER=$(echo "${RELEASE_DATA}" | jq -r '.releases[] | select(.version | startswith("6.18.")) | .version')
RELEASE_DATE=$(echo "${RELEASE_DATA}" | jq -r '.releases[] | select(.version | startswith("6.18.")) | .released.isodate')
CHANGELOG_URL=$(echo "${RELEASE_DATA}" | jq -r '.releases[] | select(.version | startswith("6.18.")) | .changelog')
DIFF_URL=$(echo "${RELEASE_DATA}" | jq -r '.releases[] | select(.version | startswith("6.18.")) | .diffview')

if [ -z "${UPSTREAM_VER}" ] || [ "${UPSTREAM_VER}" = "null" ]; then
    echo "ERROR: Unable to locate 6.18 series in kernel.org releases.json" >&2
    exit 2
fi

# 2. Determine local version
LOCAL_VER="none"
if [ -f "${TARGET_DIR}/Makefile" ]; then
    K_VER=$(grep -E "^VERSION =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
    K_PATCH=$(grep -E "^PATCHLEVEL =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
    K_SUB=$(grep -E "^SUBLEVEL =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
    LOCAL_VER="${K_VER}.${K_PATCH}.${K_SUB}"
elif compgen -G "${ROOT_DIR}/dist/linux-image-6.18.*.deb" >/dev/null; then
    LATEST_DEB=$(ls -v "${ROOT_DIR}/dist"/linux-image-6.18.*.deb | tail -n1)
    LOCAL_VER=$(basename "${LATEST_DEB}" | sed -E 's/linux-image-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

# 3. Output logic
if [ "${OUTPUT_JSON}" -eq 1 ]; then
    jq -n \
      --arg local "${LOCAL_VER}" \
      --arg upstream "${UPSTREAM_VER}" \
      --arg date "${RELEASE_DATE}" \
      --arg changelog "${CHANGELOG_URL}" \
      --arg diff "${DIFF_URL}" \
      --arg update_available "$([ "${LOCAL_VER}" != "${UPSTREAM_VER}" ] && echo true || echo false)" \
      '{local: $local, upstream: $upstream, released: $date, update_available: ($update_available == "true"), changelog: $changelog, diffview: $diff}'
    exit 0
fi

echo "================================================="
echo " Linux 6.18 LTS Upstream Tracking"
echo "================================================="
echo "Local Version:    ${LOCAL_VER}"
echo "Upstream Version: ${UPSTREAM_VER} (Released: ${RELEASE_DATE})"
echo "Changelog URL:    ${CHANGELOG_URL}"
echo "Diffview URL:     ${DIFF_URL}"
echo "================================================="

if [ "${LOCAL_VER}" = "${UPSTREAM_VER}" ]; then
    echo "==> Up to date: Local version matches latest upstream release."
    exit 0
else
    echo "==> UPDATE AVAILABLE: ${LOCAL_VER} -> ${UPSTREAM_VER}"
    if [ "${SHOW_SUMMARY}" -eq 1 ] && [ -n "${CHANGELOG_URL}" ]; then
        echo ""
        echo "--- Changelog Highlights for ${UPSTREAM_VER} ---"
        curl -s --connect-timeout 10 "${CHANGELOG_URL}" | head -n 35 || true
        echo "..."
    fi
    exit 1
fi
