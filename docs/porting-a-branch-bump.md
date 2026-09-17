# Porting a device to a newer LineageOS branch — order of operations

Written after the ether 18.1 -> 20.0 port (2026-09), where eleven build cycles surfaced eleven
causes one at a time, several of which were predictable before the first build.

## Do these BEFORE the first build

```sh
# 1. Which upstream gates silently exclude this SoC? Cheapest predictor there is.
./tools/check-platform-support.sh <NEW_SRC> device/<vendor>/<codename>

# 2. SELinux types the device references that the new branch deleted.
./tools/find-orphaned-sepolicy-types.sh <OLD_SRC> <NEW_SRC> device/<vendor>/<codename>

# 3. C/C++ constants the new branch removed but the device tree still uses.
./tools/find-removed-platform-symbols.sh <OLD_SRC> <NEW_SRC> device/<vendor>/<codename>
```

Then build with `KEEP_GOING=true` and triage the whole error surface at once:

```sh
KEEP_GOING=true JOBS=<n> PRESET=clean ./forge/bootstrap.sh
./forge/tools/triage-build-log.sh build_output/logs/build.log
```

Fixing one error per 30-minute cycle is the default failure mode of a port. Don't.

## The pattern that costs the most time

**A newer branch drops legacy platforms from a filter, and the failure never points at the filter.**

Seen twice in one port:

| Filter | Symptom |
|---|---|
| `QCOM_BOARD_PLATFORMS` (`qcom_boards.mk`) | Ten "non-existent modules in PRODUCT_PACKAGES" at the *end* of the parse. Bluetooth and the power HAL had been silently gated out by `$(call is-vendor-board-platform,QCOM)` returning false. Nothing errors where the gating happens. |
| `BOARD_SEPOLICY_M4DEFS` exclusion (`device/lineage/sepolicy/qcom/sepolicy.mk`) | `ERROR 'unknown type vendor_hal_perf_default_exec'` in a .te file that looks internally consistent. The m4 defs renamed the domain but not its `_exec` type, and `init_daemon_domain` derives `$1_exec` from the renamed name. |

> **Heuristic:** when something legacy breaks on a newer branch, `git diff` the same file between the
> old and new trees and check whether the old branch **special-cased this platform**. Treat that
> before treating the symptom.

Watch for the inverted form especially — `ifeq (,$(filter <list>,$(TARGET_BOARD_PLATFORM)))` runs
its block when the SoC is **absent**, so being missing from the list means the block **does** apply.

Note upstream is fixing this class: lineage-23.2 replaced the SoC list in that sepolicy gate with a
check on whether `BOARD_VENDOR_SEPOLICY_DIRS` contains a legacy dir — behaviour, not a hardcoded
list. Newer branches may not need the workaround.

## Check the old branch's output image, not your assumptions

When the new branch rejects a `PRODUCT_PACKAGES` entry, look for the artifact in the **old branch's
built image** before deciding what it was:

```sh
find <OLD_SRC>/out/target/product/<codename> -name 'Foo.apk' -o -name 'libfoo.so'
```

On the ether port this split ten rejected entries into four that were never built on the old branch
either (dead weight, safe to delete) and one that genuinely was (a real feature loss to record).
Same error message, opposite conclusions.

## Don't assume a patch is redundant because a file already has one

Two patches touching the same project are usually independent. On the ether port, `vendor/lineage`
needed four unrelated patches; one was dropped at promotion time as a "duplicate" of another and had
to be restored after it caused a build failure.

## Env plumbing

Anything `_build_rom.sh` reads must be added in **two** places — `bootstrap.sh` hands the container
an explicit env list. Missing the second gives no error, just silently unset behaviour.
