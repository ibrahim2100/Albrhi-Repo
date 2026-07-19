# Albrhi Changelog

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
