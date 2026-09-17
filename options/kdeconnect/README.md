# kdeconnect

KDE Connect (`org.kde.kdeconnect_tp`): phone <-> desktop link -- notifications, clipboard, file
transfer, remote input, media control, "find my phone". Pairs with KDE Connect on Linux desktops
and with GSConnect on GNOME. F-Droid build, F-Droid's signature, ~7 MB, no GMS dependency.

Same shape as `k9`; that README explains the per-branch module choice. Differences only:

```
patches/<branch>/vendor/lineage/   prebuilts/kdeconnect module + guarded PRODUCT_PACKAGES in config/common.mk
fetch.sh                           pulls the APK into vendor/lineage/prebuilts/kdeconnect at sync time
require.sh                         APK present; on 20.0, the build/make presigned-warn patch applied
post-build.sh                      shipped APK byte-identical to the fetched one
```

- The `PRODUCT_PACKAGES` block sits before `# rsync` in `config/common.mk`; `k9` inserts after it,
  `termoneplus` after the Root block, `firefox` at EOF. Each option's hunk must keep a distinct
  anchor or the second patch fails to apply.
- One JNI library (`libandroidx.graphics.path.so`), stored, `extractNativeLibs=false`: loaded from
  the APK directly, so no `jni/` unpacking as in `termoneplus`. The APK passes the 22.2/23.2
  `preprocessed` check as-is; do not add `skip_preprocessed_apk_checks`.
- 20.0 `LOCAL_OPTIONAL_USES_LIBRARIES`: `androidx.window.extensions androidx.window.sidecar
  org.apache.http.legacy`.

## Updating

`prebuilt/fetch-kdeconnect.sh` pins URL + sha256 to one F-Droid versionCode. To move:
`curl -s https://f-droid.org/api/v1/packages/org.kde.kdeconnect_tp` for `suggestedVersionCode`,
download `https://f-droid.org/repo/org.kde.kdeconnect_tp_<code>.apk`, `sha256sum` it, update both
constants. Re-check `aapt2 dump badging` for new `uses-library-not-required` entries and mirror
them in the 20.0 `Android.mk`; re-run `zipalign -c -p 4` and confirm `lib/*.so` are still Stored.
