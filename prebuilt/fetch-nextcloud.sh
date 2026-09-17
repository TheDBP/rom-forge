#!/usr/bin/env bash
# fetch-nextcloud.sh — download the Nextcloud bundle for the nextcloud option: the build F-Droid
# currently suggests of each app, verified against a pinned signing certificate (see
# lib-fdroid.sh). Runs in-container (network + aapt2/JDK/zipalign from the tree).
#   ./fetch-nextcloud.sh [AOSP_ROOT]
# FDROID_PINS="com.nextcloud.talk2=240000094 ..." holds any of them to one build.
#
# Each APK ships byte for byte, so what its author packed decides how it is wired, per fetch:
#   - native libraries compressed or unaligned in the APK (NC Passwords today; any of them after some
#     release) -> lib/arm64-v8a/*.so unpacked to <App>/lib/arm64-v8a/ beside it, which the branch's
#     module installs as app/<App>/lib/arm64/. PackageManager does not extract native libraries for
#     a bundled app, so without this the app dies at launch in UnsatisfiedLinkError.
#   - on Soong branches (22.2+; anything whose patch ships no Android.mk here) the module file is
#     WRITTEN here, Android.bp, gitignored: skip_preprocessed_apk_checks has to be set on exactly
#     the APKs Soong's check fails, and Soong refuses it on one that passes, so a static file cannot
#     be right across releases. 20.0's Android.mk needs no per-app knowledge (a wildcard on the
#     unpacked libraries) and comes from the patch.
set -euo pipefail

AOSP="${1:-/aosp}"; export AOSP
DEST="${FEATURE_DEST:-$AOSP/vendor/lineage/prebuilts/nextcloud}"
. "$(dirname "${BASH_SOURCE[0]}")/lib-fdroid.sh"

# module name | package | signer certificate sha256 (apksigner verify --print-certs, Signer #1)
# Files and Talk are Nextcloud GmbH's reproducible builds under Nextcloud's own key; the others are
# their authors' keys, as F-Droid publishes them. Read on 2026-09-17.
NEXTCLOUD_APPS='
NextcloudFiles  com.nextcloud.client                  5709576f9d6c6a7687dd5d56b269d1fa5e379702b91bc83f39fd7b7c597c1b83
NextcloudTalk   com.nextcloud.talk2                   5709576f9d6c6a7687dd5d56b269d1fa5e379702b91bc83f39fd7b7c597c1b83
NextPush        org.unifiedpush.distributor.nextpush  be6b681667944be91a62bc0f05200c5fcb9bc776a3a90b5b67ee0b9b9b063db4
NextcloudDeck   it.niedermann.nextcloud.deck          ea929cafc33a6ca77392809f53b1daf80992c4a83f4d11433200174493aebe93
NCPasswords     de.jbservices.nc_passwords_app        1c15bcadd013d7c0632f5a63604008f73d340e25de1b676fb22ca51287fffe1e
NextcloudNotes  it.niedermann.owncloud.notes          3e80f32df2c89e4cdd3a32f1002178d8d4f21b9da89f8add6abae29fd3c95c0b
DAVx5           at.bitfire.davdroid                   8b48e676a6864967791783c1d8d0fc0dd6d2ce33e1fb36787793ecd086d44707
Tasks           org.tasks                             a038a055bf43b2659cbaf862808afd5e447d4d0e2749a10391910009cbd8dcfa
'

# Called with no arguments from anything that only wants the module list (require.sh, post-build.sh).
nextcloud_modules() { printf '%s\n' "$NEXTCLOUD_APPS" | awk 'NF==3 {print $1}'; }
[ "${NEXTCLOUD_LIST_ONLY:-0}" = 1 ] && { nextcloud_modules; exit 0; }

mkdir -p "$DEST"
fail=0
unpacked=""
while read -r mod pkg signer; do
  [ -n "$mod" ] || continue
  fdroid_fetch_latest "$pkg" "$DEST/$mod.apk" "$signer" "$mod" || { fail=1; continue; }
  # Re-derived on every run from the APK that is there, so a release that changes its packaging
  # changes the wiring with it, in either direction.
  rm -rf "${DEST:?}/$mod"
  loadable="$(fdroid_apk_libs_loadable "$DEST/$mod.apk")" || { fail=1; continue; }
  if [ "$loadable" = no ]; then
    mkdir -p "$DEST/$mod"
    unzip -q -o "$DEST/$mod.apk" 'lib/arm64-v8a/*.so' -d "$DEST/$mod" || { echo "!! $mod: could not unpack native libraries" >&2; fail=1; continue; }
    echo "   $mod: native libraries not loadable from the APK; unpacked $(ls "$DEST/$mod/lib/arm64-v8a" | wc -l) beside it"
    unpacked="$unpacked $mod"
  fi
done <<EOF
$(printf '%s\n' "$NEXTCLOUD_APPS" | awk 'NF==3')
EOF
[ "$fail" = 0 ] || { echo "!! nextcloud: one or more apps failed to fetch — see above" >&2; exit 1; }

if [ ! -f "$DEST/Android.mk" ]; then
  {
    echo "// Written by forge/prebuilt/fetch-nextcloud.sh on every fetch from the APKs it fetched;"
    echo "// gitignored, not edited by hand. Native libraries for the apps marked below are unpacked"
    echo "// beside the APK and installed by jni/Android.mk."
    echo "//"
    echo "// preprocessed: true installs each APK byte for byte. Any rewrite (uncompressing libs or dex,"
    echo "// re-aligning) invalidates the whole-file APK Signature Scheme v2 signature, and PackageManager"
    echo "// then rejects the package at boot scan without logging, so the build succeeds and the app is"
    echo "// absent. skip_preprocessed_apk_checks goes on exactly the APKs whose native libraries are"
    echo "// compressed or unaligned: Soong fails the build if it is set on one that passes the check."
    echo "// enforce_uses_libs: false -- the build otherwise refuses any APK whose manifest <uses-library>"
    echo "// tags it was not told about, and those change with releases."
    while read -r mod pkg signer; do
      [ -n "$mod" ] || continue
      echo
      echo "// $pkg"
      echo "android_app_import {"
      echo "    name: \"$mod\","
      echo "    apk: \"$mod.apk\","
      echo "    presigned: true,"
      echo "    preprocessed: true,"
      case " $unpacked " in *" $mod "*) echo "    skip_preprocessed_apk_checks: true, // libraries unpacked to $mod/lib/arm64-v8a/" ;; esac
      echo "    product_specific: true,"
      echo "    enforce_uses_libs: false,"
      echo "}"
    done <<EOF
$(printf '%s\n' "$NEXTCLOUD_APPS" | awk 'NF==3')
EOF
  } > "$DEST/Android.bp"
  echo "   nextcloud: wrote $DEST/Android.bp (${unpacked:- no app} with unpacked libraries)"
fi
echo "   nextcloud: $(nextcloud_modules | wc -l) apps in $DEST ($(du -sh "$DEST" | cut -f1))"
