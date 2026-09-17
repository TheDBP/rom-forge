#!/usr/bin/env bash
# fetch-termoneplus.sh — download the TermOne Plus APK (terminal emulator, GPL-3.0, F-Droid-signed)
# for the termoneplus option and unpack its native libraries beside it. Runs in-container (network +
# aapt2 from the tree). Verified by package name, arm64 ABI and a pinned sha256 (the URL names one
# exact versionCode, so the hash is stable); set TERMONEPLUS_URL and TERMONEPLUS_SHA256 together to
# move to a newer build. The F-Droid APK is universal (all ABIs); only arm64-v8a is unpacked.
#   ./fetch-termoneplus.sh [AOSP_ROOT]
# If TERMONEPLUS_SRC points at an already-downloaded APK (staged by the prefetch phase), it is verified
# and installed instead of re-downloading.
set -euo pipefail

AOSP="${1:-/aosp}"
SRC="${TERMONEPLUS_SRC:-}"
DEST="${FEATURE_DEST:-$AOSP/vendor/lineage/prebuilts/termoneplus}"
OUT="$DEST/TermOnePlus.apk"
PKG="com.termoneplus"
# TermOne Plus 5.7.0 (versionCode 570), F-Droid build. Override with TERMONEPLUS_URL + TERMONEPLUS_SHA256.
TERMONEPLUS_URL="${TERMONEPLUS_URL:-https://f-droid.org/repo/com.termoneplus_570.apk}"
TERMONEPLUS_SHA256="${TERMONEPLUS_SHA256:-fc0ab7c7299011568e41776679b18ed7a92870722beef97c3b3a9dd66a8cd9ff}"
AAPT2="$(command -v aapt2 || echo "$AOSP/prebuilts/sdk/tools/linux/bin/aapt2")"

mkdir -p "$DEST"
verify() {  # $1 = apk
  [ -x "$AAPT2" ] || { echo "!! aapt2 not found — cannot verify TermOne Plus"; return 1; }
  [ "$("$AAPT2" dump packagename "$1" 2>/dev/null)" = "$PKG" ] || { echo "!! wrong package"; return 1; }
  # capture-then-count: `grep -q` exits early -> unzip SIGPIPEs -> pipefail fails a VALID apk.
  [ "$(unzip -l "$1" 2>/dev/null | grep -c 'lib/arm64-v8a/' || true)" -gt 0 ] || { echo "!! not an arm64 build"; return 1; }
  echo "$TERMONEPLUS_SHA256  $1" | sha256sum -c - >/dev/null 2>&1 || { echo "!! sha mismatch"; return 1; }
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
  echo "   ok (cached): TermOnePlus.apk"; unpack_libs "$OUT"; exit $?
fi
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
  echo ">> using prefetched TermOne Plus APK ($SRC)"
  cp -f "$SRC" "$OUT"
else
  echo ">> downloading TermOne Plus (F-Droid, universal) — ~6 MB"
  curl -fSL -o "$OUT" "$TERMONEPLUS_URL"
fi
verify "$OUT" || { echo "!! TermOne Plus verification failed — refusing to use it"; rm -f "$OUT"; exit 1; }
echo "   verified: TermOnePlus.apk ($PKG, arm64, sha256 pinned)"
unpack_libs "$OUT"
