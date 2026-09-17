#!/usr/bin/env bash
# fetch-kdeconnect.sh — download the KDE Connect APK (GPL-2.0+, F-Droid-signed) for the kdeconnect
# option. Runs in-container (network + aapt2 from the tree). Verified by package name, arm64 ABI and
# a pinned sha256 (the URL names one exact versionCode, so the hash is stable); set KDECONNECT_URL
# and KDECONNECT_SHA256 together to move to a newer build.
#   ./fetch-kdeconnect.sh [AOSP_ROOT]
# If KDECONNECT_SRC points at an already-downloaded APK (staged by the prefetch phase), it is
# verified and installed instead of re-downloading.
set -euo pipefail

AOSP="${1:-/aosp}"
SRC="${KDECONNECT_SRC:-}"
DEST="${FEATURE_DEST:-$AOSP/vendor/lineage/prebuilts/kdeconnect}"
OUT="$DEST/KDEConnect.apk"
PKG="org.kde.kdeconnect_tp"
# KDE Connect 1.35.15 (versionCode 13515), F-Droid build. Override with KDECONNECT_URL + KDECONNECT_SHA256.
KDECONNECT_URL="${KDECONNECT_URL:-https://f-droid.org/repo/org.kde.kdeconnect_tp_13515.apk}"
KDECONNECT_SHA256="${KDECONNECT_SHA256:-a3835741e0d037d7693d196acdf784817121aec647605b33b0dc69a8eac9247c}"
AAPT2="$(command -v aapt2 || echo "$AOSP/prebuilts/sdk/tools/linux/bin/aapt2")"

mkdir -p "$DEST"
verify() {  # $1 = apk
  [ -x "$AAPT2" ] || { echo "!! aapt2 not found — cannot verify KDE Connect"; return 1; }
  [ "$("$AAPT2" dump packagename "$1" 2>/dev/null)" = "$PKG" ] || { echo "!! wrong package"; return 1; }
  # capture-then-count: `grep -q` exits early -> unzip SIGPIPEs -> pipefail fails a VALID apk.
  [ "$(unzip -l "$1" 2>/dev/null | grep -c 'lib/arm64-v8a/' || true)" -gt 0 ] || { echo "!! not an arm64 build"; return 1; }
  echo "$KDECONNECT_SHA256  $1" | sha256sum -c - >/dev/null 2>&1 || { echo "!! sha mismatch"; return 1; }
  return 0
}

if [ -f "$OUT" ] && verify "$OUT" >/dev/null 2>&1; then
  echo "   ok (cached): KDEConnect.apk"; exit 0
fi
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
  echo ">> using prefetched KDE Connect APK ($SRC)"
  cp -f "$SRC" "$OUT"
else
  echo ">> downloading KDE Connect (F-Droid, arm64) — ~7 MB"
  curl -fSL -o "$OUT" "$KDECONNECT_URL"
fi
verify "$OUT" || { echo "!! KDE Connect verification failed — refusing to use it"; rm -f "$OUT"; exit 1; }
echo "   verified: KDEConnect.apk ($PKG, arm64, sha256 pinned)"
