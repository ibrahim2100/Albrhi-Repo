<div align="center">

# Albrhi · البرهي

### The complete Instagram experience for iOS — bilingual, native, open source

**العربية · English** · maximum-quality downloads · ad-free feed · real privacy controls

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)]()
[![Rootless](https://img.shields.io/badge/rootless-supported-success.svg)](#-compatibility)
[![Version](https://img.shields.io/badge/version-3.2.2-orange.svg)](CHANGELOG.md)
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

**Albrhi** is an Instagram tweak for jailbroken and sideloaded iOS. It adds maximum-quality media
downloads, strips advertising and algorithmic clutter, gives you real control over what Instagram
reports about you, and wraps it all in a settings panel that looks and feels native — in **Arabic
or English**, with automatic right-to-left layout.

Developed by **Ibrahim Ismail AL-Rahn** ([@ibrahim2100](https://github.com/ibrahim2100)).

> Albrhi is an **educational and corrective derivative** of
> [SCInsta](https://github.com/SoCuul/SCInsta) by **SoCuul**, developed with AI assistance to
> improve code quality, design, performance and user experience — while fully respecting the
> original project, its authors and its licence. Original authorship is credited in-app, in this
> README, in the package metadata and in the source headers.

---

## ✨ Features

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

## 🧩 Compatibility

| | |
|---|---|
| **iOS** | 15.0 and later |
| **Architecture** | `arm64` |
| **Instagram** | Built and tested on **410.1.0** *(not a ceiling — see below)* |
| **Jailbreaks** | Rootless (Dopamine, palera1n) · roothide · rootful (unc0ver, checkra1n) |
| **Sideloading** | Supported via the bundled FLEXing sub-project |

<details>
<summary><b>About that Instagram version</b></summary>

<br/>

Albrhi is built and tested against **Instagram 410.1.0** — the newest build the developer's phone
will still accept, and the phone is not taking questions.

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

export THEOS_PACKAGE_SCHEME=rootless   # omit for a rootful .deb
make package
# → packages/com.albrhi.tweak_3.2.2_iphoneos-arm64.deb
```

Install straight to a connected device with `make package install`. GitHub Actions builds are also
configured — see [BUILD.md](BUILD.md) and [GITHUB_BUILD.md](GITHUB_BUILD.md).

---

## 📖 Usage

Open the settings panel by **holding the ☰ button at the top right of your profile**. With *Settings
quick-access* on, holding the **home tab** works too.

- **Download** a post/reel/story with the inline download button in the action row.
- **Long-press** a post to **zoom** it (configurable under Downloads → Long-press action).
- **Search** any setting from the search bar at the top of the panel.

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
- [ ] Settings profiles — several configurations, switched per account
- [ ] Crash protection that isolates and disables a faulting feature rather than the whole tweak

---

## 🤝 Contributing

Issues and pull requests are welcome.

1. Fork and branch from `main`.
2. Keep one feature per file under `src/Features/<Category>/`; register its settings page under
   `src/Settings/Pages/` and its defaults in `src/Tweak.x`.
3. Add **both** Arabic and English strings to `src/Localization/SCILocalize.m` — never hard-code
   user-facing text (`tools/check.py` enforces parity).
4. Follow the `SCI` prefix and Objective-C style; build before opening the PR.
5. By contributing you agree your work is licensed under the GPLv3.

---

## 🙏 Credits

- **[SoCuul](https://github.com/SoCuul)** — author of [SCInsta](https://github.com/SoCuul/SCInsta), the project Albrhi is derived from.
- **[RyukGram](https://github.com/faroukbmiled/RyukGram)** by faroukbmiled (GPLv3) — a fellow SCInsta fork that identified the DM and timestamp hook points.
- **[JGProgressHUD](https://github.com/JonasGessner/JGProgressHUD)** by Jonas Gessner — MIT.
- **[dav1d](https://code.videolan.org/videolan/dav1d)** by VideoLAN — the AV1 decoder behind on-device transcoding.
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
