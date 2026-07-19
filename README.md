# Albrhi

An enhanced Instagram tweak for iOS — **maximum-quality downloads**, ad-hiding, privacy controls, and a fully **bilingual (العربية / English)** interface.

`Version v2.0.0` · Based on [SCInsta](https://github.com/SoCuul/SCInsta) by SoCuul · Licensed under **GPLv3**

---

## What's new in Albrhi (vs. the SCInsta base)

- 🟠 **New identity** — renamed to *Albrhi*, burnt-orange accent (`#E8590C`), rebranded settings & credits.
- ⬇️ **Fixed & improved downloads** — video now always selects the **highest resolution/bitrate** available (the base picked a random or the *smallest* quality). Photos already grab max resolution.
- 💾 **Save directly to Photos** — optional; bypasses the share sheet and writes straight to your library with a confirmation toast.
- 🖼️ **HD profile pictures** — long-pressing a profile photo now grabs the full-resolution `HDProfilePicURL` when available.
- 🌐 **Bilingual UI** — full Arabic + English localization with automatic RTL layout. Language auto-follows the device or can be forced from settings.

## Core features (inherited)

Hide ads · Hide Meta AI · Copy captions · No suggested content · Notes customization · Feed/Reels controls · Download feed / reels / stories / DMs / profile pics · Keep deleted messages · Disable story-seen & typing status · Confirm actions (like/follow/call/…) · Navigation customization.

## Settings

Open **Instagram → Profile → hold the three lines (☰)** top-right, or enable *quick-access* to hold the home tab.

## Building

See BUILD.md. Quick version for Dopamine 2 (rootless):

    git submodule update --init --recursive
    export THEOS_PACKAGE_SCHEME=rootless
    make package
    # -> packages/com.albrhi.tweak_2.0.0_iphoneos-arm64.deb

## License & credits

Albrhi is a derivative work of **SCInsta** by **SoCuul**, distributed under the **GNU GPL v3**. This project remains GPLv3: the source stays open, and original authorship is credited in-app (Settings -> Credits) and here. Modifications by Ibrahim.
