#!/bin/bash
# fetch.sh -- pull the KDE Connect APK into vendor/lineage/prebuilts/kdeconnect, where this option's
# patch builds it from. Same shape as k9: one destination, no legacy device-tree module.
#
# Runs at sync time. It has to: PRODUCT_PACKAGES resolves at product-config time, and the module is
# guarded on the APK existing, so a missing APK means no KDE Connect and no error -- which is why
# post-build.sh then checks the image.
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/kdeconnect" \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-kdeconnect.sh" "$AOSP" || exit 1
