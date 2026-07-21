#!/usr/bin/env bash
#
# Builds an APT repository that Sileo, Zebra and Cydia can add as a source.
#
# Takes the .deb files in a directory and produces the index files APT needs:
# Packages (plus compressed variants) and Release. Output is a self-contained
# folder ready to be served by GitHub Pages.
#
# Packages come from two places: the debs just built, and anything dropped into
# extra-debs/ in the source tree. Adding another tweak to the source is therefore
# a matter of copying its .deb into that folder and pushing.
#
# Usage: tools/make-repo.sh <deb-dir> <output-dir> <base-url>

set -euo pipefail

DEB_DIR="${1:?deb directory required}"
OUT_DIR="${2:?output directory required}"
BASE_URL="${3:?base url required}"

mkdir -p "$OUT_DIR/debs"

# Newly built debs win over whatever the branch already had at the same filename.
built=$(find "$DEB_DIR" -maxdepth 1 -name '*.deb' -type f | wc -l | tr -d ' ')
echo "Built packages found: ${built}"

if [ "$built" -gt 0 ]; then
    find "$DEB_DIR" -maxdepth 1 -name '*.deb' -type f -exec cp -f {} "$OUT_DIR/debs/" \;
fi

# Hand-added packages. Copied after the built ones so a file placed here can
# deliberately override a build of the same name.
EXTRA_DIR="$(dirname "$0")/../extra-debs"
if [ -d "$EXTRA_DIR" ]; then
    # find, not ls: a glob that matches nothing makes ls exit non-zero, and under
    # `set -o pipefail` that killed the whole script before it printed anything.
    count=$(find "$EXTRA_DIR" -maxdepth 1 -name '*.deb' -type f | wc -l | tr -d ' ')
    echo "Extra packages found: ${count}"

    if [ "$count" -gt 0 ]; then
        find "$EXTRA_DIR" -maxdepth 1 -name '*.deb' -type f -exec cp -f {} "$OUT_DIR/debs/" \;
    fi
fi

if ! ls "$OUT_DIR"/debs/*.deb >/dev/null 2>&1; then
    echo "::error::No .deb files to index"
    exit 1
fi

# --- Collision guard -------------------------------------------------------
#
# APT identifies a package by name + version + architecture. Two debs sharing
# all three are indistinguishable to a package manager: it will list one and
# may install the wrong jailbreak's build. The rootless and roothide packages
# must therefore differ in architecture.
echo "Package identities:"
IDENTITIES=""
for deb in "$OUT_DIR"/debs/*.deb; do
    name=$(dpkg-deb -f "$deb" Package)
    version=$(dpkg-deb -f "$deb" Version)
    arch=$(dpkg-deb -f "$deb" Architecture)

    # Label the jailbreak each package targets. Old sourceless tweaks are usually
    # rootful, which no modern jailbreak can install -- better to see that here
    # than to field "it will not install" reports later.
    case "$arch" in
        iphoneos-arm)     note="  [rootful - will NOT install on rootless or roothide]" ;;
        iphoneos-arm64)   note="  [rootless]" ;;
        iphoneos-arm64e)  note="  [roothide]" ;;
        *)                note="  [unknown architecture]" ;;
    esac

    echo "  $(basename "$deb")  ->  ${name} ${version} ${arch}${note}"
    IDENTITIES="${IDENTITIES}${name}_${version}_${arch}"$'\n'
done

DUPES=$(printf '%s' "$IDENTITIES" | sort | uniq -d)
if [ -n "$DUPES" ]; then
    echo "::error::Two packages share name+version+architecture: ${DUPES}"
    echo "::error::A single APT repo cannot serve both. Give the roothide build its own architecture."
    exit 1
fi

# --- Index -----------------------------------------------------------------

cd "$OUT_DIR"

dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null

gzip  -9fkn Packages
bzip2 -9fk  Packages
xz    -9fk  Packages 2>/dev/null || true

cat > Release <<EOF
Origin: Albrhi
Label: Albrhi
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm64 iphoneos-arm64e
Components: main
Description: Tweaks by Ibrahim Ismail AL-Rahn.
Icon: CydiaIcon.png
EOF

# Already inside $OUT_DIR after the cd above, so list the current directory --
# listing "$OUT_DIR" again looks for pages/pages and fails under set -e.
echo "Repo written to $OUT_DIR (base: $BASE_URL)"
ls -la
