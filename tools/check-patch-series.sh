#!/usr/bin/env bash
# check-patch-series.sh — find patches that undo earlier patches in the same series.
#
#   check-patch-series.sh [DEVICE_REPO] [--quiet]
#
# A patch series is not a history. It is a description of how the tree differs from upstream, and it
# is replayed from scratch every time the tree is synced. So a patch that adds a line and a later
# patch that removes it are not "two steps of the work" -- they are one change, written twice, where
# a reader has to hold both in their head to know what the tree actually contains.
#
# It happens naturally and it is invisible without a check like this:
#
#   - a value is tuned, then retuned (a dimension set to one number, then another)
#   - something is added, found not to work, and removed (dead config nobody notices is dead)
#   - a feature is staged across commits -- stubs first, implementation later -- which reads fine as
#     history and badly as a series
#   - a flag is set true, then set false by a later patch, so the series says both
#
# Detection: for every line an earlier patch ADDS, see whether a later patch REMOVES it. Short and
# whitespace-only lines are skipped, since braces and blank lines move around constantly and mean
# nothing. The result is advisory -- collapsing a series is a rebase, not something to do
# automatically -- but it should be seen every time the patches are regenerated.
set -uo pipefail

ARG=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARG="$1"; shift ;;
  esac
done
DEVICE_REPO="${ARG:-$(cd "$(dirname "$0")/../.." && pwd)}"
PDIR="$DEVICE_REPO/overlay/patches"
[ -d "$PDIR" ] || { echo "!! no overlay/patches under $DEVICE_REPO" >&2; exit 1; }
export LC_ALL=C

python3 - "$PDIR" "$QUIET" <<'PY'
import os, sys, glob

pdir, quiet = sys.argv[1], sys.argv[2] == "1"
total_pairs = 0
report = []

for root, dirs, files in os.walk(pdir):
    pats = sorted(f for f in files if f.endswith('.patch'))
    if len(pats) < 2:
        continue
    project = os.path.relpath(root, pdir)
    added = {}      # body -> first patch that added it
    undo = {}       # (later, earlier) -> [bodies]
    for p in pats:
        num = p[:4]
        with open(os.path.join(root, p), encoding='utf-8', errors='replace') as fh:
            for raw in fh:
                if raw.startswith(('+++', '---', '@@')):
                    continue
                body = raw[1:].strip()
                # short lines are punctuation and noise: braces, blank lines, "endif"
                if len(body) < 12:
                    continue
                if raw.startswith('+'):
                    added.setdefault(body, num)
                elif raw.startswith('-'):
                    first = added.get(body)
                    if first is not None and first != num:
                        undo.setdefault((num, first), []).append(body)
    if undo:
        report.append((project, undo))
        total_pairs += len(undo)

if not report:
    if not quiet:
        print(">> patch series: no patch undoes an earlier one")
    sys.exit(0)

print(">> patch series: %d patch pair(s) where a later patch undoes an earlier one" % total_pairs)
for project, undo in report:
    print("   %s" % project)
    for (later, earlier), bodies in sorted(undo.items()):
        print("     %s undoes %s  (%d line(s))" % (later, earlier, len(bodies)))
        for b in bodies[:2]:
            print("         %s" % (b[:96] + ('…' if len(b) > 96 else '')))
print()
print("   A series is replayed from scratch, so this is one change written twice. Collapse the pair")
print("   into a single patch describing the end state: reset the project to before the earlier")
print("   commit, replay with the correction folded in, and confirm the resulting tree is identical")
print("   to the one you started with before regenerating the patches.")
sys.exit(0)
PY
