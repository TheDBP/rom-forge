#!/usr/bin/env bash
# lib-fdroid.sh — fetch the build F-Droid currently suggests for a package, trusting the signer,
# not a file hash. Source it; then:
#
#   fdroid_fetch_latest PKG OUT SIGNER_SHA256 [LABEL]
#
# Resolves PKG's suggestedVersionCode from the F-Droid API, downloads that APK to OUT unless OUT
# already is that version, and accepts it only if
#   - aapt2 reports the package name PKG,
#   - it carries arm64-v8a native code (an armeabi-only build would install and then crash),
#   - apksigner verifies it and the first signer certificate's sha256 is SIGNER_SHA256.
# The signer pin is what makes "latest" safe: the key is the one thing that does not change between
# releases, and it is checked over the whole file (v2/v3 signature), so a tampered or truncated
# download fails here. To get a new signing key accepted, change the pin on purpose.
#
# FDROID_PINS="pkg=versionCode pkg=versionCode" pins packages to one exact build instead (to
# reproduce a release, or to hold back a known-bad update). Anything not listed stays on latest.
#
# Offline: if the API cannot be reached but OUT exists and verifies, it is used with a warning; a
# missing or bad OUT is an error. Runs in-container: needs curl, unzip, and the tree's aapt2, JDK
# and apksigner.jar (AOSP in $AOSP, default /aosp).
set -o pipefail

FDROID_API="${FDROID_API:-https://f-droid.org/api/v1/packages}"
FDROID_REPO="${FDROID_REPO:-https://f-droid.org/repo}"
FDROID_ARCHIVE="${FDROID_ARCHIVE:-https://f-droid.org/archive}"
# Official mirrors (f-droid.org/docs/Running-a-Mirror), tried after the primary. Safe to use: every
# download is accepted only on the pinned signer, so a mirror can at most fail to have the file.
FDROID_MIRRORS="${FDROID_MIRRORS:-https://mirror.cyberbits.eu/fdroid https://ftp.lysator.liu.se/pub/fdroid https://fdroid.tetaneutral.net/fdroid https://mirror.fcix.net/fdroid https://ftp.fau.de/fdroid}"

_fdroid_aapt2() {
  command -v aapt2 2>/dev/null || echo "${AOSP:-/aosp}/prebuilts/sdk/tools/linux/bin/aapt2"
}
_fdroid_java() {
  local j
  j="$(ls -d "${AOSP:-/aosp}"/prebuilts/jdk/jdk*/linux-x86/bin/java 2>/dev/null | sort -V | tail -1)"
  [ -x "$j" ] && { echo "$j"; return; }
  command -v java
}
_fdroid_apksigner_jar() { echo "${AOSP:-/aosp}/prebuilts/sdk/tools/linux/lib/apksigner.jar"; }
_fdroid_zipalign() { echo "${AOSP:-/aosp}/prebuilts/build-tools/linux-x86/bin/zipalign"; }

# apk -> versionCode as aapt2 reads it, or empty
fdroid_apk_version_code() {
  "$(_fdroid_aapt2)" dump badging "$1" 2>/dev/null | sed -n "s/^package:.*versionCode='\([0-9]*\)'.*/\1/p" | head -1
}
fdroid_apk_version_name() {
  "$(_fdroid_aapt2)" dump badging "$1" 2>/dev/null | sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p" | head -1
}
# apk -> sha256 of the first signer certificate, only if the signature verifies; empty otherwise
fdroid_apk_signer() {
  local java jar
  java="$(_fdroid_java)"; jar="$(_fdroid_apksigner_jar)"
  [ -x "$java" ] && [ -f "$jar" ] || { echo "!! no JDK or apksigner.jar in the tree — cannot verify signatures" >&2; return 1; }
  "$java" -jar "$jar" verify --print-certs "$1" 2>/dev/null | sed -n 's/^Signer #1 certificate SHA-256 digest: *\([0-9a-f]*\).*/\1/p' | head -1
}

# apk -> "yes" if its native libraries can be loaded straight out of the archive (every lib/**/*.so
# stored, archive page-aligned), "no" otherwise; nonzero if it cannot tell. This is exactly Soong's
# check_prebuilt_presigned_apk.py test for a preprocessed APK: skip_preprocessed_apk_checks must be
# set on a "no" APK and must NOT be set on a "yes" one, or the build fails either way. A "no" APK
# shipped byte for byte also needs its arm64 libraries unpacked beside it: PackageManager does not
# extract native libraries for a bundled app, and the linker cannot dlopen a compressed entry.
fdroid_apk_libs_loadable() {
  local za n
  za="$(_fdroid_zipalign)"
  [ -x "$za" ] || { echo "!! zipalign not found in the tree — cannot classify $1" >&2; return 1; }
  if ! "$za" -c -p 4 "$1" >/dev/null 2>&1; then echo no; return 0; fi
  n="$(unzip -v "$1" 'lib/*.so' 2>/dev/null | awk '$NF ~ /^lib\/.*\.so$/ && $2 != "Stored" {c++} END {print c+0}')"
  [ "$n" -gt 0 ] && echo no || echo yes
}

# pkg -> suggestedVersionCode, or nonzero (offline, unknown package)
fdroid_latest_version_code() {
  local json
  json="$(curl -fsS --max-time 30 "$FDROID_API/$1")" || return 1
  printf '%s' "$json" | sed -n 's/.*"suggestedVersionCode":\([0-9]*\).*/\1/p' | head -1 | grep -E '^[0-9]+$'
}

# _fdroid_verify APK PKG SIGNER -> 0 if the apk is PKG, arm64, and signed by SIGNER
_fdroid_verify() {
  local apk="$1" pkg="$2" signer="$3" aapt2 got
  aapt2="$(_fdroid_aapt2)"
  [ -x "$aapt2" ] || { echo "!! aapt2 not found — cannot verify $apk" >&2; return 1; }
  [ "$("$aapt2" dump packagename "$apk" 2>/dev/null)" = "$pkg" ] || { echo "!! $apk: wrong package (want $pkg)" >&2; return 1; }
  # capture-then-count: `grep -q` exits early -> unzip SIGPIPEs -> pipefail fails a VALID apk.
  [ "$(unzip -l "$apk" 2>/dev/null | grep -c 'lib/arm64-v8a/' || true)" -gt 0 ] || { echo "!! $apk: not an arm64 build" >&2; return 1; }
  got="$(fdroid_apk_signer "$apk")" || return 1
  [ "$got" = "$signer" ] || { echo "!! $apk: signer $got is not the pinned $signer" >&2; return 1; }
}

# _fdroid_download FILE DEST: primary repo, primary archive, each mirror's repo and archive
_fdroid_download() {
  local base
  for base in "$FDROID_REPO" "$FDROID_ARCHIVE" $(for m in $FDROID_MIRRORS; do echo "$m/repo $m/archive"; done); do
    curl -fsL --retry 2 --max-time 1800 -o "$2" "$base/$1" && return 0
  done
  return 1
}

fdroid_fetch_latest() {
  local pkg="$1" out="$2" signer="$3" label="${4:-$1}" want have pin tmp
  mkdir -p "$(dirname "$out")"

  pin="$(printf '%s\n' ${FDROID_PINS:-} | sed -n "s/^$pkg=\([0-9]*\)$/\1/p" | head -1)"
  if [ -n "$pin" ]; then
    want="$pin"; echo "   $label: pinned to versionCode $want (FDROID_PINS)"
  elif ! want="$(fdroid_latest_version_code "$pkg")"; then
    if [ -f "$out" ] && _fdroid_verify "$out" "$pkg" "$signer"; then
      echo "   $label: F-Droid unreachable; using the cached $(fdroid_apk_version_name "$out") (verified)"
      return 0
    fi
    echo "!! $label: cannot resolve the current F-Droid build of $pkg and no verified copy is cached" >&2
    return 1
  fi

  if [ -f "$out" ]; then
    have="$(fdroid_apk_version_code "$out")"
    if [ "$have" = "$want" ] && _fdroid_verify "$out" "$pkg" "$signer" 2>/dev/null; then
      echo "   ok (cached): $label $(fdroid_apk_version_name "$out") ($want)"
      return 0
    fi
  fi

  # Primary repo/ and archive/, then the mirrors: the primary has been seen 404 a file the API
  # still suggests while every mirror served it. If nothing has it, a verified cached copy of any
  # version beats no app.
  tmp="$out.download"
  echo ">> downloading $label ${pkg}_$want.apk (F-Droid)"
  if ! _fdroid_download "${pkg}_$want.apk" "$tmp"; then
    rm -f "$tmp"
    if [ -f "$out" ] && _fdroid_verify "$out" "$pkg" "$signer"; then
      echo "   $label: F-Droid has no ${pkg}_$want.apk right now; using the cached $(fdroid_apk_version_name "$out") (verified)"
      return 0
    fi
    echo "!! $label: download failed and no verified copy is cached" >&2; return 1
  fi
  _fdroid_verify "$tmp" "$pkg" "$signer" || { rm -f "$tmp"; echo "!! $label: verification failed — refusing to use it" >&2; return 1; }
  mv -f "$tmp" "$out"
  echo "   verified: $label $(fdroid_apk_version_name "$out") ($want) — $pkg, arm64, signer pinned"
}
