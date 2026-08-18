#!/usr/bin/env bash
#
# Build Albrhi locally and drop the .deb on the Desktop, without touching GitHub.
#
# The APT source is paused deliberately while TikTok's download quality is still being measured:
# every release so far cost the owner an install, a report and a round trip, and several were
# wrong. Building to a folder keeps that loop between this machine and the phone, and the source
# gets one push at the end instead of a version number for every attempt.
#
#   bash tools/build-local.sh                  # the whole suite, roothide  <- what the owner installs
#   bash tools/build-local.sh tiktok           # one tweak on its own
#   bash tools/build-local.sh suite rootless   # the other flavour
#
# **The suite is the default because that is what is actually installed.** com.albrhi carries
# Instagram, YouTube, X, TikTok *and* the Settings panel; handing over the single TikTok package
# leaves the panel behind -- and the per-app switch is opt-in, so without the panel the tweak
# stands down and reads as broken.
#
# **roothide is the default flavour because the owner's phone is roothide**, and the two are not
# interchangeable: a rootless package puts everything under `var/jb`, a roothide one does not,
# because roothide decides its prefix on the device. Theos settles that when it *stages*, so the
# flavour is chosen by which Theos builds it, never by the control file. The roothide scheme
# lives only in the roothide fork, hence the separate THEOS below.
set -euo pipefail

TARGET="${1:-suite}"
MODE="${2:-roothide}"
OUT="$HOME/Desktop/Albrhi"

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

if [ "$TARGET" = "suite" ]; then
    bash tools/make-suite.sh "$MODE"
    DEB="$(ls -t packages/*.deb | head -1)"
else
    bash build.sh "$TARGET" "$MODE"
    DEB="$(ls -t "tweaks/$TARGET/packages/"*.deb | head -1)"
fi

# **Prove the flavour from the staged paths, not the filename.** 1.0.2 shipped a "roothide"
# package built from a rootless staging tree and it installed as rootless, because that is what
# it was.
# Listed once into a variable, and every check reads that.
#
# **`dpkg-deb -c … | grep -q` kills the listing halfway.** grep exits at its first match, dpkg-deb
# takes SIGPIPE, and the *next* check sees a truncated list and reports a missing dylib that is
# right there in the package. The first version of this guard refused a perfectly good suite for
# exactly that reason -- a check that cries wolf is worse than no check, and this one was wrong
# about the thing it existed to protect.
LISTING="$(dpkg-deb -c "$DEB")"

INSIDE="$(printf '%s\n' "$LISTING" | awk '{print $6}' | grep -m1 'DynamicLibraries' || true)"
case "$MODE:$INSIDE" in
    roothide:./var/jb/*|roothide:var/jb/*)
        echo "REFUSING: $DEB is staged rootless ($INSIDE) under THEOS=$THEOS" >&2; exit 1 ;;
    rootless:./Library/*|rootless:Library/*)
        echo "REFUSING: $DEB is staged roothide ($INSIDE) under THEOS=$THEOS" >&2; exit 1 ;;
esac

# And prove the suite is whole. A merge that quietly drops a dylib produces a package that
# installs fine and simply does nothing for one app.
if [ "$TARGET" = "suite" ]; then
    for DYLIB in Albrhi AlbrhiTT AlbrhiTW AlbrhiYT; do
        case "$LISTING" in
            *"$DYLIB.dylib"*) ;;
            *) echo "REFUSING: $DEB is missing $DYLIB.dylib" >&2; exit 1 ;;
        esac
    done
    case "$LISTING" in
        *AlbrhiPanel.bundle*) ;;
        *) echo "REFUSING: $DEB has no Settings panel" >&2; exit 1 ;;
    esac
fi

mkdir -p "$OUT"
cp "$DEB" "$OUT/"

echo
echo "→ $OUT/$(basename "$DEB")"
echo "  staged as: $INSIDE"
ls -lt "$OUT" | head -5
