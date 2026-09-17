# gapps

Google apps: Play Store and GMS from MindTheGapps, plus Google's versions of the stock apps.

## What was device-specific and wasn't

Three devices carried three hand-written implementations of the same two lines:

```make
ifeq ($(WITH_GAPPS),true)
$(call inherit-product-if-exists, vendor/gapps/arm64/arm64-vendor.mk)
-include .../gapps-extras/packages.mk
endif
```

Identical on ether, bonito and vs995, because they are not facts about any of those phones — they
are what `WITH_GAPPS` means. That is the whole of this option's `product.mk`.

What genuinely stayed with the devices:

- **bonito**: the product partition has to be sized to fit GApps. That is a real fact about that
  device's partition layout.
- **ether**: nothing any more. It used to carry a GApps-flavoured home screen and browser/dialer/SMS
  role defaults in an `overlay-gapps` directory. Both were wrong: every option that installs an app
  already replaces the incumbent via `LOCAL_OVERRIDES_PACKAGES`, so exactly one candidate exists for
  each role and naming one could only ever be wrong on a build where that option was off. The home
  screen half silently overrode the `minimal-home` option. `overlay-gapps` is gone.

## Where the apps are staged

`forge/tools/extract-gapps-apps.sh` writes to **`vendor/extra/gapps-extras/`**, not the device
tree. Two reasons:

1. The option is then the same everywhere, with no device patch to include it.
2. From Android 16 (lineage-23.0) `build/soong/ui/build/androidmk_denylist.go` rejects `Android.mk`
   under `device/google/`, `device/generic/`, `device/common/` and more — *failing lunch outright*.
   These prebuilts used to live exactly there. (They are emitted as `Android.bp` for the same
   reason; `vendor/extra` removes the hazard entirely.)

The extractor sweeps the old `device/<vendor>/<codename>/gapps-extras/` on the way past. A tree
built before this change still has one, and leaving it would mean two copies of every Google app
with a single `-include` line deciding which set won — a stale set looks exactly like a fresh one.

## require.sh

The extractor runs only from `bootstrap.sh`'s sync phase. A rebuild after a device retarget, or any
direct `_build_rom.sh` call, would otherwise ship a `WITH_GAPPS` ROM whose stock apps were never
swapped — and it would *look* right, because Play Store and GMS come from the `vendor/gapps`
manifest repo and would still be there. Silently wrong contents.

That check used to run after the compile. It now runs before it.

## What this ships, and what it deliberately does not

Velvet — the Google app, Search and Assistant — is removed on every branch. It is the largest single
item in the set (276 MB on `vic`) and the one least likely to be opened. `patches/<branch>/vendor/gapps/`
carries the removal, per branch because the package list genuinely differs: on `rho` Velvet is the
last entry with no trailing backslash, so dropping it also means fixing the line above.

`SpeechServicesByGoogle` and `talkback` share the same upstream guard and stay — voice typing and
accessibility, and far smaller. `VelvetTitan` sits behind a `tangorpro`-only guard no device here
matches. The `-1` feed is off separately, via the `google-feed-off` option.

## Two "Files" apps

Installing Google Files leaves two launcher entries both labelled *Files*, because AOSP's
DocumentsUI resolves its `launcher_label` to `files_label` = "Files". The
`patches/lineage-*/packages/apps/DocumentsUI` patch points it at `chip_title_documents` instead:
**Documents**, in every locale DocumentsUI ships. Not an overlay: `launcher_label` is not in
DocumentsUI's `<overlayable>` list, so an RRO on it is refused (`STATE_NO_IDMAP`) and silently does
nothing.

DocumentsUI is renamed rather than removed, and that is deliberate. It is the provider behind
`ACTION_OPEN_DOCUMENT` and the Storage Access Framework, so overriding the package would break every
file picker on the device, not just its own icon. Its launcher entry is an `activity-alias` with no
`android:enabled` hook, so an overlay cannot hide it either; hiding would mean patching its manifest.
A one-line string patch renames it and ends the collision at no risk.
