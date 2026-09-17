#!/usr/bin/env bash
# fetch-fdroid.sh — download the pinned, sha256-verified F-Droid client + Privileged Extension
# from f-droid.org (GPLv3, redistributable) for the bake-in. Not vendored in git. Idempotent.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="https://f-droid.org/repo"

# pkg-file  sha256  destination-name
CLIENT_APK="org.fdroid.fdroid_1023052.apk"
CLIENT_SHA="985f5181d48bb6bafd54083a048b391271e0ab28385881cc41294fb01a222762"
PRIV_APK="org.fdroid.fdroid.privileged_2070.apk"
PRIV_SHA="429bde81414c8779283c2e552c4d27893ca8ed17dff6d7296cf2a06ff197672e"

# FEATURE_DEST (set by the apps/fdroid feature) -> place each APK in its module subdir; else legacy $HERE.
if [ -n "${FEATURE_DEST:-}" ]; then
  mkdir -p "$FEATURE_DEST/FDroid" "$FEATURE_DEST/FDroidPrivilegedExtension"
  CLIENT_DST="$FEATURE_DEST/FDroid/FDroid.apk"
  PRIV_DST="$FEATURE_DEST/FDroidPrivilegedExtension/FDroidPrivilegedExtension.apk"
else
  CLIENT_DST="$HERE/FDroid.apk"; PRIV_DST="$HERE/FDroidPrivilegedExtension.apk"
fi

fetch() {
  local src="$1" sha="$2" dst="$3"
  if [ -f "$dst" ] && echo "$sha  $dst" | sha256sum -c - >/dev/null 2>&1; then
    echo "   ok (cached): $(basename "$dst")"; return 0
  fi
  echo ">> downloading $(basename "$dst")"
  curl -fsSL -o "$dst" "$BASE/$src"
  echo "$sha  $dst" | sha256sum -c - >/dev/null 2>&1 \
    || { echo "!! sha256 mismatch for $(basename "$dst") — refusing to use it"; rm -f "$dst"; exit 1; }
  echo "   verified: $(basename "$dst")"
}

fetch "$CLIENT_APK" "$CLIENT_SHA" "$CLIENT_DST"
fetch "$PRIV_APK"   "$PRIV_SHA"   "$PRIV_DST"
