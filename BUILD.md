# Building Albrhi

Target device: **RootHide Dopamine 2 (rootless)**, Instagram **v409** (works on nearby versions).

The build must run on a **Mac or Linux** machine with Theos — it cannot be produced on-device or in a sandbox without the iOS SDK.

---

## 1. Prerequisites (one-time)

1. **Install Theos** (official): https://theos.dev/docs/installation
   ```bash
   export THEOS=~/theos
   git clone --recursive https://github.com/theos/theos.git $THEOS
   ```
2. **Add an iOS SDK** into `$THEOS/sdks` (a recent 16.x/17.x SDK is fine; the Makefile uses `latest`).
3. **Confirm the toolchain** (Swift/clang for iOS). On Linux use the Theos-provided toolchain.

## 2. Get the source ready

From the project root:
```bash
# Pull the FLEXing + JGProgressHUD submodules referenced by .gitmodules
git submodule update --init --recursive
```
> The uploaded ZIP does **not** include submodule contents. `modules/JGProgressHUD` and `modules/FLEXing` must be populated or the build will fail.

## 3. Build the rootless .deb

```bash
export THEOS_PACKAGE_SCHEME=rootless
make clean
make package
```
Output:
```
packages/com.albrhi.tweak_3.0.1_iphoneos-arm64.deb
```
The bundled `build.sh` also works: `./build.sh rootless`.

## 4. Install on the device

Copy the `.deb` to the phone and install with your package manager (Sileo/Zebra) or over SSH:
```bash
scp packages/com.albrhi.tweak_3.0.1_iphoneos-arm64.deb mobile@<device-ip>:/tmp/
ssh mobile@<device-ip>
sudo dpkg -i /tmp/com.albrhi.tweak_3.0.1_iphoneos-arm64.deb
sudo sbreload   # or fully re-open Instagram
```

## 5. Converting to .deb from other formats

If you build the sideload/IPA variant instead (`./build.sh sideload`), that produces an `.ipa`, not a `.deb`. For Dopamine 2 you want the **rootless `.deb`** from step 3 — no conversion needed.

---

## Notes on v409 vs v418

SCInsta was tested on Instagram **418.2.0**; you're on **409**. Class names are almost always identical across this range, but if a specific feature misbehaves:

1. Confirm which hook is failing (check Console logs filtered by `Albrhi` / `SCInsta`).
2. `class-dump` your installed Instagram binary and compare the class/ivar names in `src/InstagramHeaders.h`.
3. Adjust only the mismatched selector/ivar; leave the rest intact.

### Download quality — how it now works
`SCIUtils getVideoUrl:` selects the highest-quality video by:
1. Reading `_videoVersionDictionaries` (each entry has `url` + `width`/`height` + bitrate) and picking the largest pixel area, tie-broken by bitrate.
2. If unavailable, using `sortedVideoURLsBySize` and taking the **last** (largest) element.
3. As a last resort, `allVideoURLs` (an unordered set) — returns any object.

If your Instagram version exposes a different ivar name for the version list, update the KVC keys in `getVideoUrl:` (`_videoVersionDictionaries` / `videoVersionDictionaries`).

### Save directly to Photos
Controlled by the `dw_save_to_camera` toggle (Downloads section). When on, media is written to the library via the Photos framework instead of the share sheet. The host app already carries a photo-add usage description; if a save silently fails, verify Instagram has "Add Photos Only" or full Photos permission in iOS Settings.

---

## v2.2.0 — new capabilities & caveats

**Photos permission (direct save + custom album):** saving straight to the library or to the "Albrhi" album uses the Photos framework. Instagram already declares photo-library usage, so this normally works. If a save fails silently, grant Instagram full Photos access in iOS Settings → Privacy → Photos.

**Silent video** re-encodes via `AVAssetExportSession` (highest-quality preset). This adds a short processing delay after download and needs temporary disk space. Output is always `.mp4`.

**Reel audio download:** audio lives on `IGMedia`, which isn't always reachable from the reels video cell in every build. The extractor walks several accessors (`media`, `item`, `mediaView`, `video`); if none expose the audio asset, Albrhi cleanly falls back to a normal video download — no crash. If audio download doesn't appear on reels in your build, that's why; the video path still works.

**Quality picker** reads `-[IGVideo videoVersions]` (array of `IGAPIVideoVersion`). If empty, Albrhi falls back to automatic best-quality selection.

**Custom accent color** requires iOS 14+ (system `UIColorPickerViewController`). Stored as a hex string in `albrhi_accent_hex`; the reset button clears it back to the Albrhi orange.
