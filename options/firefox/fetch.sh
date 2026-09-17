#!/bin/bash
# fetch.sh -- pull the Firefox APK into whichever prebuilt directory this branch's module reads.
#
# Two destinations, because two mechanisms build it:
#   vendor/lineage/prebuilts/firefox   this option's patch (22.2+)
#   device/<vendor>/<codename>/firefox an older device-tree module (ether 19.1 and 20.0 have one)
# Both consumers guard on the APK existing, so populating both is harmless and populating neither is
# silent: PRODUCT_PACKAGES resolves at product-config time, and a module with no APK simply is not
# built -- no error, no Firefox.
#
# Runs at sync time. It has to: a module that does not exist yet is not "missing later", it fails
# lunch outright with "includes non-existent modules in PRODUCT_PACKAGES".
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/firefox" \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-firefox.sh" "$AOSP" || exit 1
