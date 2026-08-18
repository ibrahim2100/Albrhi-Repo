# Albrhi for TikTok — what changed

## v0.16.1

**0.15.1's probe crashed TikTok repeatedly. The hook is gone.**

It hooked the player's selection method with a signature written from the selector name alone —
`(double)duration`, `(NSInteger)trategyType`, returning `id` — and none of that was read from the
runtime. A `%hook` whose argument types do not match the real method does not fail politely: the
arguments arrive in the wrong registers and of the wrong widths, and the process dies. It is the
same mistake as the guessed `long long` cast on `-bitRate` that crashed 0.12.0, made again in the
one file whose entire purpose was to stop guessing.

Nothing is lost by removing it. **The probe already answered its question** — `bitrateModels`
carries the same gear names at a quarter of the player's bitrate — and 0.16.0 acts on that by
reading `__playBSModel` from the video model this tweak already holds, which needs no hook at
all. The measurement was worth it; shipping it without checking the signature was not.

## v0.16.0

**The probe found it, and it is one cause for both complaints.** Put side by side on your
device, the ladder this tweak reads and the ladder TikTok hands its own player carry **the same
gear names at four times the bitrate**:

| gear | what `bitrateModels` says | what the player is offered |
|---|---|---|
| `adapt_lower_720_1` | 373,349 | **1,512,265** |
| `adapt_540_1` | 308,455 | **1,015,884** |
| `lower_540_1` | 197,536 | **584,415** |

So every download has been taking a *reduced copy of the correct gear* — a 720 at a quarter of
the bitrate the app plays. That is the picture and the sound at once, and it also disproves the
theory in 0.15.1: none of the player's gears carries a `selectedAudio`, so the audio is muxed
there too and simply follows the bitrate. The separate-audio-stream idea was wrong, and the
probe is what showed it rather than another release built on it.

The player's models live on `__playBSModel` and its siblings on the same video model this tweak
already holds, so they are now read first — from the same object, with no cross-video risk.
Each is a method rather than a declared property, so nothing states its type: every one is asked
behind `-respondsToSelector:` and accepted only if it looks like a gear list, meaning an array
whose members answer `playAddr`. If none does, the old ladder is used exactly as before.

## v0.15.1

**A measurement, not a fix — deliberately.** The report says the audio and the picture are both
noticeably worse than what the app plays, and there are two candidate explanations that would
lead to opposite changes. Two releases have already been spent acting on an inference a single
measurement would have settled, so this one only measures.

Two facts are behind it. Every gear this tweak has ever seen, across every report, is named
`lower` or `lowest` — not one `normal_720`, not one `adapt_higher_` — which is either the whole
ladder or a filtered subset. And each gear carries `selectedAudio`, a pointer to a *separate*
audio stream with its own bitrate and its own links, which is not the audio baked into the muxed
file the download takes.

So Settings › Status gains one line: what TikTok's own picker
(`AWEVideoPlayBitrateControler`) is handed, and which entry it chooses, with each gear's audio
bitrate beside it. If that list is larger than the one the download reads, the difference is the
answer. Nothing about downloading changed in this release.

Also confirmed again, from your own report: `tikwm HD` and `bitrateModels` resolved to the
*same file name*. That is the third independent confirmation that the external service returns
the file this tweak already downloads.

## v0.15.0

**The external HD service was being asked the wrong way, and the answer changes what the feature
is worth.**

`…/video/media/hdplay/<id>.mp4` is not an endpoint on its own — it answers 400 for an id the
service has not been asked about, which is exactly why it measured 0.0 MB in two reports and why
no `User-Agent` fixed it. It is an API: one JSON request names the links, and the shortcut only
works afterwards. That is what NA9's JSON parsing was for, and it was read here as decoration
first. The switch now makes the real request.

**And for the video from your own report, the external HD file is byte for byte the file this
tweak already downloads.** Queried directly: `wm_size` 8,399,664 — the watermarked copy this
build correctly refuses; `size` 4,567,673; and `hd_size` **3,786,622**, which is precisely the
3,786,622 bytes the tweak saved through `bitrateModels`. So for that video the external route is
not a better file. It is the same file, fetched by a route that also tells a third party what is
being watched.

The switch stays, off by default, because it was asked for and because other videos may differ —
but it is no longer sold as the thing that unlocks quality. When 720 is the ceiling, it is the
upload's ceiling.

## v0.14.5

**Ranking works — your report proved it.** The links measured 3.6, 3.0, 8.0 and 4.4 MB, and the
one taken was the 3.6 MB clean copy over the 8.0 MB watermarked one, saved at exactly 3,786,622
bytes. That is the intended behaviour and it is now confirmed rather than assumed.

**The external HD service refuses a request that does not look like a browser.** It answered
neither `HEAD` nor a range `GET` and measured 0.0 MB twice over, while the same address works in
a browser — and NA9 sets request headers and installs a redirect handler for the very same call,
which is evidence, not decoration. Measurements now carry a normal `User-Agent`.

**And switching that source on is a request for it, not a hint.** It was being outvoted by
whichever internal link happened to measure larger. When it answers at all it now ranks above
them; when it does not, it keeps its ordinary rank and loses on the merits, so a service that is
down costs the download nothing.

**"0 cleared" was a counter that did not count the path that runs.** Only the watermark setter
incremented, and on this build TikTok never calls it — the getter, which does the work, answered
silently. Working code reported as not working, which is the same failure as a tally that records
only the last event.

## v0.14.4

**A refused `HEAD` was sinking the very link you asked for.** Servers that will not answer a
`HEAD` scored zero and dropped to the bottom — which included `tikwm.com`, so switching the
external HD option on changed nothing, and included the quality ladder's own address. The size
is now asked a second way when the first fails: a one-byte range request is an ordinary `GET`,
so any server that serves the file answers it, and `Content-Range` carries the total.

**Every link was labelled with the previous link's accessor.** The origins list was searched by
value instead of walked in step, so inserting the external HD address at the front shifted every
label by one — the report stayed plausible while naming the wrong thing. The two arrays are now
grown, shrunk and read together.

**Photos: `UIImage` was the only decoder, and its failure disabled the fallback that existed for
exactly that case.** When it returns nil, the JPEG re-encode and the plain-image paths were both
skipped and only the untouched bytes were offered — which is why 3302 came back after "three"
attempts. `CGImageSourceCreateWithData` reads formats `UIImage` declines, so the re-encode is now
reachable whenever anything can read the file at all. And the error line names which attempts
actually ran instead of implying all of them did.

## v0.14.3

**Read both reference tweaks' actual hook tables and closed what they cover and we did not.**

The watermark is answered at **both** ends now — the setter and the getter — which is what NA9
does, and the reason holds: the setter covers every reader of a stored value, but a value TikTok
never sets keeps whatever it decoded from the response.

TikTok's own two download-permission flags are forced open. NA9 hooks `-canDownload` and
`-isPreventDownload`; **neither exists on this build**. The real names here are `preventDownload`
and `disableDownload`, read from the app's own class metadata — the fourth time in this tweak
that a working reference's selectors turned out not to be ours.

## v0.14.2

**"Largest wins" was stamping a watermark on every download, and no measurement could have
caught it.** `downloadURL` and `h264DownloadURL` are TikTok's *watermarked* save copies and are
usually the biggest files on offer, while `downloadNoWatermarkURL` and the quality ladder's own
address are clean. Nothing in the HTTP response says which is which — only the accessor the link
came from knows, so that name now travels with the link. A clean video outranks a watermarked
one whatever the sizes say; size still decides between equals, and a watermarked video still
beats a link that would not identify itself.

**And the watermark decision is answered at its source.** `AWEAwemeACLItem.watermarkType` — the
property TikTok itself consults, confirmed in this build's own class metadata — is forced to
zero at its setter rather than at a getter, because the app reads that value by more than one
path and a stored zero is true for all of them. Settings › Status reports whether it attached
and how many decisions it cleared.

**The music is no longer a candidate.** One report recorded the resolved link as an `.mp3` from
TikTok's music CDN. Ordering by type kept it out of the actual save, but it should never have
been on the list: it made the diagnostics describe the wrong file, and a URL that says `.mp3` in
its own address needs no request to disprove.

## v0.14.1

**Two faults, both introduced by 0.14.0 itself, both caught by its own new report.**

**The measurement picked the music.** One video offered an `.mp4` whose server refused `HEAD`
(measured 0.0 MB) and an `.mp3` of 0.9 MB — and "largest wins" took the audio. The type was in
the same response the size came from and was thrown away. Kind now decides before size: a link
that answers as audio never wins however much bigger it is, one that answers as video wins over
one that will not say, and size only settles ties between videos. Refusing to answer `HEAD` is
not evidence of being the wrong thing, so an unmeasurable link still outranks a known audio one.

**A photo post saved a video.** TikTok renders a photo slideshow as a video too, so the video
links resolved first and the tap never reached the picture branch. Pictures are checked first
now, the same order the other entry point already used: a post that has pictures is a photo
post, whatever else it also carries.

## v0.14.0

**Quality stops being a guess about names and becomes a measurement.** Your report showed the
ladder holding a single `comet_lowest_540_1` where an earlier one held five gears up to 720 —
TikTok only populates the gears it is currently streaming, so preferring the ladder takes the
worse file exactly when the app has not fetched the better one. Preferring
`downloadNoWatermarkURL` instead would be the same mistake pointing the other way. Every link
the video model offers is now collected — the best gear, the two download copies, the play
URL — and each is measured with a `HEAD` request before saving. The largest file wins, and
Settings › Status prints what each one measured and which was taken. A link that will not
answer scores zero and sinks to the bottom rather than being dropped: a server that refuses
`HEAD` still serves `GET`.

**And an optional HD path through an outside service, off by default.** NA9's HD button has
been reliable for years for a reason that is not cleverness — it never touches TikTok's model
chain at all, so there was never an internal accessor in that path to break. It asks
`tikwm.com`, keyed by the post id.

That is a real trade and it is written into the switch's own row: turning it on tells a service
unrelated to TikTok and unrelated to this tweak which video you are watching, which is the exact
thing the three privacy switches beside it exist to stop. It is off unless you turn it on, it is
never the quiet default, and with it on the external link is measured against the internal ones
like any other candidate rather than being trusted because it is external.

## v0.13.5

**`PHPhotosErrorDomain 3302` is Photos refusing the format, not the download.** It arrived for
two pictures that `UIImage` had already decoded perfectly well, which rules out bad bytes — and
the cause is that data handed to Photos carries no file name, so the library has to guess the
type, and TikTok serves these as WebP, which it will not take. That is also why one post saved
and another did not: the criterion was never how the post was found, only what format its
pictures happened to be in.

A picture is now tried three ways and the report names the one that worked:

1. **the original bytes, with their own file name** — the only path that saves the picture
   exactly as posted, with no re-encoding;
2. **re-encoded as JPEG**, if Photos refuses the format — a real loss in quality, and worth
   taking over saving nothing;
3. the plain image request, which is what worked before any of this.

## v0.13.4

**A photo post asks which picture you meant.** A post of sixteen saved all sixteen without a
word, which is not what tapping a download button on one picture means. Tapping now offers the
picture on screen or the whole post — and which one is on screen is read from
`AWEPhotoAlbumModel.currentIndex`, the app's own record of the swipe, not guessed from the view.
With nothing to present the question from, it saves the one on screen: a whole post arriving
unasked is the complaint, and the rest is one more tap away.

**And it shows the same progress the video save does.** Photos were saving correctly with
nothing on screen to say so — which looks exactly like a button that does nothing. The pie HUD
now advances per picture and ends with "Saved N of M".

**720 was TikTok's ceiling, not a bad pick — and the ladder proved it.** A device report listed
`adapt_lower_720_1` as the top of five gears, so the picker was already taking the best on
offer. The same report showed the three quality lists are identical on this build, printing the
same five gears three times; they are still all read, but the ladder is deduplicated so the row
can be read at a glance.

## v0.13.3

**The report and the settings table were built from two separate lists, and the row asked for
by name was in only one of them.** The gear ladder added in 0.13.2 appeared in the table and
never in the copyable report — so a report sent to be read for it could not contain it. Both
new rows are in both places now.

**Photo posts resolve; the save was failing silently.** "saved 0 of 1" collapsed three
unrelated causes into one number: the download failing, the bytes arriving and not decoding,
and Photos refusing the write. Each is counted separately now and the first real error message
is kept. TikTok serves these as WebP and HEIC, so when `UIImage` cannot decode the bytes they
are handed to Photos as the original resource instead — which also keeps the file exactly as
posted rather than re-encoding it.

**Quality compares three ladders, not one.** `AWEVideoModel` declares `bitrateModels`,
`SDRBitrateModels` and `HDRBitrateModels`; only the first was ever read. A gear missing from one
list is not a gear the app does not have. All three are gathered and compared together, and the
report names which list the winner came from.

## v0.13.2

**Photo posts: the wrapper was right and the list accessor was not.** A photo post in this build
is an `AWEPhotoAlbumModel` reached through `-photoAlbum`, and its list is called `photos` —
0.13.1 reached the album correctly and then asked it for `images`, which is the *other*
container's name, so every post read as empty for a second release. The elements are
`AWEPhotoAlbumPhoto`, whose picture-as-posted is `originPhotoURL`; the thumbnail is tried last,
because saving a preview instead of a photo is the same mistake as saving SD.

**Quality now reports the whole ladder, not just the pick.** A download coming out at 720 has
two completely different causes — the picker chose wrong, or 720 was everything TikTok offered
for that video — and the saved file looks identical either way. Settings › Status now lists
every gear the app was handed, each with its own `gearName` and bitrate, and marks the one
taken. That is a fact about one video on one account, so it is reported rather than reasoned
about.

## v0.13.1

**Both new features in 0.13.0 were one wrong name each, and the binary settled both.**

HD never ran. The entries in `-bitrateModels` are `AWEVideoBSModel`, and that class calls its
rate **`bitrate`**, all lowercase — 0.13.0 asked for `bitRate`, every entry answered
`-respondsToSelector:` with NO, every one scored zero, and the comparison fell through to the
ordinary chain. `bitRate` is a real name in this binary; it belongs to `TTKECVideoBitModel`,
which is nowhere near the feed. A name existing and a name being answered are different facts,
and this is the third release in this project to pay for confusing them.

Photo posts found nothing. `AWEAwemeModel` has no `imagePostInfo` at all in this build — it
answers `-images` itself — and its entries are `AWEImageModel`, which is not a URL model and
has no `displayImage`. The links are one level further in, under `lightURLModel` /
`localURLModel` / `darkURLModel`, each an `AWEURLModel` with `originURLList`.

Neither was guessed at this time. `tools/objc-classes.py` reads the class metadata out of
MusicallyCore and prints what a class actually answers, so "is this selector on this class" is
a question the binary answers in one command instead of a release.

## v0.13.0

Three things asked for by name: the progress bar, HD, and photo posts.

**A seek bar under every video.** TikTok has one — `AWEFeedPlayerBottomProgressBar` — and
hides it, showing it only while you are dragging. The switch keeps it on screen: `-setHidden:`
is answered with `NO` and `-setAlpha:` refuses to fade it to nothing, so nothing has to be
drawn and nothing has to be positioned. On by default, with its own switch under Controls
and its own line in Status — which distinguishes "not in this build" from "switched off"
from "working", since only the first is a reason to change any code.

**Photo posts save as photos.** They were being ignored entirely: a photo post has no
`-video`, so every download chain here reported failure and the button had nothing to offer.
The images come from `imagePostInfo` → `images`/`imageList` → `displayImage` →
`originURLList`/`urlList`, and they are saved one at a time, each as its own entry in Photos,
with the result reported as "saved N of M" rather than as a single yes or no — a post of
twelve images where two fail is not a failed download.

**HD, and why it took two attempts.** Downloads were SD because `downloadNoWatermarkURL` is
one link and `bitrateModels` is a list of alternatives — the right one is *chosen* by
comparing them, and nothing here had ever compared anything. 0.12.0 tried and crashed the app.
Both of that release's mistakes are fixed as measurements rather than as guesses:

- **The type of `-bitRate` is asked for, not assumed.** `property_getAttributes` returns the
  real encoding — `q`, `d`, `@"NSNumber"` — and the value is read through a cast that matches
  it. An encoding this does not recognise scores zero instead of being guessed at, so an
  unreadable variant simply loses and the download still happens.
- **The ladder is read when the model is finished, not while it is being built.** There are
  two entry points now: `+captureModel:`, called from the aweme model's own `-init` hooks
  where `-video` is half-built and only the shallow chains are safe, and
  `+captureSettledModel:`, called by the feed cell's button for a model the app has finished
  with and is currently showing. "Is this object safe to walk" is a fact about the caller, so
  it is a second entry point and not a flag a future caller could answer wrongly.

If the ladder gives nothing, the ordinary chain runs exactly as it did in 0.12.1. A crash is
worse than SD; that rule has not moved.

## v0.12.1

**0.12.0 crashed TikTok. Reverted.**

The HD picker is gone entirely rather than patched, and the tweak is back to 0.11.0's
behaviour: the button appears on every video, in place, and saves the clip you are watching —
at whatever quality `downloadNoWatermarkURL` gives.

Two things in that reader could crash and I did not guard either properly:

- `-bitRate`'s **return type was assumed.** It was read through `objc_msgSend` cast to
  `long long`. If that property is a `double`, a `float` or an `NSNumber *`, the cast is
  undefined behaviour — the value arrives in a different register or is a pointer read as an
  integer. Nothing in the binary told me which it was, and I did not check.
- It ran during **model construction**. Resolution is driven from the aweme model's own
  `-init`, where `-video` is a half-built object. This repository's own rule says a `@try`
  does not make that safe, and reading a list of sub-objects off a partially initialised
  model is exactly the case that rule is about.

**A crash is worse than SD**, and shipping the fix for a quality complaint at the cost of the
app opening is not a trade worth making. HD comes back when the type is confirmed and the read
happens somewhere the model is finished — not before.

## v0.12.0

**HD: the best gear is chosen by comparing bitrates, not by taking the first one listed.**

0.11.0 fixed the last correctness problem — `AWEFeedCellViewController.model` gives the video
you are actually watching, and downloads are real videos of the right clip. What was left was
quality, and `bitrateModels` had been sitting in the video model's accessor list untouched
through four releases of chasing single URLs.

**A chain of named accessors cannot answer this question.** Every other step in the resolver
walks a path and takes the first thing it finds. `bitrateModels` is a *list of alternatives*
and the right one is chosen by **comparing** them — taking `.firstObject`, which is what the
generic walker does, yields whichever gear TikTok happened to list first, and that is the SD
copy as often as not. So it gets its own reader.

Each entry carries `-bitRate`, `-gearName`, `-qualityType` and its own `-playAddr`, all four
confirmed in TikTok 46.4.0's binary. The highest `-bitRate` wins and its address is read the
same way every other URL model is.

It is tried **ahead of** `downloadNoWatermarkURL`, which 0.11.0 settled on: that one is correct
about the *watermark* and says nothing about the size. And it goes into the same candidate list
as everything else rather than short-circuiting, so the downloader can still reject it if the
file turns out not to be a video — being the highest bitrate on offer is not a promise about
what is inside.

The report names the winner with its bitrate, so the next one says outright whether HD was
found and at what rate — and the byte count says whether it mattered.

## v0.11.0

**The cell is a container. The model belongs to the view controller it hosts.**

Unfiltering the accessor dump answered it in its first line:
`viewController, feedTableViewCellMaskView, interactionConfigClass, pageContext, parentVC,
… setupViewController, layoutViewController, _addChildVC, vcContainerView`.

`AWEFeedViewTemplateCell` has **no aweme accessor of its own** — which is why every name tried
on it answered nothing, through two releases of trying more names. The video is the
controller's, not the cell's.

And this is what NA9 had been saying from the first symbol dump: it hooks
`AWEAwemeBaseViewController$viewDidLoad` and `$viewDidAppear`, **not** the cell. Its button
lives on the cell and its model comes from the controller — two facts that only made sense
together, and I had been reading them apart.

The model is now looked for on the cell first and then on whatever controller it hosts, and the
report names which object and which accessor answered.

**One thing this does not fix, and the report already names it:**
`Photos refused: PHPhotosErrorDomain error 3302`. The link resolves and the file downloads;
Photos then rejects it. That is a different failure from the earlier ones and worth its own
look — `isCDNURLExpired` and `cdnURLExpiredTime` sit on the video model, so an expired CDN link
returning an error page rather than a video is the first thing to rule out.

## v0.10.1

**0.10.0 hid the button. That was mine, and it is restored.**

0.10.0 refused to fall back to the most recent capture, on the reasoning that saving the wrong
video is worse than saving none. That reasoning is sound about the *save*. It was applied to the
*button*: no accessor answered on this build, so the item was nil on every layout pass and
`hidden` was set on every pass. **A correct principle enforced in the wrong place removed a
working feature outright** — 0.9.0's button was visible and saved a real video, just not always
the right one, and 0.10.0 traded that for nothing at all.

The button is always visible now. The cell's own model is used when it can be found and the most
recent capture stands in when it cannot, and **the report says which of the two supplied it**, so
"saved the wrong clip" and "saved nothing" never look the same again.

**And the accessor dump could not have answered the question it was asked.** Unfiltering it
exposed a second bug: the match loop added a name only from *inside* the keyword loop, so an
empty keyword list meant the body never ran and every class came back empty. Asking for "no
filter" produced "no results" — the opposite of what it reads as. An empty filter now means
everything, and a class with nothing to show says so plainly.

That matters because the filtered list had already told us something and it was missed: it
returned UIKit and accessibility categories containing "item" or "data" and **nothing about a
video at all.** `AWEFeedViewTemplateCell` has no aweme accessor of its own. The model is reached
another way, and the next report — unfiltered, for real this time — is what will show which.

## v0.10.0

**Downloads work, and now they save the video you are actually watching.**

0.9.0's report was the first to say `saved to Photos — 1 video / 1 audio track(s), 1561847
bytes`. A real video, with a real audio track, after five releases of saving 972 KB of sound.
`downloadNoWatermarkURL` was the answer.

But it saved the *same* clip three times while something else was on screen, because the button
took `[SCITTMedia recent].firstObject` — whatever model TikTok had most recently built. During a
scroll that is a video being **preloaded**, not the one under your finger. The button was
correct about *a* video and wrong about *which*, which is exactly the Instagram carousel bug
fixed earlier the same day: assuming instead of asking.

The cell is the thing that knows. It is asked for its own model now, through whichever of
`awemeModel` / `aweme` / `model` / `currentAweme` / `itemModel` / `cellModel` it answers —
each behind `-respondsToSelector:`, and **the one that answered is printed in the report**, so
it never has to be guessed at again. A candidate that does not answer `-video` is rejected: a
property sharing the name is not a model.

**There is no fallback to "the most recent anything".** Saving the wrong video is worse than
saving none — one is a missing feature, the other hands you someone else's clip and looks like
it worked.

**The button sits above the profile picture now**, clear of the whole rail rather than among
like and comment.

And the diagnostic was dumping the wrong class. It asked `AWEFeedViewCell` while the feed uses
`AWEFeedViewTemplateCell`, which is why that list came back full of accessibility and layout
internals with nothing resembling a model in it. Three reports printed it before anyone noticed
it described a different object.

## v0.9.0

**The button goes on the feed cell now, which is where the working tweak puts its own.**

Dumping NA9's Logos symbols named the technique outright:
`AWEFeedViewTemplateCell$na9AddDownloadButton`. **Not the interaction rail.** And every symptom
the rail placement produced follows from being a guest in someone else's stack:

- it appeared on some videos and not others, because TikTok rebuilds the rail's arranged
  subviews and sweeps a guest out;
- it drifted sideways, because a vertical stack positions each child by its own width;
- it needed its size copied from its neighbours — and those neighbours turned out to be
  invisible background containers, not icons.

A cell hook has none of those. `-layoutSubviews` on the cell fires for **every video the feed
shows**, so the button cannot be missing from some of them, and its frame is one this code owns
outright rather than a slot in someone else's arrangement.

`AWEFeedViewTemplateCell` was confirmed present in TikTok 46.4.0 from the app's own binary, not
taken on trust from NA9 — whose `AWEFeedViewTemplateNewCell` is **not** in this build. A
reference tweak's class list is a map, not a manifest.

**Both surfaces ship, and they cannot both draw.** The rail hooks stay so a build missing the
cell class still gets a button, but the rail stands down the moment a cell button exists — two
buttons on one video is worse than either alone. The report counts them separately, so the next
one says which surface is actually doing the work.

The frame is recomputed from the cell's bounds on every pass, never from its own previous
value. That is the drifting-title bug from the panel's new row, made earlier the same day, and
not worth making twice.

Nothing about the download changed. That is the next problem, and it has its own answer waiting
in the same symbol dump: NA9 does not resolve URLs at all — it calls TikTok's own
`downloadVideo` on the cell.

## v0.8.1

**Three releases were aimed at a line that had not changed because nothing had happened.**

"Last save attempt: no candidate was a video — audio only, 972317 bytes" appeared *identically*
— same byte count, same media id — in the v0.7.0, v0.7.1 and v0.8.0 reports. It was read each
time as fresh evidence that the newest chain had just saved audio. It was a **stale record**:
no new attempt had been made at all, because the button was in the wrong place to be tapped.

That record now states its own age. A line from before the current build was installed can no
longer be mistaken for the last thing that ran, and "nothing saved yet" says *this launch*.

**The button was still leaning right, and the reason was the fix.** 0.8.0 constrained its
width to `reference.bounds.size.width` — and **bounds are zero at that moment**: the button is
created and constrained before the rail has ever been laid out. The width fell through to its
fallback and came out a square narrower than every icon beside it. The height had the same bug,
hidden because its fallback of 44 happened to look deliberate.

Both dimensions are now tied to the sibling's **anchors**, which resolve at layout time
whatever the order of construction, so there is no moment at which a size can be read that
does not exist yet.

**And the rail report was conflating two stacks.** Both hooked stack views write into one
string, so "appended at end" and the rail contents printed beside it could come from different
objects — which is exactly how a report shows a rail containing `PlayInteractionLikeView`
while also saying the anchor search found nothing. The rail line now names which stack it
describes.

## v0.8.0

**The device printed `AWEVideoModel`'s own accessors, and that answered both open questions.**

`downloadAddr` — guessed at twice, once from NA9's binary and once from a framework-wide
selector dump — **is not on that class at all.** A selector list taken across 785 MB says a
name exists *somewhere*; it never says on what. One line from the device settled what two
rounds of reading binaries could not.

What is actually there:

```
downloadNoWatermarkURL   download quality, no watermark
downloadURL              download quality
h264DownloadURL          codec-named download
bitrateModels            the HD ladder (plus HDR/SDR variants)
audioBitrateModels       a separate audio ladder
playURL                  the streaming URL — what this tweak had been using
playLowBitURL            named for exactly what it is
```

`downloadNoWatermarkURL` and `downloadURL` now lead the chain. `playURL` stays as a
fallback, where it belongs: it is what the app *streams*.

And `audioBitrateModels` sitting right beside the video ones is the shape of the
"972317 bytes of `audio/mp4`" this kept saving — the model carries separate audio lists, so a
URL chosen without regard to which list it came from can easily be the sound.

**The button leaning far to the right was a sizing bug, not a placement one.** Only its
height was matched to the rail. A vertical stack whose alignment is not `.fill` positions each
arranged subview by its own width, so a button sized from its glyph sat at a different
horizontal offset from every icon around it. Both dimensions now come from a sibling, and the
glyph is centred inside them.

Still open: the button appearing on some videos and not others. `2 placed` against 164 feed
items seen, and the rail is rebuilt per cell — but that is being left to a measurement rather
than a third guess.

## v0.7.1

**The button was being placed between two background views.** A device report dumped what
the rail actually holds:

```
TTKRightInteractionAreaBackgroundView | TikTokFeedInteractionBiz.PlayInteractionLikeView
| TTKRightInteractionAreaBackgroundView x4
```

Most of that rail is **not buttons**. The interactive elements are `PlayInteraction*` views
(Swift, module `TikTokFeedInteractionBiz`); the rest are background containers. Inserting
"one before last" therefore dropped the save button between two backgrounds — which is
precisely the "not centred, not aligned with the icons" that was reported, and no amount of
sizing could have fixed it, because the neighbours it was sized against are not icons.

It is now inserted directly after the last view whose class names an interaction. A rail with
none keeps the old behaviour rather than getting a newly invented one.

**And the audio problem gets measured rather than guessed at a second time.** The report says
resolution succeeds via `AWEVideoModel.playURL.originURLList` *and* that the saved file is
972317 bytes of `audio/mp4`. Both are true, which means the link that resolves is not the
video. Every accessor list in this report so far belongs to the **aweme** model — the video
model's own has never been printed, and that is the list that would name the right URL.

TikTok 46.4.0's framework does contain `downloadAddr`, `playAddr`, `playAddrH264`,
`bitrateModels`, `HDRBitrateModels` and `SDRBitrateModels`; a selector dump is global, so it
cannot say which are on `AWEVideoModel`. Trying `downloadAddr` first was the obvious guess and
it did not win. So Diagnostics now prints `AWEVideoModel`'s own URL-bearing accessors, and the
next report answers it outright.

## v0.7.0

**The download chain was mostly dead, and the app's own binary said so.**

The owner supplied the full TikTok 46.4.0 IPA — decrypted, `cryptid 0`. TikTok's classes are
not in its executable (91 KB), the same way X's are not in X's: they live in
`MusicallyCore.framework`, 785 MB and **1,032,816 selectors**. Dumping `__objc_methname` out
of it settled in one pass what three releases of guessing could not.

**Three assumptions died:**

- **`bestURLtoDownload` is not in this build at all** — and it was the first choice of nearly
  every chain in this file. Seven chains have therefore been dead for as long as they have
  existed, skipped silently, because a chain whose selector is absent looks exactly like a
  chain that was tried and found nothing.
- **`bitratePlayURL` is not there either** — which 0.6.2 added an hour earlier as *the* HD
  fix, taken from NA9's binary. NA9 was built against an older TikTok. Reading a working
  tweak's selectors is not confirming they exist in your build; that is precisely the trap
  the X tweak's dead immersive class was, made twice in one day.
- `bestURLtoDownloadFormat` and `downloadHDVideo:`, from the same source, are absent too.

**What actually exists is a real quality ladder, and "it saves SD" was one word all along:**

```
video.downloadAddr    the DOWNLOAD address
video.playAddrH264    codec-named playback address
video.playAddr        generic playback address
```

`playAddr` is what the app *streams*, served at a bitrate chosen for smooth playback.
`downloadAddr` is what TikTok serves for saving. Nothing in this file had ever asked for it.
Each ends in a URL model whose confirmed accessors are `originURLList`, `urlList` and
`URLList` — never `bestURLtoDownload`.

Also confirmed present and worth a later release: `bitrateModels` (variants carrying
`-bitRate`, `-gearName`, `-qualityType` and their own `-playAddr`), `HDRBitrateModels`,
`SDRBitrateModels`, and `allowDownloadWithoutWatermark`.

Still **not** fixed, and named so they are not read as done: the button appearing on some
videos and not others, and the wrong video being saved.

## v0.6.2

**A one-letter bug, and the first real attempt at HD.**

A live property dump from a device settled both.

**`downloadInfoModel` has a capital I.** Two candidate chains have read
`downloadinfoModel` for as long as they have existed. Selectors are case-sensitive, so
`-respondsToSelector:` answered NO every time and the chain moved past the one object on the
model whose entire purpose is download information — silently, because a skipped chain looks
exactly like a chain that was tried and had nothing.

**`playURL` is the playback URL, which is why downloads came out SD.** It is what the app
streams from, served at a bitrate chosen for smooth playback rather than for the best copy.
NA9's binary carries `bitratePlayURL`, `bestURLtoDownloadFormat` and `downloadHDVideo:` —
**none of which this chain had ever asked for.** `bitratePlayURL` names a *set* of variants
rather than one stream, and is now tried ahead of `playURL`.

**Which entry of that set is the best one is not yet known.** The array picker takes the
first, as it does everywhere in this file, and the diagnostics line naming the resolved chain
is what will say whether this is the HD copy or just a different one. Measure, then choose.

Also corrected: a comment claiming `-playURIString` and `-URLList` are "gone". They are
not — the device dump lists both. They were dropped for resolving the song rather than the
video, which is a different fact and worth stating as the true one.

Two known problems are **not** addressed here and are named so they are not mistaken for
fixed: the button appearing on some videos and not others, which has the signature of the
arranged-subview rebuild that cost the X tweak five releases; and the wrong video being
saved, which is the same shape as the Instagram carousel bug — resolving from a remembered
model instead of asking which cell is on screen.

## v0.6.1

Asked directly how the two reference tweaks pin their own button. The answer is short
and it explains both remaining complaints.

**What they hook on the rail:**

| | NA9 | VibeTok |
|---|---|---|
| `-layoutSubviews` | yes | yes |
| `-didMoveToWindow` | yes | — |
| `-setHidden:` | **yes** | — |
| `-setAlpha:` | **yes** | — |

`-setHidden:` and `-setAlpha:` are the two this project never had, and a tweak has no
reason to hook them unless its button's visibility must be **kept in step with the
rail's own**. TikTok hides and fades that rail constantly — while a comment sheet is
open, during a long-press, whenever the UI gets out of the video's way. A button that
does not follow those transitions is one that is sometimes there and sometimes not for
no reason the user can see. That is the "doesn't show on every video" report: it was
never a placement failure, it was the app's own behaviour going unmirrored. Both are
hooked now, propagating hidden/alpha onto the button on every change.

**And the tilt was a sizing bug, not a centring one — which is why three attempts at
the centring never touched it.** v0.5.0 moved the glyph out of the button's own `image`
into a subview held only by `centerXAnchor`/`centerYAnchor`. That leaves the button with
**no intrinsic content size at all**, so in a stack whose alignment is not `fill` it is
laid out at zero width — and a glyph centred on a zero-width button hangs off the edge
of it. The glyph is now pinned to all four of the button's edges instead, which gives
the button the image's own intrinsic size and makes it measure correctly under any
alignment, with `UIViewContentModeCenter` keeping the artwork unstretched.

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
