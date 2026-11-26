#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${TOPDIR:-${ROOT_DIR}/rpmbuild}"
PREPARE_ONLY=false
if [[ ${1:-} == --prepare ]]; then
  PREPARE_ONLY=true
  shift
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s [--prepare] LIBVIRT_SRPM [RBD_PATCH]\n' "$0" >&2
  exit 2
fi

SRPM_PATH=$1
PATCH_PATH=${2:-$ROOT_DIR/patches/mold-rbd.patch}
if [[ ! -s "$SRPM_PATH" || ! -s "$PATCH_PATH" ]]; then
  printf 'The libvirt SRPM and RBD patch must both exist and be nonempty.\n' >&2
  exit 2
fi

RPM_ARGS=(--target x86_64)
QUERY_FORMAT='%{NAME} %{VERSION} %{RELEASE}\n'
if ! "$PREPARE_ONLY"; then
  for tool in rpm rpmspec rpmbuild; do
    if ! command -v "$tool" >/dev/null; then
      printf 'Missing %s. Use the Rocky Linux x86_64 build environment.\n' "$tool" >&2
      exit 1
    fi
  done
  SOURCE_NVR=$(rpm -qp --qf "$QUERY_FORMAT" "$SRPM_PATH")
  read -r source_name version release <<< "$SOURCE_NVR"
  if [[ $source_name != libvirt || ! $release =~ (\.el[0-9]+(_[0-9]+)?)(\.[[:alnum:].]+)?$ ]]; then
    printf 'Expected a Rocky Linux libvirt SRPM, got %s.\n' "$SOURCE_NVR" >&2
    exit 1
  fi
  RPM_ARGS+=(--define "dist ${BASH_REMATCH[1]}")
  EXTRA_RELEASE=${BASH_REMATCH[3]}
fi

mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
BUILD_DIR=$(mktemp -d "$BUILD_ROOT/libvirt.XXXXXXXX")
mkdir -p "$BUILD_DIR/SOURCES" "$BUILD_DIR/SPECS"

if command -v rpm2cpio >/dev/null; then
  rpm2cpio "$SRPM_PATH" | (cd "$BUILD_DIR/SOURCES" && cpio -idm --quiet --no-absolute-filenames)
else
  bsdtar -xf "$SRPM_PATH" -C "$BUILD_DIR/SOURCES"
fi

STOCK_SPEC="$BUILD_DIR/SOURCES/libvirt.spec"
CUSTOM_SPEC="$BUILD_DIR/SPECS/libvirt.spec"
CUSTOM_PATCH=ablestack-mold-rbd.patch

# Apply the local patch after the distro's entire prep section.
awk -v patch_file="$CUSTOM_PATCH" '
  /^%prep([[:blank:]]|$)/ { prep_count++ }
  /^%build([[:blank:]]|$)/ {
    build_count++
    if (prep_count != 1) exit 1
    print "rbd_source=src/storage/storage_backend_rbd.c"
    print "test -f \"$rbd_source\""
    print "if grep -qF auth_supported \"$rbd_source\"; then"
    print "    %{__patch} -p1 --batch --forward --fuzz=0 -i \"%{_sourcedir}/" patch_file "\""
    print "fi"
    print "if grep -qF auth_supported \"$rbd_source\"; then"
    print "    echo \"auth_supported is still present in $rbd_source\" >&2"
    print "    exit 1"
    print "fi"
    print ""
  }
  { print }
  /^%package[[:blank:]]+daemon-driver-storage-rbd[[:blank:]]*$/ {
    rbd_count++
    print "Release: %{RELEASE}.ablestack.1"
    # RPM 4.16 updates the lowercase macro when it parses this tag.
    print "%global release %{RELEASE}"
    print "Provides: libvirt-daemon-driver-storage-rbd = %{version}-%{RELEASE}"
  }
  END {
    if (prep_count != 1 || build_count != 1 || rbd_count != 1) {
      print "Unexpected libvirt spec layout. Review the patch and RBD subpackage." > "/dev/stderr"
      exit 1
    }
  }
' "$STOCK_SPEC" > "$CUSTOM_SPEC"

mv "$STOCK_SPEC" "$BUILD_DIR/libvirt.stock.spec"
cp "$PATCH_PATH" "$BUILD_DIR/SOURCES/$CUSTOM_PATCH"
printf 'Prepared spec: %s\n' "$CUSTOM_SPEC"
if "$PREPARE_ONLY"; then
  exit 0
fi

RPM_ARGS+=(--define "_topdir $BUILD_DIR")
BUILD_NVR=$(rpmspec "${RPM_ARGS[@]}" -q --srpm --qf "$QUERY_FORMAT" "$CUSTOM_SPEC")
if [[ $BUILD_NVR != "$SOURCE_NVR" && -n $EXTRA_RELEASE ]]; then
  RPM_ARGS+=(--define "extra_release $EXTRA_RELEASE")
  BUILD_NVR=$(rpmspec "${RPM_ARGS[@]}" -q --srpm --qf "$QUERY_FORMAT" "$CUSTOM_SPEC")
fi
if [[ $BUILD_NVR != "$SOURCE_NVR" ]]; then
  printf 'Built source NVR would differ from the upstream SRPM (%s vs %s).\n' "$BUILD_NVR" "$SOURCE_NVR" >&2
  exit 1
fi

stock_rbd="libvirt-daemon-driver-storage-rbd $version $release"
stock_packages=$(rpmspec "${RPM_ARGS[@]}" -q --rpms --qf "$QUERY_FORMAT" "$BUILD_DIR/libvirt.stock.spec")
custom_packages=$(rpmspec "${RPM_ARGS[@]}" -q --rpms --qf "$QUERY_FORMAT" "$CUSTOM_SPEC")
if ! grep -Fxq "$stock_rbd" <<< "$stock_packages" ||
   [[ $custom_packages != "${stock_packages/"$stock_rbd"/"$stock_rbd.ablestack.1"}" ]]; then
  printf 'Expected only the RBD subpackage release to change.\n' >&2
  exit 1
fi

rpmbuild "${RPM_ARGS[@]}" -bb "$CUSTOM_SPEC"

RBD_RPM="$BUILD_DIR/RPMS/x86_64/libvirt-daemon-driver-storage-rbd-$version-$release.ablestack.1.x86_64.rpm"
requires=$(rpm -qp --requires "$RBD_RPM")
provides=$(rpm -qp --provides "$RBD_RPM")
grep -Fx "libvirt-daemon-driver-storage-core = $version-$release" <<< "$requires"
grep -Fx "libvirt-libs = $version-$release" <<< "$requires"
grep -Fx "libvirt-daemon-driver-storage-rbd = $version-$release" <<< "$provides"
printf 'Custom RBD RPM: %s\n' "$RBD_RPM"
