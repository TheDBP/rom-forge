#!/bin/bash
# k9 option, post-build hook -- prove the APK in the image is the one that was fetched.
#
# Any rewrite of a presigned APK (uncompressing libs or dex, re-aligning) invalidates its whole-file
# v2 signature; PackageManager then skips it silently at boot scan and the build reports success
# with no mail app. Comparing installed against fetched catches every cause. Same check as firefox.
set -uo pipefail

AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"
OUT="$AOSP/out/target/product/${DEVICE_CODENAME:?DEVICE_CODENAME unset and device.conf not found}"

SRC="$AOSP/vendor/lineage/prebuilts/k9/K9Mail.apk"
APK="$(find "$OUT" -name 'K9Mail.apk' -path '*app*' -not -path '*/obj/*' 2>/dev/null | head -1)"

[ -n "$APK" ] || { echo "!! k9: no K9Mail.apk in the built image"; exit 1; }
[ -f "$SRC" ] || { echo "   k9: no fetched copy to compare against, skipping"; exit 0; }

if cmp -s "$SRC" "$APK"; then
  echo "   k9: shipped APK is byte-identical to the fetched one -- signature intact"
  exit 0
fi
echo "!! k9: the build rewrote the APK, so its signature no longer verifies."
echo "!!   fetched: $(stat -c%s "$SRC") bytes"
echo "!!   shipped: $(stat -c%s "$APK") bytes"
echo "!! PackageManager will refuse it at boot scan and the app will simply be absent."
exit 1
