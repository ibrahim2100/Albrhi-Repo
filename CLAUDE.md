# Albrhi — working context

Read this before touching anything. It is the accumulated reasoning behind the
project: what things are, why they are that way, and which mistakes have already
been made so they are not made again.

Owner: **Ibrahim Ismail AL-Rahn** (`@ibrahim2100`). Arabic is the working language;
code, comments and user-facing strings are English + Arabic.

---

## What this is

An Instagram tweak for jailbroken and sideloaded iOS, derived from
[SCInsta](https://github.com/SoCuul/SCInsta) by SoCuul under GPLv3. Original
authorship is credited in-app, in the README and in the package metadata — that is a
licence obligation, not a courtesy. Never remove it.

The repository doubles as an **APT source**: it builds itself, publishes releases,
and serves a Sileo/Zebra repo from GitHub Pages.

- Repo: `github.com/ibrahim2100/Albrhi-Repo`
- Source: `https://ibrahim2100.github.io/Albrhi-Repo/`
- Control panel: `…/deb-edit/`
- Tested against **Instagram 410.1.0** — the newest build the developer's phone
  accepts. Not a compatibility ceiling; nothing is pinned to a version number.

---

## Ground rules learned the hard way

Every line here comes from something that actually broke.

**Do not guess at Instagram class names.** Reading a class dump tells you what
*exists* in the binary, not what the app *renders*. Two features were "fixed"
repeatedly against classes that were never instantiated. The Diagnostics page
(Settings → Diagnostics) exists precisely for this: it reports what attached at
runtime, and its magnifier button scans the live view hierarchy. Use it before
writing a hook.

**Measure each stage before changing a pipeline.** The quality picker was
"fixed" three times against the wrong stage. The bug only surfaced once the code
reported `raw → parsed → deduped` counts separately.

**A non-nil object is not a working object.** `IGMedia.video` returns a hollow
`IGVideo` for photo posts. Check that a thing can actually do its job, not that it
is non-null — see `hasPlayableVideo:` in `SCIMediaDownloader.m`.

**Run scripts before shipping them.** Three CI failures in a row came from shell
one-liners that were never executed once locally. `tools/check.py` and a stubbed
run of `tools/make-repo.sh` cost seconds.

**Never write shell/Python heredocs containing `\n` inside string literals.** This
corrupted source files three separate times — the escape becomes a real newline and
Objective-C has no multi-line strings. Write a script file instead.

---

## Layout

```
src/
  Tweak.x                  entry point, NSUserDefaults defaults registration
  SCIProject.h             repo owner/name — rename the repo, edit only here
  SCILog.h                 SCILogV, gated on the verbose_logging preference
  Utils.m/.h               shared helpers, media URL resolution, colours
  InstagramHeaders.h       every Instagram class the tweak touches
  Localization/            bilingual string tables (AR/EN must stay in parity)
  Settings/
    SCISettingsRegistry    features register their own pages in +load
    Pages/                 one file per settings page; delete a file, page is gone
    SCIDiagnosticsViewController   runtime truth + one-tap issue reporting
  Downloader/
    SCIMediaDownloader     THE single entry point for every download
    Queue/                 background queue, history, Download Center UI
  Features/<Category>/     one file per feature
  Onboarding/              welcome / what's-new screen
tools/                     repo, depiction, logo, deb editing — see below
extra-debs/                drop third-party .deb files here to publish them
```

### Settings are self-registering

`SCISettingsRegistry` composes the settings tree from pages that register
themselves in `+load`. Adding a feature means adding one file under
`Settings/Pages/` — no shared file to edit, no merge conflicts. A page whose
builder returns an empty array simply does not appear.

### One download path

Every surface — inline button, story button, DM viewer, profile picture — goes
through `SCIMediaDownloader`. Before this existed, each surface built its own
download call and settings applied to only one of them. Do not add a second path.

---

## Toolchain gotchas

**Logos `%orig` is fragile in this version.** It expands with `#line` directives.
It must sit alone on its own line inside a full block. This breaks:

```objc
if (x) { %orig; return; }        // "%end does not make sense inside a block"
```

**A hooked class needs an `@interface` if you touch its properties.** Otherwise
Logos emits only a forward declaration and `self.view` fails to compile.

**`FINALPACKAGE=1` is set in `build.sh`** for all packaging modes. Without it every
published build carried debug symbols and a `-1+debug` version suffix.

**Rootless and roothide packages have separate identities** — `com.albrhi.tweak`
and `com.albrhi.tweak.roothide`, each declaring `Conflicts`/`Replaces` on the
other. `build.sh roothide` swaps the fields in `control` and restores them via a
`trap` on exit, including on failure.

---

## Verification

`python tools/check.py` — runs in CI before Theos, so a typo fails in seconds
rather than after a five-minute compile. Eight rules, every one of them derived
from a real build failure:

1. duplicate `@interface` definitions
2. brace balance and `%hook`/`%end` pairing
3. hooked class used with properties but never declared
4. fragile `%orig` placement
5. unterminated string literals (comment-aware, so `https://` is not a false hit)
6. localization parity and undefined keys
7. version match between `control` and `Tweak.x`
8. project symbols used without their header, resolved transitively

A check that cries wolf gets ignored. Three of these produced false positives on
first writing and were tightened before landing. If you add a rule, prove it fails
when it should by reintroducing the bug.

---

## CI, releases and the repo

`.github/workflows/buildtweak.yml`, one job:

```
checks → version → decide → [build ×2 + dylib] → release → repo index → Pages
                      ↓ already released
                   reuse published assets, skip the build
```

- **Builds only when the version is new.** Reads `Version:` from `control`; if that
  release exists it downloads the published assets instead of recompiling. Manual
  runs accept `force_rebuild`.
- **Releases publish themselves** when the version is new — no tagging by hand.
  Three assets: rootless `.deb`, roothide `.deb`, and a `.dylib` for sideloading.
- **The repo index rebuilds on every main push**, so adding or removing a package in
  `extra-debs/` takes effect without touching Albrhi's version.
- `debs/` on `gh-pages` is **rebuilt from scratch** each run. It used to be copied
  over, which meant deleted packages lingered in Sileo forever.
- URLs in `control` are rewritten from the repository the build runs in, so renaming
  the repo needs no edit there.

### tools/

| file | purpose |
|---|---|
| `check.py` | pre-build source checks (above) |
| `make-repo.sh` | builds the APT index; guards against two packages sharing name+version+architecture, and labels each package rootful/rootless/roothide |
| `make-depiction.py` | Sileo native depiction + HTML fallback, generated from the changelog so it cannot go stale |
| `make-logo.py` | repo icon, rasterised in pure Python; drop `tools/logo.png` in to override |
| `deb-edit.py` | edit .deb metadata from a terminal; interactive when double-clicked on Windows |
| `deb-edit.html` | browser control panel: list/remove packages, edit metadata, publish |
| `repo-index.html` | the source landing page; builds its package list from the live index |

The browser tools carry a **hand-written DEFLATE decoder**. `DecompressionStream`
only arrived in iOS 16.4 and every iOS browser is WebKit, so on the developer's
16.1 phone no browser had it. Writing gzip uses stored blocks — valid DEFLATE, and
far less surface area than a real compressor for a few-kilobyte archive.

---

## Conventions

- Bilingual: never hard-code user-facing text. Add to both tables in
  `SCILocalize.m`; `check.py` enforces parity.
- Logging goes through `SCILogV`, off unless `verbose_logging` is on.
- Comments explain **why**, especially where the code looks odd — most odd-looking
  code here is working around something real and documented above.
- Bump the version in `control` **and** `Tweak.x` together, and add a changelog
  entry — the release notes and the Sileo depiction are generated from it.

---

## Known state

- **Working:** inline download button (posts + reels), Download Center queue, story
  seen-receipt control, per-message mark-as-seen in DMs, follow-back badge, feed and
  reels cleanup, confirmations, bilingual UI, diagnostics, auto-release, APT source.
- **Disabled deliberately:** `reels_auto_next` (auto-advance) is hidden — it never
  worked reliably and shipping a broken toggle is worse than shipping none.
- **Removed in 3.1.4:** liquid glass, teen icons, doom-scrolling limits, per-surface
  download toggles, long-press tuning, keep-deleted-messages, quality picker. They
  were broken or made redundant by the inline button. Do not reintroduce without a
  reason.

## When something does not work on device

1. Settings → Diagnostics → read what actually attached
2. Magnifier button scans the live view hierarchy and names the real classes
3. Speech-bubble button files a GitHub issue with the whole report attached

That loop replaced several rounds of guessing. Use it first.
