#!/usr/bin/env bash
# Put "several saved signatures" into a PdfCraft checkout (patches/multi-signatures.patch): the
# Fill & Sign panel keeps further signatures and initials beside the one in use, and clicking one
# makes it the one placed. Settings stay readable by official builds, which keep the one in use.
#
# usage: apply_signatures.sh <pdfcraft checkout (a git clone)>
# exit: 0 patched, 3 the official sources already keep several saved signatures, 1 failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pdf="$(cd "$1" && pwd)"
# The release the patch was written against (v0.15.0): its blobs let --3way merge newer releases.
base=75360d1d7db06fed974f48c914d4c04132757187

# Only this patch's own field: any other upstream design shows up as a loud --3way conflict.
if grep -qw 'more_signatures' "$pdf/crates/ui-egui/src/lib.rs"; then
  echo 'the official sources already keep several saved signatures'
  exit 3
fi

git -C "$pdf" cat-file -e "$base^{commit}" 2>/dev/null ||
  git -C "$pdf" fetch -q --depth 1 https://github.com/storytold/pdfcraft "$base"
git -C "$pdf" update-index -q --refresh || true
git -C "$pdf" apply --3way "$here/patches/multi-signatures.patch"
echo 'several saved signatures applied'
