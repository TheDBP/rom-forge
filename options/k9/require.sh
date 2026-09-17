#!/bin/bash
# require.sh -- checked BEFORE the build when WITH_K9=true.
#
# 1. The APK must be in the tree. The module is guarded on it, so without it the build succeeds
#    and ships no mail app.
# 2. On 20.0 the module ships the APK verbatim through BUILD_PREBUILT's do_not_alter_apk path, and
#    stock build/make fails that path when an APK carries compressed dex -- K-9's is Deflated. The
#    device tree has to carry the "warn instead of fail" patch to build/make/core/definitions.mk
#    (ether-20.0 does). Without it the failure is a hard build error at minute ~200, so check now.
set -o pipefail
AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"

[ -f "$AOSP/vendor/lineage/prebuilts/k9/K9Mail.apk" ] || {
  echo "!! k9: vendor/lineage/prebuilts/k9/K9Mail.apk is missing; the module is guarded on it and" >&2
  echo "!!     the build would ship no mail app. Run the option's fetch.sh (bootstrap does)." >&2
  exit 1
}
case "${BRANCH:-}" in
  lineage-20.0)
    grep -q 'presigned, shipped as-is' "$AOSP/build/make/core/definitions.mk" 2>/dev/null || {
      echo "!! k9: on $BRANCH the verbatim-copy path needs the build/make patch that turns" >&2
      echo "!!     check-jni-dex-compression into a warning (K-9's dex is compressed). Not applied." >&2
      exit 1
    } ;;
esac
echo "   k9: K9Mail.apk present"
