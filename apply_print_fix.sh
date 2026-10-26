#!/usr/bin/env bash
# Put the Brother print fix into a PdfCraft checkout. The root cause first: winprint builds the
# PrintTicket from the driver's default one, so the driver's own JobPrintSpeed isn't duplicated
# (patches/winprint-ticket.patch, upstream ArcticLampyrid/winprint.rs 1516b36ef). As a safety net,
# craft-print prints through GDI when the driver still refuses the XPS job
# (patches/craft-print.patch, storytold/craft-libs#188) with winprint's GdiPdfPrinter
# (patches/winprint-gdi.patch, storytold/winprint.rs#6). All are applied to the exact revisions
# the checkout's Cargo.lock uses, cloned into ../print-fix beside it, and wired in with [patch]
# tables.
#
# usage: apply_print_fix.sh <pdfcraft checkout>
# exit: 0 patched, 3 the official sources already fix printing (nothing changed), 1 failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pdf="$(cd "$1" && pwd)"
work="$pdf/../print-fix"
lock="$pdf/Cargo.lock"

# The git revision PdfCraft's build takes package $1 from, out of repository $2.
locked_rev() {
  awk -v name="name = \"$1\"" -v src="source = \"git+$2?rev=" '
    $0 == name { found = 1; next }
    found && index($0, src) == 1 { sub(/.*#/, ""); sub(/"$/, ""); print; exit }
    /^\[\[package\]\]/ { found = 0 }' "$lock"
}

craft_libs_rev="$(locked_rev craft-print https://github.com/storytold/craft-libs)"
winprint_rev="$(locked_rev winprint https://github.com/storytold/winprint.rs)"
for rev in "$craft_libs_rev" "$winprint_rev"; do
  [[ "$rev" =~ ^[0-9a-f]{40}$ ]] || { echo "craft-print or winprint is not pinned to a git revision in $lock" >&2; exit 1; }
done
echo "craft-libs $craft_libs_rev, winprint $winprint_rev"

rm -rf "$work"
mkdir -p "$work"
# LF working trees, like the patches (Git for Windows checks out CRLF by default); `clone -c`
# keeps the setting for the checkout and apply that follow.
git clone -c core.autocrlf=false -q https://github.com/storytold/craft-libs "$work/craft-libs"
git -C "$work/craft-libs" checkout -q "$craft_libs_rev"
git clone -c core.autocrlf=false -q https://github.com/storytold/winprint.rs "$work/winprint"
git -C "$work/winprint" checkout -q "$winprint_rev"

# Our fallback merged, or winprint starting its PrintTicket from the driver's default (the
# upstream fix for the duplicate JobPrintSpeed, ArcticLampyrid/winprint.rs 1516b36ef).
if grep -rqsE 'GdiPdfPrinter|falls_back_to_gdi' "$work/craft-libs/crates/print/src" ||
  grep -qs 'default_for(device)' "$work/winprint/src/ticket/builder.rs"; then
  echo 'the official sources already fix printing'
  rm -rf "$work"
  exit 3
fi

git -C "$work/craft-libs" apply --3way "$here/patches/craft-print.patch"
git -C "$work/winprint" apply --3way "$here/patches/winprint-gdi.patch"
git -C "$work/winprint" apply --3way "$here/patches/winprint-ticket.patch"

# The fallback reads the HRESULT inside winprint's errors.
toml="$work/craft-libs/crates/print/Cargo.toml"
if ! grep -q '^windows-result *=' "$toml"; then
  header="[target.'cfg(windows)'.dependencies]"
  grep -qxF "$header" "$toml" || { echo "no $header in $toml" >&2; exit 1; }
  awk -v header="$header" '{ print } $0 == header { print "windows-result = \"0.4\"" }' "$toml" > "$toml.new"
  mv "$toml.new" "$toml"
fi

if grep -qE '^\[patch\."https://github.com/storytold/(craft-libs|winprint\.rs)"\]' "$pdf/Cargo.toml"; then
  echo "$pdf/Cargo.toml already patches craft-libs or winprint: check by hand" >&2
  exit 1
fi
cat >> "$pdf/Cargo.toml" <<'EOF'

# pdfcraft-stampa: the Brother print fix (GDI fallback), from ../print-fix.
[patch."https://github.com/storytold/craft-libs"]
craft-print = { path = "../print-fix/craft-libs/crates/print" }

[patch."https://github.com/storytold/winprint.rs"]
winprint = { path = "../print-fix/winprint" }
EOF

# Rewrite only the patched entries of Cargo.lock, so the packaging's --locked build accepts it.
(cd "$pdf" && cargo metadata --format-version 1 > /dev/null)
grep -q 'name = "craft-print"' "$lock"
if grep -A2 'name = "craft-print"' "$lock" | grep -q '^source = "git+'; then
  echo "Cargo.lock still takes craft-print from git: the [patch] was not used" >&2
  exit 1
fi
# The fallback downcasts winprint's errors to craft-print's windows_result::Error: with two
# versions of the crate it would compile and never fire.
versions="$(cd "$pdf" && cargo tree --locked -p craft-print --target x86_64-pc-windows-msvc -e normal --prefix none |
  awk '$1 == "windows-result" { print $2 }' | sort -u)"
if [ "$(wc -l <<<"$versions")" -ne 1 ] || [ -z "$versions" ]; then
  echo "craft-print and winprint use different windows-result versions: $(echo $versions)" >&2
  exit 1
fi
echo 'print fix applied'
