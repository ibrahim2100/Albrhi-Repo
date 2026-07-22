# Albrhi Changelog

## v3.1.8.3

- Video downloads now read Instagram's full DASH quality ladder, not just the
  single ready-made rendition. When a higher H.264/HEVC version is available it
  is taken automatically; otherwise nothing changes. Groundwork for saving the
  AV1-only qualities is in place but not yet switched on.

## v3.1.8.2

- The DASH diagnostic from 3.1.8.1 came back empty because it questioned only
  the video object, and because the names it looked for were guesses. It now
  asks the media object too, and asks the runtime which names exist instead of
  assuming. Diagnostics only — nothing else changes.

## v3.1.8.1

- Diagnostics now reports the DASH manifest Instagram serves for a video, and
  how many renditions it lists. Groundwork for improving download quality —
  nothing else changes.

## v3.1.8

No changes to the tweak. Published during work on the source repository.

## v3.1.7

No changes to the tweak. Published during work on the source repository.

## v3.1.6

- **The source address changed** to
  [ibrahim2100.github.io/Albrhi-Repo](https://ibrahim2100.github.io/Albrhi-Repo/).
  If you added the old one, add this instead.
- Albrhi now has a proper package page in Sileo, with the feature list, what
  changed, and version details.

## v3.1.5

**Fixed**
- **Smaller, faster builds.** Every release until now shipped as a debug build,
  carrying debug symbols and a `-1+debug` version suffix.

**New**
- Albrhi has its own source: add
  [ibrahim2100.github.io/Albrhi-Repo](https://ibrahim2100.github.io/Albrhi-Repo/)
  in Sileo or Zebra and updates arrive on their own.

## v3.1.4 — First public beta

**Fixed**
- **Mark-as-seen in DMs now actually sends the receipt.** One press marks the message
  you are looking at, and only that one — five view-once messages in a row stay
  unseen until you press each. It previously showed a green tick and sent nothing.
- Photo posts no longer fail with "could not extract URL": a photo still hands back
  an empty video object, and the download button was taking the video path.
- The inline download button appears on reels, above the like button.

**Removed**
Thirteen settings that were broken or pointless, rather than left to disappoint:
liquid glass buttons and surfaces, teen app icons, disable scrolling reels, doom
scrolling limits, the per-surface download toggles (the inline button replaces
them), long-press tuning, keep deleted messages, and the quality picker. Videos now
always download at the highest quality available.

**New**
- **Diagnostics page**, at the top level of settings. Reports which Instagram
  classes the tweak actually attached to on your build, and files a pre-filled
  GitHub issue in one tap.
- **Releases publish automatically** with both a `.deb` for jailbroken devices and a
  `.dylib` for sideloading, from a single build.
- Redesigned welcome screen, shown on first install and after each update.
- Verbose logging is now off by default and toggleable in Debug.

**Housekeeping**
- 92 orphaned translation keys removed; Arabic and English are at full parity.
- `tools/check.py` runs before every build: brace balance, duplicate interfaces,
  fragile `%orig` placement, multi-line string literals, missing imports,
  translation drift and version mismatch. Every rule exists because that exact
  mistake broke a build.

**Tested on Instagram 410.1.0** — the newest build the developer's phone will still
accept. Newer versions should work; reports from them are especially welcome.

## v3.0.28

**Changes**
- **Removed the on-screen ∞ auto-next button** from the reels action bar — the reels
  bar and its download button are back exactly as Instagram lays them out. Auto-advance
  is still toggleable from Reels settings.
- Follow-back badge now resolves the profile user via safe KVC (no crash), and shows
  correctly on the profile.

## v3.0.27

**New**
- **Auto-advance to the next reel.** When on, a finished reel scrolls to the next by
  itself (drives Instagram's own auto-scroll). Toggle in Reels settings, or with the
  ∞ button on the reels action bar, above the download button.

## v3.0.26

**Changes**
- **Quality picker removed; always downloads the highest quality automatically.** No
  more picker or toggles — every video download takes the best ready-to-play (muxed
  H.264 + audio) rendition Instagram offers. The higher DASH ladder is skipped for
  downloads because it's video-only/VP9-AV1 and won't save on iOS.

## v3.0.25

**Fixes**
- **Fixed a crash when opening a profile.** Removed the reflective ivar search that
  read arbitrary Swift ivars via `object_getIvar`. The follow badge now relies solely
  on the avatar's `-userGQL`, which is safe.

## v3.0.24

**Fixes**
- **Follow badge shows on the profile page itself** (under the followers count), no
  longer only when the profile picture is opened. The profile owner is captured from
  the header avatar's `-userGQL`, and the badge is placed on the Swift stats row.

## v3.0.23

**Fixes**
- **View-once "seen" eye is now per-message.** Marking one view-once message as seen
  no longer leaks to the next: each message opens unmarked, tapping the eye sends the
  seen receipt for that message only (on close), then resets.

## v3.0.22

**Fixes**
- **Picked-quality downloads no longer fail.** IG serves its high-res DASH ladder in
  VP9/AV1, which iOS can't save (the file opened as an image). Albrhi now keeps only
  H.264/HEVC renditions, so a picked quality actually downloads.
- **Zoom now enlarges properly.** Long-press floats an enlarged preview of the media
  over a dimmed backdrop (in-place scaling was clipped by the cell and looked wrong).
- **Long-press "download" option fully removed** — any leftover value migrates to Zoom.
- **Follow badge rebuilt for IG 410's Swift profile.** It hooks the Swift stats
  container and finds the profile user via the responder chain, then places the pill
  under the followers count (the old hook never fired on the new profile header).

## v3.0.21

**Fixes**
- **DASH quality labels were wrong** (e.g. "1421375×2560"): `width="…"` was matching
  inside `bandwidth="…"`. Added a word boundary so width/height parse correctly.

**Diagnostics**
- New "Last download URL" line records the exact URL a pick was downloaded from, to
  debug the "download failed" on picked qualities.

## v3.0.20

**Changes**
- **Removed download-by-long-press from settings.** Long-press action is now Zoom or
  Off only — downloads happen via the inline button (crash-prone press-save is gone).
- **View-once eye is now a "seen" action, not a feature switch** — clearer toasts.

**Fixes**
- **Follow badge no longer vanishes.** It anchors under the followers count when found
  and otherwise falls back to just below the avatar, and disables clipping so a tight
  stats container can't hide it.
- **DM save "could not find media"** — view-once save now routes through the shared
  coordinator (`downloadMedia`), and the permanent-media viewer reads the media off
  itself if the init capture missed.

## v3.0.19

**Fixes**
- Build fix: braced the zoom `switch` cases (blocks in a case need their own scope),
  which broke the v3.0.18 build.

## v3.0.18

**New**
- **Save button for view-once DM media.** The one-time photo/video viewer now has a
  save button (trailing) next to the mark-as-read eye — captures the media from the
  opened message and downloads it through the normal pipeline.

## v3.0.17

**Changes**
- **Follow-back badge now sits under the Followers count.** It anchors to the
  `user-detail-header-followers` stat button (found by accessibility id) instead of
  the avatar, and only appears on a real profile page — no more badge over the photo.

## v3.0.16

**New**
- **Mark-as-read eye in the view-once viewer.** Opening a view-once photo/video in
  DMs now shows an eye toggle: off = watch without registering as seen, on = mark it
  read. "Unlimited replay of visual messages" now defaults on so this works out of
  the box.

**Fixes**
- The visual-message hooks no longer swallow playback events when the feature is off.

## v3.0.15

**Changes**
- **Long-press is now Zoom by default.** Holding a post/reel/story peeks (zooms) it
  instead of downloading — download-by-press was crash-prone. New setting under
  Downloads → Long-press action: Zoom / Download / Off.

**Fixes**
- Quality downloads that resolve an extension-less URL (DASH BaseURLs) now default to
  `.mp4`/`.jpg`, fixing the save error after picking a resolution.
- DM save button is re-asserted on layout so the viewer's media can't bury it.

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
