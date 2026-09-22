# openvpn

Bundles **OpenVPN for Android** (`de.blinkt.openvpn`, GPL-2.0) as a system app, so a build can
reach a self-hosted VPN with nothing to install first.

Builds with `EXTRA_OPTIONS=openvpn`, or by naming it in a preset's `options=`.

## What it does

`fetch.sh` downloads the build F-Droid currently suggests into
`vendor/lineage/prebuilts/openvpn`, verified against a pinned signing certificate, and writes the
Soong module file. The patch adds a `PRODUCT_PACKAGES` line guarded on the APK existing, so a build
without the option is unaffected; `require.sh` fails the build if the option is on and the APK is
missing, and `post-build.sh` proves the APK in the image is byte-identical to the fetched one.

Pin a version with `FDROID_PINS="de.blinkt.openvpn=220"`.

## The signature is F-Droid's, not upstream's

Every other app the forge bundles is signed by its own author and pinned to that key. This one is
signed by **F-Droid** (`CN=FDroid, O=fdroid.org`), because upstream publishes no reproducible build
there. The pin therefore proves *F-Droid built and signed this package*, not *the OpenVPN author
signed it*.

That is exactly the trust you get installing it from F-Droid by hand, and no less — but it is a
different root from the rest, and worth knowing before shipping it in a system image.

## Native libraries

The VPN implementation is `libovpnexec.so` / `libopvpnutil.so`. PackageManager does not extract
native libraries for a bundled app, so when the fetcher finds them compressed or unaligned it
unpacks them beside the APK and `jni/Android.mk` installs them under `app/OpenVPN/lib/arm64/`.
Without that the app installs and simply cannot connect, which looks like a configuration problem
rather than a packaging one.
