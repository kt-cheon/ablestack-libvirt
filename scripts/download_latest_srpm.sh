#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${1:-libvirt}"
DEST_DIR="${2:-${ROOT_DIR}/.cache/srpm}"

if ! command -v dnf >/dev/null 2>&1; then
  echo "Error: dnf is required to download source RPMs." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

echo "Downloading latest source RPM for ${PACKAGE_NAME} to ${DEST_DIR}"

dnf download --source --destdir "${DEST_DIR}" "${PACKAGE_NAME}"

ls -1 "${DEST_DIR}"/*.src.rpm 2>/dev/null | tail -n 5

echo "Done. SRPM is kept outside Git and can be customized locally."
