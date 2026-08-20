<div align="center">

# Albrhi · البرهي

### iOS tweaks, built in the open — bilingual, native, and written to be read

**العربية · English** · a working APT source · nine tweaks, seven in one package

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)]()
[![Rootless](https://img.shields.io/badge/rootless-supported-success.svg)](#-compatibility)
[![Albrhi](https://img.shields.io/badge/Albrhi-1.57.0-blueviolet.svg)](suite/CHANGELOG.md)
[![Instagram](https://img.shields.io/badge/Instagram-4.1.10-orange.svg)](tweaks/instagram/CHANGELOG.md)
[![YouTube](https://img.shields.io/badge/YouTube-1.20.0-red.svg)](tweaks/youtube/CHANGELOG.md)
[![X](https://img.shields.io/badge/X-0.14.0-black.svg)](tweaks/twitter/CHANGELOG.md)
[![TikTok](https://img.shields.io/badge/TikTok-0.18.0-ff0050.svg)](tweaks/tiktok/CHANGELOG.md)
[![Spotify](https://img.shields.io/badge/Spotify-0.2.3-1DB954.svg)](tweaks/spotify/CHANGELOG.md)
[![YT Music](https://img.shields.io/badge/YT%20Music-0.1.0-FF0000.svg)](tweaks/ytmusic/CHANGELOG.md)
[![NextUp](https://img.shields.io/badge/NextUp-0.1.5-FF375F.svg)](tweaks/nextup/CHANGELOG.md)
[![Watch](https://img.shields.io/badge/Watch-0.5.2-FF375F.svg)](tweaks/watch/CHANGELOG.md)
[![Based on](https://img.shields.io/badge/based%20on-SCInsta-lightblue.svg)](https://github.com/SoCuul/SCInsta)

<br/>

### 📦 Add the source to your package manager

**`https://ibrahim2100.github.io/Albrhi-Repo/`**

[![Add to Sileo](https://img.shields.io/badge/Add%20to-Sileo-2C7CF0?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/Albrhi-Repo/)
[![Add to Zebra](https://img.shields.io/badge/Add%20to-Zebra-D4462D?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/Albrhi-Repo/)

</div>

---

## ⚡ Install

**There is one package to install: `com.albrhi`, listed as *Albrhi*.** It carries the
Instagram, YouTube, X and TikTok tweaks and the Settings panel together — one thing to
install, one thing to update, and a new tweak arrives inside it rather than as a second
download.

**1 · Add the source**

Tap a button above, or add it by hand:

```
https://ibrahim2100.github.io/Albrhi-Repo/
```

- **Sileo** → Sources → **＋** → paste the URL.
- **Zebra** → Sources → **＋** → paste the URL.

**2 · Install** *Albrhi*, then **respring**.

The source serves both flavours; your package manager picks the right one:

| Package | For |
|---|---|
| `com.albrhi` | Rootless jailbreaks (Dopamine, palera1n) |
| `com.albrhi.roothide` | roothide |

> The two `Conflict`/`Replace` each other, so only one is ever active. What makes a package
> roothide is its *paths*, not its control file, so the two are genuinely different builds
> rather than the same one relabelled.

**3 · Choose what it patches.** Settings → **Albrhi** lists every app, with a switch each.
Turning one off leaves the package installed and its settings intact; reopen that app for
the change to take effect.

> **The individual packages are no longer served.** `com.albrhi.tweak`,
> `com.albrhi.youtube` and the rest were frozen at whatever version they last published —
> the source was offering YouTube 1.9.0 while the suite carried 1.13.0 — and they could
> never have updated, because nothing publishes them any more. `com.albrhi` declares
> `Conflicts`/`Replaces` on all ten of those identities anyway, so a device could not hold
> both. If you installed one before, it still works; install the suite and it is removed
> for you.

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

**Nine tweaks. Seven ship inside `com.albrhi`; two stand on their own.**

| Tweak | Patches | Version | What it does |
|---|---|---|---|
| **Albrhi for Instagram** | Instagram | 4.1.10 | downloads, a quieter feed, watching without a seen receipt |
| **Albrhi for YouTube** | YouTube | 1.20.0 | downloads with their own player, no ads, SponsorBlock, background playback |
| **Albrhi for X** | X / Twitter | 0.14.0 | media downloads, and the feature switches X asks itself about |
| **Albrhi for TikTok** | TikTok | 0.18.0 | a download button in the feed, photo posts, no ads, confirmations, privacy, extras |
| **Albrhi for Spotify** | Spotify | 0.2.3 | no ads, no Premium popups, sponsored podcast segments skipped |
| **Albrhi for YouTube Music** | YouTube Music | 0.1.0 | no ads, background playback without the upsell |
| **Albrhi Panel** | Settings | 0.9.21 | the Albrhi page — one switch per patched app, and a page per tweak |
| **Albrhi NextUp** | SpringBoard, Music, Podcasts, YouTube, YT Music, Spotify | 0.1.5 | what plays next, on the Lock Screen — **its own package** |
| **Albrhi Watch** | SpringBoard, Watch app | 0.5.2 | pair an Apple Watch on a newer watchOS than iOS expects, and hold watchOS 26 back — **its own package** |

Each is a self-contained Theos project under `tweaks/`, with its own sources, package
identity and version number, and **they never meet at runtime**: an injection filter binds
each dylib to one bundle id, so the YouTube tweak is never loaded into Instagram. What they
share is the build plumbing — the checks, the build script and the APT index.

`com.albrhi` is the merge of the first seven, built by `tools/make-suite.sh`, which picks up
any `tweaks/*/control` automatically. A tweak leaves the merge only by carrying a
`.no-suite` marker file in its directory — NextUp and Watch are the two that do.

**Albrhi for Locket was removed from this repository**, on the owner's instruction to isolate it
completely: it left the suite first, then left the project. Its five `locket-v*` releases stay on
the releases page as history, and the source no longer serves them — deleting a tweak does not
stop an index built from published releases from offering it, so `com.albrhi.locket` is named in
`WITHHELD_PACKAGES` as well.

**Albrhi CarPlay was removed from this repository.** It patched SpringBoard and Camera to put an
app on the car display, and it never ran on a device: 0.3.0 and 0.4.0 each looked finished and were
not, and 0.4.1's fixes for what a real iOS 16.1 report found missing were themselves never observed.
A tweak that takes the home screen with it when a hook is wrong does not belong in a source that
updates for a download button, so it is going to be rebuilt from scratch in a repository of its own.
Its `carplay-v*` releases stay on the releases page as history, and the source no longer serves
them — deleting a tweak does not stop an index built from published releases from offering it, so
`com.albrhi.carplay` stays named in `WITHHELD_PACKAGES`.

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
- Always the best quality your iPhone can save. Some of Instagram's higher qualities come in a
  format iOS will not play; Albrhi converts those **on your phone** so you still get them.
  Nothing is ever uploaded anywhere.
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
**Hold the video** and the qualities appear — pick one, and it lands in the Download Centre
with a percentage while it works. **Shorts get a save button** of their own, beside like and
share, because Shorts has no long press to spare.

Video or audio, your choice. Sound is saved as a proper `.m4a` with the cover art from the
video, so it arrives somewhere else looking like a song rather than an untitled file.

YouTube no longer hands out a direct link for a video, so the tweak collects it in pieces
and puts them back together on your phone. Most tweaks bundle a large media library to do
that last step; Albrhi does it without one, so the download stays small and **nothing is
re-encoded** — the quality you picked is the quality you get.

Qualities your iPhone cannot play are left out of the list rather than offered and then
failing, and if something does go wrong the message says what.

### 📁 The Download Centre
A **tab of its own**, beside Home and You — not a panel over the app. YouTube draws that tab
itself, so it has a real label, a real selected state, and its share of the width.

Inside: everything you have saved, in video and audio, with a player written for the job.
Landscape fills the screen, the controls fade while you watch and come back with a tap, and
double-tapping either side jumps ten seconds. **Picture in picture**, playback speed, a sleep
timer, AirPlay, and it remembers where you stopped — days later, across restarts.

A **mini bar** along the bottom keeps the sound going while you look through the rest, and
tapping it puts the full screen back where it was. The lock screen gets the title, the artwork,
a scrubber you can drag, and next and previous that move through your own list.

Rename anything you have saved, share it, or send it to Photos — the tweak keeps it and does
not decide for you where it should live.

### 🚫 No ads
Blocked in three places, because ads arrive three different ways: the app stops asking for them,
promoted posts are dropped from the feed, and the player refuses ads before a video, in the middle
of one, and the kind built into the video itself.

### ⏭️ Skip the sponsored parts
Paid plugs, self-promotion and subscribe reminders are jumped over automatically, using segments
other viewers submitted to **SponsorBlock**. A short line names what was skipped and offers an undo,
and each segment is **coloured on the progress bar** so you can see what is coming. Eight categories,
each with its own switch — intros, endcards, recaps and tangents are off until you turn them on.

**Which video you are watching is never sent.** SponsorBlock offers two ways of asking, and this
uses the private one, so the server cannot tell what you are watching. Nothing is sent at all when
the feature is off.

### 🎧 Background playback
Audio keeps going when you leave the app or lock the screen — YouTube's own video, and anything
saved.

### 📶 A quality ceiling
Separately for Wi-Fi and for mobile data. Set mobile to 480p and a video on the road stays at
480p without touching what you get at home. It is a ceiling, not a fixed quality: YouTube still
drops lower on its own when the connection cannot keep up. The full quality list is available
too, instead of the two-line shortcut newer builds show.

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

## 🎵 Albrhi for TikTok

### ⬇️ A download button in the feed
A blurred disc with a down arrow, **above the profile picture** on every video, riding with
TikTok's own rail as it fades and returns. It saves the clip you are watching — not the one
before it — because the video is read from the controller the button is sitting inside at the
moment you tap it, rather than from whatever was resolved most recently.

Quality is **measured, not guessed**. Every link TikTok offers is collected and weighed by what
it actually is: a watermarked copy loses to a clean one, an audio-only link loses to a video,
and only then does size decide. Watermarking is refused at the source — the value is written,
not the getter answered, so code reading it directly sees the same thing.

Optionally, HD can be fetched from an outside service instead. **That switch is off, and it
stays off unless you turn it on**, with the cost written on its own row: it tells a service
outside TikTok which video you are watching, which is the exact thing the privacy switches
beside it exist to prevent. On some videos it returns the original upload — 60fps where TikTok's
own stream is 30 — and on others it is byte for byte the file the tweak already had.

### 🖼️ Photo posts
A photo post saves as photos. **It asks first**: the picture you are on, or all of them —
and the picture you are on is the one the paging controller says is on screen, read at the tap.

A single picture can also be saved **as a short video with the post's own sound over it** —
five, ten or fifteen seconds — which is what a photo post actually was. The sound is optional
in the export: a post whose music cannot be fetched still gives you the clip.

### 🚫 Ads
A feed item TikTok's own server marked as an ad is refused as the object is built, never hidden
after the fact — and the splash ad on launch with it.

### ✋ Confirmations
Ask before a like — the heart *and* the double tap — and ask before a follow, on the feed and on
a profile. Both off until you turn them on. If the question cannot be shown for any reason, the
tap you made goes through: "ask me first" must never quietly become "liking is broken".

### 🔒 Privacy
Three separate switches, because they are three different reports to three different places: a
story's seen mark, a message's read receipt, and a profile view. What shows on your own screen is
never touched — only what gets sent back.

### 🧩 Extras
**More logged-in accounts** — TikTok caps how many may be signed in at once, and the cap is the
app's own. Raised, not removed.

**Messages the sender took back stay visible, and say so.** TikTok had already delivered the
message and then received an instruction to hide it; hiding is the app's own doing, and this
refuses that instruction. Nothing is fetched back from a server — and the message is **marked as
taken back** rather than restored as though nothing happened, because a tweak that leaves no trace
of what it decided is deciding on your behalf without saying so.

**A record of profile visitors**, kept as TikTok delivers them, so somebody who blocks you
afterwards does not erase what already arrived. TikTok's own list is never modified: Albrhi keeps
its own, bounded, and shows it on its own screen.

### 🎛️ Also
The seek bar under the video kept visible instead of fading a moment after playback starts · the
jailbreak answered for as an unmodified phone would · a settings screen grouped by what you came
to change, with the full diagnostic report one row away and copyable in a tap.

---

## 🎧 Albrhi for Spotify

### No ads — and **no Premium**
Audio and display advertising is refused where Spotify asks for it, the home feed's sponsored rows
are filtered out of the JSON before the screen is built, and the "go Premium" popups are dropped as
they are presented.

**This does not unlock a paid subscription.** It does not touch your account, does not report you as
a subscriber, and does not remove the skip limit or raise the audio quality — those are account
attributes the server decides, not switches inside the app. The tweak the ad blocking comes from is
known for exactly that, and it is the one thing deliberately not carried over. The settings page says
so above its own switches rather than leaving it to be discovered.

### Sponsored segments in podcasts
Sponsored, self-promotion and interruption segments are skipped from SponsorBlock's community
database, with a note saying which one was skipped — a segment skipped silently is indistinguishable
from a track that jumped on its own. **Off until you turn it on:** it asks a third-party server about
what is playing, and that is a cost paid only by somebody who chose it.

> **The ad blocking and SponsorBlock are not this project's work.** They are
> [EeveeSpotify](https://github.com/SideloadLabs/EeveeSpotifyReincarnated) by **Eevee** and the
> **SideloadLabs** team, under GPLv3 — the same licence Albrhi ships under, which is what makes
> carrying them over lawful rather than merely possible. Every ported file is kept diffable against
> upstream; Albrhi adds the gate, the settings page and the bilingual interface.

---

## 🎼 Albrhi for YouTube Music

### No ads, and background playback left alone
Advertising is refused where YouTube Music asks for it, and the monetisation flags its player
response carries are answered as an unmonetised video would answer them. Background playback keeps
going without the upsell notification that interrupts it.

**This does not unlock Premium.** The tweak these hooks come from tells YouTube Music the account is
a paying one; that is the single thing not carried over. The two files taken here never ask what the
account is — `RemoveAds.x` does not contain the word.

> **The hooks are not this project's work.** They are
> [YTMusicUltimate](https://github.com/dayanch96/YTMusicUltimate) by **dayanch96**, under GPLv3 —
> the same licence Albrhi ships under, which is what makes carrying them over lawful. Albrhi adds
> the gate and the packaging; every ported file is kept diffable against upstream, with each edit
> written where it is.

---

## ⏭️ Albrhi NextUp

### What plays next, without opening the app
A row under the now-playing controls — the next track's title, artist and cover — on the
**Lock Screen**, in **Control Center** and in the **Dynamic Island**. Tap the cover to play it
now, or skip it, without ever opening the app that is playing.

### Five apps, each read from its own queue
| App | Support |
|---|---|
| **Apple Music** | Full |
| **Apple Podcasts** | Full |
| **YouTube Music** | Full — built against **9.28.4** |
| **YouTube** | Full — built against **21.32.4**. A playlist or mix has a real queue; a standalone video has none, so YouTube's own **autoplay suggestion** is shown instead — playable, but not skippable or re-orderable, and its cover is 16:9 rather than square |
| **Spotify** | Full — built against **9.1.62** |

Each row shows what that app itself would play next, read from the app's own playback queue —
not a guess. The version beside an app is the build its reader was written against: a newer app
usually still works, and when a row goes blank after an update, that number is the first thing
to check. The same table is on the package's depiction and under each switch in Settings.

### Settings
**Settings › Albrhi › Albrhi NextUp** — a master switch, one per surface, and one per app.
Changes apply immediately, with no respring. **The master is off until you turn it on**, which is
this port's own change to the original: Albrhi does not patch anything you did not ask for, and
this one injects into SpringBoard and five media apps.

> **A port, not an original.** Albrhi NextUp is [NextUp 3](https://github.com/Yves000/NextUp3) by
> **Yves**, used and redistributed under the GNU GPL v3 — the same licence this project ships
> under, which is what makes carrying the code over lawful where an unlicensed tweak may only be
> read for architecture. The design, the private-API research and very nearly all of the
> implementation are Yves's work. This port replaced the Settings pane with a page inside Albrhi
> Panel and rebranded the package; the feature itself is not this project's invention.

> **It injects into SpringBoard.** A wrong hook there takes the home screen with it — have a way
> back in (SSH, or a package manager reachable from safe mode) before installing any build. On a
> jailbreak with per-app tweak injection, the five media apps need injection enabled too, or the
> row stays empty: the display side is up and no provider answers it.

---

## ⌚ Albrhi Watch

### Pair a watch iOS does not expect
iOS refuses to pair with an Apple Watch whose watchOS is newer than it expects, and refuses to
install companion apps onto it. Albrhi Watch answers those compatibility questions the way a
supported pairing would — the pairing gate, the watch's declared capabilities, and the companion
app runtime check — so setup completes and apps install.

### Hold watchOS 26 back
A watch that updates to a watchOS your iPhone cannot pair with is a watch you cannot set up again.
So the update can be held — and it is a **filter, not a blanket refusal**: the version is read from
the update itself, so watchOS 26 and newer is withheld while the security updates for the watchOS
your watch is on are still offered. An update whose version cannot be read is let through, because
a hold that fires when it cannot tell what it is holding is not a filter.

Nothing can start a held update: the scan result, the install button's own two actions, the
download and the installation are each refused separately.

### And the page says who held it
Withholding an update makes iOS tell you the watch is up to date — a sentence the tweak caused and
iOS believes. So the watch's Software Update page carries a note naming Albrhi as the reason and
the switch that undoes it, and the install row is disabled and says the same. **A tweak that makes
the system state a fact about your device, without saying it did, is worse than the thing it hid.**

### Switches, restarts and a report
**Settings › Albrhi › Albrhi Watch.** The master is off until you turn it on: this answers the
questions iOS asks before it agrees to pair, and that should never begin because a package landed.
Each answer has its own switch, so a watch that pairs but misbehaves can have one of them turned
off rather than the tweak removed. The page says whether it is on above its own switches, because
every row below the master is inert while it is off.

**A full userspace restart is what applies a pairing change** — measured on a device: the limits are
written once by SpringBoard and every other process reads them when it next starts, so a respring
leaves the Watch app and the daemons holding what they cached at boot. The page's own buttons
(reload SpringBoard, reload the Watch app) are the lesser version and are named as such.

The report says which classes were present on your build, what the update hold installed and what
it skipped, which watchOS version it held, and whether the tweak ran in the Watch app at all —
**"a pairing that fails looks exactly like a tweak that never loaded"**, and the pairing screen
shows neither.

> **The pairing core is not this project's work.** It is
> [watched](https://github.com/34306/watched) by **34306**, used under the MIT licence — carried
> over as code, which MIT permits, with its notice shipped inside the package as MIT requires.
> Albrhi adds the update hold, the switches, the settings page, the diagnostics and the bilingual
> interface.

> **It injects into SpringBoard.** Have a way back in before installing any build.

---

## 🧩 Compatibility

| | |
|---|---|
| **iOS** | 15.0 and later |
| **Architecture** | `arm64` — runs on arm64 and arm64e devices |
| **Instagram** | Tested on **410, 439 and 441**, from one build *(other versions should work — see below)* |
| **YouTube** | Tested on **21.30.5** |
| **X / Twitter** | Tested on **12.15** |
| **TikTok** | Tested on **46.4.0** |
| **Watch** | iOS **15+**, any watchOS the pairing gate is asked about |
| **NextUp** | iOS **14.2–26**, confirmed on **16.1** · Music, Podcasts, YouTube **21.32.4**, YT Music **9.28.4**, Spotify **9.1.62** |
| **Jailbreaks** | Rootless (Dopamine, palera1n) · roothide · rootful (unc0ver, checkra1n) |
| **Sideloading** | Supported via the bundled FLEXing sub-project |

> The tested versions are the newest builds the developer's own phone accepts. They are not
> a ceiling: nothing here is pinned to a version number, every class is looked up at runtime,
> and anything absent is skipped rather than crashed on.

<details>
<summary><b>About that Instagram version</b></summary>

<br/>

Albrhi is tested against **Instagram 410, 439 and 441** — one build serves all three. Three versions
are kept so that differences between them are checked against real apps rather than assumed.

Nothing is tied to a version number. The tweak looks for the parts of Instagram it needs while the
app is running, and anything it cannot find is skipped instead of crashing. Newer versions should
be fine — and if one is not, the **Diagnostics** page shows what the tweak can actually see on your
phone and sends a report in one tap.

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

The result lands in `tweaks/instagram/packages/`. Swap `instagram` for `youtube`, `twitter`,
`tiktok`, `panel`, `nextup` or `watch`, and `rootless` for `roothide`, `rootful` or `sideload`.

**To build what people actually install**, merge the five into the suite:

```bash
tools/make-suite.sh rootless
```

**Run the source checks first, always.** They take a second and catch the mistakes that have
genuinely broken this build before — a five-minute Theos compile is a slow way to find a typo:

```bash
python3 tools/check.py
```

GitHub Actions builds are also configured — see [BUILD.md](BUILD.md) and
[GITHUB_BUILD.md](GITHUB_BUILD.md).

### Layout

```
tweaks/<app>/     a complete tweak: Makefile, control, filter plist, src/
suite/            com.albrhi — the combined package, and the preinst that clears the old ones
shared/           the Theos flags and build modes every tweak shares
tools/            source checks, APT index, depiction, logo, .deb editing
modules/ vendor/  third-party code, shared
extra-debs/       drop a .deb here and the source publishes it
```

Adding a tweak means adding a directory under `tweaks/` — `tools/check.py` finds it and
checks it without being told, `./build.sh <name> rootless` builds it, and `make-suite.sh`
pulls it into `com.albrhi` automatically. Joining the suite is the default and costs
nothing but a version bump in `suite/control`; staying out of it takes a `.no-suite` marker
file, which NextUp and Watch have.

### 🧰 The tools

Everything under `tools/` is meant to be run by hand as well as by CI. None of it needs the
repository's secrets except where noted.

| | |
|---|---|
| **`objc-classes.py`** | Prints a class's real method list, declared property types, superclass and **type encodings**, read straight out of a Mach-O's ObjC metadata. It answers "does *this* class answer *this* selector, and with what signature" — a framework-wide selector dump answers neither, and this project lost three releases to that gap. No `class-dump` needed. |
| **`check.py`** | Nineteen source checks, run before Theos so a typo fails in seconds rather than after a five-minute compile. Every rule comes from a build that actually broke: unbalanced `%hook`/`%end`, a hooked class touching `self` without an `@interface`, a fragile `%orig`, a localization key used but never defined, a `%new` parameter carrying an attribute. Run from the repo root it re-runs itself once per tweak. |
| **`make-suite.sh`** | Merges every tweak without a `.no-suite` marker into `com.albrhi`. Checks the staged tree against the scheme it was asked for and refuses a mismatch — a "roothide" package built from a rootless staging tree installs as rootless, which cost two releases to learn. |
| **`make-repo.sh`** | Builds the APT index from one or more package directories. Guards against two packages sharing name + version + architecture, and labels each rootful/rootless/roothide. Wipes `debs/` and rebuilds it on purpose, so a package removed from the source disappears from Sileo instead of lingering. |
| **`fetch-published-debs.sh`** | Gathers the newest three versions of every package **from the published releases**, which is what lets more than one workflow rebuild one index safely. Holds `WITHHELD_PACKAGES` — the explicit list of what the source will not serve, because building the index from releases means silence removes nothing. |
| **`make-depiction.py`** | Generates the Sileo native depiction and its HTML fallback **from the changelog**, so a depiction cannot go stale relative to what shipped. |
| **`make-logo.py`** | Rasterises the repo icon in pure Python — no image library. Drop in `tools/logo.png` to override it. |
| **`release-notes.py`** | Pulls one version's section out of a `CHANGELOG.md` for the GitHub release body. |
| **`deb-edit.py`** | Edits `.deb` metadata from a terminal. `label` appends `(rootless)`/`(roothide)`/`(rootful)` to the display name, read from the package's own `Architecture`, so several flavours of one tweak are not identically named in Sileo. `normalize` converts an xz control archive to gzip. CI runs both over `extra-debs/` on every push. |
| **`deb-edit.html`** | The same job in a browser, served at `…/deb-edit/`: list and remove packages, edit metadata, publish. Carries a hand-written DEFLATE encoder, because `DecompressionStream` only arrived in iOS 16.4 and every iOS browser is WebKit. |
| **`ipa-inject.html`** | Injects a tweak dylib into a decrypted IPA in the browser, for sideloading without a Mac. |
| **`repo-index.html`** | The source's landing page. Builds its package list from the live index, so it never disagrees with what is being served. |

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
- Saved videos live in their own tab beside *You*, with their own player.
- A save button and the video's end time can be added to YouTube's own player layer, under
  Interface. **Both are off by default**: they act on two classes read from another tweak's
  open source rather than confirmed on this build, so they are asked for rather than
  assumed, and Diagnostics reports which of the two attached.

**On X** — open the panel by **holding two fingers anywhere**, the same gesture and for the
same reason.

- **Hold any photo or video** to save it. One capture point serves the timeline, full
  screen, quoted posts and DMs, because all four build the same media model.
- The Switches page lists the feature flags X asks itself about, recorded from your own use
  — 341 of them on X 12.14 — with seventeen named features on top of them. The
  `app_attest_*` keys are deliberately not offered: those are how X proves to its servers
  that the device is unmodified, and answering them falsely is an account risk, not a
  privacy setting.

**On TikTok** — the download button is in the feed itself, above the profile picture. **Hold two
fingers anywhere** for the settings.

- **Tap the button** to save what you are watching. A photo post asks whether you want the picture
  you are on or all of them, and offers to save one picture as a short video with the post's sound.
- The Status report — Advanced → *Status report* — names every number behind every feature and
  copies the lot in one tap. It is the fastest way to report something that is not working.
- **Ask before liking** and **ask before following** are off until you turn them on, under
  Confirmations.

**Everywhere** — Settings → **Albrhi** is the one page listing every app Albrhi patches,
with a switch each. Turn one off and that tweak stops loading entirely, without uninstalling
anything or losing its settings. Reopen the app for the change to take effect.

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
- [x] **Albrhi for X** — the fourth tweak
- [x] **Albrhi Panel** — one Settings page, a switch per patched app, read across the sandbox
- [x] **`com.albrhi`** — the five in one package, so a new tweak arrives as an update rather than a download
- [x] A save button and an end time on YouTube's own player layer
- [x] **Albrhi for TikTok** — a download button in the feed, photo posts, confirmations, privacy
- [x] Photo posts saved as photos, and one picture saved as a clip with the post's own sound
- [x] **Albrhi NextUp** — a GPLv3 port of NextUp 3, configured from the panel, published on its own
- [ ] **Albrhi CarPlay, rebuilt from scratch in its own repository** — removed from this one
- [ ] Tie a SponsorBlock marker to the video its bar belongs to — today one global serves every bar
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
- **[NextUp 3](https://github.com/Yves000/NextUp3)** by **Yves** (GPLv3) — Albrhi NextUp is a port of it; the design and nearly all of the implementation are his.
- **[LightMessaging](https://github.com/rpetrich/libhooker)** by Ryan Petrich and **[libSandy](https://github.com/opa334/libSandy)** by opa334 — the cross-process messaging and sandbox profile NextUp needs.
- **[FLEXing](https://github.com/SoCuul/FLEXing)** — runtime debugging support.
- **[BHTikTok](https://github.com/BandarHL/BHTikTok)** by BandarHL and the maintained fork by
  [al3raQe](https://github.com/al3raQe/BHTikTok) — read for *where* TikTok is hookable, never for
  code. Two compiled tweaks, NA9 For TikTok and VibeTok, were read the same cautious way and for
  the same one question.
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
