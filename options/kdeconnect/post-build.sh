#!/bin/bash
# kdeconnect option, post-build hook -- prove the APK in the image is the one that was fetched.
#
# Any rewrite of a presigned APK (uncompressing libs or dex, re-aligning) invalidates its whole-file
# v2 signature; PackageManager then skips it silently at boot scan and the build reports success
# with no KDE Connect. Comparing installed against fetched catches every cause. Same check as k9.
set -uo pipefail

AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"
OUT="$AOSP/out/target/product/${DEVICE_CODENAME:?DEVICE_CODENAME unset and device.conf not found}"

SRC="$AOSP/vendor/lineage/prebuilts/kdeconnect/KDEConnect.apk"
APK="$(find "$OUT" -name 'KDEConnect.apk' -path '*app*' -not -path '*/obj/*' -print -quit 2>/dev/null)"

[ -n "$APK" ] || { echo "!! kdeconnect: no KDEConnect.apk in the built image"; exit 1; }
[ -f "$SRC" ] || { echo "   kdeconnect: no fetched copy to compare against, skipping"; exit 0; }

if cmp -s "$SRC" "$APK"; then
  echo "   kdeconnect: shipped APK is byte-identical to the fetched one -- signature intact"
  exit 0
fi
echo "!! kdeconnect: the build rewrote the APK, so its signature no longer verifies."
echo "!!   fetched: $(stat -c%s "$SRC") bytes"
echo "!!   shipped: $(stat -c%s "$APK") bytes"
echo "!! PackageManager will refuse it at boot scan and the app will simply be absent."
exit 1
