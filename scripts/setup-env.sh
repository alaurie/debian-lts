#!/usr/bin/env bash
# scripts/setup-env.sh: Validate host environment and install kernel build prerequisites.
set -euo pipefail

REQUIRED_PACKAGES=(
    build-essential
    bc
    bison
    flex
    libelf-dev
    libssl-dev
    dwarves
    kmod
    rsync
    cpio
    fakeroot
    zstd
    libncurses-dev
    git
    ccache
    sbsigntool
)

echo "==> Checking required kernel build dependencies on Debian..."

MISSING_PACKAGES=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
        MISSING_PACKAGES+=("${pkg}")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    echo "==> All required build packages are installed."
    exit 0
fi

echo "==> Missing packages: ${MISSING_PACKAGES[*]}"

if [ "$(id -u)" -ne 0 ]; then
    echo "==> Run with sudo to install missing packages:"
    echo "    sudo apt-get update && sudo apt-get install -y ${MISSING_PACKAGES[*]}"
    exit 1
else
    apt-get update && apt-get install -y "${MISSING_PACKAGES[@]}"
fi
