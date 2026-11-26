#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -gt 1 || ${1:-} == --help || ${1:-} == -h ]]; then
  printf 'Usage: %s [ROCKY_RELEASE]\n' "$0"
  exit "$(( $# > 1 ? 2 : 0 ))"
fi

RELEASE=${1:-}
if [[ -z $RELEASE && -r /etc/os-release ]]; then
  RELEASE=$(. /etc/os-release; if [[ $ID == rocky ]]; then printf '%s' "$VERSION_ID"; fi)
fi
BUILD_JOBS=${BUILD_JOBS:-6}
if [[ ! $RELEASE =~ ^[0-9]+(\.[0-9]+)?$ || ! $BUILD_JOBS =~ ^[1-9][0-9]*$ ]]; then
  printf 'Specify a Rocky Linux release (for example 9.9) and a positive BUILD_JOBS value.\n' >&2
  exit 2
fi
if [[ $(uname -sm) != 'Linux x86_64' ]] || ! command -v podman >/dev/null; then
  printf 'Podman on Linux x86_64 is required.\n' >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/rpmbuild"
RUN_DIR=$(mktemp -d "$ROOT_DIR/rpmbuild/run.XXXXXXXX")
mkdir -p "$RUN_DIR/scripts" "$RUN_DIR/patches"
cp "$ROOT_DIR/scripts/"{download_latest_srpm.sh,build_custom_rpm.sh} "$RUN_DIR/scripts/"
cp "$ROOT_DIR/patches/mold-rbd.patch" "$RUN_DIR/patches/"
printf 'Build directory: %s\n' "$RUN_DIR"

podman run --rm -i --pull=always --network host --cpus "$BUILD_JOBS" \
  --volume "$RUN_DIR:/workspace:Z" --workdir /workspace \
  "docker.io/library/rockylinux:$RELEASE" bash -se -- "$RELEASE" "$BUILD_JOBS" <<'BASH' 2>&1 | tee "$RUN_DIR/build.log"
set -uo pipefail
release=$1
jobs=$2
rocky_mirror=https://downloads.rockylinux.org
repo_root=$rocky_mirror/pub/rocky/$release
if ! curl -fsI --max-time 15 "$repo_root/BaseOS/x86_64/os/repodata/repomd.xml" >/dev/null; then
  repo_root=$rocky_mirror/vault/rocky/$release
  curl -fsI --max-time 15 "$repo_root/BaseOS/x86_64/os/repodata/repomd.xml" >/dev/null
fi

repos=(--releasever="$release" --disablerepo='*')
for component in BaseOS AppStream CRB; do
  repo=ablestack-${component,,}
  repos+=(--repofrompath="$repo,$repo_root/$component/x86_64/os/"
    --setopt="$repo.gpgcheck=1" --setopt="$repo.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-${release%%.*}")
done
dnf -y "${repos[@]}" install dnf-plugins-core rpm-build cpio

srpm=$(ROCKY_RELEASE="$release" ROCKY_REPO_ROOT="$repo_root" bash scripts/download_latest_srpm.sh)
dnf -y "${repos[@]}" builddep "$srpm"
printf '%%_smp_build_ncpus %s\n' "$jobs" > /root/.rpmmacros
TOPDIR=/workspace/build bash scripts/build_custom_rpm.sh "$srpm"
BASH

rpm_path=$(sed -n 's|^Custom RBD RPM: /workspace/||p' "$RUN_DIR/build.log")
if [[ ! -f "$RUN_DIR/$rpm_path" ]]; then
  printf 'Unable to find the built RBD RPM. See %s/build.log.\n' "$RUN_DIR" >&2
  exit 1
fi
printf 'RPM: %s\n' "$RUN_DIR/$rpm_path"
