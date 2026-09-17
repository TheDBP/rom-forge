# termoneplus

TermOne Plus (`com.termoneplus`) as the terminal emulator. LineageOS 20.0+ ships none: AOSP dropped
`packages/apps/Terminal` after 13, and `terminal-visible` only covers 18.1/19.1.

The maintained fork of the classic Android Terminal Emulator: a local shell and nothing else, ~6 MB,
targetSdk 36, GPL-3.0. F-Droid build, F-Droid's signature, so F-Droid updates it in place.

It is its own option rather than part of `root` or `linux`: it needs neither (a terminal is useful
unrooted), and both of those are useful from `adb shell` without it. It is the way *in* to both from
the phone -- `su`, then `linux` for the chroot -- so `libre` and `full` carry it.

## Why not Termux

Termux is the better-known choice and stays on F-Droid as a one-tap install. It is not bundled
because it targets SDK 28 by design (Android 10+ forbids apps targeting 29+ from executing binaries
in their data directory, which is Termux's whole model), so Play Protect flags it on every GApps
build, and its 114 MB userland duplicates what the `linux` chroot already provides.

## Shape

```
patches/<branch>/vendor/lineage/   prebuilts/termoneplus module + JNI modules + guarded PRODUCT_PACKAGES
fetch.sh                           pulls the APK into vendor/lineage/prebuilts/termoneplus, unpacks lib/arm64-v8a/
require.sh                         APK + libraries present; on 20.0, the build/make presigned-warn patch applied
post-build.sh                      shipped APK byte-identical to the fetched one, libterm-system.so beside it
```

No device-tree involvement: the module lives in `vendor/lineage` on every branch, so the option is
the whole feature. Same shape as `k9`, plus the native libraries.

## Native libraries ship beside the APK

The terminal's pty handling is JNI (`libterm-system.so` and three helpers). PackageManager never
extracts native libraries for a bundled system app and the linker cannot dlopen a compressed zip
entry, so without the unpacked copy beside the APK every launch dies in `UnsatisfiedLinkError`.
Same mechanism as `firefox`:

- **22.2 / 23.2** -- `android_app_import { preprocessed: true, skip_preprocessed_apk_checks: true }`
  for the APK; `jni/Android.mk` installs each `lib/arm64-v8a/*.so` as `app/TermOnePlus/lib/arm64/`,
  one Make module per library, added to `PRODUCT_PACKAGES` from the same wildcard in `common.mk`.
- **20.0** -- `BUILD_PREBUILT` with `LOCAL_SDK_VERSION := current` (verbatim copy) and
  `LOCAL_PREBUILT_JNI_LIBS`. The dex is Deflated, so the copy path's compression check needs the
  `build/make` warn-instead-of-fail patch ether-20.0 carries; `require.sh` refuses to build
  without it.

The 20.0 module sets `LOCAL_ENFORCE_USES_LIBRARIES := false` rather than mirroring the manifest's
optional `uses-library` entries (the 570 build declares two); the check only guards dexpreopt,
which is off for the module.

## No 21.0 patches

Same as `k9`: nothing has been built on 21.0 yet. Enabling `termoneplus` there fetches the APK but
adds no module, so the build compiles and then fails in `post-build.sh` (no `TermOnePlus.apk` in the
image). Add a `lineage-21.0` patch first (the 20.0 one is the starting point).

## Updating

`prebuilt/fetch-termoneplus.sh` pins URL + sha256 to one F-Droid versionCode. To move:
`curl -s https://f-droid.org/api/v1/packages/com.termoneplus` for `suggestedVersionCode`, download
`https://f-droid.org/repo/com.termoneplus_<code>.apk`, `sha256sum` it, update both constants.
Re-check `unzip -l` for
the `lib/arm64-v8a/*.so` set -- the wildcards pick those up, the `require.sh`/`post-build.sh` checks
only name `libterm-system.so`.
