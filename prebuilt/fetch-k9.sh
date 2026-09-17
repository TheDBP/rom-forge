#!/usr/bin/env bash
# fetch-k9.sh — download the K-9 Mail APK (Thunderbird for Android's codebase, Apache-2.0,
# F-Droid-signed) for the k9 option. Runs in-container (network + aapt2 from the tree). Verified by
# package name, arm64 ABI and a pinned sha256 (the URL names one exact versionCode, so the hash is
# stable); set K9_URL and K9_SHA256 together to move to a newer build.
#   ./fetch-k9.sh [AOSP_ROOT]
# If K9_SRC points at an already-downloaded APK (staged by the prefetch phase), it is verified and
# installed instead of re-downloading.
set -euo pipefail

AOSP="${1:-/aosp}"
SRC="${K9_SRC:-}"
DEST="${FEATURE_DEST:-$AOSP/vendor/lineage/prebuilts/k9}"
OUT="$DEST/K9Mail.apk"
PKG="com.fsck.k9"
# K-9 Mail 22.0 (versionCode 39043), F-Droid build. Override with K9_URL + K9_SHA256.
K9_URL="${K9_URL:-https://f-droid.org/repo/com.fsck.k9_39043.apk}"
K9_SHA256="${K9_SHA256:-a08f4f1816977d996dce4ab91732d918a13e9c02bed6080ac2b372c370b9da80}"
AAPT2="$(command -v aapt2 || echo "$AOSP/prebuilts/sdk/tools/linux/bin/aapt2")"

mkdir -p "$DEST"
verify() {  # $1 = apk
  [ -x "$AAPT2" ] || { echo "!! aapt2 not found — cannot verify K-9"; return 1; }
  [ "$("$AAPT2" dump packagename "$1" 2>/dev/null)" = "$PKG" ] || { echo "!! wrong package"; return 1; }
  # capture-then-count: `grep -q` exits early -> unzip SIGPIPEs -> pipefail fails a VALID apk.
  [ "$(unzip -l "$1" 2>/dev/null | grep -c 'lib/arm64-v8a/' || true)" -gt 0 ] || { echo "!! not an arm64 build"; return 1; }
  echo "$K9_SHA256  $1" | sha256sum -c - >/dev/null 2>&1 || { echo "!! sha mismatch"; return 1; }
  return 0
}

if [ -f "$OUT" ] && verify "$OUT" >/dev/null 2>&1; then
  echo "   ok (cached): K9Mail.apk"; exit 0
fi
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
  echo ">> using prefetched K-9 APK ($SRC)"
  cp -f "$SRC" "$OUT"
else
  echo ">> downloading K-9 Mail (F-Droid, arm64) — ~11 MB"
  curl -fSL -o "$OUT" "$K9_URL"
fi
verify "$OUT" || { echo "!! K-9 verification failed — refusing to use it"; rm -f "$OUT"; exit 1; }
echo "   verified: K9Mail.apk ($PKG, arm64, sha256 pinned)"
