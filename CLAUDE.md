# Albrhi — working context

Read this before touching anything. It is the accumulated reasoning behind the
project: what things are, why they are that way, and which mistakes have already
been made so they are not made again.

Owner: **Ibrahim Ismail AL-Rahn** (`@ibrahim2100`). Arabic is the working language;
code, comments and user-facing strings are English + Arabic.

---

## What this is

Tweaks for jailbroken and sideloaded iOS. **Five of them**, and one package:

| directory | package | what it patches |
|---|---|---|
| `tweaks/instagram` | `com.albrhi.tweak` | Instagram, tested on **410.1.0** |
| `tweaks/youtube` | `com.albrhi.youtube` | YouTube, tested on **21.30.5** |
| `tweaks/twitter` | `com.albrhi.twitter` | X / Twitter, tested on **12.15** |
| `tweaks/locket` | `com.albrhi.locket` | Locket, tested on **2.46.1** |
| `tweaks/panel` | `com.albrhi.panel` | the Settings app — the per-app switches |
| `suite/` | **`com.albrhi`** | all of the above, in one package |

The Instagram tweak is derived from [SCInsta](https://github.com/SoCuul/SCInsta) by
SoCuul under GPLv3. Original authorship is credited in-app, in the README and in the
package metadata — that is a licence obligation, not a courtesy. Never remove it.

**`com.albrhi` is what people install.** The individual packages are still built and
still published, but the suite is the front door: one thing to install, one thing to
update, and a new tweak arrives inside it rather than as a second download. It declares
`Conflicts` and `Replaces` on all ten individual identities (rootless and roothide) —
and that is not enough on its own, see the ground rule below.

The repository doubles as an **APT source**: it builds itself, publishes releases,
and serves a Sileo/Zebra repo from GitHub Pages.

- Repo: `github.com/ibrahim2100/Albrhi-Repo`
- Source: `https://ibrahim2100.github.io/Albrhi-Repo/`
- Control panel: `…/deb-edit/`
- The tested versions above are the newest builds the developer's phone accepts. Not a
  compatibility ceiling; nothing is pinned to a version number.

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

**SABR cannot be turned off from inside the app. This was measured to the end — do not
try again without new evidence.** Every format on YouTube 21.30.5 answers with an empty
`?cpn=` URL, because the client asks a server-side controller for byte ranges instead of
fetching files. The binary carries two gates that look like the answer, and neither is:

- `MLPlayerReloadContext -disableSABR` is **never consulted on a first load**. It belongs
  to the reload path.
- `MLOnesieRequestContext -bypassOnesie` *is* consulted, three to four times per playback.
  Forcing the getter changed nothing. That proved less than it appeared — code reading the
  ivar directly never passes through a getter hook — so the stored value was then written
  through the class's own `-setBypassOnesie:` until the getter answered YES on its own
  account. Twenty-two formats, still no URLs. **And the HLS manifest stopped arriving**,
  which is the one thing the downloader actually uses.

The metadata settles it: `content_length`, `init_range` and `index_range` all arrive
complete and the URL alone is withheld. That is a server-side decision about which clients
get plain files. Download sites get URLs because they ask as a television or an old web
player — clients Google has not migrated — which means impersonating a different client,
signed requests, and the `n`-signature, from inside the official app while signed in to a
real account. The counting hooks stay in `SCIYTSabr.x`; the switch was removed in 1.12.0.

**X's classes are not in X's binary, and a hook table built by scanning it is empty.**
`com.atebits.Tweetie2` is 10,827 classes across 58 Mach-O images: the interface classes
live in `T1Twitter.framework`, and `TFS*`/`TAE*`/`TFN*` in `TwitterSPMMigration` and
`TwitterAppSPMMigration`. Reading only the executable finds none of them and concludes the
build has no switch layer. `NSClassFromString` asks every loaded image, which is why the
Twitter tweak binds that way and not by scanning.

**And X answers its own feature questions in one place.** `-boolForKey:` on
`TFSFeatureSwitches`, `TFSCachingFeatureSwitchProvider` and `TPSTwitterFeatureSwitches`
(`B24@0:8@16` on all three) gates a large share of what the app does — so the tweak hooks
the decision rather than the fifty-one views that read it, which is the same lesson
Instagram's reels button cost twice. `-unsafePeekBoolForKey:` is hooked beside it: it is
the same question asked without the cache, and missing it means one screen obeying an
override while the screen beside it does not.

**What each of those keys *means* is not knowable from the binary.** X carries thousands
of lowercase underscored strings and only some are switches; the intersection with what
BHTwitter and TWIGalaxy carry is 260 strings, most of them OpenSSL symbols and image
names. So 0.1.0 shipped the recorder, not a table — and **the device answered**: 341 keys
over 345,902 questions on X 12.14, which is what 0.2.0's seventeen named features are built
from. Every key in that table was observed being asked; what each one *means* is still read
from its name, and the screen says so rather than implying more certainty than there is.

**`app_attest_*` is not offered, rather than offered with a warning.** Those keys are how X
proves to its servers that the device is unmodified. Switching them off is not a privacy
setting — it is telling the server something it will not believe, on an account that can be
locked for it. Four of them were in the report and none are in the table.

**Named features and hand-set keys are two maps, not one.** The first version merged them,
and turning a feature off then meant removing its keys — but only the ones no other enabled
feature wanted, and only where the user had not since set one by hand. That bookkeeping is
where the bugs live. Features contribute a map recomputed from scratch on every change; the
hand-set map always wins; turning a feature off is a recompute, with nothing to get wrong.

**A jailbreak-detection bypass hides the jailbreak; it never touches payment.** Locket does
not block a jailbroken phone, it *reports* it — to OneSignal, to AppsFlyer, and from its own
Flutter code — where the flag can count against an account. The tweak answers those checks
as an unmodified phone would, and that is all it does. The `Check0verPlus.dylib` the owner
sent alongside the app is a different thing: it fakes RevenueCat entitlements to unlock the
paid "Locket Gold" subscription, which is taking money from the app's developers, not a
device tweak. It was reviewed and deliberately not reproduced. The same line the rest of the
project keeps — credit SCInsta, do not lift code, keep `app_attest_*` out of the X tweak —
puts subscription cracking on the wrong side.

**Hook the primitives a detector calls, not the detector.** Three SDKs check for a jailbreak
in Locket and only one (OneSignal) exposes a single BOOL to override; AppsFlyer and the
Flutter layer read the filesystem directly. So the bypass is Shadow-shaped: `%hookf` on
`stat`/`lstat`/`access`/`fopen`, plus `-[NSFileManager fileExistsAtPath:]`, `-canOpenURL:`
and `getenv`, each asking `SCILKShield` whether the path/scheme/var is a jailbreak probe and
lying **only** then. Everything else passes through — the one rule that keeps a bypass from
becoming a crash, which is why the path list is anchored at the start and never a substring
match on "cydia" that a sandbox file could contain. `open` is left unhooked on purpose: it is
variadic, and a two-arg hook drops the mode on every real `O_CREAT`, so `stat`+`fopen` carry
it. Every hook is grouped and `%init`-ed from the `%ctor` after the panel gate, so "off"
really means no hooks — a top-level ungrouped `%hookf` would install before the gate runs.

**Run scripts before shipping them.** Three CI failures in a row came from shell
one-liners that were never executed once locally. `tools/check.py` and a stubbed
run of `tools/make-repo.sh` cost seconds.

**Never write shell/Python heredocs containing `\n` inside string literals.** This
corrupted source files three separate times — the escape becomes a real newline and
Objective-C has no multi-line strings. Write a script file instead. **It happened a
fourth time in 1.0.4**, in a commit that was fixing something else, by an author who had
read this paragraph. Treat it as a thing to check for after writing a heredoc, not as a
thing to remember while writing one.

**A fifth time, in the commit adding the rule that exists because of a half-applied
script.** A `.replace()` with no `assert` matched nothing, half the change landed, the
script printed its success line anyway, and CI found the unused variable it left behind.
The repair was then written into a heredoc whose `\n` became a real newline and broke
`check.py` itself — and in the same session an `assert` failing partway through a script
left `CLAUDE.md` untouched while the commit went out claiming it had been updated.

Use the editing tools for source. If a script must do it, `assert` every substitution
**and** re-read the file: a script that prints a confirmation it did not earn is the
failure, not the symptom.

**`Conflicts` and `Replaces` are a request to a package manager, not to dpkg.** Sileo and
Zebra honour them when installing from a source. `dpkg -i` on a downloaded file does not:
it is handed one file and told to unpack it, and the old package stays exactly where it
is — so both dylibs end up in `DynamicLibraries` under two package names and both get
injected. `suite/DEBIAN/preinst` removes them itself for that reason. Declaring a
relationship and hoping is not the same as performing it.

**What makes a package roothide is its paths, not its control file.** A rootless `.deb`
carries everything under `var/jb` and a roothide one does not, because roothide's prefix
is decided on the device. Theos settles that when it *stages*, long before any packaging
script runs — so 1.0.2 shipped a "roothide" package built from a rootless staging tree
and it installed as rootless, because that is what it was. `make-suite.sh` now checks the
staged tree against the scheme it was asked for and refuses a mismatch, naming which
`THEOS` it used. Two releases were spent on a control-file theory that was never the bug.

**Keep the fields a tool computed; override only your own.** `make-suite.sh` used to
replace `DEBIAN/control` wholesale and threw away what Theos had written into it. The
merge now wins field by field. The general direction matters more than this instance:
discarding information you did not know you had is the failure mode, and it is silent.

**A sandboxed app asking cfprefsd for another application's domain is answered with
nothing, not with an error.** The panel writes the per-app switch from inside Settings;
Instagram and YouTube read it from inside their own sandboxes and saw an absence — which
this code deliberately reads as "on", so a device that never opened the panel keeps
working. The switch moved and nothing happened. The plist is read directly now, with
CFPreferences tried first because where the sandbox permits it it is cheaper and it sees
a value written but not yet flushed. **The jailbreak prefix comes from `dladdr` on this
code's own address** — the only way to get it right on roothide, where it is a different
random directory on every device.

**A sleep is a guess about how long something takes.** Three releases went into a Pages
deploy that "hung", and each time the fix was to ask the thing itself instead: which mode
Pages is in, whether the build is `built` or `errored`, whether the live URL is serving
the version just built. Every time a sleep was replaced with a question, the answer came
back immediately and was right. See the CI section for what that turned into.

---

## Layout

The repository holds **one tweak per directory under `tweaks/`**. Each is a
complete Theos project — its own `Makefile`, `control`, filter plist and `src/` —
and nothing outside it knows which app it patches. Everything above that level is
shared: the build script, the checks, the APT index, `modules/`, `vendor/`.

```
tweaks/
  instagram/               Albrhi for Instagram — com.albrhi.tweak
    Makefile               its identity: target process, frameworks, dav1d
    Albrhi.plist           injection filter (com.burbn.instagram)
    control                package metadata; Version drives the release
    CHANGELOG.md           release notes and the Sileo depiction come from here
    src/
      Tweak.x              entry point, NSUserDefaults defaults registration
      SCIProject.h         repo owner/name — rename the repo, edit only here
      SCILog.h             SCILogV, gated on the verbose_logging preference
      Utils.m/.h           shared helpers, media URL resolution, colours
      InstagramHeaders.h   every Instagram class the tweak touches
      Localization/        bilingual string tables (AR/EN must stay in parity)
      Settings/
        SCISettingsRegistry  features register their own pages in +load
        Pages/             one file per settings page; delete a file, page is gone
        SCIDiagnosticsViewController   runtime truth + one-tap issue reporting
      Downloader/
        SCIMediaDownloader THE single entry point for every download
        Queue/             background queue, history, Download Center UI
      Features/<Category>/ one file per feature
      Onboarding/          welcome / what's-new screen
  youtube/                 Albrhi for YouTube — com.albrhi.youtube
    src/Features/Download/   the HLS pipeline; Center/ is the library, player and tabs
  twitter/                 Albrhi for X — com.albrhi.twitter
    src/Features/Switches/   the one place X decides what the app may do; the tweak
                             records every question and lets the user answer any of them
    src/Features/Media/      downloads: captured at TFSTwitterMediaInfo, the model every
                             surface builds, so one hook serves timeline, full screen,
                             quoted posts and DMs
    src/Settings/            reached by a two-finger hold on X's own window, not by
                             hooking one of X's screens
  locket/                  Albrhi for Locket — com.albrhi.locket
    src/Features/Bypass/     hides the jailbreak from Locket's three detectors; SCILKShield
                             owns the path/scheme/env list, the .x holds only thin hooks
    src/Features/Media/      saving a moment: captured at NSURLSession because a moment is a
                             Swift struct no ObjC hook can read, filtered to the storage
                             blobs and away from the public asset buckets
    src/Settings/            a two-finger hold shows the moments to save, then how many
                             checks were answered
  panel/                   Albrhi Panel — com.albrhi.panel
                           an Albrhi page in the Settings app, one switch per patched
                           app. It writes; the tweaks read — and how they read it is a
                           ground rule above, not a detail.
suite/
  control                  com.albrhi — the combined package everyone installs
  DEBIAN/preinst           removes the individual packages, because dpkg will not
  CHANGELOG.md             the suite's own notes and depiction
shared/
  tweak.mk                 the Theos flags, modules and build modes every tweak shares
build.sh                   ./build.sh <tweak> <mode> — reads the tweak's own control
build-dev.sh               a local build that skips packaging
tools/                     repo, depiction, logo, deb editing — see below
modules/  vendor/          third-party code, shared across tweaks
extra-debs/                drop third-party .deb files here to publish them
```

### Adding a tweak

Create `tweaks/<name>/` with a `Makefile` (ending in
`include $(ROOT)/shared/tweak.mk`), a `control`, a filter plist named after
`TWEAK_NAME`, and `src/` containing at minimum a `Localization/SCILocalize.m` and
a `SCIVersionString` matching `control`. `tools/check.py` finds it automatically
and checks it like the others; `./build.sh <name> rootless` builds it.

Releasing it means **its own workflow**, modelled on `buildyoutube.yml`: its own
version gate, its own tag namespace (`youtube-v*`, so two tweaks' versions can
never be confused on one releases page), its own assets. Separate workflows rather
than one job per tweak, so a tweak that will not compile can never block another
tweak's release.

**The one thing they cannot help sharing is the APT index, and that was the trap.**
`make-repo.sh` wipes `debs/` and rebuilds it on purpose, so an index built from one
tweak's build output would erase the other tweak from the source. Both workflows
therefore build the index from what is **published** — `tools/fetch-published-debs.sh`
gathers the newest three versions of every package from the releases — and both take
the `albrhi-pages` concurrency group so they never write `gh-pages` at once.

Both also deploy, and this file used to say that made the order they run in irrelevant.
**It does not, and the correction is worth keeping.** That only holds if both gathers see
the same set of releases, and a release published *between* them breaks it: both runs
started at 11:53:02, YouTube published 0.10.1 at 11:54:36, and the run that had already
gathered deployed an index without it — last. Nothing failed. The release was fine, the
packages were fine, and the source served a version older than both.

So the gather **states what the index must contain and checks**: every `tweaks/*/control`
names a package and a version that has to be present. Missing means the listing was read
too early — worth one more look after a pause, then worth failing the run. A red build is
recoverable in a minute; a source quietly a version behind is not noticed until someone
asks why the tweak did not update.

**And an index built from the releases API misses the release the same run just made.**
YouTube 0.5.0 was published at 17:05:28; the run that published it finished at 17:06:41
having built an index that stopped at the previous version. The listing is eventually
consistent and the gather step is inside the "eventually". Each workflow therefore also
copies its own freshly built `.deb` into the gathered set — the same package that was
just uploaded, taken from the machine that built it rather than from a listing that has
not caught up.

**That only holds for what lives on `gh-pages`.** The index does, because both
workflows rebuild it from the published releases. A depiction does not build itself:
it is generated, and the YouTube one was generated only into that workflow's Pages
*artifact*. The Instagram workflow builds its deployment from the **branch**, so it
deployed a site without it — and the page 404'd a minute after publishing, the two
runs being a minute apart. Anything generated must be written to `gh-pages`, not just
handed to the artifact, or the other tweak's next release quietly deletes it.

That change also closed a gap that existed with one tweak: when a build was skipped
because the version was already released, the index depended on a separate download
step succeeding. Now there is a single source of truth for what the source serves.

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
other. `build.sh <tweak> roothide` swaps the fields in `control` and restores them
via a `trap` on exit, including on failure. The new id and name are **derived from
that tweak's own `control`**, not written out in the script: the earlier version
matched literal package ids with `sed`, which would silently do nothing for a
second tweak — and doing nothing there means shipping a roothide build wearing the
rootless identity.

---

## Verification

`python tools/check.py` — runs in CI before Theos, so a typo fails in seconds
rather than after a five-minute compile. Seventeen rules, every one of them derived
from a real build failure:

1. duplicate `@interface` definitions
2. brace balance and `%hook`/`%end` pairing
3. hooked class that touches `self` — a property, a message send, *or* `self` as a
   ternary operand — but is never declared, since Logos leaves it a forward declaration
   and all three need a complete type; `@interface`s are read from sources too, and
   Apple-prefixed classes are skipped. Three builds have gone to this in three different
   shapes, the last being `SCITWMediaSubview(self) ?: self` under `-Werror`
4. fragile `%orig` placement
5. unterminated string literals (comment-aware, so `https://` is not a false hit)
6. localization parity and undefined keys — and a missing table at all
7. version match between `control` and whichever source declares `SCIVersionString`
8. project symbols used without their header, resolved transitively — the class
   half of that table builds itself from every `@interface` in the tweak's own
   headers, matched on a word boundary
9. quoted imports that resolve to nothing, checked against the `-I` flags in the makefiles
10. a header promising a method its `@implementation` never defines
11. a block variable that calls itself — ARC rejects the retain cycle, so it is a
    build failure and not a leak
12. a `%hook` whose class name is never bound anywhere
13. an untyped `NSDictionary`/`NSArray` subscripted for a property — the subscript is
    `id` and will not compile
14. `self.<property>` inside a `%group` whose `%init` names its class at runtime, where
    `self` is `id`
15. a C function in a header imported by `.xm`/`.mm` without `extern "C"`
16. a local assigned and never mentioned again — the build runs with `-Werror`
17. an `SCI…()` call whose name is defined in no header this tweak can reach. Five
    tweaks share a layout, a naming scheme and whole paragraphs of idiom, and they do
    **not** share their helpers: `SCIPrefEnabled(...)` is YouTube's and Locket's, was
    written into the X tweak by muscle memory, and killed a runner after every source
    in that tweak had already compiled. Casts and message sends cannot be mistaken for
    calls, but `@interface SCIFoo ()` can — twenty-four false positives on the first
    run, which is why the rule skips Objective-C directives by name

A check that cries wolf gets ignored. Four of these produced false positives on
first writing and were tightened before landing. If you add a rule, prove it fails
when it should by reintroducing the bug.

**Rule 16 is the clearest instance of both halves of that, and of the oracle worth
reusing.** Its first pattern put a non-greedy `[\w\s*<>,]*?` before the capture, which
ate into the name itself: `NSString *page = …` was reported as `age`, matched nothing
else in the file, and "failed" — 180 findings across four tweaks that all compile clean.
Rewritten to take the last identifier before the `=` rather than guess where the type
ends. **And the other tweaks are the oracle:** they build under `-Werror` today, so any
finding in them is by definition a false positive. That turns "does this rule cry wolf"
from a judgement into something a command answers.

Rule 16 sees only indented locals, and that gap cost the Locket build a run: a file-scope
`static const NSInteger SCILKSectionRecent = 2;` at column 0 went unused when the section
it named was reached as a fall-through, and `-Wunused-const-variable` — a different warning
from the local one — stopped the build. **Rule 16b** covers the column-0 `static const`
case, narrow (only when the name appears nowhere else in its file) and checked the same way
against the oracle. The lesson under the lesson: a rule written for one shape of a mistake
does not cover the others, and `-Werror` has more than one warning that fails a release.

**Rules 8 and 10 exist because one process failure cost two builds in a row, and
then a third edit in the very commit that documented it.** A script with several
`assert`s raises partway through: part of the change is on disk, part is not, and
nothing says so — a half-applied script is indistinguishable from one that worked.
Once the header was written without the implementation; once an `#import` was
dropped; once this paragraph itself failed to land while the commit went out anyway.

Either make the whole change in one edit, or re-read the file afterwards. And when a
script prints nothing where it should have printed a confirmation, that *is* the
failure — do not carry on to the commit.

**The rules are written against one tweak** and use paths relative to it (`src/**`,
`control`). Run from the repository root, `check.py` re-executes itself once per
directory under `tweaks/`, with the working directory moved there. Generalising the
rules in place would have meant rewriting the part of that file most expensive to
get wrong; a ten-line driver leaves every one of them untouched. A failing tweak is named,
and the others still run.

---

## CI, releases and the repo

**Seven workflows, one per thing that ships.**

| workflow | builds | tags |
|---|---|---|
| `buildtweak.yml` | Instagram | `v*` |
| `buildyoutube.yml` | YouTube | `youtube-v*` |
| `buildtwitter.yml` | X | `twitter-v*` |
| `buildlocket.yml` | Locket | `locket-v*` |
| `buildpanel.yml` | the Settings panel | its own namespace |
| `buildsuite.yml` | **`com.albrhi`**, the combined package | `v${SUITE_VERSION}` |
| `build-dav1d.yml` | the AV1 decoder Instagram links | on demand |

Separate rather than one job per tweak, so a tweak that will not compile can never block
another tweak's release. They share the `albrhi-pages` concurrency group so no two write
`gh-pages` at once.

### Publishing Pages: what three releases established

**A repository serves Pages either from a branch or from a workflow artifact, and which
one is a setting no file in the repository can read.** `deploy-pages` only works in the
second; in the first it creates a deployment nothing ever picks up and polls
`deployment_queued` forever. Two releases were spent trying to make it work before the
third removed it — an APT source does not need it, since the `gh-pages` push above it
already holds the finished index and serving that branch has no queue to sit in.

`GITHUB_TOKEN` **may deploy to Pages and may not reconfigure it.** The run still asks the
API to point Pages at `gh-pages` and to build, because both are idempotent and both work
on a repository whose token has the rights — but nothing depends on them, and the failure
message names the one setting a human has to change rather than the symptom.

**What decides success is the live URL.** A step asks it whether the source is serving the
version just built, with `always()`, because the case where that matters most is the one
where the deploy failed. And it polls `/pages/builds/latest` until `built` rather than
sleeping — a build still in progress and a build that will never finish look identical to
a sleep, and 1.0.10 exists because one was reported as the other.

### The per-tweak job

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
- **The last three releases of Albrhi are re-fetched into the index** so a bad build
  can be rolled back from Sileo rather than by hunting for an asset on the releases
  page. They come from the published releases, not from what the previous run left
  behind — keeping the old files in place would preserve deleted extras too, which
  is the exact bug the wipe above exists to prevent. `dpkg-scanpackages -m` already
  indexes several versions of one package; `repo-index.html` shows each package
  once, at its newest, since the landing page is a shop window and not a package
  manager.
- URLs in `control` are rewritten from the repository the build runs in, so renaming
  the repo needs no edit there.
- **dpkg is installed on every run, not only on build runs.** The repo index needs
  `dpkg-deb` and `dpkg-scanpackages` even when the tweak build is skipped; gating
  the whole dependency step behind the build broke exactly that. `ldid` and `make`
  stay gated — only compiling needs them.

### tools/

| file | purpose |
|---|---|
| `check.py` | pre-build source checks (above) |
| `make-repo.sh` | builds the APT index from one or more package directories (space-separated, one per tweak); guards against two packages sharing name+version+architecture, and labels each package rootful/rootless/roothide |
| `make-depiction.py` | Sileo native depiction + HTML fallback, generated from the changelog so it cannot go stale |
| `make-logo.py` | repo icon, rasterised in pure Python; drop `tools/logo.png` in to override |
| `deb-edit.py` | edit .deb metadata from a terminal; interactive when double-clicked on Windows |
| `deb-edit.html` | browser control panel: list/remove packages, edit metadata, publish |
| `repo-index.html` | the source landing page; builds its package list from the live index |

**Packages are published under `package_version_architecture.deb`,** not under the
name of the file that was uploaded. A converted package keeps its original filename,
so two flavours of one tweak collided on the same path and the second replaced the
first without a word. The Debian convention encodes exactly what distinguishes them.

**Added packages are prepared by CI, not by hand.** A workflow step runs over
`extra-debs/` on every main push and commits the result with `[skip ci]`:

- `deb-edit.py label` appends `(rootless)` / `(roothide)` / `(rootful)` to the
  display name, read from the package's own `Architecture`. Several flavours of one
  tweak otherwise appear in Sileo under identical names and the wrong one gets
  installed. Idempotent, and a package already carrying a flavour is left alone.
- `deb-edit.py normalize` converts an xz control archive to gzip.

Converting a rootless package *into* a roothide one was considered and rejected:
metadata and paths can be rewritten mechanically, but whether the binary hardcodes
jailbreak paths cannot be determined from outside, so the result would install
cleanly and then fail on the user's device. Build both flavours from source, or use
the jailbreak's own converter.

**Packages with `control.tar.xz` are normalised to gzip by CI**, not decoded in the
browser. An LZMA decoder is a large amount of exacting code whose failure mode is
silent corruption; converting the container costs nothing and the payload is copied
byte for byte. `tools/deb-edit.py normalize` does the work, and a workflow step runs
it over `extra-debs/` and commits the result with `[skip ci]`.

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
- Bump the version in the tweak's `control` **and** its `SCIVersionString` together, and add a changelog
  entry — the release notes and the Sileo depiction are generated from it.
- **And bump `suite/control` as well, or nothing ships.** `com.albrhi` is what people
  install, `make-suite.sh` rebuilds it from *every* tweak, and its version is its own —
  a tweak going from 0.5.0 to 0.6.0 does not change it. `buildsuite.yml` asks the remote
  whether `v${SUITE_VERSION}` is tagged and, finding it, prints "already released —
  building, not releasing": the work is compiled and thrown away, no release, no update
  offered, and a green run. Four version numbers move together, and the fourth is the
  only one a device ever sees.

---

## Known state

Instagram **4.1.5** · YouTube **1.12.4** · X **0.4.0** · Locket **0.2.0** · Panel **0.6.1** · suite **1.6.0**.

- **Working, Instagram:** inline download button (posts + reels), Download Center queue,
  story seen-receipt control, per-message mark-as-seen in DMs, follow-back badge, feed and
  reels cleanup, confirmations, bilingual UI, diagnostics, auto-release, APT source.
- **Working, YouTube:** downloads with their own Download Centre tab and player, ad
  blocking at three layers, SponsorBlock with per-category switches and progress-bar
  markers, background playback, diagnostics.
- **Working, Panel:** Settings › Albrhi, one switch per patched app. Turning one off
  leaves the package installed and the settings intact. The app must be reopened for a
  change to take effect, and **how the tweak reads that switch is a ground rule above** —
  it was written correctly and read nothing for a release.
- **The reels download button broke in 4.1.0 and shipped broken.** Binding by the exact
  Swift runtime name worked and was replaced with a search over `objc_copyClassList`;
  inside a `%ctor` that search does not find what `objc_getClass` still finds by name. A
  search is a fallback for when the name is unknown, never a replacement for a known one.
- **Reels auto-advance** (`reels_auto_next`) works again, under Reels settings, on
  both 410 and 439 from one build. It was hidden for a long time because it never
  fired: the old hook forced `-autoScrollState` (a 410-only getter, gone in 439) and
  left `-isAutoAdvanceEnabled` — the one gate present on both — untouched. The gates
  differ by version: `-isAutoAdvanceEnabled` and `-autoAdvanceToNextItem` on both,
  `-shouldForceEnableAutoScroll` (the server-flag override) on the Swift
  `IGSundialAutoScroll` engine in 439 only, `-autoScrollState` in 410 only. The hook
  forces every one that exists, on whichever class owns it, each behind a
  `class_getInstanceMethod` guard so a selector a build lacks is skipped rather than
  added as a dead method. Established by counting the Sundial selectors in the real
  410 and 439 binaries, not by guessing — the point of keeping both IPAs around.
- **Removed in 3.1.4:** liquid glass, teen icons, doom-scrolling limits, per-surface
  download toggles, long-press tuning, keep-deleted-messages, quality picker. They
  were broken or made redundant by the inline button. Do not reintroduce without a
  reason.

## When something does not work on device

1. Settings → Diagnostics → read what actually attached
2. Magnifier button scans the live view hierarchy and names the real classes
3. Speech-bubble button files a GitHub issue with the whole report attached

That loop replaced several rounds of guessing. Use it first.
