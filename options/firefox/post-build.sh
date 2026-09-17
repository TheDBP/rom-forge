#!/bin/bash
# firefox option, post-build hook -- prove the APK in the image can still install.
#
# BUILD_PREBUILT with LOCAL_CERTIFICATE := PRESIGNED rewrites the archive:
# build/make/core/app_prebuilt_internal.mk:213, "For PRESIGNED apks we must uncompress every .so
# file". Re-zipping invalidates an APK Signature Scheme v2 signature, which covers the whole file.
# Fennec is mostly libxul.so, so the shipped APK came out at 242,684,607 bytes against 127,545,689
# fetched, and the device refused it:
#
#   INSTALL_PARSE_FAILED_NO_CERTIFICATES: META-INF/....SF indicates the APK is signed using
#   APK Signature Scheme v2, but no such signature was found. Signature stripped?
#
# PackageManager hits this during the boot scan and skips the package silently, so the only symptom
# is a missing app in a build that reported success. Comparing the installed APK against the fetched
# one catches any rewrite, whatever its cause.
set -uo pipefail

AOSP="${AOSP:-/aosp}"
# DEVICE_CODENAME comes from device.conf, not from the hook runner -- run_option_hooks only exports
# the WITH_* switches. root/post-build.sh sources it the same way; without this the hook dies on an
# unset variable and fails a build that otherwise succeeded.
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"
OUT="$AOSP/out/target/product/${DEVICE_CODENAME:?DEVICE_CODENAME unset and device.conf not found}"

SRC="$AOSP/vendor/lineage/prebuilts/firefox/Firefox.apk"
[ -f "$SRC" ] || SRC="$(find "$AOSP/device" -name 'Firefox.apk' 2>/dev/null | head -1)"
APK="$(find "$OUT" -name 'Firefox.apk' -path '*app*' -not -path '*/obj/*' 2>/dev/null | head -1)"

[ -n "$APK" ] || { echo "!! firefox: no Firefox.apk in the built image"; exit 1; }
[ -f "$SRC" ] || { echo "   firefox: no fetched copy to compare against, skipping"; exit 0; }

if cmp -s "$SRC" "$APK"; then
  echo "   firefox: shipped APK is byte-identical to the fetched one -- signature intact"
  exit 0
fi

echo "!! firefox: the build rewrote the APK, so its signature no longer verifies."
echo "!!   fetched: $(stat -c%s "$SRC") bytes"
echo "!!   shipped: $(stat -c%s "$APK") bytes"
echo "!! PackageManager will refuse it with INSTALL_PARSE_FAILED_NO_CERTIFICATES and skip it"
echo "!! silently at boot, so the app is simply absent from a build that otherwise succeeds."
echo "!! Ship it with Soong: android_app_import { preprocessed: true }, which installs the APK"
echo "!! unmodified. BUILD_PREBUILT + LOCAL_CERTIFICATE := PRESIGNED cannot, because it always"
echo "!! uncompresses native libs (app_prebuilt_internal.mk:213)."
exit 1
