#!/usr/bin/env bash
# scripts/build-metapackage.sh: Build rolling metapackages tracking latest 6.18 LTS kernel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KVER="${1:-}"
DEB_REVISION="${2:-1~deb13}"
DIST_DIR="${ROOT_DIR}/dist"

if [ -z "${KVER}" ]; then
    echo "Usage: $0 <kernel-version-with-localversion> [deb-revision]" >&2
    echo "Example: $0 6.18.20-lts 1~deb13" >&2
    exit 1
fi

TMP_BUILD=$(mktemp -d)
trap 'rm -rf "${TMP_BUILD}"' EXIT

mkdir -p "${DIST_DIR}"

build_meta() {
    local PKG_NAME="$1"
    local TARGET_DEP="$2"
    local DESC="$3"
    local WORK_DIR="${TMP_BUILD}/${PKG_NAME}"

    mkdir -p "${WORK_DIR}/DEBIAN"
    cat <<EOF > "${WORK_DIR}/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${KVER}-${DEB_REVISION}
Section: kernel
Priority: optional
Architecture: amd64
Depends: ${TARGET_DEP} (= ${KVER}-${DEB_REVISION})
Maintainer: Debian LTS Kernel Project <debian-lts@local>
Description: ${DESC}
 This metapackage ensures the system always runs the latest point release
 of the 6.18 LTS kernel branch on Debian stable.
EOF

    dpkg-deb --build --root-owner-group "${WORK_DIR}" "${DIST_DIR}/${PKG_NAME}_${KVER}-${DEB_REVISION}_amd64.deb" >/dev/null
    echo "==> Created metapackage: ${DIST_DIR}/${PKG_NAME}_${KVER}-${DEB_REVISION}_amd64.deb"
}

# 1. Kernel image metapackage
build_meta "linux-image-6.18-lts-amd64" "linux-image-${KVER}" "Linux 6.18 LTS image metapackage"

# 2. Kernel headers metapackage
build_meta "linux-headers-6.18-lts-amd64" "linux-headers-${KVER}" "Linux 6.18 LTS headers metapackage"
