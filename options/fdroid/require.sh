#!/bin/bash
# require.sh -- checked BEFORE the build when WITH_FDROID=true: both APKs present (each module is
# guarded on its APK, so without one the build succeeds and ships no app store, or one that cannot
# install silently), module file naming both, and on 20.0 the build/make presigned-warn patch. The checks are in forge/prebuilt/lib-app-checks.sh.
AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"
. "${FORGE_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/prebuilt/lib-app-checks.sh"
app_require fdroid "$AOSP/vendor/lineage/prebuilts/fdroid" FDroid FDroidPrivilegedExtension
