#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${1:-libvirt}"
DEST_DIR="${2:-${ROOT_DIR}/.cache/srpm}"

if ! command -v dnf >/dev/null 2>&1; then
  echo "Error: dnf is required to download source RPMs." >&2
  exit 1
fi

ROCKY_RELEASE=${ROCKY_RELEASE:-$(. /etc/os-release && printf '%s' "$VERSION_ID")}
REPO_ROOT=${ROCKY_REPO_ROOT:-https://downloads.rockylinux.org/pub/rocky/$ROCKY_RELEASE}
REPO_ARGS=(--releasever="$ROCKY_RELEASE" --disablerepo='*'
  --repofrompath="ablestack-appstream-source,$REPO_ROOT/AppStream/source/tree/")

mkdir -p "$DEST_DIR"
DEST_DIR="$(cd "$DEST_DIR" && pwd)"

source_rpm=$(dnf -q --refresh "${REPO_ARGS[@]}" repoquery --arch=src --latest-limit=1 \
  --queryformat '%{name}-%{version}-%{release}.src.rpm' "${PACKAGE_NAME}.src")
if [[ $source_rpm != "$PACKAGE_NAME"-*.src.rpm || $source_rpm == *$'\n'* || $source_rpm == */* ]]; then
  printf 'Unable to identify a single latest SRPM for %s in %s.\n' "$PACKAGE_NAME" "$REPO_ROOT" >&2
  exit 1
fi

printf 'Downloading %s from %s\n' "$source_rpm" "$REPO_ROOT" >&2
dnf -q "${REPO_ARGS[@]}" download --source --destdir "$DEST_DIR" "${source_rpm%.rpm}" >&2
test -s "$DEST_DIR/$source_rpm"
printf '%s\n' "$DEST_DIR/$source_rpm"
