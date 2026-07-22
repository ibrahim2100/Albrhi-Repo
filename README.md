<div align="center">

# Albrhi

### The complete Instagram experience for iOS — bilingual, native, open source

**العربية · English** · maximum-quality downloads · ad-free feed · privacy controls

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-lightgrey.svg)]()
[![Rootless](https://img.shields.io/badge/rootless-supported-success.svg)](#rootless-support)
[![Version](https://img.shields.io/badge/version-3.1.8-orange.svg)](CHANGELOG.md)
[![Based on](https://img.shields.io/badge/based%20on-SCInsta-lightblue.svg)](https://github.com/SoCuul/SCInsta)

</div>

---

## Overview

**Albrhi** is an Instagram tweak for jailbroken and sideloaded iOS devices. It adds high-quality
media downloads, removes advertising and algorithmic clutter, gives you real privacy controls over
what Instagram reports about you, and does it all through a settings panel that looks and feels
like a native part of the app — in Arabic or English, with automatic right-to-left layout.

Developed by **Ibrahim Ismail AL-Rahn**.

## Why this project exists

Albrhi began as a study of [SCInsta](https://github.com/SoCuul/SCInsta) by **SoCuul**. Working
through that codebase surfaced real bugs — most notably video downloads that selected an arbitrary
(often the *lowest*) available quality — along with an English-only interface and a settings screen
that had grown organically rather than by design.

> This is an **educational and corrective derivative**, developed with AI assistance, whose goal is
> to improve code quality, design, performance and user experience while fully respecting the
> original project, its authors and its licence.

Original authorship is credited in-app (Settings → Credits), in this README, in the package
metadata and in the source headers. Nothing has been removed.

## Albrhi vs. the SCInsta base

| Area | SCInsta | Albrhi |
|---|---|---|
| Video download quality | Picked an arbitrary rendition, frequently the smallest | Sorts `IGAPIVideoVersion` by resolution and bitrate and always picks the best |
| Quality choice | None | Optional picker before every download |
| Profile pictures | Standard resolution | `HDProfilePicURL` / `HDMultipleProfilePicURLs` when available |
| Saving | Share sheet only | Optional direct write to Photos, with a dedicated album |
| Reel audio | — | Audio-only download, or video with the audio track stripped |
| Language | English only | Full Arabic + English with automatic RTL, switchable in-app |
| Accent colour | Fixed | System colour picker, persisted as hex |
| Identity | SCInsta | Albrhi — rebranded settings, credits and version surface |

## Features

**Media**
Download feed posts, reels, stories, carousels, DM media and profile pictures · always the best
quality iOS can save · **on-device AV1 transcoding for 1080p and above**, so the renditions
Instagram hides behind a format iOS refuses are still yours — converted on the phone, uploaded
nowhere · download queue with pause, resume and history · reel audio extraction · silent-video
export · custom Photos album · copy account info from a profile picture long-press.

**Feed & Explore**
Hide ads · hide sponsored and suggested posts · hide suggested users, reels and Threads posts ·
hide the stories tray · hide the entire feed · disable video autoplay · hide the explore grid,
trending searches, friends map and Meta AI.

**Reels**
Tap-to-pause or tap-to-mute · always-visible scrubber · disable auto-unmute · anti doom-scrolling
limit · disable scrolling · hide the reels header and blend button · refresh confirmation.

**Stories & Messages**
View stories without a seen receipt · hide the typing indicator · keep deleted messages · manual
seen marking · unlimited replay of visual messages · disable view-once limitations · disable
screenshot detection · disable instants creation.

**Confirmations**
Optional prompts before like, follow, repost, call, voice message, follow-request response, shh
mode, comment posting, chat-theme change and story-sticker interaction.

**Appearance**
Custom date formats — presets, your own `{DD}/{MM}/{YYYY} {HH}:{mm}` pattern, a threshold for how
long relative times last, compact `2h` style, or both at once · OLED theme that turns Instagram's
dark grey into true black.

**Interface**
Native inset-grouped settings · SF Symbols · customizable accent colour · full dark mode ·
Arabic/English with RTL · navigation bar tab ordering, hiding and swipe-between-tabs ·
Diagnostics page reporting what actually attached at runtime, with one-tap issue reporting.

## Compatibility

| | |
|---|---|
| iOS | 15.0 and later |
| Architecture | `arm64` |
| Instagram | Built and tested on **410.1.0** — see the note below |
| Jailbreaks | Rootless (Dopamine, palera1n) · roothide · rootful (unc0ver, checkra1n) |
| Sideloading | Supported via the bundled FLEXing sub-project |

### About that Instagram version

Albrhi is built and tested against **Instagram 410.1.0**. This was not a considered
engineering decision. It is the newest build the developer's phone will still accept,
and the phone is not taking questions.

Nothing in the tweak is pinned to a version number — every Instagram class it touches
is resolved at runtime, and anything it cannot find is skipped rather than crashed
into. So newer builds should be fine. "Should" is carrying weight there, which is
exactly why there is a Diagnostics page: it reports your Instagram version and what
the tweak actually managed to attach to, and files the whole thing as an issue in one
tap. Reports from newer builds are genuinely useful.

### Rootless support

Albrhi builds cleanly for rootless jailbreaks. Set the packaging scheme before building:

```bash
export THEOS_PACKAGE_SCHEME=rootless
```

Omit that variable for a rootful `.deb`.

## Installation

**From a release**

Each release ships three builds — take the one matching your setup:

| File | Package | For |
|---|---|---|
| `com.albrhi.tweak_*+rootless.deb` | `com.albrhi.tweak` | Rootless jailbreaks (Dopamine, palera1n) |
| `com.albrhi.tweak.roothide_*.deb` | `com.albrhi.tweak.roothide` | roothide |
| `Albrhi_*.dylib` | — | Sideloading — inject into a decrypted IPA with LiveContainer, Sideloadly or cyan |

The two packages declare `Conflicts` and `Replaces` on each other, so installing one
removes the other and they can never both be active.

1. Download the file for your setup from the Releases page.
2. Open it in Sileo, Zebra or your package manager of choice.
3. Install, then respring.
4. You can see them in my repo = https://ibrahim2100.github.io/Albrhi-Repo/
   
**From source** — see [BUILD.md](BUILD.md).

## Building

Requires [Theos](https://theos.dev) with an iOS SDK and toolchain.

```bash
git clone https://github.com/ibrahim2100/Albrhi-Repo.git
cd Albrhi-Repo
git submodule update --init --recursive

export THEOS_PACKAGE_SCHEME=rootless   # omit for rootful
make package
# → packages/com.albrhi.tweak_3.1.9_iphoneos-arm64.deb
```

Install straight to a connected device:

```bash
make package install
```

GitHub Actions builds are also configured — see [GITHUB_BUILD.md](GITHUB_BUILD.md).

## Usage

Open the settings panel by **holding the ☰ button at the top right of your profile**. If
*Settings quick-access* is enabled, holding the **home tab** works too.

Downloads are triggered by a long press on the media, using the finger count and duration
configured under Settings → Downloads.

## Roadmap

- [x] Inline download button rendered natively in the post and reel action rows
- [x] Download manager — queue, pause, resume, retry, background transfers, history
- [x] What's New screen after each update
- [x] Diagnostics — runtime info, attached hooks, live view-hierarchy scan, issue reporting
- [x] Self-publishing APT source with a browser control panel
- [x] On-device AV1 transcoding for the full quality ladder
- [ ] Searchable settings with favourites, recently used and quick actions
- [ ] Settings profiles — several configurations, switched per account
- [ ] Settings backup, restore, export and import
- [ ] Crash protection that isolates and disables a faulting feature rather than the whole tweak

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome.

1. Fork the repository and branch from `main`.
2. Keep one feature per file under `src/Features/<Category>/`, and register its settings key in
   `src/Settings/TweakSettings.m` plus its defaults in `src/Tweak.x`.
3. Add both Arabic and English strings to `src/Localization/SCILocalize.m` — never hard-code
   user-facing text.
4. Follow the existing `SCI` prefix and Objective-C style; run a build before opening the PR.
5. By contributing you agree your work is licensed under the GPLv3.

## Credits

- **[SoCuul](https://github.com/SoCuul)** — author of [SCInsta](https://github.com/SoCuul/SCInsta), the project Albrhi is derived from.
- **[RyukGram](https://github.com/faroukbmiled/RyukGram)** by faroukbmiled (GPLv3) — a fellow
  SCInsta fork, which identified the NSDate category methods Instagram formats its timestamps
  through. Albrhi's date feature attaches to the same methods.
- **[JGProgressHUD](https://github.com/JonasGessner/JGProgressHUD)** by Jonas Gessner — MIT.
- **[FLEXing](https://github.com/SoCuul/FLEXing)** — runtime debugging support.
- **Ibrahim Ismail AL-Rahn** — Albrhi rebuild, bilingual layer, download engine fixes and design.

## Connect

| | |
|---|---|
| Instagram | [@Ib.11p](https://instagram.com/Ib.11p) |
| Snapchat | [@Ib.1p](https://snapchat.com/add/Ib.1p) |
| Telegram | [@Ib11p](https://t.me/Ib11p) |

## License

Albrhi is a derivative work of SCInsta and is distributed under the **GNU General Public License
v3.0**. The full text is in [LICENSE](LICENSE). The source remains open, modifications are
documented, and original authorship is preserved as the licence requires.

Albrhi is not affiliated with, endorsed by or sponsored by Instagram or Meta Platforms, Inc.
