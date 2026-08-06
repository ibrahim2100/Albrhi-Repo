#!/usr/bin/env bash
#
# Builds any tweak in this repository.
#
#     ./build.sh <tweak> <mode>        e.g.  ./build.sh instagram rootless
#     ./build.sh <mode>                shorthand: defaults to instagram
#
# A tweak is a directory under tweaks/ holding its own Makefile, control and
# filter plist. Nothing here knows which app is being patched -- the target
# process, the bundle id and the package identity all come out of that
# directory -- so adding a second or third tweak needs no edit in this file.
#

set -e

TWEAKS_DIR="tweaks"

usage() {
    echo '+-------------------------+'
    echo '|Albrhi Repo Build Script |'
    echo '+-------------------------+'
    echo
    echo 'Usage: ./build.sh <tweak> <sideload|rootless|roothide|rootful>'
    echo
    echo 'Available tweaks:'
    for d in "${TWEAKS_DIR}"/*/; do
        [ -f "${d}control" ] && echo "    $(basename "${d}")"
    done
    exit 1
}

# Accept both "./build.sh instagram rootless" and the older "./build.sh rootless".
case "$1" in
    sideload|rootless|roothide|rootful)
        TWEAK="instagram"
        MODE="$1"
        shift 1
        ;;
    "")
        usage
        ;;
    *)
        TWEAK="$1"
        MODE="$2"
        shift 2 || true
        ;;
esac

TWEAK_DIR="${TWEAKS_DIR}/${TWEAK}"
if [ ! -f "${TWEAK_DIR}/control" ]; then
    echo -e "\033[1m\033[0;31mUnknown tweak '${TWEAK}' — no ${TWEAK_DIR}/control.\033[0m"
    usage
fi

field() { awk -F': *' -v k="^$1:" '$0 ~ k {print $2; exit}' "${TWEAK_DIR}/control"; }

PACKAGE="$(field Package)"
DISPLAY_NAME="$(field Name)"

# The bundle the tweak attaches to, read from its own filter plist. Used only to
# locate the decrypted IPA for a sideload build, and having it come from the
# plist means the two can never disagree.
#
# Not every package here has a filter plist: a preference bundle injects into
# nothing and has none. The glob would then reach sed as a literal path, sed would
# fail, and `set -e` would abort the whole script before a single file compiled --
# over a value only the sideload mode ever reads.
BUNDLE_ID=""
if compgen -G "${TWEAK_DIR}/*.plist" > /dev/null; then
    BUNDLE_ID="$(sed -n 's/.*<string>\(com\.[A-Za-z0-9._-]*\)<\/string>.*/\1/p' "${TWEAK_DIR}"/*.plist | head -n1)"
fi

cd "${TWEAK_DIR}"

case "${MODE}" in

sideload)
    # Prerequisites (FLEXing is only needed for the sideload/IPA build)
    if [ -z "$(ls -A ../../modules/FLEXing 2>/dev/null)" ]; then
        echo -e '\033[1m\033[0;31mFLEXing submodule not found.\nPlease run the following command to checkout submodules:\n\n\033[0m    git submodule update --init --recursive'
        exit 1
    fi

    # Check if building with dev mode
    if [ "$1" == "--dev" ];
    then
        # Cache pre-built FLEX libs
        mkdir -p "packages/cache"
        cp -f ".theos/obj/debug/FLEXing.dylib" "packages/cache/FLEXing.dylib" 2>/dev/null || true
        cp -f ".theos/obj/debug/libflex.dylib" "packages/cache/libflex.dylib" 2>/dev/null || true

        if [[ ! -f "packages/cache/FLEXing.dylib" || ! -f "packages/cache/libflex.dylib" ]]; then
            echo -e '\033[1m\033[0;33mCould not find cached pre-built FLEX libs, building prerequisite binaries\033[0m'
            echo

            (cd ../.. && ./build.sh "${TWEAK}" sideload --buildonly)
            (cd ../.. && ./build-dev.sh true)
            exit
        fi

        MAKEARGS='DEV=1'
        FLEXPATH='packages/cache/FLEXing.dylib packages/cache/libflex.dylib'
        COMPRESSION=0
    else
        # Clear cached FLEX libs
        rm -rf "packages/cache"

        MAKEARGS='SIDELOAD=1'
        FLEXPATH='.theos/obj/debug/FLEXing.dylib .theos/obj/debug/libflex.dylib'
        COMPRESSION=9
    fi

    # Clean build artifacts
    make clean
    rm -rf .theos

    # Check for a decrypted IPA of the app this tweak patches
    ipaFile="$(find ./packages/*${BUNDLE_ID}*.ipa -type f -exec basename {} \; 2>/dev/null)"
    if [ -z "${ipaFile}" ]; then
        echo -e "\033[1m\033[0;31m${TWEAK_DIR}/packages/${BUNDLE_ID}.ipa not found.\nPlease put a decrypted IPA in its path.\033[0m"
        exit 1
    fi

    echo -e "\033[1m\033[32mBuilding ${DISPLAY_NAME} for sideloading (as IPA)\033[0m"

    make $MAKEARGS

    # Only build libs (for future use in dev build mode)
    if [ "$1" == "--buildonly" ];
    then
        exit
    fi

    DYLIBPATH=".theos/obj/debug/$(awk '/^TWEAK_NAME/ {print $3; exit}' Makefile).dylib"
    if [ "$1" == "--devquick" ];
    then
        # Exclude the tweak from the ipa for livecontainer quick builds
        DYLIBPATH=""
    fi

    # Create IPA File
    echo -e '\033[1m\033[32mCreating the IPA file...\033[0m'
    rm -f "packages/${TWEAK}-sideloaded.ipa"
    cyan -i "packages/${ipaFile}" -o "packages/${TWEAK}-sideloaded.ipa" -f $DYLIBPATH $FLEXPATH -c $COMPRESSION -m 15.0 -du

    # Patch IPA for sideloading
    ipapatch --input "packages/${TWEAK}-sideloaded.ipa" --inplace --noconfirm

    echo -e "\033[1m\033[32mDone!\033[0m\n\nYou can find the ipa file at: $(pwd)/packages"
    ;;

rootless)
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e "\033[1m\033[32mBuilding ${DISPLAY_NAME} for rootless\033[0m"

    export THEOS_PACKAGE_SCHEME=rootless
    # FINALPACKAGE strips debug symbols and drops the -1+debug version suffix.
    make package FINALPACKAGE=1

    echo -e "\033[1m\033[32mDone!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"
    ;;

roothide)
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e "\033[1m\033[32mBuilding ${DISPLAY_NAME} for roothide\033[0m"

    # The rootless and roothide packages would otherwise be identical to APT --
    # same name, version and architecture -- so a single repo could not serve both
    # and Sileo would offer the wrong build. The roothide package therefore gets
    # its own identity, and each declares Conflicts/Replaces on the other so they
    # can never be installed side by side.
    #
    # The names are derived from control rather than written out here: the old
    # version matched literal package ids with sed, which silently did nothing
    # the moment a tweak used a different id -- and doing nothing here means
    # shipping a roothide build wearing the rootless identity.
    #
    # control is edited in place and restored on exit, including on failure, so a
    # broken build never leaves the roothide identity behind.
    cp control control.orig
    trap 'mv -f control.orig control 2>/dev/null || true' EXIT

    # "Albrhi for Instagram (rootless)" -> "... (roothide)". A tweak whose Name
    # carries no flavour gets one appended, so the two builds are still told
    # apart in Sileo.
    if [ "${DISPLAY_NAME}" != "${DISPLAY_NAME/(rootless)/}" ]; then
        ROOTHIDE_NAME="${DISPLAY_NAME/(rootless)/(roothide)}"
    else
        ROOTHIDE_NAME="${DISPLAY_NAME} (roothide)"
    fi

    python3 - "${PACKAGE}" "${ROOTHIDE_NAME}" <<'PY'
import re, sys
package, roothide_name = sys.argv[1], sys.argv[2]
text = open('control', encoding='utf-8').read()

# Substituted through Python rather than sed because both the package id and the
# display name are data: a name containing a slash or an ampersand would corrupt
# a sed replacement, and the failure would be a silently mislabelled package.
def sub(pattern, replacement, body):
    body, count = re.subn(pattern, lambda _: replacement, body, flags=re.M)
    if count != 1:
        raise SystemExit('control: expected exactly one %r, found %d' % (pattern, count))
    return body

text = sub(r'^Package: %s$' % re.escape(package), 'Package: %s.roothide' % package, text)
text = sub(r'^Name: .*$', 'Name: %s' % roothide_name, text)
text = sub(r'^Conflicts: %s\.roothide$' % re.escape(package), 'Conflicts: %s' % package, text)
text = sub(r'^Replaces: %s\.roothide$' % re.escape(package), 'Replaces: %s' % package, text)

open('control', 'w', encoding='utf-8').write(text)
PY

    echo "roothide package identity:"
    grep -E '^(Package|Name|Conflicts|Replaces):' control

    # No jbroot() calls needed: the tweak writes only inside the host app's own
    # container, so the rootless sources build unchanged under the roothide scheme.
    export THEOS_PACKAGE_SCHEME=roothide
    # FINALPACKAGE strips debug symbols and drops the -1+debug version suffix.
    make package FINALPACKAGE=1

    echo -e "\033[1m\033[32mDone!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"
    ;;

rootful)
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e "\033[1m\033[32mBuilding ${DISPLAY_NAME} for rootful\033[0m"

    unset THEOS_PACKAGE_SCHEME
    # FINALPACKAGE strips debug symbols and drops the -1+debug version suffix.
    make package FINALPACKAGE=1

    echo -e "\033[1m\033[32mDone!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"
    ;;

*)
    cd ../..
    usage
    ;;
esac
