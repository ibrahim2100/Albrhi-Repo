#!/usr/bin/env bash

set -e

echo 'Note: This script is meant to be used while developing a tweak.'
echo '      This does not build "libflex" or "FLEXing", they must be built manually and moved to ./packages'
echo

# ./build-dev.sh <true|quick> [tweak]
TWEAK="${2:-instagram}"
TWEAK_DIR="tweaks/${TWEAK}"
TWEAK_NAME="$(awk '/^TWEAK_NAME/ {print $3; exit}' "${TWEAK_DIR}/Makefile")"

if [ "$1" == "true" ];
then
    _scinsta_dev_before

    # Build tweak and package into ipa
    ./build.sh "${TWEAK}" sideload --dev

    _scinsta_dev_after
else
    _scinsta_devquick_before

    # Built tweak and deploy to live container
    cd "${TWEAK_DIR}"
    make clean
    make DEV=1

    # Change framework locations to @rpath
    install_name_tool -change "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate" "@rpath/CydiaSubstrate.framework/CydiaSubstrate" ".theos/obj/debug/${TWEAK_NAME}.dylib" 2>/dev/null || true

    cd ../..
    _scinsta_devquick_after
fi
