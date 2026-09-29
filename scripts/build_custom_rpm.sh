#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${CACHE_DIR:-${ROOT_DIR}/.cache/srpm}"
TOPDIR="${TOPDIR:-${ROOT_DIR}/rpmbuild}"
SPEC_FILE="${SPEC_FILE:-${ROOT_DIR}/specs/libvirt.spec}"

if [[ ! -f "${SPEC_FILE}" ]]; then
  echo "Error: custom spec file not found: ${SPEC_FILE}" >&2
  exit 1
fi

SRPM_PATH="${1:-}"
if [[ -z "${SRPM_PATH}" ]]; then
  SRPM_PATH="$(ls -1t "${CACHE_DIR}"/*.src.rpm 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${SRPM_PATH}" || ! -f "${SRPM_PATH}" ]]; then
  echo "Error: no upstream SRPM found in ${CACHE_DIR}. Run ./scripts/download_latest_srpm.sh first." >&2
  exit 1
fi

echo "Using SRPM: ${SRPM_PATH}"

mkdir -p "${TOPDIR}/BUILD" "${TOPDIR}/BUILDROOT" "${TOPDIR}/RPMS" "${TOPDIR}/SOURCES" "${TOPDIR}/SPECS" "${TOPDIR}/SRPMS"

cp "${SPEC_FILE}" "${TOPDIR}/SPECS/"
for p in "${ROOT_DIR}"/patches/*.patch; do
  if [[ -e "${p}" ]]; then
    cp "${p}" "${TOPDIR}/SOURCES/"
  fi
done

if command -v rpm2cpio >/dev/null 2>&1; then
  echo "Extracting source payload from the downloaded SRPM into ${TOPDIR}/SOURCES"
  cd "${TOPDIR}/SOURCES"
  rpm2cpio "${SRPM_PATH}" | cpio -idm --quiet || true
  cd "${ROOT_DIR}"
else
  echo "Warning: rpm2cpio is not installed; skip unpacking the SRPM payload." >&2
fi

rpmbuild -ba --define "_topdir ${TOPDIR}" "${TOPDIR}/SPECS/$(basename "${SPEC_FILE}")"

find "${TOPDIR}/RPMS" "${TOPDIR}/SRPMS" -type f -name '*.rpm' -print

echo "Custom RPM build finished. The SRPM remains outside Git and is not tracked by this repository."
