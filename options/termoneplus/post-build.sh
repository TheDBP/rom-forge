#!/bin/bash
# termoneplus option, post-build hook -- prove the APK in the image is the one that was fetched, and that
# its native libraries were installed beside it.
#
# Any rewrite of a presigned APK (uncompressing libs or dex, re-aligning) invalidates its whole-file
# v2 signature; PackageManager then skips it silently at boot scan and the build reports success
# with no terminal. Comparing installed against fetched catches every cause. Same check as firefox.
set -uo pipefail

AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"
OUT="$AOSP/out/target/product/${DEVICE_CODENAME:?DEVICE_CODENAME unset and device.conf not found}"

SRC="$AOSP/vendor/lineage/prebuilts/termoneplus/TermOnePlus.apk"
APK="$(find "$OUT" -name 'TermOnePlus.apk' -path '*app*' -not -path '*/obj/*' 2>/dev/null | head -1)"

[ -n "$APK" ] || { echo "!! termoneplus: no TermOnePlus.apk in the built image"; exit 1; }
[ -f "$SRC" ] || { echo "   termoneplus: no fetched copy to compare against, skipping"; exit 0; }

if ! cmp -s "$SRC" "$APK"; then
  echo "!! termoneplus: the build rewrote the APK, so its signature no longer verifies."
  echo "!!   fetched: $(stat -c%s "$SRC") bytes"
  echo "!!   shipped: $(stat -c%s "$APK") bytes"
  echo "!! PackageManager will refuse it at boot scan and the app will simply be absent."
  exit 1
fi
# The terminal is JNI-backed (pty handling); without the libraries every launch dies in
# UnsatisfiedLinkError.
_LIB="$(dirname "$APK")/lib/arm64/libterm-system.so"
[ -f "$_LIB" ] || { echo "!! termoneplus: $_LIB missing -- the app would crash with UnsatisfiedLinkError"; exit 1; }
echo "   termoneplus: shipped APK is byte-identical to the fetched one, native libraries beside it"
