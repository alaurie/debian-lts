#!/usr/bin/env bash
# scripts/prepare-config.sh: Configure kernel using Debian baseline + olddefconfig.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"


# If host lacks flex or bison and Podman is available, delegate to build container
if ! command -v flex >/dev/null 2>&1 || ! command -v bison >/dev/null 2>&1; then
    if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ] && command -v podman >/dev/null 2>&1; then
        echo "==> flex/bison not detected on host. Delegating to Podman container..."
        exec "${SCRIPT_DIR}/podman-build.sh" ./scripts/prepare-config.sh "$@"
    fi
fi
TARGET_DIR="${1:-${ROOT_DIR}/src/linux-6.18}"
FLAVOR="${FLAVOR:-amd64}"  # amd64, cloud-amd64, rt-amd64
FULL_DEBUG="${FULL_DEBUG:-0}"

CONFIG_SOURCE="${ROOT_DIR}/config/config.amd64_none_${FLAVOR}"

if [ ! -d "${TARGET_DIR}" ]; then
    echo "ERROR: Target kernel directory does not exist: ${TARGET_DIR}" >&2
    echo "Run 'make fetch' or 'scripts/fetch-kernel.sh' first." >&2
    exit 1
fi

if [ ! -f "${CONFIG_SOURCE}" ]; then
    echo "ERROR: Baseline configuration not found: ${CONFIG_SOURCE}" >&2
    exit 1
fi

echo "==> Applying Debian baseline config: ${CONFIG_SOURCE} -> ${TARGET_DIR}/.config"
cp "${CONFIG_SOURCE}" "${TARGET_DIR}/.config"

# Safe adjustments using kernel's own scripts/config tool
KCONFIG="${TARGET_DIR}/scripts/config"
if [ ! -x "${KCONFIG}" ]; then
    echo "==> Building scripts/config..."
    make -C "${TARGET_DIR}" scripts_basic
fi

# 1. Certificates & Signing
# Clear Debian builder keys to avoid 'No rule to make target certs/...' failure
"${KCONFIG}" --file "${TARGET_DIR}/.config" --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
"${KCONFIG}" --file "${TARGET_DIR}/.config" --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

if [ -f "${ROOT_DIR}/certs/mok.key" ] && [ -f "${ROOT_DIR}/certs/mok.crt" ]; then
    echo "==> Custom MOK found in certs/. Enabling module signing..."
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --enable CONFIG_MODULE_SIG
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --enable CONFIG_MODULE_SIG_ALL
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --set-str CONFIG_MODULE_SIG_KEY "${ROOT_DIR}/certs/mok.key"
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --set-str CONFIG_SYSTEM_TRUSTED_KEYS "${ROOT_DIR}/certs/mok.crt"
fi

# 2. Debug Info Footprint
if [ "${FULL_DEBUG}" -eq 0 ]; then
    echo "==> Optimizing build time & disk usage (keeping BTF, disabling full DWARF)..."
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
    "${KCONFIG}" --file "${TARGET_DIR}/.config" --enable CONFIG_DEBUG_INFO_NONE
else
    echo "==> Retaining full Debian DWARF debug symbols..."
fi

# 3. Reconcile against target kernel Kconfig
echo "==> Running 'make olddefconfig' inside ${TARGET_DIR}..."
make -C "${TARGET_DIR}" olddefconfig

echo "==> Configuration ready. Key configuration audit:"
grep -E "CONFIG_PREEMPT_DYNAMIC|CONFIG_DEBUG_INFO_BTF|CONFIG_SECURITY_APPARMOR|CONFIG_MODULE_SIG=" "${TARGET_DIR}/.config" || true
