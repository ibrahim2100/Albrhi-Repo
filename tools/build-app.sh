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

# ── the home screen widget ────────────────────────────────────────────────────────────────────
#
# Built apart from the app and folded in afterwards, for two reasons. It is Swift against Xcode's
# own iOS SDK while the app is Objective-C against the pinned 16.2 one, and — the half that
# matters — **a widget that will not build must never take the app with it**: this is an extra on
# a home screen, and the app it belongs to is the thing somebody is waiting for.
WIDGET_SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)
WIDGET_BIN=$(mktemp -d)/AlbrhiWidget

if [ -n "$WIDGET_SDK" ] && xcrun --sdk iphoneos swiftc \
        -target arm64-apple-ios15.0 -sdk "$WIDGET_SDK" -O -whole-module-optimization \
        -parse-as-library -Xlinker -e -Xlinker _NSExtensionMain \
        -o "$WIDGET_BIN" app/widget/Widget.swift 2>/dev/null; then

    APPEX="$APP/PlugIns/AlbrhiWidget.appex"
    mkdir -p "$APPEX"
    cp "$WIDGET_BIN" "$APPEX/AlbrhiWidget"
    cp app/widget/Info.plist "$APPEX/Info.plist"
    ldid -Sapp/widget/entitlements.plist "$APPEX/AlbrhiWidget"
    echo "الودجت: ضُمّت"
else
    echo "الودجت: لم تُبنَ — التطبيق نفسه سليم"
fi

# Fake-signed. The one entitlement is the app group the widget reads its numbers from -- the token
# stays in the keychain and is never shared with the extension.
ldid -Sapp/entitlements.plist "$APP/AlbrhiLicences"

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
