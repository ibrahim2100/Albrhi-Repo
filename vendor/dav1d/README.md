# dav1d (vendored)

Prebuilt static libraries of [dav1d](https://code.videolan.org/videolan/dav1d),
the VideoLAN AV1 decoder, for iOS.

## Why this is here

Instagram serves its higher-quality video as AV1, which iOS cannot decode or
save on its own. dav1d turns those frames into something VideoToolbox can
re-encode to H.264 — it is the single external dependency the transcoding path
needs. Everything else (H.264 encode, xHE-AAC audio, muxing) is done with Apple
frameworks already on the device.

## Provenance

These are **not** third-party binaries pulled from a mirror. They were built
from VideoLAN's own source, at a pinned release tag, by this repository's own CI:

- workflow: `.github/workflows/build-dav1d.yml`
- script: `tools/build-dav1d.sh`
- version: dav1d 1.4.3 (API 7), see `BUILD-INFO.txt`
- source: https://code.videolan.org/videolan/dav1d.git @ `1.4.3`

To rebuild — reproducibly, from the same source — run the workflow from the
Actions tab and replace `lib/` and `include/` with the artifact it produces.

| file | architecture | for |
|---|---|---|
| `lib/libdav1d-arm64.a`  | arm64  | rootless |
| `lib/libdav1d-arm64e.a` | arm64e | roothide |

## Licence

dav1d is distributed under the **BSD 2-Clause** licence, which is compatible
with this tweak's GPLv3. The full text follows, as its redistribution requires.

```
Copyright © 2018-2024, VideoLAN and dav1d authors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
