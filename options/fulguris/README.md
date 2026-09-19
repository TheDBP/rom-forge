# fulguris

[Fulguris](https://github.com/Slion/Fulguris) as the browser, replacing Jelly. A WebView browser --
the system WebView renders, so this is a better shell around the same engine, not a second engine.

| | |
|---|---|
| package | `net.slions.fulguris.full.fdroid` |
| size | 9.3 MB, no native libraries |
| licence | Apache-2.0 |

What it has over Jelly: named sessions (tab groups), a vertical tab panel with drag-to-reorder and a
recoverable trash, a horizontal tab bar for desktop modes, and an address bar that can sit at the
bottom.

This is what the presets carry by default. `firefox` and `fulguris` on one build is an error
(`require.sh`): both `overrides: ["Jelly"]`. Pick the engine you want -- Fennec is 320 MB staged,
Fulguris is 9 MB, and on a device where the first does not fit the second is the point. Fennec is
still there for a device with the room.

## Shape

The `k9` shape, and see `firefox` for the Jelly override: `patches/<branch>` adds the guarded
`PRODUCT_PACKAGES` line and `prebuilts/fulguris/{.gitignore,jni/Android.mk}`; the APK and the Soong
module file are written per fetch by `prebuilt/fetch-fulguris.sh`, which pins the signer, not the
version.

Only `lineage-22.2` carries patches. On a branch without them the option has nothing to contribute
and the build stops at the option check -- add a patch set before putting it in that device's preset.

## Updating

Nothing to bump for a new release -- the next build fetches it. The signer pin lives in
`prebuilt/fetch-fulguris.sh`; `FDROID_PINS` holds a version when you need one.
