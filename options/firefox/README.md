# firefox

Firefox (Fennec F-Droid) as the browser, replacing Jelly.

## What it does

Installs Firefox (Fennec F-Droid) and gets out of the way. The module carries
`LOCAL_OVERRIDES_PACKAGES := Jelly`, so exactly one browser ends up on the image and Android resolves
the browser role on its own — nothing has to declare a default.

The package line is guarded on the APK existing, because naming a module whose APK was never fetched
fails the whole build before anything compiles:

```
lineage_ether.mk includes non-existent modules in PRODUCT_PACKAGES
Offending entries: Firefox
```

The option owns all of it — the patch, the fetch, and the guard — so the three cannot disagree.

## Shape

```
patches/<branch>/vendor/lineage/   the prebuilt module and the guarded PRODUCT_PACKAGES line
fetch.sh                           pulls the APK into vendor/lineage/prebuilts/firefox
```

`fetch.sh` runs at **sync time**, not before the build, because `PRODUCT_PACKAGES` is resolved during
product config — a module that does not exist yet is not "missing later", it fails `lunch` outright.

## Why the patches are branch-scoped

Patches are diffs against upstream source, and upstream changes per release. That is not theoretical:
across the feature set this replaced, `themed-icons` has three distinct versions (19.1, 20.0, and
22.2/23.2), and `nfc-off` and `livedisplay-off` each have two. An option whose patches were shared
across branches would apply the wrong diff somewhere.

Everything else in an option — `product.mk`, `tree/`, the hooks — is text we wrote, so it applies to
every branch unchanged. Only `patches/` is scoped.

There are no patches for 19.1 or 20.0 here because those branches need none: the option's
`fetch.sh`/`post-patch.sh` place the APK and the ether device tree carries the module (see below).
An option with no patches for the branch and nothing else to contribute is a hard error; this one
always has the fetch.

## It appears as "Fennec"

The package is `org.mozilla.fennec_fdroid` and its `application-label` is **Fennec**, which is what
the F-Droid build of Firefox calls itself. Looking for "Firefox" in the launcher will not find it.

## Why the module sets `LOCAL_SDK_VERSION`

`BUILD_PREBUILT` with `LOCAL_CERTIFICATE := PRESIGNED` rewrites the archive — it uncompresses every
embedded `.so` — and an APK Signature Scheme v2 signature covers the whole file, so the re-zip
invalidates it. Fennec is mostly `libxul.so`: the APK went from 127,545,689 bytes fetched to
242,684,607 installed, and the device refused it with `INSTALL_PARSE_FAILED_NO_CERTIFICATES`.
PackageManager hits that during the boot scan and skips the package silently, so the build succeeds
and the browser is simply absent.

`LOCAL_SDK_VERSION` selects the `do_not_alter_apk` path: copy, then check alignment and compression
only. Soong's `preprocessed: true` does the same thing but does not exist on `android_app_import`
before 14, so it cannot be used on the older branches.

`post-build.sh` compares the installed APK against the fetched one and fails the build on any
difference, so this cannot recur silently.

## Native libraries ship beside the APK

PackageManager never extracts native libraries for a bundled system app
(`PackageAbiHelperImpl.shouldExtractLibs`), and the linker cannot dlopen a compressed zip entry, so
an unmodified Fennec APK on its own crashes at launch with `UnsatisfiedLinkError:
libjnidispatch.so`. `fetch-firefox.sh` unpacks `lib/arm64-v8a/` next to the APK and the module
installs it as `<app>/lib/arm64/*.so` -- `LOCAL_PREBUILT_JNI_LIBS` on the ether tree; on 22.2/23.2,
where `android_app_import` has no such property, one `BUILD_PREBUILT` module per library in
`prebuilts/firefox/jni/Android.mk`, added to `PRODUCT_PACKAGES` from the same wildcard.

## Which branches carry patches

Only 22.2 and 23.2 have patches here, because only those need a module added to `vendor/lineage`.
The ether branches ship Firefox through a module in their own device tree instead — so "no patches
for 20.0" does not mean "no Firefox on 20.0".
