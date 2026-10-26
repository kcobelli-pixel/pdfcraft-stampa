#!/bin/bash
# PdfCraft con le patch, per macOS: più firme salvate in Compila e firma.
#
# Dopo ogni aggiornamento di PdfCraft fatto con l'ArtCraft Launcher, fai doppio clic su questo
# file. Legge la versione di PdfCraft installata, scarica da
# github.com/kcobelli-pixel/pdfcraft-stampa la build della stessa versione con le patch, ne
# controlla l'impronta SHA-256 e sostituisce l'app. Le firme salvate restano nelle preferenze di
# PdfCraft. Per tornare alla versione ufficiale basta "Reinstalla" nel Launcher, o il prossimo
# aggiornamento.
set -euo pipefail

REPO='kcobelli-pixel/pdfcraft-stampa'
BUNDLE_ID='ai.storyteller.pdfcraft'
LAUNCHER_RECORD="$HOME/Library/Application Support/ArtCraft Launcher/installed.json"
TMP='' APP='' STAGE='' OLD=''

cleanup() {
  # Interrupted mid-swap: put the original back.
  if [ -n "$OLD" ] && [ -e "$OLD" ] && [ ! -e "$APP" ]; then mv "$OLD" "$APP" 2>/dev/null || true; fi
  if [ -n "$STAGE" ]; then rm -rf "$STAGE"; fi
  if [ -n "$TMP" ]; then
    hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || hdiutil detach -force -quiet "$TMP/mnt" 2>/dev/null || true
    # Never recurse into an image that is still mounted (its folder is on another device).
    if [ ! -d "$TMP/mnt" ] || [ "$(stat -f %d "$TMP/mnt")" = "$(stat -f %d "$TMP")" ]; then rm -rf "$TMP"; fi
  fi
}
trap cleanup EXIT

fail() {
  printf '\n\033[31m%s\033[0m\n' "$1"
  exit "${2:-1}"
}

# Builds exist only for the newest PdfCraft: an older one is told to update first.
fail_not_ready() {
  local latest
  latest="$(curl -sS https://api.github.com/repos/storytold/pdfcraft/releases/latest 2>/dev/null |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([0-9][0-9.]*\)".*/\1/p' | head -n1)" || latest=''
  if [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$latest" != "$VERSION" ]; then
    fail "C'è una versione più recente di PdfCraft ($latest): aggiornalo con l'ArtCraft Launcher, poi riesegui la patch. La patch viene preparata solo per l'ultima versione." 2
  fi
  fail "La versione di PdfCraft $VERSION con le patch non è ancora pronta. Viene preparata in automatico entro qualche ora da ogni aggiornamento: riprova più tardi." 2
}

plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true; }

app_version() {
  local v
  v="$(plist "$1" PdfCraftVersion)"
  [ -n "$v" ] || v="$(plist "$1" CFBundleShortVersionString)"
  printf '%s' "$v"
}

assert_not_running() {
  if pgrep -x PdfCraft >/dev/null 2>&1; then fail 'PdfCraft è aperto: chiudilo e riesegui la patch.'; fi
}

# Where the launcher put PdfCraft (its own record first), as long as it is PdfCraft.
find_app() {
  local recorded='' app
  if [ -f "$LAUNCHER_RECORD" ]; then
    recorded="$(osascript -l JavaScript -e '
      function run(argv) {
        ObjC.import("Foundation");
        const s = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
        if (s.isNil()) return "";
        const r = JSON.parse(s.js);
        return (r && r.apps && r.apps.pdfcraft && r.apps.pdfcraft.path) || "";
      }' "$LAUNCHER_RECORD" 2>/dev/null || true)"
  fi
  for app in "$recorded" /Applications/PdfCraft.app "$HOME/Applications/PdfCraft.app"; do
    if [ -n "$app" ] && [ -d "$app" ] && [ "$(plist "$app" CFBundleIdentifier)" = "$BUNDLE_ID" ]; then
      printf '%s' "$app"
      return 0
    fi
  done
  return 1
}

# Prints the HTTP status (000 when the transfer itself failed); the body goes to $TMP/<name>.
fetch() {
  local code
  code="$(curl -sSL --retry 2 -o "$TMP/$1" -w '%{http_code}' "https://github.com/$REPO/releases/download/v$VERSION/$1" 2>/dev/null)" || code=000
  printf '%s' "$code"
}

echo 'PdfCraft con le patch'
echo '====================='

APP="$(find_app)" || fail "PdfCraft non risulta installato: installalo (o aggiornalo) con l'ArtCraft Launcher, poi riesegui la patch."
VERSION="$(app_version "$APP")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Versione di PdfCraft non riconosciuta: '$VERSION'."
echo "PdfCraft installato: versione $VERSION ($APP)"
assert_not_running

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pdfcraft-patch.XXXXXX")"
# build.yml publishes this marker instead of a Mac build once the official sources have
# everything the patches add.
if [ "$(fetch PATCH-UFFICIALE-mac.txt)" = 200 ]; then
  official="Buone notizie: PdfCraft $VERSION contiene già ufficialmente tutto quello che aggiungeva la patch (più firme salvate). La patch non serve più: da ora puoi aggiornare PdfCraft con il Launcher e usarlo così com'è."
  printf '\n\033[32m%s\033[0m\n' "$official"
  osascript -e 'on run argv' -e 'display dialog (item 1 of argv) with title "PdfCraft: patch" buttons {"OK"} default button 1 with icon note' -e 'end run' "$official" >/dev/null 2>&1 || true
  exit 0
fi

echo 'Scarico la versione con le patch...'
status="$(fetch SHA256SUMS.txt)"
[ "$status" != 404 ] || fail_not_ready
[ "$status" = 200 ] || fail "Non riesco a contattare GitHub (risposta: $status). Controlla la connessione e riprova."
DMG="pdfcraft-$VERSION-macos-universal.dmg"
want="$(awk -v n="$DMG" 'length($1) == 64 && $1 ~ /^[0-9a-fA-F]+$/ && ($2 == n || $2 == "*" n) { print tolower($1); exit }' "$TMP/SHA256SUMS.txt")"
# Not listed yet: the release is still being published.
[ -n "$want" ] || fail_not_ready
status="$(fetch "$DMG")"
[ "$status" != 404 ] || fail_not_ready
[ "$status" = 200 ] || fail "Non riesco a scaricare $DMG da GitHub (risposta: $status). Controlla la connessione e riprova."
got="$(shasum -a 256 "$TMP/$DMG" | awk '{ print $1 }')"
[ "$got" = "$want" ] || fail "Il file scaricato $DMG non corrisponde all'impronta pubblicata, quindi non lo installo. Se la versione si stava aggiornando proprio ora, riprova tra qualche minuto."

mkdir "$TMP/mnt"
hdiutil attach -nobrowse -readonly -noverify -noautoopen -mountpoint "$TMP/mnt" "$TMP/$DMG" >/dev/null || fail "Non riesco ad aprire $DMG."
NEW_APP="$TMP/mnt/PdfCraft.app"
[ "$(plist "$NEW_APP" CFBundleIdentifier)" = "$BUNDLE_ID" ] || fail "$DMG non contiene PdfCraft."
[ "$(app_version "$NEW_APP")" = "$VERSION" ] || fail "$DMG non contiene PdfCraft $VERSION."

PARENT="$(dirname "$APP")"
[ -w "$PARENT" ] || fail "Non ho il permesso di scrivere in $PARENT."
# A private folder beside the app holds the new copy; the original is renamed in place, so the
# swap never moves the installed bundle to another folder.
STAGE="$(mktemp -d "$PARENT/.PdfCraft-patch.XXXXXX")"
OLD="$STAGE-originale.app"
echo 'Installo la versione con le patch...'
ditto "$NEW_APP" "$STAGE/PdfCraft.app"
xattr -dr com.apple.quarantine "$STAGE/PdfCraft.app" 2>/dev/null || true
codesign --verify "$STAGE/PdfCraft.app" 2>/dev/null || fail "La copia di PdfCraft non è integra: non la installo."
assert_not_running
mv "$APP" "$OLD" || fail "Non sono riuscito a sostituire $APP: PdfCraft resta com'era."
if ! mv "$STAGE/PdfCraft.app" "$APP"; then
  mv "$OLD" "$APP"
  fail "Non sono riuscito a sostituire $APP: PdfCraft resta com'era."
fi
rm -rf "$OLD"

echo ''
printf '\033[32m%s\033[0m\n' "Fatto: PdfCraft $VERSION ha le patch: puoi salvare più firme in Compila e firma."
echo "Se PdfCraft chiede di nuovo il permesso di usare un ID digitale del Portachiavi, consenti: la build non è firmata da ArtCraft."
echo 'Dopo il prossimo aggiornamento di PdfCraft riesegui Applica-patch.command.'
