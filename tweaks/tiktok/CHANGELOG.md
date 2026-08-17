# Albrhi for TikTok — what changed

## v0.6.0

**The rail's own contents, printed by v0.5.3's new report, settled the placement
question by proving my own last fix impossible:**

```
TTKRightInteractionAreaBackgroundView | TikTokFeedInteractionBiz.PlayInteractionLikeView
| TTKRightInteractionAreaBackgroundView ×4
```

TikTok wraps every icon except like in the *same* generically-named background view. No
icon but like can be identified by class name at all, so v0.5.3's "find the one whose
name mentions share" always failed and always fell through to appending at the very end
— below the music disc, which is exactly what "way below the picture" was describing.
That was a regression this file introduced; the index arithmetic it replaced was closer
to right. Placement is one position before the end again, the button's height is now
matched to a sibling's own measured height rather than a number picked here, and the
assumption about rail order is printed in the report rather than buried in code.

**Audio is no longer an outcome — it is a rejected candidate.** This is the real fix for
"saved as audio". The resolver used to stop at the first chain that answered and keep
one URL; `originURLList` answers reliably and answers with the *sound's* link, so there
was nothing to fall back to and the same 972317-byte `audio/mp4` file was saved release
after release. Now **every** chain is run and every http(s) link it produces is kept on
the item. The downloader fetches them in turn and only accepts one whose downloaded file
actually carries a video track — the file itself deciding, the same standard v0.4.12
established. An audio-only file, a non-2xx status, an unplayable body, or a failed
transfer each mean "wrong candidate, try the next" instead of "done, here is a song".
Only when every candidate has been fetched and none had a video track does it give up,
naming every link it rejected and why.

**Also recorded, and still outstanding:** the button reads
`[SCITTMedia recent].firstObject` — the most recently resolved link, which during a
scroll belongs to a prefetched neighbour rather than the video on screen. `AWEFeedViewCell`
was dumped for a model accessor to fix this properly and came back with nothing usable —
only UIKit and framework-category internals (`_focusItemDeferralMode`, `nsli_superitem`,
`ttket_dataProvider`…), no `model`/`aweme`/`item` of TikTok's own. That cell holds its
model somewhere this dump does not reach, and the next attempt has to go at it from a
different angle rather than a fifth keyword guess.

## v0.5.3

`972317 bytes` — the *exact* same byte count as three releases ago, with the winning
chain now reported as `video.playURL.originURLList`. An identical file from a
differently-named chain means the chain name was never the useful fact, and this
release stops guessing on three separate fronts by recording what was actually
happening instead.

**The resolved link is now in the report.** Every version of this diagnostic named which
*selectors* answered and never once what they answered *with*. Host plus last path
component is enough to tell a music CDN from a video CDN at a glance — and truncated
deliberately, so a signed account-scoped URL does not end up in a pasted report.

**The button's real design flaw, stated plainly.** It saves
`[SCITTMedia recent].firstObject` — whichever URL was resolved *most recently*. During a
scroll that is a prefetched neighbour several videos ahead, not the video on screen.
That single fact explains both remaining complaints at once: it downloads the wrong
thing, and it appears unevenly because it appears only when *something* has resolved
recently. Fixing it needs the cell's own model accessor, which no reference tweak names
because neither hooks `AWEFeedViewCell` — so a new Status row dumps that class's own
`model`/`aweme`/`item`/`data` accessors from the live runtime, the same way the aweme
model's were found. The next report names the accessor; the release after this one binds
to it.

**The button is now placed by finding share, not by counting from the end.** "Second
from last" assumed TikTok's rail ends with its music disc — an assumption about a layout
this project had never actually read, and it put the button in the wrong place twice. The
siblings' class names were available the whole time: the one whose name mentions share is
the one to sit under. The rail's full contents are recorded in the report either way, so a
build whose naming does not match says so instead of landing somewhere odd.

## v0.5.2

**VibeTok does have a download feature, and reading only NA9 is what kept this
broken.** An earlier pass concluded VibeTok had none — it does: a whole
`MSGDownloadSettingsViewController`, "Download video", "Download audio",
`PHAssetCreationRequest`, a `download_HD_Video` preference. And crucially it reaches the
link through **different selector names than NA9 uses for the same job**:

| selector | NA9 sends | VibeTok sends |
|---|---|---|
| `playURL` | yes | — |
| `h264DownloadURL` | — | **yes** |
| `playURLList` | — | **yes** |
| `bestURLtoDownload` | yes | — |
| `originURL` | yes | — |
| `originUrl` | — | **yes** (note the casing) |
| `originURLList` | **yes** | **yes** |
| `urlList` | — | **yes** |

All of those are `_objc_msgSend$…` stub symbols — emitted only for a selector the
compiler saw actually being sent, which is a far higher bar than a name appearing
somewhere as a string. `originURLList` is the only one **both** tweaks send, so it is
now tried early on every container. `h264DownloadURL` is VibeTok's own path and its
name says exactly what this feature wants: a download link rather than a streaming
address.

**Two names this file had invented are gone.** `-h264URL` and `-downloadURL` were
guesses from an earlier release; neither tweak sends them and neither binary carries
them as strings at all. Same for the ranking of `-playAddr`/`-bitratePlayAddr` — strings
only, never sent, so they stay last rather than second.

## v0.5.1

**The Download list is gone from the settings screen, on request.** It was a list of
bare timestamps with a Save button each — a debugging aid wearing a feature's clothes.
Nobody picks a video out of thirty unlabelled rows they cannot see; the in-feed button
beside share is the whole interface, and a second, worse way to do the same thing only
made the screen look unfinished. `SCITTMedia` still keeps its recent list because the
button reads from it; it just has no UI of its own any more.

**Two more confirmed ways out of an `AWEURLModel`, from a third pass over NA9's binary.**
`_objc_msgSend$originURL` and `_objc_msgSend$originURLList` are both present as stub
symbols — which the compiler emits only for a selector it actually saw being sent — so
they meet exactly the same bar `-bestURLtoDownload` does, and all three are now tried
in turn. That same pass also settled something the other way: `-playAddr` and
`-bitratePlayAddr` are **not** sent anywhere in that binary. They appear only as plain
strings, which is dictionary-key territory, so they now sit after the three confirmed
selectors rather than in front of them.

**And a finding deliberately not built.** NA9's download does not resolve a link from
the app at all for its HD path — it fetches
`https://tikwm.com/video/media/hdplay/<id>.mp4` from a third-party scraper service,
keyed by the video's own ID. That is why its button has worked unchanged for years: it
never depended on TikTok's internal model chain. It is not reproduced here, and the
reason is the same line this project already drew at `app_attest_*` in the X tweak and
at Check0verPlus in Locket: it would send what the user is watching to an unrelated
third party, inside a tweak whose neighbouring feature exists specifically to stop
watch activity being reported to servers. The owner can have it if they ask for it
knowing that; it will not arrive quietly.

## v0.5.0

**The 288 "successful" resolutions were all the song, not the video, and the file's own
track list is what finally said so.** `-URLList` on `AWEAwemeModel` resolved 288 times
out of 706 — and the file it produced was 972 KB of `audio/mp4` with no video track at
all. It is the *sound's* URL list. Every save reporting "sound saved" was that chain
being confidently, consistently wrong; v0.4.12's AVFoundation check is what turned an
invisible wrong answer into a measurable one. `-URLList` and `-playURIString` are both
removed rather than reordered: a chain that reliably resolves the wrong media is worse
than one that resolves nothing.

**The link comes from `AWEVideoModel`, caught at its own construction.** Every attempt
so far went through the aweme model, and `AWEAwemeModel -video` is nil for the
overwhelming majority of models at the moment they are built — a retry timer only
partly papered over that. `AWEVideoModel` is confirmed real by the reports themselves
(one said `"AWEVideoModel has no -playAddr"`, which only a real class can say; another
said `video.playURL` ended `"at AWEURLModel"`, one hop short of that class's own
doubly-confirmed `-bestURLtoDownload`). A new file, `SCITTCapture.x`, hooks
`AWEVideoModel -init`/`-initWithDictionary:error:` and resolves
`playURL.bestURLtoDownload` from it directly — by the time that object exists, the play
URL is what it was built to carry, so there is nothing to wait for. `%orig` runs first
and the return value is never altered; this reads, it does not filter.

**The button's glyph is no longer the button's image.** A plain image button was tried
three ways and read tilted every time: `contentEdgeInsets` and
`contentHorizontalAlignment` are reinterpreted by `UIButtonConfiguration` on iOS 15+
whether one was asked for or not, and a fixed width fought the stack's own fill
alignment. The glyph is now a separate `UIImageView` centred inside the button by this
file's own `centerXAnchor`/`centerYAnchor` constraints — which nothing in `UIButton`'s
internal layout or in the stack's alignment can reinterpret. It sits in the middle by
construction rather than by an alignment property holding.

## v0.4.12

**"Sound saved" was never a failure message — it was the audio branch succeeding on a
file that is actually a video.** Two releases guessed at a file's kind from its name:
first the response's MIME type, then the URL's own path extension. Both were wrong on a
real device, and both were guesses about a file that was already sitting on disk and
could simply have been asked.

`AVURLAsset` now reads the downloaded file's own track list, and *that* decides:
a video track present means Photos, no video track and an audio track present means
the Documents folder, and neither means the file is not playable media at all — an
error page, a truncated transfer, an HTML redirect that answered 200 — which is now
reported as such rather than handed to Photos to be refused for unrelated-sounding
reasons.

This is this project's own ground rule applied to a file instead of an object: *"a
non-nil object is not a working object; check that a thing can actually do its job, not
that it is non-null."* An extension on a URL that may carry query parameters, no path
segment at all, or a CDN's own naming scheme is exactly the kind of proxy that rule
exists to rule out. The "Last save attempt" row now reports the actual track counts and
byte size alongside the outcome, so the next report is a measurement rather than an
inference.

## v0.4.11

**Two releases were spent fixing the wrong thing because this tweak's own diagnostic
was actively misleading, and that is the real lesson here.** `+lastAttemptState`
recorded only the *last* resolution attempt, and the overwhelming majority of attempts
are brand-new models asked a moment after construction, before their video data is
populated. So the row read "every chain failed — -video answered nil" while the feed
button, which appears *only* when a URL has actually been resolved, was visibly
appearing and being reported as placed. The failing line was the last of two hundred
attempts, not the verdict on all of them; resolution has been working for at least two
releases. Successes are now counted separately, the winning chain is named, and the
last attempt's own detail is shown only while nothing has ever succeeded — a number
that climbs cannot be drowned out the way one overwritten string could.

The same pattern this project already documented for the YouTube tweak's SABR section
("a report showing no interceptions had two readings, and those need opposite fixes"),
repeated in a new place. A diagnostic that reports the last event rather than a tally
is not a diagnostic.

**The button's tilt was caused by v0.4.10's own fix.** A vertical `UIStackView` aligned
`fill` — the default, and what TikTok's rail evidently uses — gives every arranged
subview the stack's full width. Pinning this one to 34 points fought that: the
constraint and the fill cannot both hold, and the loser reads as a button sitting off
to one side of a column whose siblings are centred in full-width slots. The width
constraint is removed; only the height is fixed, and the glyph is centred inside
whatever width the stack gives it, exactly as every sibling icon already does.

**The download failure now says what refused it.** "Couldn't save it" is all a user
needs and nothing a fix can be built from: an HTTP 403 on the resolved link, a file
Photos will not decode, and a zero-byte download that answered 200 all look identical
from there. A non-2xx HTTP status is now caught before the file is ever handed to
Photos (`NSURLSession` treats an error page as a perfectly successful download, which
is how a 403 arrives as an unplayable `.mp4`), and the real reason — the status code,
Photos' own error, or which extension/MIME pair decided a file was audio — is recorded
and shown as its own "Last save attempt" Status row.

## v0.4.10

Three things reported against v0.4.9, all in one round this time.

**The button read tilted.** A plain `UIButtonTypeSystem` has no fixed size of its own
— its intrinsic content size comes from the glyph plus the system's own default
content insets, not necessarily the same width or centring TikTok's own icons use.
Given an explicit 34×34 square, centred content, and its default edge insets zeroed
out, it now sizes the same way its siblings in the rail do rather than however the
system decided to pad a bare image button.

**It still shows only sometimes.** This is not a new bug so much as the honest shape
of the current approach: the button only shows when `SCITTMedia` has actually
resolved something, and resolution itself is still inconsistent from one video to the
next — the same report that asked about this also showed every chain failing outright
for the video it was taken on. The retry window was widened (ten attempts over twenty
seconds rather than six over nine) on the chance some of that inconsistency is still
a timing question rather than a wrong name, but a resolver this unreliable will keep
producing a button that shows unevenly until a chain proves itself consistently
right.

**A downloaded video saved as "sound saved."** MIME-type sniffing alone decided
audio vs. video, and a server answering a missing or generic `Content-Type` for a
link whose own path plainly ends `.mp4` is exactly what that cannot tell apart from a
genuine audio-only link with the same gap. The URL's own path extension is now
checked first (`.mp4`/`.mov`/`.m4v`/`.webm` → video, `.m4a`/`.mp3`/`.aac`/`.wav` →
audio) and MIME type only decides when the extension itself is inconclusive.

## v0.4.9

The centering fix worked — one button, reported placed once, no more scatter. Two
things followed directly from the last full failure report.

**The resolution chain was one hop short of a real answer, named by its own failure.**
`-video` no longer answers nil (the retry timer's own doing) and returns a real
`AWEVideoModel`; `video.playURL` was already being tried, and the report said exactly
why it failed: `"chain ended at AWEURLModel, not a URL or string"` — `-playURL`
answers a real `AWEURLModel`, one hop short of that class's own doubly-confirmed
`-bestURLtoDownload`. `video.playURL.bestURLtoDownload` is now the first chain tried,
built from that failure rather than another guess.

**The button's position.** Reported as fixed under the wrong icon. TikTok's own rail
is avatar, like, comment, bookmark, share, then a spinning record/music-disc last —
not confirmed against a class dump the way this project holds every other hook target
to, but a layout consistent across TikTok's own app regardless of build. Appending at
the very end (what `-addArrangedSubview:` does) landed the button after that disc
rather than under share. It is now inserted one position before the end instead,
which puts it directly under share on that layout.

## v0.4.8

Both problems reported against v0.4.7 were real progress, not new failures: the button
attached and placed real instances on both surfaces (3 on the cell overlay, 9 on the
rail), and resolution succeeded for the first time (`playURIString`). Two bugs
followed directly from that success.

**Scattered, duplicate buttons.** TikTok keeps more than one cell alive at once for
smooth scrolling -- the one on screen and its prefetched neighbours -- and every alive
cell's own rail was showing a button regardless of whether that cell was actually the
one visible. Four to six buttons on screen at once was the two surfaces (cell overlay,
interaction rail) each placing one per alive cell. The cell-overlay surface is dropped
entirely -- it was a fallback for a build where the rail did not exist, and this
device's own report already proved it does, so keeping both only doubled the scatter.
The rail surface now checks whether its own view is actually centred in the window
before showing anything (`-convertRect:toView:` against the window's own bounds,
within a quarter of its height) and hides itself otherwise -- so of however many cells
are alive, only the one on screen shows a button.

**The download itself failed.** `playURIString` resolving to *something* was never the
same claim as that something being a fetchable link, and `NSURL URLWithString:` builds
a URL object out of almost any string without checking. The resolver now requires the
scheme to be `http` or `https` before accepting a chain's answer, treating anything
else (an internal resource identifier, most likely, on a property named this
generically) as a failed step and moving on to the next candidate rather than handing
the downloader something it can never fetch. Chain order was also reshuffled so paths
most likely to reach a real `AWEURLModel` -- and therefore `bestURLtoDownload`, the one
doubly-confirmed step in this whole file -- are tried before `playURIString`/`URLList`.

## v0.4.7

The full `+candidateAccessorsOnAwemeModel` dump, read this time from the live class on
a real device rather than from either reference tweak's own binary, settled the
`-video` question: it exists as a real property, and every attempt to read it so far
has answered nil. Two readings are possible -- the wrong candidate, or the right one
simply not populated yet at the moment a model is first built -- and this project has
no way to tell them apart from a class dump alone.

**So both are now covered.** Seven more candidate chains join the resolver, each read
directly off that same live property list rather than guessed: `downloadinfoModel`,
`urlHolder`, `playURIString`, `playItem`, `URLList` (now handled as a value that can
itself be a list — the first entry that converts to a URL wins). And a model whose
first resolution attempt finds nothing is no longer simply logged and discarded:
`+watchModel:` holds it *weakly* — nothing here extends how long a feed cell's own
model stays alive — and a repeating timer retries resolution on every pending model up
to six times, in case the answer was only ever a timing question. A model still
unresolved after six tries is assumed to genuinely have no video (a photo post, most
likely) and dropped rather than retried forever.

**A "copy report" button was asked for directly and added to the settings screen's
navigation bar.** The Status section's own rows can each run to a long, dynamically
built string — every candidate chain's own failure reason, every property name on the
live class — exactly the kind of thing a bug report needs pasted whole rather than
retyped from a screenshot. One tap copies gate state, ad filter counts, the button
report, the resolution state, the full candidate list, and both bypass and privacy
states to the pasteboard.

## v0.4.6

Rather than wait on another device report to try one more guessed selector, NA9's own
binary was read again -- not its `_ungrouped$` hook table this time, but its generic
`_objc_msgSend$…` message-send stub symbols, which name every selector the binary
actually sends anywhere, hook or not. Real candidates turned up: `-video` (no "Model"
suffix), `-playURL`, `-url`, alongside `-bestURLtoDownload` itself (the one step that
was always doubly confirmed). `awemeVideoModel` also appears as a plain string near
`_videoModel`/`bitratePlayAddr` in the same table that misled this project the first
time, and is deliberately not used here for that reason alone -- string proximity is
exactly the standard that already failed once on this same question.

`SCITTMedia.resolveURLForModel:` now tries seven candidate chains in order --
`videoModel.playAddr.bestURLtoDownload` (the original, kept in case some path still
uses it), `video.playAddr.bestURLtoDownload`, `video.bestURLtoDownload`,
`video.playURL`, `video.url`, `playURL`, `videoModel.playURL` -- each guarded by
`-respondsToSelector:` at every step, stopping at the first that resolves. When none
do, `+lastAttemptState` now reports every chain's own failure point in one line
instead of only the first, so the next report is decisive rather than another single
data point.

## v0.4.5

The answer came back: **"model has no -videoModel."** `-videoModel` was always this
tweak's own weakest link -- the header has said so since v0.2.0, marked circumstantial
because neither reference tweak's own hook table ever names it, only string-table
proximity to `playAddr`/`bitratePlayAddr` suggested it. A live device now says outright
it is wrong on this build.

Guessing a replacement name would repeat the exact mistake that produced the
`AWEFeedViewCell` bug two releases ago. Instead, `SCITTMedia` gained
`+candidateAccessorsOnAwemeModel`, a new Status row that reads `AWEAwemeModel`'s own
properties and no-argument methods straight off the *live runtime class on this exact
device* — walking up a few superclasses too, since the accessor may not sit on
`AWEAwemeModel` itself — and lists every one whose name contains "video", "play",
"url", "media", "cover", "download" or "aweme". Not a class dump taken somewhere else:
whatever this row lists is what the chain can actually be pointed at on the build that
matters, the same "ask the device, not the assumption" principle Diagnostics pages use
throughout this project.

## v0.4.4

Still 0 placed on both surfaces after v0.4.3, on a device where the ad filter's own
count (122 feed items seen, 10 dropped) proves `AWEAwemeModel` construction is being
reached. That count alone does not prove the *download* resolution chain succeeds for
any of those models — `-configWithModel:`'s replacement, reading
`[SCITTMedia recent].firstObject`, would show nothing whether the placement hooks
never fire *or* fire correctly and simply have nothing resolved to show. Those need
different fixes, and nothing on the report so far said which.

`SCITTMedia` has carried exactly the diagnostic for this since v0.2.0 —
`+lastAttemptState`, which records which step of `videoModel.playAddr.bestURLtoDownload`
the chain last reached — and it was never wired into the settings screen. It is now, as
its own Status row, separate from the button's own placement count. The next report
names which of "no -videoModel", "-videoModel nil", "no -playAddr", "-playAddr nil", "no
-bestURLtoDownload", a wrong return type, or "resolved a download URL" is actually
happening, rather than leaving "0 placed" to mean any of them.

## v0.4.3

**A real device report settled the button question outright.** The Status screen's
own "In-feed button" row, checked after v0.4.2, said: `cell overlay — 0 placed;
TTKFeedInteractionStackView + TTKFeedRightInteractionStackView — 0 placed; above it:
TTKFeedInteractionStackView < TTKFeedInteractionMainView < TTKFeedInteractionRootView
< UITableViewCellContentView < AWEFeedViewCell < AWENewFeedTableView < … <
AWEFeedSlidingScrollView`. The rail was attached and running — it is what walked that
chain — and the chain names the real cell: **`AWEFeedViewCell`**, not
`AWEFeedViewTemplateCell`, the class both NA9 and VibeTok's own symbol tables name and
the one every placement attempt through v0.4.2 hooked. `AWEFeedViewCell` is in neither
reference's own hook table at all; this build has moved past what either was written
against. `-configWithModel:`/`-configureWithModel:` were therefore never called on a
real cell, and the association they were meant to stash was never there for the rail
or the overlay to read — which is the entire reason both surfaces reported zero.

**The fix drops per-cell precision rather than guess at another bind method.** Nothing
in the walked chain says which selector actually sets `AWEFeedViewCell`'s model, and
guessing one is exactly what produced this bug the first time. `-layoutSubviews` needs
no such guess — inherited from `UIView`, it fires regardless of what TikTok calls its
own bind method. Both surfaces (the cell overlay and the rail) now show
`[SCITTMedia recent].firstObject` — the newest video this tweak has actually resolved
a link for — rather than a specific per-cell association. This is the same "download
the newest capture" shortcut Locket's own quick-save button already takes, for the
same reason: the ad filter's diagnostics already prove `SCITTMedia` is capturing real
items (the report that found this bug also showed 154 feed items seen, 6 dropped),
so the newest one is almost always the video just watched. `AWEFeedViewCell` is hooked
alongside the older `AWEFeedViewTemplateCell` rather than replacing it, at zero cost
if the older name never fires again on this build.

## v0.4.2

v0.4.1's own fixes did not hold, reported directly against a real build: the settings
text was still overlapping and the button still did not appear.

**The overlap had a second, more direct cause than the row height fix addressed.** The
Status section used `UITableViewCellStyleValue1` with a multi-line detail label —
Value1 lays its title and detail side by side on one line by design, and several of
these rows hold a long, dynamically-built diagnostic string (a comma list of hook
names, a whole superview chain). Forcing that onto two lines in a layout built for one
draws the wrapped text over the title beside it rather than under it. Switched to
`UITableViewCellStyleSubtitle`, the same style already used everywhere else on this
screen, which stacks a note under its title instead of beside it.

**The button gained a second, primary placement that does not depend on the interaction
rail at all.** Reported directly: NA9 For TikTok's own download button — its classic
surface, not the sidebar one — has worked without interruption for years, drawn
straight onto `AWEFeedViewTemplateCell` itself via `-layoutSubviews` calling its own
`na9AddDownloadButton`. That is now this tweak's primary surface too: a button added
as a direct subview of the cell, bottom-right, raised to the front on every layout
pass the same way the X tweak's own `ImmersiveCardView` surface does for the identical
reason (the video's own overlays are re-added as the cell renders, and a button under
one of them is a button nobody can tap). It needs only `AWEFeedViewTemplateCell` to
exist — nothing else has to be present for it to have a chance of showing. The
interaction-rail surface (`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView`)
is kept as a second, optional surface exactly as NA9 also carries both. The Status
screen's own report now names both surfaces and how many buttons each has placed.

## v0.4.1

Three things reported directly after v0.4.0 shipped: the in-feed button still did not
appear, privacy was one switch for three different reports, and the settings screen's
own text overlapped itself.

**The overlap was a real, confirmable bug, independent of anything device-specific.**
Every Controls/Privacy row carries a wrapped, multi-line note under its title, and the
table never set an automatic row height -- every cell sat clamped to the fixed 44-point
default, so a two- or three-line note was drawn on top of the row underneath it rather
than pushing it down. `self.tableView.rowHeight = UITableViewAutomaticDimension` with an
estimated height fixes it outright.

**Privacy split into three separate switches**, each its own row in a new Privacy
section: story views, message read receipts, profile views. One switch bundling all
three could never be turned off for just one of them, which is what was asked for
directly. `SCIPrefPrivacy` is gone; `SCIPrefPrivacyStory`/`SCIPrefPrivacyMessages`/
`SCIPrefPrivacyProfile` gate their own hook in `SCITTPrivacy.x` independently.

**The in-feed button's placement no longer depends on the rail's own layout firing.**
`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView -layoutSubviews` and
`-didMoveToWindow` are still hooked as a fallback, but this project's own CLAUDE.md
already documents why neither can be trusted alone on a *reused* cell -- the same
lesson a much earlier X-tweak bug cost a release to learn, and a UIStackView is not
guaranteed a fresh layout pass just because the cell holding it was rebound to a
different model. Placement is now driven directly from `AWEFeedViewTemplateCell`'s own
`-configWithModel:`/`-configureWithModel:` -- confirmed to fire on every reuse -- via a
depth-first search of the cell's own subview tree for the rail, immediately after the
resolved item is stashed on the cell. Whether this actually surfaces the button on a
real device is still unconfirmed; the Status section's own "In-feed button" row now
says exactly which of four states it is in (rail absent, cell hooked but no rail, rail
found with nothing resolved above it, or N buttons placed) rather than a bare yes/no,
so a report from here on names which one rather than only "no button."

## v0.4.0

A download button in the feed itself, and a real settings screen -- both asked for
directly after v0.3.0 shipped only a status-screen list.

**The button.** NA9 For TikTok's and VibeTok's own `_ungrouped$` hook tables were read
again, this time for where a *visible* button belongs rather than for a resolution
chain. NA9 places one on `AWEFeedViewTemplateCell` directly and, on a newer rail, on
`TTKFeedInteractionStackView` / `TTKFeedRightInteractionStackView` -- the vertical stack
of like/comment/bookmark/share icons beside the video. VibeTok, a tweak with no
download feature at all, independently hooks `TTKFeedInteractionStackView
-layoutSubviews` for its own unrelated reason, which is a second, unrelated confirmation
that class is real. Both stack names are confirmed present as literal strings in TikTok
46.4.0's own `MusicallyCore` binary, read directly the same no-`otool` way every class in
this tweak has been.

What is not carried over is how the reference tweaks find out which video to download --
that reads a model accessor on the stack view this project has not independently
confirmed. Instead, the model is caught where it needs no confirmation at all:
`AWEFeedViewTemplateCell -configWithModel:` / `-configureWithModel:` are two of NA9's own
hooked selectors, and a hooked method's own argument is simply what was passed, not a
guess. The resolved URL is stashed on the cell the moment its model is set, and the
button -- nested somewhere inside that cell -- reads it back by walking up its own
superview chain, the same upward search the X tweak's own immersive button already uses
to reach its card from its rail. `SCITTMedia`'s resolution chain was split out into its
own `+resolveURLForModel:`, callable without touching the status screen's recent list, so
there is exactly one resolution implementation behind both surfaces.

**The settings screen.** Replaced entirely -- a plain stack of three switches over one
text-view report is not what "detailed and organized like NA9 and VibeTok" asked for.
Rebuilt as a real grouped `UITableViewController`, in the shape the X tweak's own
settings screen (`SCITWSettings.m`) already settled on: a status card with pass/fail
pills at the top, a Controls section with a coloured icon and an explanation under every
switch, a Download section listing what has actually been resolved (tap a row to save
it, no confirmation sheet), and a Status section with live numbers -- the panel gate,
the ad filter's own count, which interaction rail the button attached to, and what the
bypass and privacy hooks have each answered. Privacy answers now record into their own
set (`SCITTDiagnostics recordPrivacyAnswer:`/`privacyState`) instead of sharing the
bypass tally, so the two numbers cannot be read as one.

**Privacy widened by two more confirmed selectors.** `TTKProfileViewsVisitor -visit:` and
`-p_shouldReportHasVeiwedProfileForUser:` turned up in the same NA9/VibeTok symbol tables
the other three privacy hooks came from, confirmed present in the real binary the same
way -- added alongside `-reportProfileView`/`-p_shouldReportProfileView` on the same
class, all four withheld together.

## v0.3.0

Two more references arrived — NA9 For TikTok's compiled `.deb` and VibeTok's compiled
`.dylib` — both read the same way every closed reference in this project is: with the
precise `_ungrouped$Class$selector` Logos debug-symbol table each carries (both are
unstripped debug builds), which names the exact class-and-selector pairs each one
actually hooks, not just what strings sit near each other. Read for where TikTok is
hookable only; no code is taken from either.

**Download.** `AWEAwemeModel.videoModel.playAddr.bestURLtoDownload` is the chain both
references resolve a video's URL through. `-bestURLtoDownload` is confirmed twice over —
present in this build's own binary and the exact selector NA9's own symbol table hooks.
`-videoModel` and `-playAddr` are not in either reference's own hook table (neither
overrides them, only calls them), so they are held to the lower, circumstantial bar this
project's other "not a hooked selector" findings are — `SCITTMedia.m` walks the chain
behind `-respondsToSelector:` at every step and records which one failed rather than
assuming it holds. A kept (non-ad) model is captured the moment `AWEAwemeModel` finishes
building, resolved synchronously, and only the resulting URL is kept — never the model
itself, so nothing here extends how long a feed cell's own object stays alive. The
status screen lists what has been captured with a Save button per item;
`SCITTDownload.m` fetches and writes it into Photos, or into the app's own Documents for
audio-only content Photos cannot hold, mirroring Locket's and X's own downloader almost
exactly (`JGProgressHUD`, `PHPhotoLibrary requestAuthorizationForAccessLevel:`,
`NSURLSessionDownloadDelegate`).

**Privacy.** Three points where the app reports what was watched back to TikTok's own
servers, cross-validated between both new references before being hooked:
`TTKStoryMarkReadService -markAsRead:` (a story was opened), `AWEIMMessageReadComponent
-p_markReadSyncToServerWithMessage:` (a DM was read — its sibling
`-p_markMessageAsReadLocally:` is deliberately untouched, so the conversation's own
unread badge keeps clearing normally on this device), and `TTKProfileViewsVisitor
-reportProfileView` / `-p_shouldReportProfileView` (a profile was visited). New switch,
off by nothing — on by default like the rest, in the status screen.

**Ad filter widened.** `isAd`, `isAdItem` and `isAdsOrPseudoAds` join `-isAds` as marks
`AWEAwemeModel` can carry — found sitting beside it in the same run of the binary's own
string table, the same circumstantial standard `-videoModel` was already held to.
`-respondsToSelector:` guards each independently; any one answering YES is enough to
drop the model. A separate splash/launch-ad surface is suppressed too — three plausible
manager class names (`AWESplashManager`, `BDASplashManager`, `TTAdSplashManager`) are
each hooked behind their own `NSClassFromString` guard, since the references disagree on
which name a given build actually ships and an absent class's hook simply never
attaches.

**Bypass widened.** Six more jailbreak-detection points, each confirmed present by class
name and cross-validated between both new references: `IOSSecuritySuite +amIJailbroken`,
`AppsFlyerUtils -isJailbrokenWithSkipAdvancedJailbreakValidation:`, `IESLiveDeviceInfo
-isJailBroken`, `TTInstallUtil -isJailBroken`, `UIDevice -btd_isJailBroken`, and a bare
`NSObject -jailbroken` category method. **`PIPOStoreKitHelper -isJailBroken`, also named
by a reference, is deliberately left unhooked** — v0.1.0's own reading already refused
`PIPOStoreKitHelper` and its sibling `PIPOIAPStoreManager` as sitting inside the
in-app-purchase surface, the same boundary Locket's Check0verPlus review drew, and one
confirmed method on that class is not reason enough to cross it. The other six checks
already answer the same underlying question.

## v0.2.0

The real IPA and a real class dump of TikTok 46.4.0 arrived, and every class this tweak
now hooks was confirmed against it directly — `MusicallyCore.framework` (810 MB, the app's
real logic; the main executable is a 92 KB stub) parsed by hand for its own class and
selector names, the same Mach-O-by-hand method this project already uses everywhere else
there is no `otool` available.

**No ads.** `AWEAwemeModel` — confirmed present — carries the server's own `-isAds` mark
on every feed item, confirmed as a real property name in this build's own strings. Refused
at `-init` and `-initWithDictionary:error:`, after `%orig` builds the object (the mark
cannot be read before then) and before anything downstream ever sees it. Not a view hidden
afterward; the object is never returned.

**Hides the jailbreak.** `TTAdSplashDeviceHelper -isJailBroken`, `GULAppEnvironmentUtil`'s
three environment questions, `FBSDKAppEventsUtility -isDebugBuild`, `AWEAPMManager
-signInfo`, `AWESecurity -resetCollectMode`, and `NSBundle` asked for a
`.mobileprovision` — six real checks, each answered the way an unmodified phone would.
Nothing here touches `PIPOIAPStoreManager`/`PIPOStoreKitHelper` or any purchase flag, and
nothing will.

**v0.1.0's own reading corrected itself here, not silently.** `AWEAPMManager` was filed
under "Ads" in that entry, going only by its name — reading BHTikTok's actual hook showed
it answers a signing-info question (`+signInfo` → `"AppStore"`), which is a jailbreak-
detection answer, not an ad control. It is filed correctly above. `AWEPlayVideoPlayerController`
and `TIKTOKProfileHeaderView`, both named in v0.1.0's list, do not exist as exact strings
in the 46.4.0 binary at all — plausible replacements were found
(`AWEPlayVideoPlayerControllerClass`, `AWEVideoPlayerController`; a `TTK`-prefixed profile
header family) but not yet confirmed enough to hook.

Settings: a two-finger hold opens a status screen with a switch for each feature above and
the same diagnostics report `SCITTDiagnostics` builds — how many feed items were seen and
how many dropped as ads, and which bypass hooks have actually answered a real caller.

Next: download. `AWEURLModel` is confirmed present; what shape it answers in — a direct
URL, or another indirection the way most of this project's other download features turned
out to need — is not yet measured.

## v0.1.0

Scaffold only. The tweak's structure exists — Makefile, control, filter plist, source
layout, bilingual localisation table, the panel gate — so `tools/check.py` and
`./build.sh tiktok rootless` both run against it while the real hooks are written. No
feature patches TikTok yet.

Two references were read for architecture, both by the same author family already
credited in the X tweak's own control file: BandarHL's original BHTikTok
(github.com/BandarHL/BHTikTok) and al3raQe's maintained fork
(github.com/al3raQe/BHTikTok). Neither carries a LICENSE file, so both are read the same
cautious way every other unlicensed reference in this project is — for *where* things are
hookable, never for the code itself. Their `Tweak.x` hooks 34 classes; the ones that
matter for what this project would actually build:

- **Ads**: `AWEAPMManager`, `TTAdSplashDeviceHelper`
- **Download / feed model**: `AWEAwemeModel`, `AWEURLModel`, `AWEPlayVideoPlayerController`,
  `AWEFeedVideoButton`, `AWEFeedViewTemplateCell`, `AWEAwemeDetailTableViewCell`
- **Profile**: `TIKTOKProfileHeaderView`, `AWEProfileImagePreviewView`,
  `AWEProfileEditTextViewController`, `AWEUserModel`
- **Confirmations / comments**: `AWECommentPanelCell`, `AWEPlayInteractionUserAvatarElement`
- **Device / jailbreak-detection evasion**: `BDADeviceHelper`, `BDInstallNetworkUtility`,
  `GULAppEnvironmentUtil`, `UIDevice`, `CTCarrier`, `NSFileManager` — the same class of
  check Locket's own bypass answers, not a paywall
- **Settings surface**: `TTKSettingsBaseCellPlugin`, `AWESettingsNormalSectionViewModel`,
  `SparkViewController` (built on Cephei/CepheiPrefs, an external dependency this project
  does not use — a native settings screen would be written instead, the way every other
  tweak here already does it)

**Deliberately not being built, regardless of what a class dump confirms**:
`PIPOIAPStoreManager` and `PIPOStoreKitHelper` — an in-app-purchase / StoreKit fake, the
same shape of thing `Check0verPlus.dylib` was for Locket and was reviewed and refused for
the same reason: that takes money from TikTok's own developers, it is not a device tweak.
Any "fake verified badge" / "fake follower count" cosmetic-spoofing features named in
BHTikTok's own README are being treated the same way as Locket's Check0verPlus review
until there is a reason to think otherwise — parked, not assumed safe.

Next: a real class dump and a real IPA of the current TikTok build, so every hook is
confirmed against what actually exists on this build rather than carried over from a
reference that may target a TikTok years older than today's.
