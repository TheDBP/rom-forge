#!/bin/bash
# require.sh -- checked BEFORE the build when WITH_TERMONEPLUS=true.
#
# 1. The APK and its unpacked native libraries must be in the tree. The module is guarded on the
#    APK, so without it the build succeeds and ships no terminal; without the libraries it ships a
#    terminal that dies in UnsatisfiedLinkError on first launch.
# 2. On 20.0 the module ships the APK verbatim through BUILD_PREBUILT's do_not_alter_apk path, and
#    stock build/make fails that path when an APK carries compressed dex -- TermOne Plus's is Deflated.
#    The device tree has to carry the "warn instead of fail" patch to build/make/core/definitions.mk
#    (ether-20.0 does). Without it the failure is a hard build error at minute ~200, so check now.
set -o pipefail
AOSP="${AOSP:-/aosp}"
_REPO="${DEVICE_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
[ -f "$_REPO/device.conf" ] && . "$_REPO/device.conf"

_D="$AOSP/vendor/lineage/prebuilts/termoneplus"
[ -f "$_D/TermOnePlus.apk" ] || {
  echo "!! termoneplus: vendor/lineage/prebuilts/termoneplus/TermOnePlus.apk is missing; the module is" >&2
  echo "!!     guarded on it and the build would ship no terminal. Run the option's fetch.sh (bootstrap does)." >&2
  exit 1
}
[ -f "$_D/lib/arm64-v8a/libterm-system.so" ] || {
  echo "!! termoneplus: lib/arm64-v8a/ was not unpacked beside TermOnePlus.apk; the app would crash on launch." >&2
  exit 1
}
case "${BRANCH:-}" in
  lineage-20.0)
    grep -q 'presigned, shipped as-is' "$AOSP/build/make/core/definitions.mk" 2>/dev/null || {
      echo "!! termoneplus: on $BRANCH the verbatim-copy path needs the build/make patch that turns" >&2
      echo "!!     check-jni-dex-compression into a warning (TermOne Plus's dex is compressed). Not applied." >&2
      exit 1
    } ;;
esac
echo "   termoneplus: TermOnePlus.apk + native libraries present"
