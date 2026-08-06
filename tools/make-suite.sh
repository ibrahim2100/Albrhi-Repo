#!/usr/bin/env bash
#
# Builds every Albrhi tweak and puts them in one package.
#
# The three projects stay exactly as they are -- separate sources, separate
# Makefiles, each still buildable and testable on its own. What changes is only
# how they are delivered: one .deb holding every dylib, every filter plist and
# the preference bundle, so a person installs one thing and updates one thing.
#
# The dylibs are NOT merged into one binary, and that is deliberate. Each keeps
# its own filter, so Instagram's code is loaded into Instagram and nowhere else.
# One combined dylib would have to be injected into every supported app and then
# work out where it was, which is more memory in every app and a new way to be
# wrong for no gain at all.
#
# Theos leaves a complete file tree in each project's .theos/_ after packaging.
# Merging those trees is the whole job, and it means this script never has to
# know what a project installs -- a fourth tweak needs no edit here.
#

set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SCHEME="${1:-rootless}"
SUITE_DIR="${ROOT}/suite"
STAGE="${ROOT}/.suite-stage"

if [ ! -f "${SUITE_DIR}/control" ]; then
    echo "No ${SUITE_DIR}/control — nothing describes the combined package." >&2
    exit 1
fi

VERSION="$(awk -F': *' '/^Version:/ {print $2; exit}' "${SUITE_DIR}/control")"
PACKAGE="$(awk -F': *' '/^Package:/ {print $2; exit}' "${SUITE_DIR}/control")"

echo "Building ${PACKAGE} ${VERSION} (${SCHEME})"

rm -rf "${STAGE}"
mkdir -p "${STAGE}"

# Every directory under tweaks/ that has a control file, in a fixed order so the
# package is byte-identical between runs that changed nothing.
for TWEAK_PATH in "${ROOT}"/tweaks/*/; do
    TWEAK="$(basename "${TWEAK_PATH}")"
    [ -f "${TWEAK_PATH}/control" ] || continue

    echo ""
    echo "=== ${TWEAK}"
    ./build.sh "${TWEAK}" "${SCHEME}"

    STAGED="${TWEAK_PATH}/.theos/_"
    if [ ! -d "${STAGED}" ]; then
        echo "::error::${TWEAK} produced no staged tree at ${STAGED}" >&2
        exit 1
    fi

    # DEBIAN/ belongs to that project's own package and must not travel into the
    # combined one: its control names the wrong package and its version is the
    # wrong version.
    (cd "${STAGED}" && find . -path ./DEBIAN -prune -o -type f -print0 | \
        while IFS= read -r -d '' FILE; do
            mkdir -p "${STAGE}/$(dirname "${FILE}")"
            cp -p "${FILE}" "${STAGE}/${FILE}"
        done)
done

echo ""
echo "=== assembling"

mkdir -p "${STAGE}/DEBIAN"

# The control Theos itself wrote for this scheme, used as the base for anything this
# project does not define.
#
# 1.0.2 replaced DEBIAN/control wholesale with suite/control, which threw away every
# field Theos computes -- and for the roothide scheme those fields are how a package
# manager is told what it is looking at. The roothide build then installed as a rootless
# one, because as far as its control said, it was one.
THEOS_CONTROL=""
for TWEAK_PATH in "${ROOT}"/tweaks/*/; do
    CANDIDATE="${TWEAK_PATH}/.theos/_/DEBIAN/control"
    if [ -f "${CANDIDATE}" ]; then
        THEOS_CONTROL="${CANDIDATE}"
        break
    fi
done

if [ -n "${THEOS_CONTROL}" ]; then
    echo "scheme fields from ${THEOS_CONTROL#${ROOT}/} -- what Theos wrote:"
    sed 's/^/    /' "${THEOS_CONTROL}"
else
    echo "::warning::no Theos-generated control found; using suite/control alone"
fi

python3 "${ROOT}/tools/merge-control.py" \n    "${SUITE_DIR}/control" "${THEOS_CONTROL}" "${STAGE}/DEBIAN/control"

# Maintainer scripts, if the suite has any. The preinst removes the packages this
# one replaces -- Conflicts alone is only honoured by a package manager installing
# from a source, and a .deb installed by hand leaves the old ones in place with
# both dylibs injected.
for SCRIPT in preinst postinst prerm postrm; do
    if [ -f "${SUITE_DIR}/DEBIAN/${SCRIPT}" ]; then
        cp "${SUITE_DIR}/DEBIAN/${SCRIPT}" "${STAGE}/DEBIAN/${SCRIPT}"
        chmod 755 "${STAGE}/DEBIAN/${SCRIPT}"
        echo "  + ${SCRIPT}"
    fi
done

# The roothide package needs its own identity for the same reason the individual
# ones did: two packages with the same name, version and architecture cannot both
# live in one APT source, and a manager offered the wrong one would install it.
if [ "${SCHEME}" = "roothide" ]; then
    python3 - "${STAGE}/DEBIAN/control" "${PACKAGE}" <<'PY'
import re, sys
path, package = sys.argv[1], sys.argv[2]
text = open(path, encoding='utf-8').read()

def sub(pattern, replacement, body):
    body, count = re.subn(pattern, lambda _: replacement, body, flags=re.M)
    if count != 1:
        raise SystemExit('control: expected exactly one %r, found %d' % (pattern, count))
    return body

text = sub(r'^Package: %s$' % re.escape(package), 'Package: %s.roothide' % package, text)
text = sub(r'^Name: (.*)$', 'Name: Albrhi (roothide)', text)
open(path, 'w', encoding='utf-8').write(text)
PY
fi

echo "package identity:"
grep -E '^(Package|Name|Version|Conflicts|Replaces):' "${STAGE}/DEBIAN/control"

echo ""
echo "contents:"
find "${STAGE}" -type f -not -path '*/DEBIAN/*' | sed "s|${STAGE}/||" | sort

# Ownership matters: a tweak file owned by anyone but root is one MobileSubstrate
# refuses to load, and the failure is silent.
if command -v dpkg-deb > /dev/null; then
    mkdir -p "${ROOT}/packages"

    ARCH="$(awk -F': *' '/^Architecture:/ {print $2; exit}' "${STAGE}/DEBIAN/control")"
    SUFFIX=""
    [ "${SCHEME}" = "roothide" ] && SUFFIX=".roothide"

    OUT="${ROOT}/packages/${PACKAGE}${SUFFIX}_${VERSION}_${ARCH}.deb"
    dpkg-deb -Zgzip --root-owner-group -b "${STAGE}" "${OUT}"

    echo ""
    echo "Done: ${OUT}"
else
    echo ""
    echo "dpkg-deb not found — the tree is staged at ${STAGE} and not packaged." >&2
    exit 1
fi
