<div align="center">

# Albrhi · البرهي

### iOS tweaks, built in the open — bilingual, native, and written to be read

**العربية · English** · a working APT source · one repository, one tweak per app

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)]()
[![Rootless](https://img.shields.io/badge/rootless-supported-success.svg)](#-compatibility)
[![Instagram](https://img.shields.io/badge/Instagram-3.8.2-orange.svg)](tweaks/instagram/CHANGELOG.md)
[![Based on](https://img.shields.io/badge/based%20on-SCInsta-lightblue.svg)](https://github.com/SoCuul/SCInsta)

<br/>

### 📦 Add the source to your package manager

**`https://ibrahim2100.github.io/Albrhi-Repo/`**

[![Add to Sileo](https://img.shields.io/badge/Add%20to-Sileo-2C7CF0?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/Albrhi-Repo/)
[![Add to Zebra](https://img.shields.io/badge/Add%20to-Zebra-D4462D?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/Albrhi-Repo/)

</div>

---

## ⚡ Install

The easiest way — and how you get every update automatically — is to **add the Albrhi source** to Sileo or Zebra, then install *Albrhi for Instagram* from it.

**1 · Add the source**

Tap a button above, or add it by hand:

```
https://ibrahim2100.github.io/Albrhi-Repo/
```

- **Sileo** → Sources → **＋** → paste the URL.
- **Zebra** → Sources → **＋** → paste the URL.

**2 · Install** *Albrhi for Instagram* from the source, then **respring**.

The source serves both flavours; your package manager picks the right one:

| Package | For |
|---|---|
| `com.albrhi.tweak` | Rootless jailbreaks (Dopamine, palera1n) |
| `com.albrhi.tweak.roothide` | roothide |

> The two packages `Conflict`/`Replace` each other, so only one is ever active.

<details>
<summary><b>Other ways to install</b></summary>

<br/>

**From a GitHub release** — download the `.deb` for your setup from the
[Releases page](https://github.com/ibrahim2100/Albrhi-Repo/releases) and open it in your package manager.

**Sideloading (no jailbreak)** — inject the `Albrhi_*.dylib` into a decrypted Instagram IPA with
LiveContainer, Sideloadly or cyan.

**From source** — see [Building](#-building) below and [BUILD.md](BUILD.md).

</details>

---

## Overview

**Albrhi** is a personal workshop for iOS tweaks that also happens to be a working APT source: it
builds itself, publishes its own releases, and serves a Sileo/Zebra repository from GitHub Pages.
It is written for learning as much as for using — the code is commented to explain *why*, not just
what, and the reasoning behind the awkward parts is kept in [CLAUDE.md](CLAUDE.md) rather than lost.

Developed by **Ibrahim Ismail AL-Rahn** ([@ibrahim2100](https://github.com/ibrahim2100)).

### What is in here

| Tweak | App | Status |
|---|---|---|
| **Albrhi for Instagram** | Instagram | **Released** — `com.albrhi.tweak` |
| **Albrhi for YouTube** | YouTube | **Released** — `com.albrhi.youtube`: video downloads, no ads, SponsorBlock, background playback |

Each tweak is a self-contained project under `tweaks/`, with its own sources, package identity and
version number. They are **separate packages that never meet at runtime**: an injection filter binds
each dylib to one bundle id, so the YouTube tweak is never loaded into Instagram and neither can
affect the other on your device. What they share is the build plumbing — the checks, the build
script and the APT index — which is why installing one has nothing to do with the other.

> Albrhi is an **educational and corrective derivative** of
> [SCInsta](https://github.com/SoCuul/SCInsta) by **SoCuul**, developed with AI assistance to
> improve code quality, design, performance and user experience — while fully respecting the
> original project, its authors and its licence. Original authorship is credited in-app, in this
> README, in the package metadata and in the source headers.

---

## ✨ Albrhi for Instagram

### 📥 Downloads
- One-tap **download button** in the post and reel action rows.
- Posts, reels, stories, **whole albums** (choose one slide or all), DM media and **HD profile pictures**.
- Always the best quality iOS can save — plus **on-device AV1 → 1080p transcoding** (decoded with
  dav1d, re-encoded with VideoToolbox), so the qualities Instagram hides behind a format iOS
  refuses are still yours. Nothing is uploaded anywhere.
- **Download Center** — queue, pause, resume, retry, background transfers and history.
- Reel audio extraction · silent-video export · dedicated Photos album.

### 🧹 Feed & Explore
Hide ads, sponsored and suggested posts · suggested users, reels and Threads posts · stories tray ·
the entire feed · explore grid · trending searches · friends map · Meta AI · disable video autoplay.

### 🎬 Reels
Tap-to-pause or tap-to-mute · always-on scrubber · disable auto-unmute · anti doom-scrolling ·
disable scrolling · hide the header and blend button · refresh confirmation.

### ✉️ Stories & Messages
View stories with no seen receipt · a story download button · save DM photos & videos (even
view-once) with per-message mark-as-seen · **full last-active time** as a real date · **hide the
voice and video call buttons** · hide the typing indicator · replay visual messages · disable
screenshot detection.

### 🔒 Confirmations
Optional prompt before like, follow, repost, call, voice message, follow-request response, Shh
mode, comment, chat-theme change and story-sticker tap — so a mis-tap never becomes a notification.

### 🎨 Appearance
Custom **date & time formats** everywhere Instagram writes a time — presets, your own pattern,
12/24-hour, combine-with-relative · **OLED black theme** · customizable accent colour.

### 👤 Profile
**Follow-back badge** under the followers count (green *follows you* / red *doesn't*) · copy account
info · save HD profile pictures.

### 🛠️ Interface
Native inset-grouped settings with **search** · **backup & restore** all your settings to a file ·
**copy any text** (caption, comment, bio) by long-press · full dark mode · Arabic/English with RTL ·
navigation-bar tab ordering, hiding and swipe-between-tabs · a **Diagnostics** page reporting what
actually attached at runtime, with one-tap issue reporting.

---

## ▶️ Albrhi for YouTube

### 💾 Save a video
**Hold the video**, or open the panel, and the qualities appear — pick one and it goes to
Photos with a percentage while it works.

Getting there took nine releases of measuring, and the finding is worth stating: on this
build **every individual quality arrives without a download address**, through the media
layer, the format nested inside it, the player response and four ways of asking YouTube
directly. What does have an address is the **playlist** that lists them — which is where
every tweak whose downloading works ends up.

The difference is what gets carried to finish the job. YouTube serves those parts as
MPEG-TS, which iOS has never opened from a file, and the usual answer is to bundle FFmpeg
— **between 2 and 19 MB** of media library. Albrhi bundles none: the picture inside is
already H.264 and the sound already AAC, so the transport wrapper is unpacked in about
600 lines and Apple's own writer builds the .mp4. Nothing is re-encoded, so nothing loses
quality, and the tweak stays small.

Qualities iOS cannot play are filtered out *before* they are offered, and a failure names
which of the three things went wrong rather than one sentence for all of them.

### 🚫 No ads
Stopped at three points, because they arrive by three routes and blocking one does nothing about
the others: the app **stops asking** for ads at all, promoted rows are dropped from the feed by the
identifier YouTube's own servers attach to them, and the player refuses ads before a video, mid-video,
and the kind **stitched into the stream itself**.

### ⏭️ Skip the sponsored parts
Paid plugs, self-promotion and subscribe reminders are jumped over automatically, using segments
other viewers submitted to **SponsorBlock**. A short line names what was skipped and offers an undo,
and each segment is **coloured on the progress bar** so you can see what is coming. Eight categories,
each with its own switch — intros, endcards, recaps and tangents are off until you turn them on.

**Your video is never sent.** SponsorBlock offers two ways to ask; this uses the one that sends only
the first four characters of the video's fingerprint, so the server cannot tell which video you are
watching. Nothing is requested at all when the feature is off.

### 🎧 Background playback
Audio keeps going when you leave the app or lock the screen.

### 🤫 Quieter
Silence the prompt to update — updating replaces the app and removes the tweak. And optionally hide
the paid-promotion banner, off by default, because it is a disclosure.

### ⚙️ Settings & diagnostics
**Hold two fingers anywhere** in YouTube. Arabic and English with RTL, and a card at the top saying
whether everything actually attached to *your* build. The report is also written to
`Documents/AlbrhiYT-report.txt`, so it is readable even if nothing else worked.

> Hooked on YouTube's **model and service layer, never its views** — view classes get renamed between
> releases and a tweak that hooks them quietly stops working. The one exception is the progress-bar
> colouring, which has to be drawn on a view; it is laid out with frames rather than constraints, and
> a fault there costs the colours, never the video.

---

## 🧩 Compatibility

| | |
|---|---|
| **iOS** | 15.0 and later |
| **Architecture** | `arm64` — runs on arm64 and arm64e devices |
| **Instagram** | Built and tested on **410.1.0 and 439.0.0**, from one build *(not a ceiling — see below)* |
| **Jailbreaks** | Rootless (Dopamine, palera1n) · roothide · rootful (unc0ver, checkra1n) |
| **Sideloading** | Supported via the bundled FLEXing sub-project |

<details>
<summary><b>About that Instagram version</b></summary>

<br/>

Albrhi is built and tested against **Instagram 410.1.0 and 439.0.0** — one build serves both. 410 is
the newest release the developer's phone will still accept, and the phone is not taking questions;
439 is kept alongside it precisely so version differences are measured in two real binaries instead
of guessed at.

Nothing is pinned to a version number: every Instagram class the tweak touches is resolved at
runtime, and anything it can't find is skipped rather than crashed into. Newer builds *should* be
fine — which is exactly why there's a **Diagnostics** page. It reports your Instagram version and
what actually attached, and files the whole thing as an issue in one tap. Reports from newer builds
are genuinely useful.

</details>

---

## 🔨 Building

Requires [Theos](https://theos.dev) with an iOS SDK and toolchain.

```bash
git clone https://github.com/ibrahim2100/Albrhi-Repo.git
cd Albrhi-Repo
git submodule update --init --recursive
./build.sh instagram rootless
```

The result lands in `tweaks/instagram/packages/`. Swap `rootless` for `roothide`, `rootful` or
`sideload`. `python3 tools/check.py` runs the source checks on their own — it takes a second and
catches the mistakes that have actually broken this build before.

GitHub Actions builds are also configured — see [BUILD.md](BUILD.md) and
[GITHUB_BUILD.md](GITHUB_BUILD.md).

### Layout

```
tweaks/<app>/     a complete tweak: Makefile, control, filter plist, src/
shared/           the Theos flags and build modes every tweak shares
tools/            source checks, APT index, depiction, logo, .deb editing
modules/ vendor/  third-party code, shared
extra-debs/       drop a .deb here and the source publishes it
```

Adding a tweak means adding a directory under `tweaks/` — `tools/check.py` finds it and checks it
without being told, and `./build.sh <name> rootless` builds it. Releasing a second one still needs
the workflow taught about per-tweak versions and tags; see [CLAUDE.md](CLAUDE.md).

---

## 📖 Usage

**On Instagram** — open the panel by **holding the ☰ button** at the top right of your profile. With
*Settings quick-access* on, holding the **home tab** works too.

- **Download** a post/reel/story with the inline download button in the action row.
- **Long-press** a post to **zoom** it (configurable under Downloads → Long-press action).
- **Search** any setting from the search bar at the top of the panel.

**On YouTube** — open the panel by **holding two fingers anywhere**. It is deliberately not in
YouTube's own settings: two attempts at that crashed the app, because a settings entry has to satisfy
tables the tweak cannot reach. The gesture is on `UIWindow`, which is UIKit and cannot go missing.

- **Hold the video** to save it — or use the row in the panel.
- Everything else is a switch in the panel, and the card at the top says whether it all attached to
  your build.

---

## 🗺️ Roadmap

- [x] Native inline download button in post and reel action rows
- [x] Download Center — queue, pause, resume, retry, background transfers, history
- [x] On-device AV1 transcoding for the full quality ladder
- [x] Custom date & time formats, OLED theme
- [x] Searchable settings
- [x] Backup, restore, export and import of settings
- [x] Diagnostics — runtime info, attached hooks, live view-hierarchy scan, issue reporting
- [x] Self-publishing APT source with a browser control panel
- [x] **Albrhi for YouTube** — a second tweak in this repository, sharing none of Instagram's runtime
- [x] Video downloads on YouTube, without bundling a media library to convert them
- [ ] Settings profiles — several configurations, switched per account
- [ ] Crash protection that isolates and disables a faulting feature rather than the whole tweak

---

## 🤝 Contributing

Issues and pull requests are welcome.

1. Fork and branch from `main`.
2. Keep one feature per file under `tweaks/instagram/src/Features/<Category>/`; register its settings page under
   `tweaks/instagram/src/Settings/Pages/` and its defaults in that tweak's `src/Tweak.x`.
3. Add **both** Arabic and English strings to `tweaks/instagram/src/Localization/SCILocalize.m` — never hard-code
   user-facing text (`tools/check.py` enforces parity).
4. Follow the `SCI` prefix and Objective-C style; build before opening the PR.
5. By contributing you agree your work is licensed under the GPLv3.

---

## 🙏 Credits

- **[SoCuul](https://github.com/SoCuul)** — author of [SCInsta](https://github.com/SoCuul/SCInsta), the project Albrhi is derived from.
- **[RyukGram](https://github.com/faroukbmiled/RyukGram)** by faroukbmiled (GPLv3) — a fellow SCInsta fork that identified the DM and timestamp hook points.
- **[JGProgressHUD](https://github.com/JonasGessner/JGProgressHUD)** by Jonas Gessner — MIT.
- **[dav1d](https://code.videolan.org/videolan/dav1d)** by VideoLAN — the AV1 decoder behind on-device transcoding.
- **[SponsorBlock](https://sponsor.ajay.app)** by Ajay Ramachandran — the segment database the YouTube tweak skips by, CC BY-NC-SA 4.0.
- **[iSponsorBlock](https://github.com/Galactic-Dev/iSponsorBlock)** by Galactic Dev (GPLv3) — the YouTube tweak's coloured progress-bar markers are derived from it.
- **[FLEXing](https://github.com/SoCuul/FLEXing)** — runtime debugging support.
- **Ibrahim Ismail AL-Rahn** — Albrhi rebuild, bilingual layer, download & transcode engine, and design.

---

## 📬 Connect

| | |
|---|---|
| Instagram | [@Ib.11p](https://instagram.com/Ib.11p) |
| Snapchat | [@Ib.1p](https://snapchat.com/add/Ib.1p) |
| Telegram | [@Ib11p](https://t.me/Ib11p) |

---

## ⚖️ License

Albrhi is a derivative work of SCInsta, distributed under the **GNU General Public License v3.0**
([LICENSE](LICENSE)). The source stays open, modifications are documented, and original authorship
is preserved as the licence requires.

*Albrhi is not affiliated with, endorsed by or sponsored by Instagram or Meta Platforms, Inc.*
