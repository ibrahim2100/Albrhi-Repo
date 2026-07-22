#!/usr/bin/env bash
#
# Cross-compiles dav1d (the AV1 decoder) as a static library for iOS, one slice
# per architecture, and stages the result under dist/dav1d/.
#
# Why dav1d and nothing more: Instagram serves its high-quality ladder as AV1,
# which iOS cannot decode or save on its own. dav1d turns those frames into
# something VideoToolbox can re-encode to H.264 — so this one small BSD-licensed
# library is the whole external dependency. Encoding, audio and muxing are all
# done with Apple frameworks already on the device.
#
# Runs in CI on a macOS runner; not buildable on the developer's Windows machine,
# so it lives in its own workflow and never touches the tweak build until the
# artifact it produces is proven.
set -euo pipefail

# A released tag, never a moving branch: the binary we ship must be reproducible
# from an exact source revision.
DAV1D_VERSION="${DAV1D_VERSION:-1.4.3}"
MIN_IOS="${MIN_IOS:-15.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ROOT}/.dav1d-build"
DIST="${ROOT}/dist/dav1d"

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"

echo "dav1d ${DAV1D_VERSION}  |  iOS ${MIN_IOS}+  |  SDK ${SDK_PATH}"

rm -rf "${WORK}" "${DIST}"
mkdir -p "${WORK}" "${DIST}/lib"

# --- source ----------------------------------------------------------------

cd "${WORK}"
git clone --depth 1 --branch "${DAV1D_VERSION}" https://code.videolan.org/videolan/dav1d.git
SRC="${WORK}/dav1d"

# --- one static lib per architecture ---------------------------------------

build_arch() {
    local arch="$1"
    local builddir="${WORK}/build-${arch}"
    local crossfile="${WORK}/cross-${arch}.txt"

    # Meson needs an explicit cross file for iOS: the compiler is the SDK clang
    # with the arch, sysroot and deployment target baked into every invocation.
    cat > "${crossfile}" <<EOF
[binaries]
c = '${CLANG}'
cpp = '${CLANG}'
ar = '$(xcrun --sdk iphoneos --find ar)'
strip = '$(xcrun --sdk iphoneos --find strip)'
pkg-config = 'pkg-config'

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[built-in options]
c_args = ['-arch', '${arch}', '-isysroot', '${SDK_PATH}', '-miphoneos-version-min=${MIN_IOS}', '-fembed-bitcode']
c_link_args = ['-arch', '${arch}', '-isysroot', '${SDK_PATH}', '-miphoneos-version-min=${MIN_IOS}']
EOF

    # Library only — no CLI tool, no tests, no docs: those pull in dependencies
    # we neither need nor could run on a phone.
    meson setup "${builddir}" "${SRC}" \
        --cross-file "${crossfile}" \
        --default-library=static \
        --buildtype=release \
        -Denable_tools=false \
        -Denable_tests=false \
        -Denable_docs=false

    ninja -C "${builddir}"

    cp "${builddir}/src/libdav1d.a" "${DIST}/lib/libdav1d-${arch}.a"
    echo "  built ${arch}: $(du -h "${DIST}/lib/libdav1d-${arch}.a" | cut -f1)"
}

build_arch arm64
build_arch arm64e

# --- headers (identical across slices) -------------------------------------

mkdir -p "${DIST}/include/dav1d"
cp "${SRC}/include/dav1d/"*.h "${DIST}/include/dav1d/"

# version.h and the generated config live in the build tree, not the source.
cp "${WORK}/build-arm64/include/dav1d/version.h" "${DIST}/include/dav1d/" 2>/dev/null || true
cp "${WORK}/build-arm64/include/vcs_version.h" "${DIST}/include/dav1d/" 2>/dev/null || true

# --- a record of exactly what was built ------------------------------------

cat > "${DIST}/BUILD-INFO.txt" <<EOF
dav1d ${DAV1D_VERSION}
built $(date -u +%Y-%m-%dT%H:%M:%SZ)
iOS deployment target ${MIN_IOS}
architectures: arm64 (rootless), arm64e (roothide)
source: https://code.videolan.org/videolan/dav1d.git @ ${DAV1D_VERSION}
license: BSD-2-Clause (compatible with the tweak's GPLv3)
EOF

echo
echo "staged under ${DIST}:"
find "${DIST}" -type f | sed "s#${DIST}/#  #"
