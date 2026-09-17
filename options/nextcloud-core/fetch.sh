#!/bin/bash
# fetch.sh -- pull Files, Talk and NextPush into vendor/lineage/prebuilts/nextcloud, the same place
# and patch as the nextcloud option; the fetcher takes the subset and removes the other five, so the
# per-APK guard in config/common.mk ships exactly these three. Latest F-Droid build of each,
# signer-pinned (see forge/prebuilt/lib-fdroid.sh); FDROID_PINS holds any of them to one versionCode.
#
# Runs at sync time. It has to: PRODUCT_PACKAGES resolves at product-config time, and each module is
# guarded on its APK existing, so a missing APK means a missing app and no error -- which is why
# require.sh checks before the build and post-build.sh checks the image.
set -o pipefail
AOSP="${1:-/aosp}"
FEATURE_DEST="$AOSP/vendor/lineage/prebuilts/nextcloud" \
NEXTCLOUD_MODULES="NextcloudFiles NextcloudTalk NextPush" NEXTCLOUD_LABEL=nextcloud-core \
  bash "${FORGE_DIR:?FORGE_DIR unset}/prebuilt/fetch-nextcloud.sh" "$AOSP" || exit 1
