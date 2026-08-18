#!/usr/bin/env bash
#
# Build one tweak and drop the .deb on the Desktop, without touching GitHub.
#
# The APT source is paused deliberately while TikTok's download quality is still being measured:
# every release so far has cost the owner an install, a report and a round trip, and several were
# wrong. Building to a folder keeps that loop between this machine and the phone, and the source
# gets one push at the end instead of a version number for every attempt.
#
#   bash tools/build-local.sh                  # tiktok, roothide  <- the owner's device
#   bash tools/build-local.sh tiktok rootless  # the other flavour
#   bash tools/build-local.sh youtube          # any other tweak
#
# **roothide is the default because the owner's phone is roothide, and the two are not
# interchangeable**: a rootless package carries everything under `var/jb` and a roothide one does
# not, because roothide decides its prefix on the device. Theos settles that when it *stages*, so
# the flavour is chosen by which Theos builds it -- not by anything in the control file. The
# roothide scheme lives only in the roothide fork, hence the separate THEOS below.
set -euo pipefail

TWEAK="${1:-tiktok}"
MODE="${2:-roothide}"
OUT="$HOME/Desktop/Albrhi-TikTok"

if [ "$MODE" = "roothide" ]; then
    export THEOS="${THEOS_ROOTHIDE:-$HOME/theos-roothide}"
    if [ ! -d "$THEOS/vendor/mod/roothide" ]; then
        echo "roothide Theos is missing its scheme at $THEOS/vendor/mod/roothide" >&2
        echo "  git clone --recursive https://github.com/roothide/theos.git $THEOS" >&2
        echo "  cp -R \$HOME/theos/sdks/. $THEOS/sdks/" >&2
        exit 1
    fi
else
    export THEOS="${THEOS:-$HOME/theos}"
fi

export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."

# check.py first, exactly as CI would: seconds, against five minutes of compiling.
python3 tools/check.py

bash build.sh "$TWEAK" "$MODE"

DEB="$(ls -t "tweaks/$TWEAK/packages/"*.deb | head -1)"

# **Prove the flavour rather than trusting the filename.** 1.0.2 shipped a "roothide" package
# built from a rootless staging tree and it installed as rootless, because that is what it was.
INSIDE="$(dpkg-deb -c "$DEB" | awk '{print $6}' | grep -m1 'DynamicLibraries' || true)"
case "$MODE:$INSIDE" in
    roothide:var/jb/*)  echo "REFUSING: $DEB is staged rootless ($INSIDE) under THEOS=$THEOS" >&2; exit 1 ;;
    rootless:Library/*) echo "REFUSING: $DEB is staged roothide ($INSIDE) under THEOS=$THEOS" >&2; exit 1 ;;
esac

mkdir -p "$OUT"
cp "$DEB" "$OUT/"

echo
echo "→ $OUT/$(basename "$DEB")"
echo "  staged as: $INSIDE"
ls -lt "$OUT" | head -5
