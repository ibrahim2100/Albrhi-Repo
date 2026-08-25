#!/bin/bash
#
# The YouTube tweak's pure parts, compiled for the Mac and run.
#
# The arrangement is the one the YouTube Music port brought in, pointed at a different tweak: build
# against the macOS SDK's iOSSupport frameworks so iOS code compiles unchanged, and execute it here.
# A hook still needs a device. A transport-stream demuxer does not -- it is bytes in and bytes out,
# and 759 of those lines are ours rather than ffmpeg's, which is exactly why they are worth proving.
#
set -euo pipefail
cd "$(dirname "$0")/../.."

XCODE="${XCODE:-/Applications/Xcode.app}"
if [[ ! -d "$XCODE/Contents/Developer" ]]; then
  echo "tests/host/run.sh: needs Xcode.app at $XCODE (set XCODE=/path/to/Xcode.app)" >&2
  exit 2
fi

export DEVELOPER_DIR="$XCODE/Contents/Developer"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
IOS_FW="$SDK/System/iOSSupport/System/Library/Frameworks"
OUT=".theos/host-tests"
mkdir -p "$OUT"

xcrun clang \
  -fobjc-arc -Wall \
  -Wno-deprecated-declarations -Wno-unguarded-availability-new \
  -target arm64-apple-ios16.0-macabi -isysroot "$SDK" \
  -iframework "$IOS_FW" -F "$IOS_FW" \
  -I src -I src/Features/Download -I tests/host \
  -DALBRHI_HOST_TESTS=1 \
  -framework Foundation -framework UIKit -framework AVFoundation -framework CoreMedia \
  src/Features/Download/SCIYTTransport.m \
  src/Localization/SCILocalize.m \
  tests/host/*.m \
  -o "$OUT/albrhi-yt-host-tests"

"$OUT/albrhi-yt-host-tests" "$@"
