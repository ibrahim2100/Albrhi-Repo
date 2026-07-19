# Albrhi Changelog

## v3.0.14

**New**
- **Save DM photos & videos.** Opening a photo or video in DMs now shows a Save
  button (and always allows saving, even when the sender disabled it). Saves route
  through the normal downloader, so the quality picker applies. Toggle under
  Stories & messages.

## v3.0.13

**Fixes**
- **Quality picker actually works now.** IG 410 keeps the resolution ladder in
  `-[IGVideo dashManifestData]`, which returns the manifest as **NSData**; Albrhi
  now decodes it and lists every resolution (1080p, etc.). Confirmed against the
  410 class dump.

**Changes**
- Follow-back badge moved to the right of the avatar, by the stats row (near the
  followers count).

## v3.0.12

**New**
- **Story download button.** A visible download button now sits in the story viewer
  (bottom-trailing) so stories save without needing the long-press gesture. Toggle
  under Stories & messages.

**Changes**
- Follow-back badge moved to sit below the avatar (near the stats), not on it.

**Quality picker / diagnostics**
- The DASH manifest is now located by reflection instead of guessed selector names,
  and the "DASH manifest" diagnostics line reports the candidate selectors a build
  actually exposes — so the real accessor can be pinned down on IG 410.

## v3.0.11

**Fixes**
- Build fix: declared the follow-badge helper selectors on `IGProfilePictureImageView`
  so the tweak compiles (v3.0.10 failed to build).

## v3.0.10

**Diagnostics**
- New "DASH manifest" line under Last video download: reports whether the manifest
  is reachable on this build and how many video resolutions it yields.

**New**
- **Follow-back badge on profiles.** A colored pill now sits on the profile-header
  avatar — green "Follows you" or red "Doesn't follow you" — visible directly on the
  profile, no long-press needed, and suppressed on your own profile.

**Fixes**
- **Quality picker — the real fix.** On Instagram 410 `videoVersions` returns a
  single progressive rendition (e.g. 720p), so the picker had nothing to offer. The
  higher resolutions live in the **DASH manifest**; Albrhi now parses it and lists
  every real quality (1080p, etc.). When a video genuinely has one quality, no
  picker appears — by design.

## v3.0.8

**Localization**
- Full Arabic pass: every settings page, section header, dropdown menu, stepper
  label and DM seen/replay toast is now localized — no hard-coded English left in
  the settings UI.

**New**
- **Follow-back status.** Long-press a profile picture to see whether that account
  follows you ("Follows you" / "Doesn't follow you"), and it's added to the copied
  account info. Toggle under Downloads → Show follow-back status.

**Fixes**
- Quality picker now applies to **story videos** too. They previously resolved a
  single URL directly and skipped the picker; they now route through the same
  coordinator as feed and reels.
- More robust rendition extraction: broader set of URL accessors, and a last-resort
  picker built from `allVideoURLs` when a build exposes no resolution metadata.

## v3.0.1

**Fixes**
- **Quality picker now actually runs.** `show_quality_picker` was never registered as a
  default, so it sat off for everyone regardless of the toggle. It now defaults on.
- Every download path — feed, reels, stories and the inline button — routes through one
  coordinator, so the picker applies everywhere instead of feed videos only.
- Quality list falls back to `sortedVideoURLsBySize` on builds without `videoVersions`, and
  duplicate renditions served from different CDNs are collapsed.

**New**
- **Welcome / What's New screen** on first install and after every update.
- **Mark-as-seen button** — an eye toggle in the story viewer. Off means invisible viewing as
  before; on means the story you're watching registers as seen.
- **Diagnostics page** (Settings → Debug) reporting which action-row classes exist in your
  Instagram build, where the download button attached, how many renditions the last video
  offered, and how many seen receipts were blocked. Copyable as a report.

**Known issues**
- The inline download button still does not appear on some builds. The diagnostics page exists
  to identify which class the action row uses on the affected device.

## v3.0.0 — Foundation rebuild

**Download Center**
- Full download queue on a background `NSURLSession` — transfers continue after you leave the app.
- Real pause and resume via resume data: a paused transfer continues where it stopped.
- Retry, cancel, concurrency limit (`dl_max_concurrent`), duplicate detection and a persistent
  history of the last 250 downloads.
- New Download Center screen: live progress rings, search, filter by media kind, sorting, swipe
  actions, context menus and bulk controls.

**Inline download button**
- A native download icon in the post action row, next to save (`inline_download_button`,
  on by default). One tap replaces the long press.
- Routes into the queue when `dl_use_queue` is on, otherwise uses the original HUD flow.

**Architecture**
- Settings are now self-registering: each page lives in its own file under `Settings/Pages/` and
  declares itself through `SCISettingsRegistry`. `TweakSettings.m` dropped from 550 lines to a thin
  composer, and adding or deleting a feature no longer touches shared files.
- Removed the leftover example section and demo menu from the upstream project.

**Identity**
- Developer links — Instagram, Snapchat and Telegram accounts open directly from Settings.
- Credits attribute Ibrahim Ismail AL-Rahn and link to this repository; SCInsta remains credited
  as the upstream project under GPLv3.
- Professional package description for Sileo, and a fully rewritten README.

**Fixes**
- Fixed a race where pausing a download recorded it as cancelled and lost the transfer.
- Fixed the CI version parser, which could pick up any line containing `Version:` from the new
  multi-line package description.

## v2.3.0
- Initial inline download and identity work, superseded by v3.0.0.

## v2.2.0
New features (all verified against the class-dump of Instagram 409):
- **Choose quality before download** — pick from available resolutions (`show_quality_picker`).
- **Reel audio download** — choose video or audio-only when saving a reel (`dw_reel_audio`).
- **Silent video** — strip the audio track from downloaded videos via AVFoundation (`dw_silent_video`).
- **Copy account info** — long-press a profile picture to copy username, name, and verified status (`copy_account_info`).
- **Custom "Albrhi" album** — organize saved media into a dedicated Photos album (`custom_album`).
- **Custom accent color** — system color picker + reset; persists as hex (`albrhi_accent_hex`).
- **Real verified detection** — uses `computedIsVerified`.

## v2.1.0
- Correct video-quality selection using `IGAPIVideoVersion` (width/height/bandwidth).
- HD profile pictures via `HDMultipleProfilePicURLs` / `HDProfilePicURL`.
- Save directly to Photos option.

## v2.0.0
- Rebranded SCInsta → **Albrhi** (burnt-orange accent, credits, version).
- Full bilingual (Arabic/English) UI with automatic RTL.
- Reorganized settings; Language + Appearance sections.

Based on SCInsta by SoCuul — GPLv3.
