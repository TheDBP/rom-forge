#!/bin/bash
# fetch.sh -- pull the K-9 Mail APK into vendor/lineage/prebuilts/k9, where this option's patch
# builds it from. One destination only: unlike firefox/fdroid there is no legacy device-tree module.
#
# Runs at sync time. It has to: PRODUCT_PACKAGES resolves at product-config time, and the module is
# guarded on the APK existing, so a missing APK means no K-9 and no error -- which is why
# post-build.sh then checks the image.
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/k9" \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-k9.sh" "$AOSP" || exit 1
