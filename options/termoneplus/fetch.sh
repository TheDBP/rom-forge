#!/bin/bash
# fetch.sh -- pull the TermOne Plus APK into vendor/lineage/prebuilts/termoneplus, where this option's patch
# builds it from, and unpack its native libraries beside it. One destination only: no legacy
# device-tree module, unlike firefox/fdroid.
#
# Runs at sync time. It has to: PRODUCT_PACKAGES resolves at product-config time, and the module is
# guarded on the APK existing, so a missing APK means no terminal and no error -- which is why
# post-build.sh then checks the image.
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/termoneplus" \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-termoneplus.sh" "$AOSP" || exit 1
