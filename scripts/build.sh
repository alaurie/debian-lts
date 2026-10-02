#!/usr/bin/env bash
# scripts/build.sh: Compile the kernel and produce native Debian .deb packages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_DIR="${1:-${ROOT_DIR}/src/linux-6.18}"
DIST_DIR="${ROOT_DIR}/dist"
JOBS="${JOBS:-$(nproc)}"
LOCAL_TAG="${LOCAL_TAG:--lts}"
DEB_REVISION="${DEB_REVISION:-1~deb13}"

if [ ! -d "${TARGET_DIR}" ]; then
    echo "ERROR: Kernel tree not found at ${TARGET_DIR}" >&2
    exit 1
fi

if [ ! -f "${TARGET_DIR}/.config" ]; then
    echo "ERROR: .config missing. Run 'scripts/prepare-config.sh' first." >&2
    exit 1
fi

mkdir -p "${DIST_DIR}"

# Extract base version from kernel Makefile
K_VER=$(grep -E "^VERSION =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
K_PATCH=$(grep -E "^PATCHLEVEL =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
K_SUB=$(grep -E "^SUBLEVEL =" "${TARGET_DIR}/Makefile" | awk '{print $3}')
FULL_VER="${K_VER}.${K_PATCH}.${K_SUB}"

echo "==> Building Linux ${FULL_VER}${LOCAL_TAG} with ${JOBS} threads..."

export ARCH=x86_64
export LOCALVERSION="${LOCAL_TAG}"
export KDEB_PKGVERSION="${FULL_VER}-${DEB_REVISION}"
export KDEB_CHANGELOG_DIST="trixie"
export KBUILD_BUILD_USER="debian-lts"
export KBUILD_BUILD_HOST="debian-lts"

if command -v ccache >/dev/null 2>&1; then
    export CC="ccache gcc"
fi

# Clean previous packaging artifacts in kernel parent dir
rm -f "${ROOT_DIR}/src"/linux-*.deb "${ROOT_DIR}/src"/linux-*.buildinfo "${ROOT_DIR}/src"/linux-*.changes

# Compile and package via upstream bindeb-pkg
make -C "${TARGET_DIR}" -j"${JOBS}" bindeb-pkg

# Collect packages into dist/
echo "==> Moving generated packages to ${DIST_DIR}..."
mv "${ROOT_DIR}/src"/linux-image-*.deb "${DIST_DIR}/" 2>/dev/null || true
mv "${ROOT_DIR}/src"/linux-headers-*.deb "${DIST_DIR}/" 2>/dev/null || true
mv "${ROOT_DIR}/src"/linux-libc-dev_*.deb "${DIST_DIR}/" 2>/dev/null || true

# Generate metapackages
echo "==> Generating rolling metapackages..."
"${SCRIPT_DIR}/build-metapackage.sh" "${FULL_VER}${LOCAL_TAG}" "${DEB_REVISION}"

echo "==> Build complete! Output artifacts in ${DIST_DIR}:"
ls -lh "${DIST_DIR}"/*.deb
