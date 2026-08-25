# Albrhi — working context

Read this before touching anything. It is the accumulated reasoning behind the
project: what things are, why they are that way, and which mistakes have already
been made so they are not made again.

Owner: **Ibrahim Ismail AL-Rahn** (`@ibrahim2100`). Arabic is the working language;
code, comments and user-facing strings are English + Arabic.

---

## What this is

Tweaks for jailbroken and sideloaded iOS. **Eight of them**, four in one package and
four standing on their own:

| directory | package | what it patches |
|---|---|---|
| `tweaks/instagram` | `com.albrhi.tweak` | Instagram, tested on **410.1.0** |
| `tweaks/youtube` | `com.albrhi.youtube` | YouTube, tested on **21.30.5** |
| `tweaks/twitter` | `com.albrhi.twitter` | X / Twitter, tested on **12.15** |
| `tweaks/tiktok` | `com.albrhi.tiktok` | TikTok, tested on **46.4.0** |
| `tweaks/spotify` | `com.albrhi.spotify` | Spotify — **Swift and Orion, the only one** |
| `tweaks/ytmusic` | `com.albrhi.ytmusic` | YouTube Music — ads and background playback |
| `tweaks/panel` | `com.albrhi.panel` | the Settings app — the per-app switches |
| `suite/` | **`com.albrhi`** | the four social-app tweaks and the panel, in one package |
| `tweaks/nextup` | `com.albrhi.nextup` | SpringBoard + 5 media apps — what plays next, **a GPLv3 port, released on its own** |
| `tweaks/watch` | `com.albrhi.watch` | SpringBoard — Apple Watch pairing, **an MIT port, released on its own** |

**Albrhi NextUp is a port, and that is the first thing to know about it.** It is
[NextUp 3](https://github.com/Yves000/NextUp3) by Yves, carried over under the GNU GPL
v3 — the same licence this repository ships under, which is precisely what separates it
from the unlicensed TikTok references that may only be read for architecture. Attribution
is a licence obligation here exactly as SCInsta's is for Instagram: it is in `control`,
in the changelog, in the panel page's own footer, and it does not come out. Nearly all of
the implementation is Yves's; what this project changed is the settings pane and the
package identity, and `tweaks/nextup/CHANGELOG.md` lists every change rather than letting
the port read like original work.

**Locket is gone from this repository entirely, and the removal has two halves for a reason
worth keeping.** It was first taken out of the suite on request (its own package, its own
`locket-v*` releases, its own workflow), and then out of the project altogether on the
instruction to isolate it completely: `tweaks/locket/` and `.github/workflows/buildlocket.yml`
are both deleted.

**Deleting a tweak does not stop the source serving it, and that is the trap this file already
warned about from the other side.** `fetch-published-debs.sh` builds the index from what is
*published*, so five `locket-v*` releases would go on being gathered and offered forever, at
0.4.1, from a tweak whose source is no longer in the tree to fix. So `com.albrhi.locket` and
`com.albrhi.locket.roothide` are named in `WITHHELD_PACKAGES` **as well as** the directory being
removed. Both flavours, because they are separate package identities. The releases stay as
history; the source stops mentioning them.

The reasoning Locket contributed to this project is kept where it is referenced below — the
bypass-versus-payment line, the `%ctor` gate for self-contained builds, the `SELFCONTAINED`
makefile lesson — because those were paid for once and apply to whatever comes next. What is
gone is the tweak, not what it taught.

**Albrhi CarPlay was removed from this repository**, to be rebuilt from scratch in one of its
own. It was never in `com.albrhi` — it patched SpringBoard and Camera for a car feature with no
relationship to the social apps — and it was withheld from the source as well, having never been
confirmed on a device. The removal is recorded in full further down; the mechanism half of it is
the same one Locket needed and is the reason `WITHHELD_PACKAGES` exists: **deleting a tweak
removes nothing from a source built out of published releases.** `com.albrhi.carplay` and
`com.albrhi.carplay.roothide` stay named there, both flavours, or the index goes on offering
0.4.1 forever from a tree that no longer holds its source.

`tools/make-suite.sh` skips any `tweaks/*/` directory carrying a `.no-suite` marker file, which is
the only thing that keeps a tweak out of the merge. **NextUp is the one that has it now**; CarPlay
was the first, and its marker left with it.

The Instagram tweak is derived from [SCInsta](https://github.com/SoCuul/SCInsta) by
SoCuul under GPLv3. Original authorship is credited in-app, in the README and in the
package metadata — that is a licence obligation, not a courtesy. Never remove it.

**A seventh tweak, for TikTok — `tweaks/tiktok`, package `com.albrhi.tiktok`, version
0.3.0.** Wired into `suite/control` and `suite/DEBIAN/preinst` the same as Instagram,
YouTube and X, on the owner's own instruction rather than waiting for a device report
the way CarPlay's own withholding did — `com.albrhi` now bundles four social-app
tweaks, `buildsuite.yml`'s own "holds every tweak" assertion checks for
`AlbrhiTT.dylib`/`.plist` alongside the rest, and Albrhi Panel needed no code change at
all for a TikTok row to appear: `SCIPanelScan` already draws every row from whichever
`Albrhi*.plist` filters actually sit beside a dylib on the device, so a row is a
consequence of `AlbrhiTT.plist` shipping, not a fact this panel had to be taught.
Architecture was read from four unlicensed references: BandarHL's original
[BHTikTok](https://github.com/BandarHL/BHTikTok) and al3raQe's maintained fork
([github.com/al3raQe/BHTikTok](https://github.com/al3raQe/BHTikTok)), both by the same
author family the X tweak's own control file already credits; and two compiled ones read
later, **NA9 For TikTok** (a `.deb`) and **VibeTok** (a `.dylib`), both unstripped debug
builds carrying the exact `_ungrouped$Class$selector` Logos symbol this project already
uses to confirm a hook target precisely rather than by string co-occurrence — the same
technique Locket's own bypass review first established. All four are read the same
cautious way every unlicensed reference here is, for where TikTok is hookable, never for
the code.

**Every class this tweak hooks is now confirmed against a real TikTok 46.4.0 IPA, not
carried over from a reference that turned out to target an older build.** The app's real
logic sits in `MusicallyCore.framework` — 810 MB; the main executable itself is a 92 KB
stub — parsed by hand for its own class and selector strings, the same no-`otool` method
this project already uses everywhere else. Two names in BHTikTok's own source,
`AWEPlayVideoPlayerController` and `TIKTOKProfileHeaderView`, do not exist as exact
strings in that binary at all; plausible replacements were found
(`AWEPlayVideoPlayerControllerClass`, a `TTK`-prefixed profile family) but are not yet
confirmed enough to hook. **`AWEAPMManager` was misfiled as an ad-related class on first
reading, going only by its name** — reading BHTikTok's own hook showed it answers a
signing-info question (`+signInfo` → `"AppStore"`), a jailbreak-detection answer, not an
ad control; corrected in the same changelog entry that found it rather than silently.

Shipped in v0.2.0: an ad filter (`AWEAwemeModel`'s own `-isAds` mark, refused at
`-init`/`-initWithDictionary:error:` after `%orig` builds the object, never as a view
hidden afterward) and a jailbreak-detection bypass across six confirmed checks.

**v0.3.0 added download and privacy, and widened both existing features, entirely from
reading NA9's and VibeTok's own confirmed hook tables.** Download resolves
`AWEAwemeModel.videoModel.playAddr.bestURLtoDownload` the moment a kept (non-ad) model
finishes building — `-bestURLtoDownload` is confirmed twice over (a real string in the
binary and NA9's own hooked selector), while `-videoModel`/`-playAddr` sit only in
circumstantial string-table proximity the same way this tweak's own header already
flagged, so `SCITTMedia.m` walks the chain behind `-respondsToSelector:` at each step
and records which one failed rather than assuming it holds. Only the resolved URL is
kept, never the model. Privacy stops three report-to-server calls cross-validated
between both new references: a story's seen mark, a message's read-sync (its sibling
local-only mark is deliberately left alone, the same local/receipt distinction
Instagram's own story-seen feature draws), and a profile view. The ad filter now also
checks `isAd`/`isAdItem`/`isAdsOrPseudoAds` alongside `-isAds`, plus a separate
splash/launch-ad surface. Bypass gained six more confirmed checks.

**Two reference tweaks doing the same job can use entirely different selector names for
it, and reading only one of them is how a feature stays broken for eight releases.**
VibeTok was first read as having no download feature at all — it has a whole
`MSGDownloadSettingsViewController` — and where NA9 sends `-playURL` /
`-bestURLtoDownload` / `-originURL`, VibeTok sends `-h264DownloadURL` / `-playURLList` /
`-urlList` / `-originUrl` (that casing) for the same purpose. `-originURLList` is the
only selector **both** send, which makes it the strongest single candidate in the whole
table. The technique that settles this is the `_objc_msgSend$<selector>` stub symbol:
the compiler emits one only for a selector it actually saw being sent, so its presence
is real evidence where a bare string in `__cstring` is not — and its *absence* is
evidence too, which is how `-playAddr` and `-bitratePlayAddr` were demoted to last
(strings only, never sent) and how `-h264URL`/`-downloadURL` were caught as names this
project had invented. Grep both binaries for the stub before ranking a candidate chain.

**NA9's own download button works because it does not use TikTok's model chain at all,
and that is deliberately not reproduced here.** Its HD path fetches
`https://tikwm.com/video/media/hdplay/<id>.mp4` — a third-party scraper service, keyed
by the video's own ID, found as a literal format string in its binary. That is why its
button has been reliable for years across TikTok updates while this tweak spent eight
releases chasing an internal accessor: there was never an internal accessor in that
path to break. It is not built here for the same reason `app_attest_*` is not offered
in the X tweak and `Check0verPlus` was refused for Locket: it would send what the user
is watching to an unrelated third party, from inside a tweak whose neighbouring feature
exists specifically to stop watch activity being reported to servers. **Worth knowing
rather than rediscovering** — if the owner asks for it knowing the trade, that is their
call, but it does not arrive quietly as "the fix".

**`PIPOStoreKitHelper -isJailBroken`, named by a reference alongside the rest, was found
and deliberately not hooked.** v0.1.0's own reading had already refused
`PIPOIAPStoreManager`/`PIPOStoreKitHelper` as sitting inside the in-app-purchase surface
— the same shape of thing `Check0verPlus.dylib` was for Locket, reviewed and refused
there for taking money from the app's own developers rather than being a device tweak.
One confirmed jailbreak-check method on that specific class was not treated as reason
enough to cross a boundary this project had already drawn on purpose; the same question
is already answered by the six other checks that are hooked.

**v0.4.0 put the download button in the feed itself and rebuilt the settings screen,
both directly requested after v0.3.0 shipped download as a status-screen list only.**
`AWEFeedViewTemplateCell -configWithModel:`/`-configureWithModel:` — two of NA9's own
hooked selectors — are hooked not to place anything but to catch the model a hooked
method's own argument already hands over with no guessing needed, and the resolved URL
is stashed on the cell via an associated object. The button itself lives on
`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView` (both confirmed present
as literal strings in the real 46.4.0 binary; VibeTok independently hooks the first for
an unrelated reason, which counts as a second confirmation), added as an arranged
subview the same way the X tweak's own immersive button avoids fighting `layoutSubviews`
— and it reads its item by walking up from the rail to whichever ancestor cell holds the
association, the same upward-search shape `SCITWFirstSaveableInStatusView` already uses.
The settings screen was replaced with a real grouped `UITableViewController` — status
pills, a Controls section with an icon and an explanation per switch, a Download list,
and a Status section with live per-hook numbers — in the shape the X tweak's own
`SCITWSettings.m` had already settled on. Privacy diagnostics now record into their own
set rather than sharing the bypass tally, and gained two more confirmed
`TTKProfileViewsVisitor` selectors (`-visit:`, `-p_shouldReportHasVeiwedProfileForUser:`)
found in the same pass.

**v0.4.1 answered three reports against v0.4.0 directly: the button still did not
appear, privacy was one switch for three different things, and the settings screen's
own text overlapped.** The overlap was a genuine, device-independent bug — the table
never set `rowHeight = UITableViewAutomaticDimension`, so a wrapped multi-line note
under a switch row was drawn on top of the row below it rather than pushing it down.
Privacy split into three independent preferences (`SCIPrefPrivacyStory`/
`…Messages`/`…Profile`), each its own row in a new Privacy section, rather than one
switch bundling a story-seen mark, a message read receipt and a profile view together.
The button's placement was moved off the rail's own `-layoutSubviews`/`-didMoveToWindow`
— this file's own recycled-cell lesson already says why those cannot be trusted alone
on a *reused* cell — and onto `AWEFeedViewTemplateCell`'s confirmed-every-reuse config
hook instead, which now does a depth-first search of its own subview tree for the rail
immediately after stashing the resolved item. Whether this actually surfaces the button
is still unconfirmed; the Status section's own report was widened from a bare count to
four distinct states so the next report names which one instead of only "no button."

**`com.albrhi` is what people install for the social apps.** The individual packages are
still built and still published, but the suite is the front door for Instagram, YouTube,
X, TikTok and the panel: one thing to install, one thing to update, and a new social-app
tweak arrives inside it rather than as a second download. It declares `Conflicts` and
`Replaces` on all ten of those individual identities (rootless and roothide) — and
that is not enough on its own, see the ground rule below. Neither CarPlay nor Locket is among
them: its identities were taken out of `Conflicts`/`Replaces` when it
left the suite, and its removal from the repository does not put them back — the suite has no
business deleting a package it never carried.

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

**A class dump is of one app version, and an undated dump is a trap.** The follow-badge
crash fix was built from a dump nobody had dated; it turned out to be **439**, while the
device reporting had none of that crash because it runs **410**. Narrowing a lookup to one
accessor confirmed on 439 alone, in a tweak that serves 410, 439 and 441 from one build, is
how a crash fix silently costs a feature on a version it was never tested against. Date the
dump before trusting it — this project's own markers do it in one grep: `-autoScrollState`
is 410-only, `IGSundialAutoScroll` is 439-only.

**Do not guess at Instagram class names.** Reading a class dump tells you what
*exists* in the binary, not what the app *renders*. Two features were "fixed"
repeatedly against classes that were never instantiated. The Diagnostics page
(Settings → Diagnostics) exists precisely for this: it reports what attached at
runtime, and its magnifier button scans the live view hierarchy. Use it before
writing a hook.

**`-valueForKey:` is not a safe probe — it runs the app's code.** It calls the real getter
when one exists and reads the ivar directly when one does not; raising is its last resort,
not its first. The follow-status badge probed twelve guessed keys with it — `user`,
`account`, `dataSource`, `viewModel` and more — on every object up the responder chain, two
deep, from inside `-layoutSubviews`, behind a comment asserting that a missing key "just
throws (caught)". It was executing Instagram's own code dozens of times a second, and
changing a profile picture crashed the app.

**And `@catch` does not make a probe safe.** It catches `NSException`. A Swift getter that
traps, a failed assertion, or a half-initialised object are none of those: they end the
process and no handler ever sees them. A `@try` around a speculative call buys far less
than it looks like it does — it is why that comment was believed for so long.

The replacement asks for **one selector confirmed in a class dump**, guarded by
`-respondsToSelector:`, and steps over anything that does not answer. Same rule as the
class-name one above, applied to accessors: read what exists, do not guess and catch.

**Measure each stage before changing a pipeline.** The quality picker was
"fixed" three times against the wrong stage. The bug only surfaced once the code
reported `raw → parsed → deduped` counts separately.

**A diagnostic that reports the last event instead of a tally is not a diagnostic, and
it will send you fixing what is not broken.** The TikTok tweak's own
`SCITTMedia +lastAttemptState` recorded only the *most recent* resolution attempt — and
resolution runs on every feed model, the overwhelming majority of which are asked a
moment after construction, before their video data is populated. So the status row read
`every chain failed — -video answered nil` for three releases while resolution was
actually **working**: the in-feed button appears only when a URL has genuinely been
resolved, and the same report said it had been placed. Two releases were spent chasing
selector names that were already right, because one overwritten string outvoted a
counter that did not exist yet. The fix is the same shape as the quality picker's above
— count successes and attempts separately, name the chain that won, and show the last
failure's own text only while nothing has ever succeeded. **When a report and an
observable behaviour disagree, suspect the report**; and read every number on a
diagnostic screen for whether it is a tally or a snapshot before believing what it
implies.

**A non-nil object is not a working object.** `IGMedia.video` returns a hollow
`IGVideo` for photo posts. Check that a thing can actually do its job, not that it
is non-null — see `hasPlayableVideo:` in `SCIMediaDownloader.m`.

**And "it cannot do its job" is not "it is the other kind" — the answer to a capability
question must not be spent on an identity question.** `hasPlayableVideo:`, written for
the rule above, is correct and stayed correct; what broke was reading its `NO` as
"therefore a photo" because the photo branch simply came next. Saving a **repost** then
saved its cover image: Instagram models one as `IGRepostModel`, which carries a
`mediaId` string and *no media object*, so the `IGMedia` behind it is built with
`-initWithPk:` and is a stub until fetched — `-needsFetch`, `-needsMediaFetch` and
`-coverPhotoDidPartiallyLoad` are its own declared accessors, and the cover arrives
before the renditions. A real video, no playable rendition yet, a perfectly resolvable
cover photo, and one branch that could not tell "photo" from "video, not loaded". The
kind is asked separately now (`mediaDeclaresVideo:` — duration, DASH manifest, or
`mediaTypeEnum`, any one sufficient, a photo post satisfying none), and the media search
prefers a candidate that can resolve a video over the first one merely carrying a photo.
**Two questions that sound alike: "can I do this now" and "what is this".** Whenever a
capability check gates a fallback, check that the fallback is not silently asserting an
identity the check never established.

**And a capability check must ask the same question the capability answers — a gate
narrower than what it guards refuses work that would have succeeded.** Fixing the above
made the repost report `video — declared but no rendition resolved` with `-needsFetch`
answering **NO**, which ruled out the stub theory and exposed a second, older bug behind
it: `hasPlayableVideo:` decided whether to take the video path by asking
`getVideoUrl:` (`videoVersions`, `sortedVideoURLsBySize`, `allVideoURLs`), while
`downloadVideo:` behind it asks `getBestVideoUrl:`, **which also parses the DASH
manifest**. A video whose only rendition lives in that manifest was refused by a test the
download itself would have passed — and this project had already written the DASH parser,
correctly, for the quality ladder; it was simply never reached from the gate. Nothing was
missing but the question. When a guard and the thing it guards resolve the same resource
by different routes, the guard is wrong by construction, and it fails silently in the
direction of doing less.

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

**The TikTok downloader is built on the wrong architecture, and the reference tweaks say so
plainly once their *hooks* are read instead of their strings.** Five releases went into a
500-line URL resolver that walks candidate accessor chains looking for a link. NA9 does not
resolve anything. Its Logos symbols name exactly what it does:

```
AWEFeedViewTemplateCell$na9AddDownloadButton     the button goes on the FEED CELL
AWEFeedViewTemplateCell$downloadVideo            it calls TikTok's own download
AWEFeedViewTemplateCell$downloadProgress         and hooks the progress/finish callbacks
AWEAwemeACLItem$setWatermarkType                 forcing the watermark off
AWEAwemeModel$canDownload / isPreventDownload    forcing the permission
```

**It asks the app to download its own video.** That is why it gets the right clip at the right
quality without a resolver: TikTok already knows which video is on screen and which URL is the
download copy. Confirmed in 46.4.0: `AWEFeedViewTemplateCell`, `AWEAwemeACLItem`,
`AWEAwemeBaseViewController`, `downloadVideo`, `downloadProgress` and `watermarkType` are all
present; `downloadHDVideo`, `canDownload`, `isPreventDownload` and `AWEFeedViewTemplateNewCell`
are **not** — NA9 was built against an older TikTok, so its list is a map, not a manifest.

**And the button belongs on the cell, not on the interaction rail.** A cell hook fires once per
video, so the button cannot be missing on some of them; its position is a frame this code owns
rather than a slot in a stack whose arranged subviews TikTok rebuilds. Every symptom the rail
placement produced -- appearing on some videos, drifting sideways, needing its size copied from
neighbours -- is a consequence of being a guest in someone else's stack.

**Reading a reference tweak's strings is not reading its technique.** Three releases were spent
comparing selector *names* against ours before anyone dumped its Logos symbols, which took one
command and answered the architecture question outright.

**A correct principle enforced in the wrong place removes working features.** "Saving the wrong
video is worse than saving none" is right about the *save*. Applied to the *button* -- hiding it
whenever the preferred model lookup returned nil -- it shipped a TikTok build with no download
button at all, replacing a button that worked and was merely sometimes wrong about which clip.
Refusing a fallback belongs at the point of the irreversible action, never at the point that
decides whether the user can reach it.

**And a filter loop that only adds from inside itself cannot be asked for "everything".** The
accessor dumper matched names from within its keyword loop, so an empty keyword list meant the
body never ran: asking for an unfiltered dump returned nothing, which reads as "this class has
no accessors" and is the opposite of the truth. Any predicate offered as optional needs the
empty case written deliberately.

**A diagnostic that does not date itself will be read as current, and three releases were
aimed at one that was not.** TikTok's "last save attempt" line carried the identical byte
count and media id across three reports; each was read as fresh proof that the newest download
chain had just saved audio. Nothing had happened at all -- the button was in the wrong place to
be tapped, so no new attempt existed and the old string simply persisted. Any recorded state a
report prints should say when it was recorded, or say plainly that it is from this launch;
otherwise the absence of change is indistinguishable from a change that failed.

**And a constraint built from `bounds` at construction time is built from zero.** The same
button was sized from `reference.bounds` while being created -- before the rail had ever laid
out -- so it came out a square narrower than its neighbours and drifted to one side. Anchor
constraints resolve at layout time and cannot read a size that does not exist yet; a constant
copied out of `bounds` in an initialiser always can.

**A framework-wide selector dump says a name exists; it never says on what class.** This
cost two rounds on TikTok's downloader. `downloadAddr` appears in MusicallyCore's
`__objc_methname` and in NA9's binary, so it was tried first -- twice -- and it is **not on
`AWEVideoModel`**. The class's own accessors, printed from the device in one line, are
`downloadNoWatermarkURL`, `downloadURL`, `h264DownloadURL`, `bitrateModels`,
`audioBitrateModels`, `playURL`, `playLowBitURL`. Reaching for the binary was right; treating
a global name list as class membership was not. When the question is "does *this* class answer
*this* selector", the device answers it and a 785 MB dump does not.

**A framework-wide selector dump says a name exists; only class metadata says who answers
it — and `tools/objc-classes.py` reads that in one command.** This project has now lost three
releases to the same gap: `downloadAddr` (a real name, on no class here), `bestURLtoDownload`
(real in a reference tweak's older build, absent in ours), and — in 0.13.0, after both of those
were already written down — `bitRate`, which is a real name in MusicallyCore belonging to
`TTKECVideoBitModel`, while the feed's own `AWEVideoBSModel` calls it **`bitrate`**. Every
bitrate entry answered `-respondsToSelector:` with NO, scored zero, and the whole HD comparison
fell through silently to the SD chain. In the same release photo posts found nothing because
`AWEAwemeModel` has no `imagePostInfo` in this build (it answers `-images` itself) and
`AWEImageModel` has no `displayImage` (the links sit under `lightURLModel`/`localURLModel`/
`darkURLModel`, each an `AWEURLModel` with `originURLList`).

**And the same tool then found the same mistake one level deeper, twice in two releases.** A
photo post is an `AWEPhotoAlbumModel` under `-photoAlbum` whose list is `photos` — 0.13.1 fixed
the *wrapper* and kept asking it for `images`, so the post still read as empty. Elements are
`AWEPhotoAlbumPhoto` (`originPhotoURL` as posted, `thumbnailPhotoURL` a preview), not
`AWEImageModel`. Reading declared property *types* is what settles a chain rather than a single
hop, which is why the tool prints them: `photoAlbum : @"AWEPhotoAlbumModel"` names the next
class to ask about, and a chain confirmed hop by hop is the only kind that has ever worked here.

**A copyable report and the screen it mirrors are two lists, and a row added to one is
silently absent from the other.** `SCITTStatus` builds its report text in one method and its
table in another. The gear ladder went into the table, the user was asked to send that row, and
the report they sent had never contained it — a whole round trip spent on a row that did not
exist where it was being looked for. Anything added to one belongs in both, and this is the
same shape as the depiction that was written only into a Pages artifact.

**"saved 0 of 1" is a count, not a cause.** Photo saving fails three unrelated ways — the
download, the decode, the library refusing the write — and one number cannot say which, so
nothing could be fixed from it. Counted separately with the first real error kept. The decode
one had a real fix behind it: TikTok serves photos as WebP and HEIC, and bytes `UIImage` will
not decode can still be handed to Photos as the original resource, which also stops the save
re-encoding a file that was already fine.

**A Photos error is not a download error, and 3302 says which.** `PHPhotosErrorDomain 3302`
came back for pictures `UIImage` had already decoded, which rules out the bytes — it is the
library refusing the *format*. Data handed to Photos carries no file name, so it has to guess
the type, and TikTok serves some pictures as WebP. `PHAssetResourceCreationOptions.originalFilename`
is what tells it, and the save now falls back to a JPEG re-encode when the format is still
refused. Two posts behaving differently had nothing to do with where they were found, which is
what the user's own "what is the criterion" was asking — the answer was in the error code.

**Saving the whole post is a decision, and it was being made silently.** A photo post of
sixteen saved all sixteen on one tap. The fix is not a guess about intent: `AWEPhotoAlbumModel`
tracks the swipe in `currentIndex`, so the app already knows which picture is on screen — ask,
and default to that one when there is nowhere to present the question. **And a save with no
indicator is indistinguishable from a button that does nothing**, which is how "it saves
correctly" and "nothing happens" were reported about the same working code.

**A quality number on its own is not a diagnosis.** "It saves 720" has two causes that produce
an identical file — the picker chose wrong, or 720 was the whole ladder — so the Status screen
reports every gear offered with the chosen one marked. Same shape as the `raw → parsed →
deduped` counts the quality picker needed, and as the tally-versus-snapshot rule above.

The tool walks `__objc_classlist` and prints a class's real method list, so it answers class
membership rather than name existence, and it needs no `class-dump`. **Its one non-obvious
mechanic is worth knowing before trusting any similar script: in a modern arm64 image the
quadwords in `__DATA`/`__DATA_CONST` are not pointers** — chained fixups put the target in the
low 36 bits and the fixup's own metadata in the high bits. Unmasked, the class list parses as a
single entry and every lookup reports "not in this binary", which is a confidently *wrong*
answer rather than a visible failure. `otool -s` has a matching trap: it prints little-endian
words, so piping its hex through a naive decoder yields scrambled text that greps as clean
absence.

**TikTok's classes are not in TikTok's binary either, and a competitor's selectors are not
your build's.** `com.zhiliaoapp.musically` 46.4.0 ships a 91 KB executable and puts everything
in `MusicallyCore.framework` — 785 MB, **1,032,816 selectors** in `__objc_methname`. Dumping
that framework with `otool` (which *is* installed, contrary to what this file said for a
while) settled in one pass what three releases of guessing could not: `bestURLtoDownload`,
the first choice of seven candidate chains in the download resolver, **is not in this build at
all** — so those chains had never once run. Nor is `bitratePlayURL`, which had been added an
hour earlier as the HD fix on the strength of appearing in NA9's binary. NA9 was built
against an older TikTok. **Reading a working tweak's selectors tells you what worked for its
author, not what is in front of you** — the same mistake the X tweak's dead immersive class
was, repeated in one day on a different app.

**And "it saves SD" was one word.** `playAddr`/`playURL` is what the app *streams*, served at
a bitrate chosen for smooth playback; `downloadAddr` is what TikTok serves for saving, and
nothing in the tweak had ever asked for it. Confirmed alongside it, for later: `bitrateModels`
(variants with `-bitRate`, `-gearName`, `-qualityType`, each with its own `-playAddr`),
`HDRBitrateModels`, `SDRBitrateModels`, `allowDownloadWithoutWatermark`.

**X's classes are not in X's binary, and a hook table built by scanning it is empty.**
`com.atebits.Tweetie2` is 10,827 classes across 58 Mach-O images: the interface classes
live in `T1Twitter.framework`, and `TFS*`/`TAE*`/`TFN*` in `TwitterSPMMigration` and
`TwitterAppSPMMigration`. Reading only the executable finds none of them and concludes the
build has no switch layer. `NSClassFromString` asks every loaded image, which is why the
Twitter tweak binds that way and not by scanning.

**"A button was added" is not "a button appeared", and a rising add-count with nothing on
screen is the signature of an arranged-subview rebuild.** `ImmersiveActionsStackView` is a
Swift `UIStackView` whose arranged subviews X rebuilds; a button added to it is swept out,
found missing by tag on the next layout pass, and added again — eleven times in one session,
never visible. The counter was read here as success for a whole release. When an add-count
climbs and the screen stays empty, suspect the container is rebuilding its children, not
that placement is nearly working.

**The bar X actually extends is `TTAStatusInlineActionsView`, and it is drawn under a
timeline post *and* over a playing video.** One surface for both, which is what the three
earlier surfaces were each reaching for separately. It is not a stack view — it lays its
buttons out by hand in `-_t1_layoutInlineActionButtons`, so a subview survives; it answers
`-viewModel` directly; `-setViewModel:options:displayType:displayTextOptions:account:` is
its bind point, firing on reuse as well as first use; and X adds its own buttons to it
(`TTAStatusInlineGrokButton`, `…AnalyticsButton`, `…DownvoteButton`), so it takes another by
design. **TWIGalaxy hooks this, not the rail** — its binary names only `ImmersiveCardView`
and the dead `ImmersiveInlinePlaybackButtonsStackView`, plus `TTAStatusInline*Button` and a
selector `eleventhButtonTapped:`. Reading a competitor's binary for *which class* was right;
assuming its immersive references were live was not.

**And that class is gone. `ImmersiveInlinePlaybackButtonsStackView` is not in X 12.15 at
all** — established from a class dump of `com.atebits.Tweetie2`, not guessed: its sibling
`T1TwitterSwift.ImmersiveCardView` *is* in the same dump, so Swift classes are covered and
the absence is real. Five releases of button-placement work could not have worked, because
nothing was there to attach to. X rebuilt the immersive player around plugin views
(`ImmersiveEngagementActionsPluginView`, `ImmersivePlayPauseButtonPluginView`,
`ImmersiveTopRightActionsPluginsView`, ~30 more) and the action rail is now
**`ImmersiveActionsStackView`**, members `ImmersiveActionButton`. Same shape, new name — the
arranged-subview placement below was right and did not change. Both names are hooked now,
since a `%hook` on an absent class never attaches, and the report names *which* rail
attached rather than answering yes or no. **TWIGalaxy's binary still references the old
name, which is the trap**: a working competitor naming a class is not evidence the class is
in *your* build, and the dump is what settles it.

**The in-video save button goes on the immersive player's control stack, not on an inline
media view.** Four X releases put a floating button on `T1InlineMediaView` and it never
appeared inside the video — and reading TWIGalaxy's binary said why: that class is not in it
at all. What a working tweak hooks for an in-video button is one Swift class,
`_TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView` — the row of playback
controls in X's immersive (swipe-up, reels-style) player — and it adds the button there as an
**arranged subview**, so the stack lays it out beside like and share on its own. A floating
button fought `layoutSubviews`; an arranged one in a `UIStackView` is inside the picture by
construction. The media is reached by walking up to `ImmersiveCardView`, whose model knows
what is playing. The two older button surfaces are kept and the diagnostics report names
which of the three attached, so "no button" is never four silent reasons at once.

**A recycled table or collection view cell is never removed from its window, so
`-didMoveToWindow` fires once for its whole life and never again on reuse.** The inline and
status buttons were both triggered from `-didMoveToWindow` alone, and both appeared on the
first screenful of a fresh scroll and nowhere after — every cell recycled after that got a
new post and no signal to add or refresh a button for it. Opening a tweet worked regardless,
because a push builds genuinely new views, which do enter a window for the first time.
`-setViewModel:` is the actual bind point: it fires on first appearance and on every reuse
alike, and it was already being hooked on all four classes to count models for the
diagnostics report — the fix was asking it to trigger placement too, not only count.
`-didMoveToWindow` stays as a fallback for a view windowed before its model is ever set.

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

**The owner's phone is roothide, not rootless, and the local setup needs a second Theos for
it.** The two flavours are not interchangeable — a rootless package carries everything under
`var/jb` and a roothide one does not, because roothide decides its prefix on the device — and
**Theos settles that when it stages, so the flavour is chosen by which Theos builds it**, never
by the control file. The `roothide` package scheme exists only in the roothide fork
(`vendor/mod/roothide`), so stock Theos answers `'roothide' package scheme does not exist`:

```bash
git clone --recursive https://github.com/roothide/theos.git ~/theos-roothide
cp -R ~/theos/sdks/. ~/theos-roothide/sdks/        # same SDK, not fetched twice
```

`tools/build-local.sh` builds roothide by default for that reason, points `THEOS` at the fork
itself, and then **proves the flavour from the staged paths rather than the filename** — 1.0.2
shipped a "roothide" package built from a rootless tree and it installed as rootless, because
that is what it was. It refuses to copy a mismatch out.

**While the source is paused, builds go to `~/Desktop/Albrhi-TikTok` and versions do not move.**
A version number means something was published; nothing is being published during a measurement
loop, and bumping one per attempt turns the changelog into a list of guesses.

**Build locally before pushing — the CI round trip is five minutes and the local one is
under a minute.** This is set up on the owner's Mac and is **per machine**, so a different
computer needs it again:

```bash
brew install ldid make dpkg          # dpkg is for dpkg-deb only; it cannot install here
git clone --recursive https://github.com/theos/theos.git ~/theos
# then the iPhoneOS16.2.sdk from xybp888/iOS-SDKs into ~/theos/sdks/ — the same SDK CI uses
export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"   # GNU make; Apple's fails Theos
```

Both exports belong in `~/.zshrc`, and `build.sh` may need `chmod +x`. Then the cycle is:

```bash
python3 tools/check.py && bash build.sh <tweak> rootless
```

**What it catches and what it does not, measured over one long session.** It caught a
duplicated method, a missing header import, a stale reference to a class not yet written, a
flag used above its own definition, and a hooked class needing a real `@interface` — every
one of which would otherwise have been a five-minute CI failure. It caught **none** of:
`cellClass` set to a string where Preferences wants a Class (crashed Settings), a
constraint built from `bounds` at construction time, a `%new` parameter attribute, or a
`objc_msgSend` cast to the wrong return type (crashed TikTok). Those compile perfectly.
Compilation is the second of three gates; the third is a device, and there is no substitute
for it — which is what the Diagnostics pages are for.

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

**The per-app switch is opt-in now: absence reads as *off*, and that reverses what this
file used to argue.** The old reading — nothing written means on — was right while a package
meant one tweak for one app: somebody who installed it deliberately should not have it
silently disabled. `com.albrhi` ended that. One install carries Instagram, YouTube, X and
TikTok (Locket has since left the suite, but the reasoning does not change with the
count), so reading silence as consent modifies apps the install never asked about.
Nothing is patched until it is asked for, and the panel's footer says so in both languages
rather than leaving a fresh install looking broken.

**One question, three answers, in three processes — and two of them agreeing is not
enough.** `SCIPanelGate` decides whether the dylib acts; `SCIPanelRoot -isOnForSpecifier:`
draws the row in Settings; `SCICPSettingsController -enabledForSpecifier:` draws the same
row on a tweak's own detail page. All three read `app_enabled_<bundleid>` from separate code, and
the first sweep found only the first two. Leaving the third at YES would have drawn
a tweak's switch on while the gate held it off — a screen actively lying, which is worse
than one that merely surprises. Grep `app_enabled_` before changing this default again;
sub-feature keys (a tweak's own sub-options) are a different question and stay defaulted on,
because they sit *inside* a tweak already opted into.

**Persistence needed no code.** The value lives in the panel's plist, which dpkg leaves
alone on upgrade and `suite/DEBIAN/preinst` does not remove — checked, not assumed. On stays
on across updates; a deliberate off stays off just as firmly.

**A sandboxed app asking cfprefsd for another application's domain is answered with
nothing, not with an error.** The panel writes the per-app switch from inside Settings;
Instagram and YouTube read it from inside their own sandboxes and saw an absence — which
this code deliberately reads as "on", so a device that never opened the panel keeps
working. The switch moved and nothing happened. The plist is read directly now, with
CFPreferences tried first because where the sandbox permits it it is cheaper and it sees
a value written but not yet flushed. **The jailbreak prefix comes from `dladdr` on this
code's own address** — the only way to get it right on roothide, where it is a different
random directory on every device.

**The opt-in panel gate is right for `com.albrhi` and wrong for every self-contained
sideload build, and this went unnoticed until Locket's own report said "nothing works,
not even the welcome screen."** `SCIPanelAllowsThisApp()` reading absence as *off* exists
because installing the suite patches four apps at once, and silence should not read as
consent for all of them — but a `SELFCONTAINED` build is one tweak, chosen and installed
deliberately, for one app, quite possibly on a device with no jailbreak on it at all.
Albrhi Panel is itself a jailbreak package (a `PreferenceLoader` bundle, no sideloaded
equivalent exists), so on such a device it can *never* be installed, the switch can never
be turned on, and the opt-in gate refuses forever — every hook in the tweak standing down
on every launch, silently, because the gate sits before all of them in `%ctor`. Fixed once,
in `SCIPanelGate.m` itself rather than per tweak: `SCIPanelAllowsThisApp()` answers `YES`
unconditionally under `#ifdef SCI_SELFCONTAINED`, restoring the older "installed it
deliberately" reading for the one case that is still true of. Every tweak's own `%ctor`
needed no change, because every tweak already asks this one function and nothing else.

**A path derived from where a file *used to* be installed is a guess, and the package
itself is the thing that answers it.** Albrhi NextUp came back "it didn't work at all",
and the cause was readable from this machine with no device and no log: unpack the
published `.deb` and look at the paths. Five of its seven processes are sandboxed apps
that must register a mach service, which needs a libSandy profile applied from `%ctor`;
the profile is found by `dlopen`, and the fallback for a randomised jbroot derived the
root by searching this dylib's own path for `/usr/lib/`, because upstream stages into
`<jbroot>/usr/lib/TweakInject/`. Theos stages *this* package into
`<jbroot>/Library/MobileSubstrate/DynamicLibraries/`. The substring is simply not there,
the fallback returned quietly, every lookup was denied, and the row was dead everywhere.

Two things generalise. **A ported tweak inherits its upstream's assumptions about its own
installed layout, and packaging is exactly what a port changes** — so any path built from
`dladdr` on the tweak's own address is worth re-reading against the staged tree the first
time it is packaged here. And **the same derivation existed twice in that tweak and only
one copy was wrong**: `NULocalization.h` handled both staging shapes, `NUShared.h` handled
one, and the file with the bug carried a comment saying it used the same pattern as the
file without it. A comment claiming two things match is not a check that they do.

**A sleep is a guess about how long something takes.** Three releases went into a Pages
deploy that "hung", and each time the fix was to ask the thing itself instead: which mode
Pages is in, whether the build is `built` or `errored`, whether the live URL is serving
the version just built. Every time a sleep was replaced with a question, the answer came
back immediately and was right. See the CI section for what that turned into.

**Albrhi CarPlay is gone from this repository, and what it learned is kept in one place rather
than in the eight sections it used to occupy.** It patched SpringBoard and Camera to put an
ordinary app on the car display, plus a dashboard wallpaper and a recording-audio fix. **It never
ran on a device**: 0.3.0 and 0.4.0 each looked finished and were not, and 0.4.1's fixes for what a
real iOS 16.1 report found missing were themselves never observed. The owner's decision is to
rebuild it from scratch in a repository of its own — which is the right shape for it, because a
wrong hook there takes the home screen with it and that risk has no business riding along with a
source that updates for a download button.

**What it established, for whoever builds the next one:**

- **The display mechanism is the app patching itself, not SpringBoard reaching into another app.**
  A dylib in the target app rewrites its own incoming CarPlay scene role to the ordinary
  `UIWindowSceneSessionRoleApplication`; UIKit then resolves the app's real Info.plist scene
  configuration. A bug crashes that one app rather than SpringBoard. `carplay-cast`'s
  `SBSceneManagerCoordinator` scene-hosting path is the *old* CarBridge-era mechanism, abandoned
  once CarPlay's UI moved out of SpringBoard.
- **Admission is decided by LaunchServices on iOS 15–17 and by CarKit on 18+**, and one build must
  gate on the version: running the 16/17 LaunchServices hooks on 18 puts SpringBoard into safe
  mode. On 15–17 the answer is the typed entitlement getters plus `-entitlementValuesForKeys:`,
  whose result is a private `LSBundleInfoCachedValues` — **tag that object, never replace it**, and
  the tag set must hold weak references.
- **An app that ships its own CarPlay interface must be left alone.** Rewriting a template scene
  after CarPlay has built one throws inside `+[UIScene _sceneForFBSScene:…]` and kills the app on
  every launch.
- **`carsurf` by pavunato is the current reference and carries a "do not retry" table**, every row
  of which cost a device recovery: no global `LSBundleInfoCachedValues` swizzle, nothing hooked in
  `carkitd`, no fabricated entitlement dictionaries, no forcing `launchUsingTemplateUI = NO` on a
  genuinely native template app — and a visible icon is never proof, a real `UIWindowScene` is. It
  has **no LICENSE file**, so it is read for architecture only, the same line this project keeps
  for the unlicensed TikTok references and the opposite of what GPLv3 allowed for NextUp.
- Two lessons from it are general and stay below in their own sections: **an XML comment cannot
  contain `--`** (check.py rule 18), and **a space-separated `TWEAK_NAME` builds two binaries**
  (`shared/tweak.mk`).


**Albrhi Panel assumed one filter names one app, and CarPlay is the counterexample.**
`SCIPanelScan` turned every `Bundles` entry in a filter plist into its own row, so
CarPlay's two-process filter (SpringBoard, Camera) showed up as two rows reading
"Camera" and "SpringBoard" — as if Albrhi patched Apple's own apps rather than hooking
two processes for one feature. A filter can now declare `SCIPanelGroupIdentifier` /
`SCIPanelGroupName` / `SCIPanelDetailController` to collapse to a single named row that
pushes to a real settings page (`SCICPSettingsController`) instead of showing a plain
switch — the master on/off, the audio-fix toggle and the microphone choice do not fit
one switch cell between them. And that page's own preferences could not have worked
before this: 0.1.0 stored them in `NSUserDefaults standardUserDefaults`, which is local
to whichever of the two processes loaded the dylib and unreachable from Settings either
way. `SCIPanelGate`'s cross-sandbox reader — built and proved for the per-app switch —
was generalized from a bool-only, switch-only helper (`SCIPanelReadBool`/
`SCIPanelReadString`, plus `SCIPanelAllowsApp` for an identity other than the calling
process's own) rather than giving CarPlay a second, unproven cross-sandbox path of its
own. Mic choice is three `PSSwitchCell` rows acting as a radio group, not a
`PSListItemsController` picker — the private list-picker class was never confirmed to
compile against the SDK this repository pins, and this project does not ship a guess
at private API it has not built once.

**An XML comment cannot contain `--`.** `AlbrhiCP.plist` failed to parse — silently, as
far as `check.py` is concerned, since nothing here parses filter plists — because a
comment explaining the grouped-row keys used `--` the way this file's own prose does
everywhere else. `plistlib` catches it; `dpkg-deb` and MobileSubstrate might not agree
on how, which is worse. Worth checking with a real plist parser after editing a `.plist`
comment, the same discipline this project already applies to shell heredocs.

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
  tiktok/                  Albrhi for TikTok — com.albrhi.tiktok, in the suite
    src/TikTokHeaders.h      every class this tweak touches, with which confirmation
                             bar each one meets — a hooked-selector symbol table beats
                             string-table proximity, and the header says which is which
    src/Features/Download/   SCITTCapture hooks AWEVideoModel's own construction, which
                             is the only point a real play URL exists; SCITTMedia
                             resolves and holds only a URL, never the model; SCITTButton
                             puts one button in the centred cell's rail; SCITTDownload
                             saves it and asks AVFoundation what the file actually is
    src/Features/Privacy/    three report-to-server calls withheld, local state untouched
    src/Settings/            a two-finger hold shows switches and what has been captured
  panel/                   Albrhi Panel — com.albrhi.panel
                           an Albrhi page in the Settings app, one switch per patched
                           app. It writes; the tweaks read — and how they read it is a
                           ground rule above, not a detail.
    src/NextUp/              Albrhi NextUp's own settings page, pushed to from the one row
                             the panel collapses its seven-process filter down to — see
                             SCIPanelScan's SCIPanelGroupIdentifier handling
  nextup/                  Albrhi NextUp — com.albrhi.nextup, a GPLv3 port of
                           NextUp 3 by Yves. Kept as a near-verbatim copy on purpose,
                           NU* prefix and all, so it can still be diffed against
                           upstream; the port's own additions live in one file
    src/                     the providers (one per media app, each reading that app's
                             own queue) and the display side, in one binary gated at
                             runtime on host process and iOS major
    src/hooks/               eight display-side files covering iOS 14.2 through 26 —
                             the version spread is why they are split by surface
    src/NUAlbrhi.m           everything this port adds, in one place, so the rest of
                             the tree stays a clean copy
    bundle/                  NUPrefs.bundle: resources only. Upstream's Settings pane
                             is gone (the page lives in the panel now) but the name and
                             path are load-bearing — NULocalization.h compiles them in
                             — and 27 .lproj tables including Arabic ride on it
    layout/                  the libSandy profile that lets a sandboxed app register
                             the mach service the display side looks up
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

Most new tweaks belong inside `com.albrhi`, and need no workflow of their own at all:
`make-suite.sh` picks up any `tweaks/*/control` automatically, so joining the suite is
the default and costs nothing but a version bump in `suite/control`.

A tweak only earns its **own publishing workflow** when it has nothing to do with what
the suite bundles — NextUp is the one that has. `buildnextup.yml` is the shape to copy, and two
more sit in git history: `buildlocket.yml` as of the commit before it was deleted, and
`buildcarplay.yml` as of the same for CarPlay. What that shape is: its own version gate, its own tag namespace
(`carplay-v*`, `locket-v*` — so two packages' versions can never be confused on one releases
page), its own assets including a self-contained sideload dylib, and a `.no-suite` marker file
in the tweak's directory so `make-suite.sh` does not also pull it into the combined package.
Separate workflows rather than one job per tweak, so a tweak that will not compile can
never block another tweak's release.

**The `.no-suite` marker keeps a tweak out of the package; it does not keep
`buildsuite.yml` from running on that tweak's commits, and those are two different
things.** `buildsuite.yml`'s own trigger watched `tweaks/**`, which matches
`tweaks/carplay/**` (and, while it existed, `tweaks/locket/**`) just as much as any bundled
tweak's directory — so a commit touching only a standalone tweak rebuilt Instagram, YouTube, X
and the panel anyway,
every single time, for a package that commit could never change. Reported plainly as
confusion ("ليش بعد كل تحديث يتم اعادة بناء البانل؟"), and it was worth taking at face
value: the workflow really was doing something it had no reason to do. Fixed with `!`
exclusion patterns for both standalone tweaks in the trigger's `paths:` list, kept next
to `make-suite.sh`'s own skip list so the two are checked together. A third standalone
tweak needs a line in both places, not just the marker file.

**The one thing two publishers cannot help sharing is the APT index, and that was the
trap.** `make-repo.sh` wipes `debs/` and rebuilds it on purpose, so an index built from
one tweak's build output would erase the other tweak from the source. Both `buildsuite.yml`
and any second publisher therefore build the index from what is **published** —
`tools/fetch-published-debs.sh` gathers the newest three versions of every package from
the releases — and both take the `albrhi-pages` concurrency group. Two workflows publish
today, genuinely racing for `gh-pages` rather than hypothetically; every word below is
what that costs, and CarPlay will be a third if it is ever un-withheld.

**And a package can be removed from the source by *someone else* releasing, which is the same
failure arriving from the opposite direction.** The gather looked at the newest 40 releases
outright, and the suite publishes constantly — so `locket-v0.4.1`, still Locket's current release
and perfectly healthy, was pushed to position 66 by the suite's own version history and stopped
being gathered. **The source served no Locket at all, and nothing failed**: no red build, no
warning, just a package that quietly stopped being mentioned. One global window means the fastest
publisher starves every slower one, invisibly. The window is per *tag namespace* now (`v*`,
`locket-v*`, and whatever a future tweak adds) — which is exactly the boundary a separate publisher
already has, so it needed no new bookkeeping. Worth checking after adding a third publisher, and
worth remembering as the general shape: **a bounded scan shared between producers is a starvation
bug waiting for one of them to speed up.**

**That same design is why a package is not removed from the source by not releasing it.**
Building the index from the releases means the releases *are* the source: a workflow that
goes quiet keeps being gathered from what it published before, at the last version it
shipped, indefinitely. Withholding is therefore an explicit list —
`WITHHELD_PACKAGES` in `fetch-published-debs.sh` — and never an absence of action.

Two publishers also means the order they run in is not automatically safe.
**This file used to say a shared gather made the order irrelevant, and the correction is
worth keeping.** That only holds if both gathers see the same set of releases, and a
release published *between* them breaks it: both runs started at 11:53:02, YouTube
published 0.10.1 at 11:54:36 back when it still published, and the run that had already
gathered deployed an index without it — last. Nothing failed. The release was fine, the
packages were fine, and the source served a version older than both.

So the gather **states what the index must contain and checks**: `suite/control`, and the
running workflow's own tweak if it has one, each name a package and a version that has to
be present. Missing means the listing was read
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

**A `%new` method's parameter type is pasted into `@encode()`, so an attribute there is a
build failure.** Logos generates the method's Objective-C type encoding from what the
parameter is *written* as, verbatim. `- (void)sciSaveTapped:(__unused UIButton *)sender`
becomes `@encode(__unused UIButton *)`, clang answers `'__unused__' attribute ignored when
parsing type`, and `-Werror` turns that into three fatal errors inside one generated line
that exists in no source file, pointing at a column in the middle of it. The habit that
causes it is a good one everywhere else in this project — `__unused` on a parameter a hook
does not read is correct in `%hook`, and appears throughout. It is only `%new` that
encodes. Every other `%new` here writes a plain typed parameter, which is also the fix:
an unused parameter is not warned about in an Objective-C method the way it is in a C
function, so the attribute buys nothing. Rule 19 catches it now.

**A hooked class needs an `@interface` if you touch its properties.** Otherwise
Logos emits only a forward declaration and `self.view` fails to compile.

**A `PSListController` subclass that overrides `-specifiers` must assign the result
to the `_specifiers` ivar itself, not just return it.** `SCICPSettingsController`
(CarPlay's detail page, pushed from the panel's grouped row) built its row list
correctly and returned it, and the page opened to a black screen with nothing on it
— reported on-device. `PSListController`'s own machinery reads `_specifiers`
directly in places an override's return value never reaches; `SCIPanelRoot.m`'s root
page had always done `_specifiers = specifiers; return _specifiers;` and worked, and
the new page skipped the ivar assignment and did not. Confirmed by matching the
already-working pattern rather than guessing at why a black screen specifically
means this.

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

**A space-separated `TWEAK_NAME` builds two binaries; `$(TWEAK_NAME)_FILES +=` builds
one badly-named variable.** CarPlay is the first tweak here with two dylibs
(`AlbrhiCP AlbrhiCPApp`), and `shared/tweak.mk` had always written
`$(TWEAK_NAME)_FILES += ...` on the assumption of exactly one name — Make does not
split a variable-name substitution on spaces, so that line silently built a single
variable named `AlbrhiCP AlbrhiCPApp_FILES` instead of setting `AlbrhiCP_FILES` and
`AlbrhiCPApp_FILES` separately. Fixed with `$(foreach T,$(TWEAK_NAME),$(eval $(T)_FILES
+= ...))`, which degrades to exactly the old behaviour when a tweak names only one
binary, so every other tweak here is unaffected. **And the fix broke all six tweaks at
once on the first attempt**, for an unrelated reason: `tools/check.py`'s rule 9 finds
include roots by scanning this file's raw text for `-I(\S+)`, and `-I$(ROOT))` with no
separating space reads as one token — the `$(eval ...)`'s own closing paren swallowed
into the path, turning `../..))` into every "shared/src/..." import's include root and
failing every one of them. The fix is a literal trailing space before the paren, now
commented so nobody reads it as stray formatting and removes it.

**A tab in column one of a makefile is never indentation — it is always an attempted
recipe, and a bare `$(eval)`-as-statement line is not a rule.** That same CarPlay commit
indented the `ifdef SIDELOAD` and `ifdef SELFCONTAINED` blocks' own `$(foreach ...)` lines
with a tab, to show they belonged inside their `ifdef` — which reads as correct and is
the opposite of correct. Make decides "is this a recipe" purely from the first character,
before any macro expansion, so a tab there demands a preceding target and finds none:
`shared/tweak.mk:73: *** recipe commences before first target. Stop.` It went unnoticed
for as long as it did because neither `SIDELOAD` nor `SELFCONTAINED` is ever set by an
ordinary build — normal builds skip both blocks entirely, and skipping still requires
Make to scan every line for the matching `endif`, so the broken line was there to trip
over the first time anything actually set either flag. That was Locket's own
sideload-dylib CI step, the first in a long while (maybe ever, since the conversion) to
pass `SELFCONTAINED=1`. The unconditional `$(foreach ...)` above both blocks (for
JGProgressHUD, `SCIPanelGate` and the rest) was never touched by that commit and sits at
column one, which is exactly why it kept working while its neighbours silently did not.

---

## Verification

`python tools/check.py` — runs in CI before Theos, so a typo fails in seconds
rather than after a five-minute compile. Nineteen rules, every one of them derived
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
18. `--` inside a `.plist` XML comment — illegal XML, and this project's own prose
    uses `--` constantly. Nothing else here parses filter plists, so this broke
    `AlbrhiCP.plist` silently three times in one afternoon before earning a rule;
    caught only by running the file through `plistlib` by hand each time until then
19. a `%new` method parameter written with an attribute — `(__unused UIButton *)` and the
    like. Logos pastes the written type into `@encode()`, where an attribute is a
    `-Wignored-attributes` error under `-Werror`, reported against a generated line no
    source file contains. Only the parameter list is examined: `__unused` on a *local*
    inside a `%new` body is fine, and matching the whole method would flag those. Cost a
    full CI run, which is exactly the five minutes this file exists to save

A check that cries wolf gets ignored. Four of these produced false positives on
first writing and were tightened before landing. If you add a rule, prove it fails
when it should by reintroducing the bug.

**Two more were narrowed when Albrhi NextUp arrived, and the shape of both mistakes is
the same: a rule that tested a proxy instead of the condition.** A port of an
outside tweak is the hardest thing this file has ever been run against, because it was
written entirely against code that grew up under it — nineteen findings, every one of
them wrong, on sources that build clean upstream.

- **Rule 1 compared files, when the compiler compares translation units.** Twelve
  duplicate-`@interface` reports for classes declared in two files that never meet:
  `NUMusicProvider.m` imports neither `NUPrivate.h` nor the header that does. It now
  resolves each compiled unit's transitive quoted-import closure and reports only a pair
  that actually lands in one of them — which still catches the Instagram bug it was
  written for, where the redeclaring `.xm` imports the header that also declares it.
- **Rule 13's sibling asked "same name", when the bug was "wrong type".** Seven ordinary
  hand-written getters (`- (UIFont *)font` for a `UIFont *font` property) reported as
  fatal. Its own comment already named the real failure — `- (void)close` could not be
  `close`'s getter *because a getter cannot return void* — so it now fires on a void
  return and leaves a normal custom accessor alone.

Both were fixed in the rule, never in the code being checked, and the six pre-existing
tweaks were re-run as the oracle after each edit. **When a rule fires on imported code
that demonstrably builds, suspect the rule** — and read the provenance comment, which in
both of these already described a narrower condition than the code was testing.

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

**A release that fails while "finalizing" leaves a worse state than one that fails outright,
and this happened during a GitHub outage.** `softprops/action-gh-release` creates the release
as a **draft**, uploads the assets, then publishes it. v1.36.0's upload succeeded and the
publish step 503'd, which left: the tag pushed, both `.deb`s attached, and the release still a
draft. Both halves of this repository's own machinery then work against recovery —
`fetch-published-debs.sh` selects `.draft == false`, so the index cannot see it, and
`buildsuite.yml` finds the tag already on the remote and prints "already released — building,
not releasing", so a re-run never publishes it either. **The fix is to publish the draft by
hand from the Releases page, then re-run so the index gathers it.** Worth guarding one day:
the version gate could ask whether a *draft* of the same tag exists before concluding the
release is done.

**And the `deploy` failures in that same outage were not from these workflows.** `deploy-pages`
was deliberately removed from all of them (see below); the failing job was GitHub's own
auto-generated `pages-build-deployment`, which runs because Pages serves from a branch. Nothing
was lost — the finished index is pushed to `gh-pages` before any of that, which is the whole
reason the arrangement is shaped this way.

**Ten workflows, one per thing that ships.**

| workflow | builds | tags | publishes? |
|---|---|---|---|
| `buildtweak.yml` | Instagram | `v*` | manual build only |
| `buildyoutube.yml` | YouTube | `youtube-v*` | manual build only |
| `buildtwitter.yml` | X | `twitter-v*` | manual build only |
| `buildtiktok.yml` | TikTok | — | manual build only |
| `buildnextup.yml` | `com.albrhi.nextup` | — | manual build only — withheld |
| `buildpanel.yml` | the Settings panel | its own namespace | manual build only |
| `buildsuite.yml` | **`com.albrhi`**, the combined package | `v${SUITE_VERSION}` | yes |
| `build-dav1d.yml` | the AV1 decoder Instagram links | on demand | — |

**One workflow publishes: `buildsuite.yml`.** The four per-tweak workflows for what the suite
bundles (Instagram, X, YouTube's own, and TikTok's) were reduced to — or, for TikTok, started as
— manual, non-publishing builds once the suite became the front door: a tweak that will not
compile can block only its own build, never another tweak's release, but nothing short of the
suite's own run ships anything they carry.

CarPlay is the one exception that still has a publishing workflow at all, and it is withheld
until its app bridging is confirmed on a device — see the top of this file for what that took and
how to undo it. **Locket was the second real publisher and is gone**: removed from the repository
outright, with its package names in `WITHHELD_PACKAGES` so the index stops offering the releases
it already made.

**Keep the `albrhi-pages` concurrency group on every workflow that publishes anyway.** It is the
one thing that stops two runs writing `gh-pages` at once, and the arrangement below — a shared
gather, a stated-and-checked index, a run folding in its own build — exists because two
publishers really did race. Albrhi NextUp made that current again rather than historical: there
are two publishers today.

**And a shared concurrency group cancels a *pending* run, which `cancel-in-progress: false`
does not prevent.** That flag protects a run already executing; a run still queued behind it is
simply dropped when a newer run joins the group, because GitHub keeps only the most recent
pending member. So a commit touching a path both publishers watch — `tools/**` and `shared/**`
are in both trigger lists — starts two runs, and whichever queues *second* cancels the first.
It shows up as `cancelled`, not `failure`, with no error anywhere and no index update, which is
the one outcome this whole section exists to prevent and the easiest to mistake for "it ran".

The practical rule: **when only the second publisher's run matters, push a commit that touches
only that tweak's own directory.** `tweaks/nextup/**` is excluded from `buildsuite.yml`'s
trigger, so a change confined there starts exactly one run and nothing can cancel it. Editing a
shared tool and expecting both publishers to complete in one push is the thing that does not
work — do the shared edit, let the suite take it, then push the tweak-local change separately.

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
| `objc-classes.py` | prints a class's real method list out of a Mach-O binary's ObjC metadata — the answer to "does *this* class answer *this* selector", which a selector dump cannot give |
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

Instagram **4.1.11** · YouTube **1.20.0** · X **0.14.0** · Panel **0.9.22** · Watch **0.5.2** · TikTok **0.19.10** ·
Spotify **0.2.3** · YT Music **0.2.0** ·
NextUp **0.1.5** · suite **1.58.13**. **CarPlay is gone** — removed from this repository, to be
rebuilt from scratch in one of its own.

**This line is read first in every session, so it being out of date costs more than it being
absent.** It said Panel 0.9.1 and suite 1.45.0 while the source served 0.9.2 and 1.46.0, and
called NextUp unproven after it had been confirmed on a device. Move it with the four version
numbers, not after them.

**NextUp is confirmed working on iOS 16.1** — the row draws and the queue is read, on Music,
Podcasts, YouTube, YouTube Music and Spotify. The first "it didn't work" was a jailbreak with
per-app tweak injection and the media apps not enabled in it: the display side was up and no
provider answered, which the log named exactly (`kr=1102`, `BOOTSTRAP_UNKNOWN_SERVICE`, defined
in `vendor/LightMessaging/bootstrap.h`). Worth keeping as the first question for any tweak that
spans a system process and App Store apps.

**Its log is compiled in and switched off** (0.1.4), rather than either always-on or compiled
out: an always-on log writes the titles of what is playing into `/var/mobile/nu/` forever, from
a package whose neighbour in this source exists to stop watching being reported at all — and
compiling it out is what left the first install undiagnosable. `NULogEnabled()` reads a
preference, off by default, in Settings › Albrhi › Albrhi NextUp › Advanced.

### Spotify, and what a Swift/Orion tweak costs

**The ad blocking is carried over from EeveeSpotify under GPLv3** — the same licence this repository
ships under, which is what made carrying code over lawful rather than merely possible, exactly as
with Albrhi NextUp. **Its Premium unlock is deliberately not here**, which is the same line this
project drew at Locket's `Check0verPlus`: a tweak that hands somebody a paid subscription is taking
money from the app's developers, not modifying a device. The owner asked for it three times and the
answer did not change; what did change is that the *reason* is now recorded next to the code.

**Why those files could be taken and the rest could not is a fact, not a judgement.** The ad
blockers never consult the subscription state — measured in the upstream sources before a line was
copied. The files that mention Premium are the subscription path and the ad blockers are not among
them. The same reading settled the audio-quality question for good: `high-bitrate`,
`very-high-bitrate` and `audio-quality` are **account attributes** the server sends, rewritten only
by the Premium spoof. There is no 320 kbps hidden on the device to unlock, which is why "block the
ads" is possible and "raise the quality" is not.

**Three things a Swift/Orion tweak needs that a Logos one does not**, each found by asking the built
artefact rather than trusting the build, and none of which produced a warning:

- **`orion_init()` is not called for you.** Logos writes its own `%ctor`; Theos's Orion generator
  emits `@_cdecl("orion_init")` and nothing invokes it. The first build linked, installed, loaded,
  logged its version, read its switches and installed **zero hooks**. Proved by building it both
  ways: without a constructor the dylib has **no `__init_offsets` section at all**.
- **`-runtime-compatibility-version none`, or it does not link.** Swift emits a force-load reference
  to `swiftCompatibility56` that the pinned iPhoneOS 16.2 SDK does not carry. Ruled out as a crash
  cause later by comparing against upstream's own package: neither build carries those shims.
- **SwiftUI cannot be compiled against that SDK at all.** Its `.swiftinterface` was built by Swift
  5.7.1 and the toolchain here is 6.3.3, which refuses to rebuild the module. Any ported file
  importing SwiftUI is out — for SponsorBlock that is the submit-and-report screens, which
  *contribute* segments rather than skip them.

**Two crashes, and both were the same mistake in different clothes: a hook installed before its
target was confirmed.**

- `AdBlockerGroup().activate()` was copied without the `if NSClassFromString("HUB…") != nil` that
  upstream wraps it in. **Activating an Orion group whose target class is absent does not fail
  politely** — and Logos's own answer to this (a `%hook` on a missing class simply never attaches)
  has no equivalent here, so the caller must check.
- **A missing `-D ROOTHIDE` was choosing a different code path.** The ported ad blocker activates
  one guarded group *per class* under that define, and one group covering all five otherwise. The
  port built for roothide and never defined it, so a roothide device silently took the branch
  written for everything else. **A conditional compiled out is not a conditional you can see**;
  upstream's own makefile is where it was finally read from.

**And the fastest diagnosis in this tweak's history was counting.** Clean share links crashed
Spotify because its three hooks named no group — Orion activates ungrouped hooks at startup, before
any gate is consulted, so they installed themselves whatever Albrhi's master switch said. Eleven of
fourteen hooks named a group; the three that did not were the whole fault. **Count the hooks against
the groups**: a file with hooks and no group runs regardless of what was decided.

**Every ported file is kept diffable against upstream** — one line in one file is the only edit, and
it says so where it is. Upstream's `writeDebugLog` wrote every message to a file forever; it goes to
`NSLog` here for the reason NextUp's log was switched off.

### Apple Watch, where it actually stands

**Confirmed on a device: pairing works, and the update hold is installed on all five of its
selectors** — `-manager:scanRequestDidLocateUpdate:error:` on `COSSoftwareUpdateController`, plus
`-startDownload:`, `-startDownload:passcode:`, `-installUpdate:` and `-installUpdate:passcode:` on
`SUBManager`. Every encoding was read off the device before a hook was written against it.

Getting there cost seven releases, and every one of them was a rule this file already contained,
arriving in a place nobody had checked it against:

**The panel gate refused forever, because the question had no answer.** `SCIPanelAllowsThisApp()`
asks whether `app_enabled_<bundleid>` is set; the panel only ever draws that switch on an *app's*
own row, and this tweak is deliberately collapsed into one grouped row. Nothing installed, the probe
never ran, and the report was empty — indistinguishable from a broken tweak. A tweak's own master
switch is the gate when its shape is not one-tweak-one-app.

**A sandboxed process's preference write is redirected, not refused — and reading it back proves
nothing.** The Watch app wrote its report into the shared domain, read it back, found it, and
announced success while Settings saw nothing: cfprefsd had put it in that app's own container,
where the read-back looked. **A self-verifying write verifies the wrong thing when the failure is
redirection.** The report travels as a file now, in the one direction needing no permission either
side lacks — the sandboxed app writes inside its own container, and SpringBoard, unsandboxed, reads
it and copies it into the shared domain.

**And the same redirection made the master switch read as off.** The report said `master OFF, hold
updates ON`, which is *precisely* the two defaults — the signature of an empty domain, not of a
switch. `SCIPanelGate.m`'s daemon-then-file lookup exists for exactly this and was left out of this
tweak on a comment reasoning that SpringBoard is not sandboxed. True of SpringBoard; this tweak
stopped being only SpringBoard three releases earlier. **A comment that was right when written is
not a check that it is still right.** The file answered from
`…/.jbroot-<random>/var/mobile/Library/Preferences/…`, so the `dladdr`-derived prefix was not
belt-and-braces — the plain `/` candidate never answered at all.

**Refusing an asynchronous call is not withholding its answer.** The first hold swallowed
`-scanForUpdates`. The device's own method list said why that was wrong before it shipped: the page
tracks its wait in `-isExpectingScanResult` and `-hasReceivedValidFirstScanResult`, so a swallowed
scan is a spinner that never stops. The answer is replaced instead — `%orig` with a nil update,
which is the path `-noUpdateFoundOrIsComplete` exists for.

**A gate narrower than what it guards fails silently toward doing less.** The hold demanded
`-scanForUpdates` *and* `-checkForSoftwareUpdate:` and installed neither; the second is not on
`SUBManager` in this build at all. Each selector decides for itself now, in its own `%group` —
which matters beyond tidiness, because **a `%hook` on a method a class does not declare does not
politely do nothing: Logos adds it**, and the tweak would be inventing an API Apple never calls.

**Two ambiguous diagnostics, both fixed by saying which.** `not reached` meant either "the app has
not run this build" or "the tweak is switched off"; `OFF` meant either off or unreadable. The switch
values and the source they were read from travel with the report now, and the settings page states
its own gate above the switches rather than only inside a report somebody must think to copy.

**The hold is finished and confirmed on a device: watchOS 26.6 is refused, 11.x would still be
offered, and the page says Albrhi is the reason.** Five more releases, and the lessons are worth
more than the feature:

**A version filter needs a version, and the device is what named it.** `SUBDescriptor`,
`-humanReadableUpdateName = watchOS 26.6`, `-productVersion = 26.6`, `-productBuildVersion = 23U67`,
`-downloadSize = 1879048192` — read by describing the first descriptor the hook ever saw, behind
`-respondsToSelector:`, taking object accessors and then the `q` scalar once its encoding was known.
The comparison is on the **major** alone; a string compare would put `26.6` before `9.5`. **An
update whose version cannot be read is let through**: a hold that fires when it cannot tell what it
is holding is the coarse behaviour wearing a filter's name.

**Feeding nil into a state machine crashed the app.** `-setUpdate:` and
`-handleManagerState:update:error:` were hooked to pass nil while the state still said an update had
been found. Nil-messaging is safe in Objective-C, **which is exactly what made it look safe** — what
is not safe is the code after the message, told a descriptor exists and reading something out of it.
**Refusing a delivery is not the same as never having had one.** Removed the same day, for the rule
TikTok 0.12.1 already established: a crash is worse than the thing being prevented. What replaced
them refuses `-downloadAndInstall:` and `-install:` — the irreversible action, never the machinery
leading to it.

**A specifier list is edited, never rebuilt or removed from.** `-reloadSpecifiers` asks the
controller to build its rows again and discards the edit in the same breath as making it;
`-removeSpecifier:` changes the list the controller is iterating. `-setProperty:forKey:` plus
`-reloadSpecifier:` is what a device has proven here. Rows are found **by structure** — the ones
after the group whose identifier is `INSTALL_BUTTON_GROUP` — because matching "Download and Install"
is matching a localised string, right in English and wrong everywhere else.

**And the page has two shapes, which four releases of diagnostics never said.** Six rows while it
offers an update; **two rows, and no footer anywhere**, once it settles into "your Apple Watch is up
to date". The notice was being stamped onto rows about to be thrown away. Three timed passes did not
help, because the problem was never timing — `2 row(s), 4 with a footer → 1 stamped — last stop: no
row on this page carries footer text` is what said so, and only because each stage counts itself.
The fix is that `footerText` is a property: a group that had no footer draws one when given it. The
report keeps **both** shapes now, since keeping only the first is how the settled page went four
releases undescribed.

**Two diagnostics lied by omission, and each cost a full round trip.** The report is written from
`%ctor`, so every counter in it was a launch-time counter and nothing that happened while the app was
*used* was ever in it — rewritten after anything worth reporting now, throttled to once every two
seconds. And `master OFF, hold updates ON` was *precisely the two defaults*, the signature of an
empty domain rather than of a switch: the Watch app is sandboxed, cfprefsd answered it with nothing,
and `SCIPanelGate.m`'s daemon-then-file lookup had been left out of this tweak on a comment reasoning
that SpringBoard is not sandboxed. True of SpringBoard; this tweak had stopped being only SpringBoard
three releases earlier.

**The four sync features are not being built, and the reason is not a technical failure.** The
owner's own device settled it: **photo sync and notifications already work automatically** on a
watch this tweak has paired, so the feature had no user left. Recorded rather than deleted, because
"we could not" and "there was nothing to fix" are different conclusions and only one of them is a
reason to try again.

**And the reading that led there cost a safe mode, which is the more important half.** The domain
probe sends messages to private classes **inside SpringBoard**, and one branch trusted
`-copyKeyList` to return an array on the strength of its name while the branch ten lines above it
asked `isKindOfClass:` first. An unrecognised selector there is not a failed diagnostic, it is a
phone that will not boot to a home screen. **A feature that fails takes its feature down; a
diagnostic that fails in SpringBoard takes the device down** — so it is off unless somebody switches
it on, and it does not switch itself back off, because a switch that resets itself is a switch that
lies.

**What was learned about NanoPreferencesSync, for whoever needs it later.** They go through **NanoPreferencesSync** —
`NPSManager` offers `-synchronizeNanoDomain:keys:` and
`-synchronizeUserDefaultsDomain:keys:container:appGroupContainer:cloudEnabled:`; `NPSDomainAccessor`
offers typed getters and setters plus `-copyKeyList` and `-domainSize`; both are confirmed in
SpringBoard, where this tweak already works. Nothing has been written yet, deliberately: a
`-setObject:forKey:` on a domain that syncs to a watch is not a diagnostic, it is a change to a
paired device.

**Sixteen guessed domain names all answered `0 byte(s), no keys` while the accessor reported itself
bound with a real pairing ID** — a uniform zero across unrelated things is a broken measurement, not
an empty world, the same shape as every bitrate entry scoring zero for one wrong selector name. The
real names came from listing the device's own registry:
`/var/mobile/Library/DeviceRegistry/<pairingID>/` holds `NanoPhotos`, `NanoMaps`, `NanoAppRegistry`,
`NanoSystemSettings`, `NanoMail`, `NanoPasses`, `com.apple.carousel`, `com.apple.shortcuts`,
`AppConduit`, `CompanionSync`, `PairedSync` and more — **and none of the sixteen guesses was among
them in that form.** Under it, `NanoPreferencesSync/` holds `NanoDomains` and a `database.db`, so a
synced domain is a row in a database rather than a file named after itself. That is where the next
round of reading starts.

### Apple Watch, and what Legizmo settled

**Legizmo Moonstone 6.3 contains no dylib and no MobileSubstrate filter — it injects into
nothing.** That one fact, read from the package in a minute, ended a plan that had already cost
several releases. The tweak this project was writing hooks `SUBManager` inside the Watch app
(`com.apple.Bridge`) to hold watchOS updates; the developer with a year of watchOS work behind him
does not hook that class, or any class, in any process. `SUBManager`,
`SoftwareUpdateBridge`, `COSSoftwareUpdate*`, `NPSManager`, `NPSDomainAccessor` and
`NRPairingCompatibilityVersionInfo` appear **nowhere** in any of its binaries.

What it is instead: a jailbreak **app** in `/Applications`, a `mobile` **LaunchDaemon**
(`legizmoappd`, started by a `com.apple.nanoregistry.devicedidpair` launch event), and a set of
`.lgzfix` plugin bundles loaded into its **own** app. The app links `NanoRegistry`,
`PBBridgeSupport`, `ProtocolBuffer`, `VisualPairing`, `OnBoardingKit` — the pairing and setup
stack. It does its work by *being a second thing that drives pairing*, not by patching the first.

**`LGZHephaestusScopeIdentifier` is a label, not an injection target, and reading it as one is the
exact mistake this file already records about selector dumps.** Each fix declares a scope —
`com.apple.Bridge`, `com.apple.Music`, `com.apple.Maps`, `com.apple.mobileslideshow`,
`com.apple.AppStore` — which reads like a filter list and is not: with no dylib in the package,
nothing of Legizmo can run in those processes. It names the app the fix is *about*, for its own UI.

**The update mechanism, from `BSUCommander.lgzsvc`:** it links `IDS.framework`, `IDSFoundation`,
`ProtocolBuffer` and `NanoRegistry`, speaks a service named `BSU-IDS`, and carries
`BSUChangeEnrolmentRequest`/`Response`, `BSUEnrolmentStatusResponse`, `assetAudience`,
`assetBrain`, `assetUpdate`, `DeveloperSeed`/`CustomerSeed`/`PublicSeed`. So watchOS updates are
controlled **on the watch**, by changing its asset-audience enrolment, over IDS. Not on the phone,
not in the phone's UI, and not by refusing a method call. Its own strings say as much to the user:
"Once configuration completes, check for updates in the Apple Watch app."

**And the screen the owner saw is Legizmo's own.** "Its name appears and it says unsupported" is
`BSU_CURRENT_SEED_CELL_UNSUPPORTED` on Legizmo's Beta Update Support page, whose footer reads that
the watch "is not currently compatible with this method of beta updates." It is not injected UI in
the Watch app, because there is no injection. A screenshot of a screen is not evidence of where
that screen lives, and the package answers it where the screen cannot.

Read for architecture only, on the owner's instruction: a paid commercial tweak, copied from in no
part. `LegizmoThemis` and `LegizmoThanos` are its licence and DRM components and were deliberately
not examined, the same line this project drew at `Check0verPlus`.

**What it means for this tweak, stated plainly rather than optimistically.** Holding a watchOS
update from inside `com.apple.Bridge` is not disproven — it is simply not what the reference does,
and no device has yet confirmed `SUBManager` is even in that process, because the probe has never
run there. The route with evidence behind it runs through **NanoPreferencesSync**, which is
`NPSManager` (17 methods) and `NPSDomainAccessor` (54) — both confirmed present **in SpringBoard**,
where this tweak already runs and already works. That is the phone's supported way of pushing a
preference domain to the watch, and it needs no IDS, no injection into a system app, and no
component on the watch.

### TikTok, where it actually stands

**0.17.0, confirmed on a device: the button, photo posts and the picture-plus-sound clip all
work.** What that release cost is six lessons, and every one is a shape this file already knew in
another form:

**A position chosen by searching the container is as many positions as the container has shapes.**
The button was inserted "after the last interaction view", with two fallbacks under it — three code
paths — and TikTok's rails genuinely differ per video (a like counter, a live badge, a music disc).
So it landed under the like icon on one video and above the avatar on the next, and the search was
not failing. **Index 0 is the one position that requires nothing to be true about the contents**,
and both fallbacks were deleted rather than kept: a fallback here is a second position, and a
second position was the bug.

**A live index read at construction time is a stale index.** `AWEPhotoAlbumModel.currentIndex` is
not what the swipe updates — the class declares `initialIndex` beside it, which is the shape of a
value set once — and the paging controller is what knows
(`AWEPlayPhotoAlbumViewController -currentIndex`, `Q16@0:8`, via the cell controller's
`activePhotoAlbumController`). The deeper fix was *when*: the item is re-resolved in the tap handler
now, not read from what was stashed when the button was made, which also stops a recycled cell
handing over a video ago's item.

**A format string is a callee with types.** Every clip length read `0 seconds`, because `%.0f` reads
a `double` and `5` written as a literal is an `int`. Nothing warns — a variadic argument has no
declared type to check — and it is the same family as the `objc_msgSend` casts that crashed this app
twice, at a smaller scale.

**A data resource has no type, so Photos infers one from the file name — and the name was a
guess.** It came from the URL's last path component with `.jpg` appended, which announced a WebP as
a JPEG and earned `PHPhotosErrorDomain 3302` for releases. **The first four bytes are a fact**;
naming the file from them is what made photo saving work at all. Alongside it, `+dataWithContentsOfURL:`
was replaced with `NSURLSession` — not for the headers, but because **it cannot report an HTTP
status**, so a 403 page and a photograph were both "some bytes".

**A diagnostic written by every call describes no call.** The photo-chain row was set on every model
the resolver walks — overwhelmingly ordinary videos — so one report read
`AWEAwemeModel → photos ×0 (empty) → 6 link(s)`, three fragments of three different calls. It is
committed only on a successful extraction now. The same release then shipped a second instance of
it: the row said `index unknown via activePhotoAlbumController.currentIndex (Q)` — one sentence
disagreeing with itself — because the index was printed from a static that is reset constantly while
the saved item held the real one. **Print state from the object that kept it, not from the last
thing that touched a global.**

**`%orig` is never captured in a block, and the replacement is a replay.** A confirmation answers
after the hooked method has returned, so the obvious shape is calling `%orig` from the alert handler
— the fragile Logos construct this file warns about. Instead a flag is raised and the same selector
re-sent to the same object; the hook passes it through. Nesting becomes safe by construction, since
an inner call sees the flag. And **a confirmation that cannot be presented lets the action
through** — refusing instead would turn "ask me first" into "liking is broken", the same
right-principle-wrong-place mistake as hiding the download button when a lookup failed.

**And two rules about screens, both learned by shipping the opposite.** A settings screen with
fourteen diagnostic rows among six switches is two screens interleaved, not one long screen — the
diagnostics now sit one row away under Advanced. And a system `UIAlertController` over TikTok's feed
reads as an error from the app: the tweak's own sheet (`SCITTSheet`, a view in the key window, so no
presentation state can conflict) is what makes a question look deliberate.

**Working, and confirmed on a device:** the ad filter, the three privacy switches, the
jailbreak bypass, and the in-feed download button — which appears on every video, sits above
the profile picture, and saves the clip actually being watched, as a real video file.

Getting there took twelve releases and the errors are worth more than the result:

- **The button belongs on `AWEFeedViewTemplateCell`, not on the interaction rails.**
  `TTKFeedInteractionStackView` and `TTKFeedRightInteractionStackView` are stack views whose
  arranged subviews TikTok rebuilds; a guest is swept out. Both rail hooks remain but stand
  down whenever a cell button exists, and the report counts the two separately.
- **The cell is a container, and the model belongs to the controller it hosts.**
  `AWEFeedCellViewController.model`, reached through the cell's `-viewController`. The cell
  has no aweme accessor of its own — which is why two releases of trying more names on it
  found nothing, and why NA9 hooks `AWEAwemeBaseViewController` while putting its button on
  the cell. Those are two halves of one design and I read them apart for four releases.
- **The link comes from `AWEVideoModel.downloadNoWatermarkURL.originURLList`.** Confirmed
  from the class's own accessor list printed by the device, after `downloadAddr` was guessed
  at twice — from NA9's binary and from a framework-wide selector dump — and is on no class
  here at all.

**Quality: settled in 0.13.0, and the fix is the two measurements this file had already
written down rather than a new idea.** `bitrateModels` is a *list of alternatives* and the
right one is chosen by comparing them — every other resolver here walks a path and takes what
it finds, which is why "it saves SD" survived every chain reporting success. 0.12.0 tried and
crashed the app; 0.13.0 does it with both of that release's mistakes answered:

1. **`-bitRate`'s type is read from the runtime, never assumed.**
   `property_getAttributes(class_getProperty(cls, "bitRate"))` gives the real encoding and the
   value is read through a matching cast — `q`/`l`, `i`/`s`, `Q`/`L`/`I`, `d`, `f`, `@`. An
   encoding not in that list scores **zero** rather than being guessed at, so an unreadable
   variant loses a comparison instead of crashing a process. A framework dump gives names, not
   signatures; the runtime gives signatures.
2. **The ladder is only read for a settled model, and that is a second entry point, not a
   flag.** `+captureModel:` is called from the aweme model's own `-init` hooks, where `-video`
   is half-built — the exact object 0.12.0 walked. `+captureSettledModel:` is called only by
   the feed cell's button, holding `AWEFeedCellViewController.model`: an object the app has
   finished with and is showing on screen. "Is this safe to walk" is a fact about the *caller*,
   so it is expressed as which function the caller may call. A parameter would let a future
   caller answer it wrongly, and that is precisely the mistake being guarded against.

Failure at any step falls through to the ordinary chains, which already produce a working file.

**Photo posts were never downloadable at all, and nothing said so.** A photo post has no
`-video`, so every chain reported failure and the button had nothing to offer — indistinguishable
from a broken resolver, and read as one for a while. Images come from `imagePostInfo` →
`images`/`imageList` → `displayImage` → `originURLList`/`urlList`, saved one at a time with the
result reported as "saved N of M": a post of twelve where two fail is not a failed download, and
a single yes/no would have called it one.

**The seek bar needed no drawing.** TikTok already has `AWEFeedPlayerBottomProgressBar` and
merely hides it outside a drag, so the feature is refusing the hide — `-setHidden:` answered
`NO`, `-setAlpha:` refusing zero. Nothing positioned, nothing added to a view hierarchy, so none
of this file's placement lessons apply. Worth noticing before building a bar: the app often
already has the view and is only choosing not to show it.

**The quality ladder is not stable between videos, and that killed the "prefer the ladder"
design.** One report showed five gears topping out at 720; the next showed a single
`comet_lowest_540_1`. TikTok populates only the gears it is streaming, so preferring the ladder
takes the worse file precisely when the app has not fetched the better one — and preferring
`downloadNoWatermarkURL` instead is the same mistake pointing the other way. **No name is
reliable, so 0.14.0 stopped comparing names and started comparing bytes**: every link is
collected and `HEAD`-ed, and the largest wins. Every earlier quality attempt here argued about
which accessor was better; `Content-Length` ends the argument, and a link that refuses `HEAD`
scores zero and sinks rather than being dropped, because a server that refuses `HEAD` still
serves `GET`.

**Both reference tweaks fetch HD from `tikwm.com`, and reading their binaries settled that it
is not one author's shortcut.** `https://tikwm.com/video/media/hdplay/%@.mp4` is a literal
string in NA9 *and* in VibeTok, and NA9 carries the non-HD `…/play/%@.mp4` beside it — so the
reliability people attribute to those buttons is the external service, not a better internal
chain. Recorded so the question is not reopened as if an undiscovered accessor exists.

**What the same read confirmed about our own chains, which is the more useful half.** VibeTok
sends exactly `photoAlbum` → `photos` → `originPhotoURL` → `originURLList`, and NA9 sends both
that and the `imagePostInfo`/`images`/`displayImage` family — which is what this tweak settled
on in 0.13.2 after two wrong releases. Both also *ask* which picture (`na9ShowPhotoDownloadSheet:`),
which 0.14.0 arrived at independently. And NA9's `downloadMusic:` shows the `.mp3` is a
deliberate separate feature there, not the accident it was here.

**A counter that does not count the path that runs reports working code as broken.** The
watermark hook incremented only at the setter, which this build never calls; the getter — the
one doing the work — answered silently, so the screen read `0 cleared` for two releases. Third
instance of this family here, after the last-event snapshot and the mislabelled parallel array:
**before believing a zero, check that the counter sits on the path that executes.**

**`__playBSModel` is not the player's ladder either — it is one gear at the same low bitrate.**
0.16.0 tried to reach the high-bitrate models without a hook by reading `__playBSModel`,
`__playBSModelV2`, `awe_playBSModel` and `ttk_playBSModel` off the video model. The device
answered `×1` for each, at `331,128` — the same number `bitrateModels` already carried, so every
one deduplicated back into the existing ladder. **The four-times-larger list is not on the object
this tweak holds at all**, which closes that line of attack rather than suggesting a fifth
accessor to try. The only place it has ever been observed is the argument of the player's own
selection method.

**`%hook` on a method the class does not declare, fired at a rate nobody measured, crashes it
too.** The universal button surface hooked `-viewDidLayoutSubviews` on
`AWEAwemeBaseViewController` — whose own method list is `loadView`, `setModel:`, `viewDidLoad`
and nothing else — and did a full quality-ladder walk inside it, on the main thread, on every
layout pass while scrolling. **Two unchecked assumptions, one crash**: that the method was there,
and that running it was cheap. `-setModel:` is declared on the class, fires once per video, and
is the bind point anyway.

The general rule now has two halves: before hooking, ask what the class *actually declares*
(`tools/objc-classes.py`) **and how often the method runs**. Frequency is part of a hook's cost
and has never been checked here until it cost something.

**A `%hook` with a guessed method signature crashes the process, and it is the same mistake as
a guessed cast.** 0.15.1's probe declared `willSelectBitrateFromModels:duration:trategyType:
autoBitrateModel:` as `(double)`, `(NSInteger)`, returning `id`, none of it read from the
runtime — arguments then arrive in the wrong registers and of the wrong widths, and TikTok died
repeatedly. **This project had already written down the identical lesson for `-bitRate`'s cast
in 0.12.0**, and it was repeated in the one file whose whole purpose was to stop guessing.

**The real encoding, once the device was asked:
`v48@0:8@16d24^q32@40`** — returning `void`, and `trategyType` is **`^q`, a pointer to a long
long**, an out-parameter. 0.15.1 declared `id` and `NSInteger`: a wrong return type, and a value
written where a pointer belongs, which writes through whatever integer happened to be in that
register. That is not a subtle mismatch, and one runtime query would have shown it.

Before hooking a method whose signature is not documented: `method_getTypeEncoding` on the real
method, compare it against what is about to be declared, and stand down on any mismatch —
`class_getInstanceMethod` returning non-NULL proves the selector exists and says nothing about
its types. And note what made this expensive rather than merely wrong: the probe was shipped to
a device before its own preconditions were checked, so **the cost of a bad measurement is paid by
the person running it.**

**Correction: `bitrateModels` is not a reduced *copy* — it is the same list read at a different
*time*, and the numbers arrive later.** The paragraph below was written from one report where the
two lists were printed side by side, and it was stated as structure. A later report on the same
build disproved it: `bitrateModels` came back reading `adapt_lower_720_1 @ 1,448,977` — the
million-scale figure, from `bitrateModels` itself, with no probe involved. So the ladder is
populated progressively, and a read that happens before the app has fetched the real gears sees
placeholder numbers. **"Two different lists" and "one list, read too early" produce identical
evidence in a single snapshot**, which is the tally-versus-snapshot trap again, one level up: a
claim about structure needs the same value observed twice at different moments before it is a
structure at all.

What follows is kept because the *comparison* was real and worth recording, with that correction
standing in front of it:

**`bitrateModels` looked like a reduced copy of the playback ladder — same gear names, a quarter
of the bitrate — and that single fact seemed to explain every quality complaint in this tweak's
history.** The
0.15.1 probe printed both lists on one screen: `adapt_lower_720_1` reads **373,349** through
`bitrateModels` and **1,512,265** in what TikTok hands its own picker; `adapt_540_1`, 308,455
against 1,015,884. So "it saves 720 and it looks worse than the app" was true in both halves at
once — the right gear, a quarter of the data. The player's models live on `__playBSModel` and
siblings on the *same* video model, which is why 0.16.0 reads them from that object rather than
from the probe's arguments: no cross-video risk.

**And the probe disproved the theory it was built to test, which is the point of a probe.** Not
one of the player's gears carries a `selectedAudio`, so audio is muxed there too and simply
follows the bitrate. The paragraph below was the standing hypothesis and is kept as a record of
what the structure *permits* rather than what this build *does* — a distinction worth keeping,
since the class declarations really do describe two streams:

**The download takes a muxed streaming copy; the app plays video and audio as two streams, and
that is why the saved audio sounds worse.** `AWEVideoBSModel` — the gear entry — declares
`selectedAudio : AWEAudioBSModel`, whose `audioMeta` carries its own `bitrate`, `codecType`,
`quality` and `urlMap`. So a gear *points at* an audio track rather than containing one, and
`playAddr` is a prepared fallback whose audio is whatever was baked in. The arithmetic agrees: a
top gear of ~550 kbps is the total for both tracks.

**And every gear ever seen here is named `lower` or `lowest`** — never `normal_720`, never
`adapt_higher_` — across every device report, while `AWEVideoModel` declares
`_HDRBitrateFilterGears` and `bitrateFilterList` and `AWEVideoPlayBitrateControler` has
`willSelectBitrateFromModels:duration:trategyType:autoBitrateModel:`. Either that is the whole
ladder or `bitrateModels` is a filtered subset and the player is handed more. **0.15.1 answers
that by probing the player's own picker instead of inferring**, which is the discipline this file
demands and which the previous two releases skipped.

**Confirmed on a device: the tweak now saves 1080 at 60 fps — the quality this whole line of
work was about.** It comes from the external switch, which means it comes with the privacy cost
stated on its own row; **internal-only downloads remain 720 at 30 fps**, because that is what
TikTok streams to the app and no accessor here was ever hiding anything better. Both halves
matter when describing this feature: the quality is real, and so is where it comes from.

**Corrected twice, and the second correction reverses the first: the external service returns
the *original upload*, and on some videos that is dramatically better.** A later device report
took tikwm's file at **13.9 MB against `bitrateModels`' 4.5**, and the saved clip came out at
**60 fps while every gear in TikTok's own ladder reported 30**. So TikTok streams a re-encoded
30 fps copy and the service hands back what the creator uploaded — which explains the size, the
frame rate, and NA9's "1080 60fps" in one stroke.

**The paragraph below is still true of the video it was measured on, and that is exactly the
problem with it.** One sample where `hd_size` matched our bytes became "the external route adds
nothing", stated as a general fact. That is the same error as calling `bitrateModels` a reduced
copy from one snapshot — **twice in one session, generalising a behaviour from n=1**. Keep both
findings side by side: sometimes identical, sometimes three times the file and double the frame
rate, and nothing observed so far says which video will be which.

**On one video the tikwm "HD" file was byte for byte the file this tweak already downloads, and
that was measured, not argued.** Querying the service for a video taken from a real device report:
`wm_size` 8,399,664 (the watermarked copy the ranking already refuses), `size` 4,567,673, and
`hd_size` **3,786,622** — precisely the 3,786,622 bytes the tweak had saved through
`bitrateModels`. **So "NA9 gets 1080 60fps" is not a better pipeline; when the ladder tops out at
720 that is the upload's ceiling and no service invents pixels.** The switch stays because it was
asked for and other videos may differ, but it is not the answer to quality and must not be
described as one.

**And `…/video/media/hdplay/<id>.mp4` is not an endpoint** — it answers 400 for an id the service
has not been asked about. It is an API: one JSON request names the links and the shortcut works
only afterwards. NA9 parses JSON for exactly this call, which its binary showed plainly and which
was read here as decoration for two releases. **A reference's request shape is part of its
technique, not incidental.**

**A `User-Agent` was the wrong diagnosis, and testing it took one command.** The theory was that
`tikwm.com` only answers browsers; a direct `curl` with and without a browser `User-Agent`
returned 400 both times. Sending a real `User-Agent` is kept (it costs nothing and is correct on
its own terms) but it fixed nothing, and **the fix was to test the hypothesis from this machine
before shipping a release built on it** — the same discipline this file already demands of
shell scripts.

**A switch the user turned on is a decision, not an input to a ranking.** The external HD link
was competing on measured size and losing to internal links; it now takes precedence when it
answers, and keeps its ordinary rank when it does not, so an unavailable service costs nothing.

**"Unmeasurable" is not "worst", and treating it as worst disabled a feature the user had
switched on.** `tikwm.com` refuses `HEAD`, so the external HD link scored zero and sank below
every internal one — the switch was on and changed nothing. A one-byte range request is a plain
`GET` and any server that serves the file answers it, with the total in `Content-Range`. **Ask
the same question a second way before concluding the answer is no.**

**A parallel array must be walked in lockstep, never re-found by value.** The origins list was
indexed with `-indexOfObject:` while the links list had the external address inserted at the
front, so every label named the *previous* link's accessor — a report that stayed entirely
plausible while being wrong throughout. Worse than no labels, and the same shape as the tally
that reported the last event.

**A fallback that is only reachable when the primary succeeds is not a fallback.** Photo saving
re-encoded to JPEG when Photos refused the format — but the re-encode needed `UIImage` to have
decoded the bytes, and the case it existed for is exactly when `UIImage` returns nil. `ImageIO`
decodes what `UIImage` declines. Check what a fallback *depends on*, not just when it fires.

**A bigger file is a worse file when the codec differs, and this is the third time size answered
the wrong question.** `h264DownloadURL` was demoted on a guess from its name, then promoted to
test that guess — the honest experiment — and the device answered plainly: it won at 7.2 MB
against 5.3 and 2.9, saved 7,561,985 bytes, and the owner reported the picture as *worse than
before*. `AWEVideoBSModel` declares `codec` and `isBytevc1`, so TikTok's modern stream is HEVC and
`h264DownloadURL` is the compatibility re-encode; H.264 needs far more bits for the same picture,
so a larger H.264 file and a smaller HEVC one are not comparable quantities at all.

First audio, then the watermark, now the codec: **bytes compare two encodings of the same thing,
and never say which thing or which encoder.** The demotion is back, under a name that says what
it means (`SCITTOriginIsDemoted`) and with both reasons written down — one guessed and confirmed,
one guessed, tested, and found true for a completely different reason than the one assumed.

**And the same mistake was made a fourth time, in photos, by the hand that wrote this
paragraph.** TikTok photo variants were sorted by measured bytes and the largest downloaded —
which is `userWatermarkedPhotoURL`, at the identical 1170×2080, because a watermarked copy is the
same picture re-encoded with something painted on it. The measurement was right and the outcome
was worse. **Kind decides first; bytes settle ties inside a kind** — clean variants ordered by size
among themselves, watermarked ones among themselves, and the clean list walked first whatever the
sizes say. Reading a rule is not the same as applying it in a new place.

**A measurement can only rank what it can see, and "which copy is watermarked" is not in the
response.** Ranking candidates by size took `downloadURL` — TikTok's *watermarked* save copy,
and reliably the largest file — so every download came out stamped. No amount of measuring fixes
that: the only thing that knows is the accessor name the link came from, so the origin now
travels beside each URL and clean beats watermarked before size is consulted at all. Pair this
with the audio lesson above: **size answers "which is bigger", never "which is right"**, and
each new wrong-file report has been a different property that size cannot see.

Separately, `AWEAwemeACLItem.watermarkType` is forced to zero **at its setter**, not at a getter
— the same reason `-bypassOnesie` failed in the YouTube tweak: code that reads the ivar directly
never passes through a getter hook, while a stored value is true for every reader.

**Measuring by size alone reintroduced the audio bug this project had already paid for once.**
0.14.0's `HEAD` gave both `Content-Length` and `Content-Type`, and only the first was kept —
so a 0.9 MB `audio/mpeg` beat an `.mp4` whose server answered 400, and the save was the music.
**A measurement is only better than a guess when it measures the right quantity**: kind decides
first, size settles ties between videos, and a link that refuses `HEAD` still outranks a known
audio one, because refusing to answer is not evidence of being the wrong thing.

**And a photo post carries a video model too.** TikTok renders a slideshow as a video, so
putting the video branch first in `+captureSettledModel:` meant a photo post always saved a
video — the picture branch was never reached. The rule is an ordering, not a test: a post that
has pictures is a photo post whatever else it carries, and both entry points must ask in that
order. Worth noting both faults were found by the diagnostics added in the same release that
caused them; a report that names what it chose is what makes a regression visible in one round.

**The tikwm.com path is now shipped, as a switch, off by default — and this file's earlier
refusal was not wrong, it was a different question.** It was refused as *the fix*, arriving
quietly; the owner then asked for it knowing the trade, which is exactly the case the refusal
reserved. It stays off unless someone turns it on, its own row states that enabling it tells an
unrelated service what they are watching, and with it on the external link is measured against
the internal ones rather than trusted for being external. The line this project keeps is not
"never touch a third party" — it is that a privacy cost is never paid on the user's behalf
without them being told.

**The ladder answered the quality question, and the answer was that nothing was wrong.** A
device report listed five gears topping out at `adapt_lower_720_1` — so 720 was TikTok's own
ceiling for that video and the picker was already taking the best. It also showed
`bitrateModels`, `SDRBitrateModels` and `HDRBitrateModels` are the *same five gears* on this
build, printed three times: gathering all three costs nothing and stays, but the report
deduplicates. Worth noting what the row bought — it ended a line of inquiry rather than opening
one, which is what a good diagnostic does.

**A crash is worse than SD** — that is why 0.12.1 exists, and it is the rule to keep if the
HD attempt goes wrong again.

- **CarPlay is built but not served.** The code is complete and compiles; the package is
  kept out of the APT index until its app bridging is confirmed on a device. Install it
  by hand from `buildcarplay.yml`'s artifact in the meantime. See the top of this file.

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
