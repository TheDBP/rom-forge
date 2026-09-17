# k9

K-9 Mail (`com.fsck.k9`) as the mail client. LineageOS ships none.

K-9 and Thunderbird for Android are the same codebase (Mozilla owns both); K-9 is the one
without the Thunderbird account-setup funnel, so it is the one bundled. F-Droid build, F-Droid's
signature, ~11 MB, no GMS dependency.

## Shape

```
patches/<branch>/vendor/lineage/   prebuilts/k9 module + guarded PRODUCT_PACKAGES in config/common.mk
fetch.sh                           pulls the APK into vendor/lineage/prebuilts/k9 at sync time
require.sh                         APK present; on 20.0, the build/make presigned-warn patch applied
post-build.sh                      shipped APK byte-identical to the fetched one
```

No device-tree involvement, unlike `firefox`/`fdroid`: the module lives in `vendor/lineage` on every
branch, so the option is the whole feature.

The `PRODUCT_PACKAGES` line is guarded on the APK existing (naming a module with no APK fails
`lunch`); `require.sh` then refuses to build with the option on and the APK absent, so the guard
cannot turn into a silent no-mail image.

## Why the module shape differs per branch

The APK must be installed byte for byte: any rewrite invalidates its v2 signature and, at
targetSdk 35, PackageManager rejects it at boot scan without logging. K-9 ships its native libs
stored but its dex Deflated, and both build systems want to "fix" that.

- **22.2 / 23.2** — `android_app_import { preprocessed: true, skip_preprocessed_apk_checks: true }`.
  Same as `firefox`.
- **20.0** — `preprocessed` does not exist on 13's `android_app_import`. `BUILD_PREBUILT` with
  `LOCAL_SDK_VERSION := current` takes the `do_not_alter_apk` path, whose compression check then
  fails on the Deflated dex. ether-20.0 carries a `build/make` patch that makes it a warning;
  `require.sh` checks for that patch and stops the build if it is missing. A 20.0 device without
  it needs that patch, not a different module.

`LOCAL_OPTIONAL_USES_LIBRARIES` lists every `uses-library required=false` in K-9's manifest
(`com.sec.android.app.multiwindow`, `androidx.window.extensions`, `androidx.window.sidecar`);
`manifest_check.py` fails the build if the two lists differ. The Samsung one does not exist in
the tree and is filtered out of dexpreopt, which is off for this module anyway.

## Updating

`prebuilt/fetch-k9.sh` pins URL + sha256 to one F-Droid versionCode. To move:
`curl -s https://f-droid.org/api/v1/packages/com.fsck.k9` for `suggestedVersionCode`, download
`https://f-droid.org/repo/com.fsck.k9_<code>.apk`, `sha256sum` it, update both constants. Re-check
`aapt2 dump badging` for new `uses-library-not-required` entries and mirror them in the 20.0
`Android.mk`.
