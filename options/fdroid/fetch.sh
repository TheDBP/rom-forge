#!/bin/bash
# fetch.sh -- pull the F-Droid client and Privileged Extension.
#
# Two destinations, because two mechanisms build them:
#   vendor/lineage/prebuilts/fdroid   this option's patch (22.2+)
#   device/<vendor>/<codename>/fdroid an older device-tree module (ether 19.1 has one)
# Each consumer guards on its own APK existing, so populating both is harmless and populating
# neither is silent -- the option applies, the build succeeds, and nothing ships.
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/fdroid" \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-fdroid.sh" "$AOSP" || exit 1
