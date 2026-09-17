#!/usr/bin/env bash
# fetch-firefox.sh — download the Fennec F-Droid APK (Firefox, MPL, F-Droid-signed) for the
# WITH_GAPPS browser swap. Runs in-container (network + aapt2 from the tree). Places the APK straight
# into the device tree's firefox/ dir. Verified by package name, arm64 ABI and pinned sha256;
# override FIREFOX_URL + FIREFOX_SHA256 together to pin a different build.
#   ./fetch-firefox.sh [AOSP_ROOT]
# If FIREFOX_SRC points at an already-downloaded APK (e.g. staged by the prefetch phase), it is
# verified + installed instead of re-downloading — this is the fetch/verify split that lets the
# download overlap `repo sync` (verify needs the tree's aapt2, so it stays here).
set -euo pipefail

AOSP="${1:-/aosp}"
SRC="${FIREFOX_SRC:-}"
_SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"; [ -f "$_SELF_REPO/device.conf" ] && source "$_SELF_REPO/device.conf"
# FEATURE_DEST (set by the apps/firefox feature) overrides the legacy device-tree path.
DEST="${FEATURE_DEST:-$AOSP/device/${DEVICE:?device.conf missing or DEVICE unset}/firefox}"
OUT="$DEST/Firefox.apk"
PKG="org.mozilla.fennec_fdroid"
# Fennec F-Droid 155.0.0 (versionCode 1550020), arm64-v8a. Override with FIREFOX_URL + FIREFOX_SHA256.
# bootstrap.sh greps the URL line for the prefetch, so keep it a single literal.
FIREFOX_URL="${FIREFOX_URL:-https://f-droid.org/repo/org.mozilla.fennec_fdroid_1550020.apk}"
FIREFOX_SHA256="${FIREFOX_SHA256:-f76bea68ef7b1fed0bfc7d99718551476da830914ae4e173fabcd8d2a6532944}"
AAPT2="$(command -v aapt2 || echo "$AOSP/prebuilts/sdk/tools/linux/bin/aapt2")"

mkdir -p "$DEST"
verify() {  # $1 = apk
  [ -x "$AAPT2" ] || { echo "!! aapt2 not found — cannot verify Firefox"; return 1; }
  [ "$("$AAPT2" dump packagename "$1" 2>/dev/null)" = "$PKG" ] || { echo "!! wrong package"; return 1; }
  # capture-then-count: `grep -q` exits early -> unzip SIGPIPEs -> pipefail fails a VALID apk.
  [ "$(unzip -l "$1" 2>/dev/null | grep -c 'lib/arm64-v8a/' || true)" -gt 0 ] || { echo "!! not an arm64 build"; return 1; }
  echo "$FIREFOX_SHA256  $1" | sha256sum -c - >/dev/null 2>&1 || { echo "!! sha mismatch"; return 1; }
  return 0
}

# PackageManager never extracts native libraries for a bundled system app
# (PackageAbiHelperImpl.shouldExtractLibs) and the linker cannot dlopen a compressed zip entry, so
# unpack lib/arm64-v8a/ beside the APK for the module to install as <app>/lib/arm64/*.so.
unpack_libs() {
  rm -rf "$DEST/lib"
  unzip -q -o "$1" 'lib/arm64-v8a/*.so' -d "$DEST" || { echo "!! could not unpack native libraries"; return 1; }
  echo "   unpacked: $(ls "$DEST/lib/arm64-v8a" | wc -l) native libraries -> lib/arm64-v8a/"
}

# Cached only if it is the pinned build; a prefetched file that differs always wins.
if [ -f "$OUT" ] && verify "$OUT" >/dev/null 2>&1 && { [ -z "$SRC" ] || cmp -s "$SRC" "$OUT"; }; then
  echo "   ok (cached): Firefox.apk"; unpack_libs "$OUT"; exit $?
fi
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
  echo ">> using prefetched Firefox APK ($SRC)"
  cp -f "$SRC" "$OUT"
else
  echo ">> downloading Firefox (Fennec F-Droid, arm64) — ~120 MB"
  curl -fSL -o "$OUT" "$FIREFOX_URL"
fi
verify "$OUT" || { echo "!! Firefox verification failed — refusing to use it"; rm -f "$OUT"; exit 1; }
echo "   verified: Firefox.apk ($PKG, arm64)"
unpack_libs "$OUT"
