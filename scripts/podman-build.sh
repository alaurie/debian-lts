#!/usr/bin/env bash
# scripts/podman-build.sh: Execute builds inside an isolated Debian Trixie Podman container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_NAME="debian-lts-builder:latest"

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman is not installed on the host." >&2
    exit 1
fi

REBUILD_IMAGE=0
if [ "${1:-}" = "--rebuild" ]; then
    REBUILD_IMAGE=1
    shift
fi

# Build image if missing or requested
if [ "${REBUILD_IMAGE}" -eq 1 ] || ! podman image exists "${IMAGE_NAME}"; then
    echo "==> Building container image ${IMAGE_NAME}..."
    podman build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/Containerfile" "${ROOT_DIR}"
fi

CMD=("${@}")
if [ ${#CMD[@]} -eq 0 ]; then
    CMD=("./scripts/build.sh")
fi
PODMAN_TTY=()
if [ -t 0 ]; then
    PODMAN_TTY=("-it")
else
    PODMAN_TTY=("-i")
fi

echo "==> Running in Podman container (${IMAGE_NAME})..."
podman run --rm "${PODMAN_TTY[@]}" \
    --userns=keep-id \
    -v "${ROOT_DIR}:/build:Z" \
    -w /build \
    -e JOBS="${JOBS:-$(nproc)}" \
    -e FLAVOR="${FLAVOR:-amd64}" \
    -e FULL_DEBUG="${FULL_DEBUG:-0}" \
    "${IMAGE_NAME}" "${CMD[@]}"
