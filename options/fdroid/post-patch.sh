#!/bin/bash
# post-patch.sh -- runs AFTER the device's patch series has been applied.
#
# The device-tree module directory this copies into is created by a device patch, so this cannot
# live in fetch.sh: that runs first, the directory does not exist yet, and a guard on it silently
# skips. That is exactly how F-Droid came to be missing from every image while the build reported
# success. Copying from vendor/lineage/prebuilts, where fetch.sh actually put the APK.
set -o pipefail
AOSP="${1:-/aosp}"
_dev="$AOSP/device/${DEVICE:-}/fdroid"
[ -n "${DEVICE:-}" ] || { echo "!! F-Droid: DEVICE unset; cannot place into the device tree" >&2; exit 1; }
[ -d "$_dev" ] || exit 0   # this device has no legacy module; nothing to do

_src="$AOSP/vendor/lineage/prebuilts/fdroid"
_bad=0
for _pair in "FDroid/FDroid.apk" "FDroidPrivilegedExtension/FDroidPrivilegedExtension.apk"; do
  mkdir -p "$_dev/$(dirname "$_pair")"
  if ! cp -f "$_src/$_pair" "$_dev/$_pair"; then
    echo "!! fdroid: could not copy $_src/$_pair" >&2; _bad=1
  fi
done
[ "$_bad" = 0 ] || { echo "!! fdroid: the device tree has the module but no APK reached it" >&2; exit 1; }
echo "   also placed into device/${DEVICE}/fdroid/ (legacy device-tree module)"
