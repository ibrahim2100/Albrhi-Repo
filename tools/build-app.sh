#!/usr/bin/env bash
#
# Build the licence panel as an app, and wrap it as an IPA for TrollStore.
#
#   bash tools/build-app.sh
#
# **Unsigned on purpose.** TrollStore installs an unsigned app and signs it itself; signing here
# with a certificate would tie the copy to that certificate's week. `ldid -S` fake-signs it, which
# is what TrollStore expects and what every jailbreak app in this repository already ships as.
#
set -euo pipefail

cd "$(dirname "$0")/.."

export THEOS="${THEOS:-$HOME/theos}"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"

OUT="$HOME/Desktop/Albrhi-App"
mkdir -p "$OUT"

( cd app && make clean >/dev/null 2>&1 || true )
( cd app && make FINALPACKAGE=1 )

APP=$(find app/.theos/obj -maxdepth 2 -name '*.app' -type d | head -n1)
[ -n "$APP" ] || { echo "no .app was produced" >&2; exit 1; }

# Fake-signed, and the app carries no entitlements of its own: it talks to one https API and keeps
# one string in the keychain, and asking for anything more would be asking for what it does not
# need.
ldid -S "$APP/AlbrhiLicences"

STAGE=$(mktemp -d)
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

VERSION=$(defaults read "$PWD/$APP/Info" CFBundleShortVersionString 2>/dev/null || echo 1.0.0)
IPA="$OUT/AlbrhiLicences_${VERSION}.ipa"
rm -f "$IPA"

( cd "$STAGE" && zip -q -r -X "$IPA" Payload )
rm -rf "$STAGE"

echo ""
echo "$IPA"
ls -lh "$IPA" | awk '{print "  " $5}'
echo ""
echo "التثبيت: TrollStore ← افتح الملف ← Install"
