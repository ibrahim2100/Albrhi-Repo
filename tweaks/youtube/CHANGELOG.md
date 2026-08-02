# Albrhi for YouTube — Changelog

**Tested on YouTube 21.30.5.** Nothing is pinned to a version number: every class the
tweak touches is looked up at runtime and skipped if it is not there.

## v0.8.4

- Includes the crash fix from 0.8.3, which never had a chance to be installed.
- **Looks for the video's formats in five more places.** Comparing against DLEasy — whose
  downloading works — showed it reaching them by different names than the two tweaks
  looked at before it. None of the names is guaranteed to be the right one on your build,
  so all of them are tried, and the report says which one actually answered.
- That is the useful part: rather than another guess, the next report will name the exact
  step where the search succeeds or stops.

**What is now known for certain**, from the fixed measurement in 0.8.2 and 0.8.3:

- The streams the app keeps for *playback* carry no download link. Not under any name, and
  not in the format details nested inside them. That question is closed.
- Asking YouTube directly over the network is refused: two identities rejected outright,
  two others answered properly and said the video was unavailable to them.
- Which leaves the player's own response — the one place that has never yet been reached
  without something failing first. This release is about reaching it.

## v0.8.3

- **Fixes the crash in 0.8.2.** Install this over it. Holding a video to save it took
  YouTube down, and that was a mistake I introduced in the previous release.
- Reading a format's number — its quality id, its height, its bitrate — went down a path
  that only works for text. The number came back as though it were an object, and the very
  next step treated it as one. It happened on the first field of the first format, so it
  crashed every time.
- The previous code read these correctly. Changing it was an optimisation nothing had
  asked for, applied where the answer's type is not known in advance.
- **And the search can no longer take the app down at all**, whatever goes wrong in it —
  the same rule the settings screen has followed since 0.1.4. A tool whose job is to
  explain what is happening must not be the reason the app stops.
- One thing the fixed report did settle: the streams the app holds for playback really do
  carry no download link, under any name. That was previously a guess from a broken
  measurement; it is now measured. What remains is the other place, which the crash
  prevented from ever being reached.

## v0.8.2

- **The diagnostics page has been misleading me for four releases, and this fixes it.**

- When it listed what each stream offered, it asked for the link under eleven different
  names — and stopped at the first one that answered anything at all. The first name
  answers with `?cpn=…`, a fragment rather than a link, so it printed that and **never
  tried the other ten, not once**. "There is no link anywhere in the app" was a conclusion
  drawn from a list of one name.

- Everything since 0.7.0 followed from that: asking YouTube over the network, four
  borrowed client identities, and all of it refused. None of that work was wrong, but it
  was answering a question that had never actually been asked properly.

- So: the report now lists **every** name that answers, and the search for something to
  download reads every name too, plus the format nested inside — taking the first that is
  genuinely a link rather than the first that replies.

- The source written off as a dead end in 0.8.0 is back in the search, for the same
  reason: it was written off on the strength of that same one-name probe.

- Comparing against **YouMod** by Tonwalter888 is what surfaced this. It reads exactly the
  same places this tweak does — it makes no network request at all — and the only
  difference was that it falls through to the next name where this one stopped.

## v0.8.1

- **The report now says what happened when it looked inside the app**, which 0.8.0 left
  out entirely. It recorded that path only when it worked, so a failure left no line at
  all and the report jumped straight to the network attempts — reading as though the app
  had never been asked.
- Three completely different outcomes were indistinguishable: the search stopping early,
  the app holding formats with no links, and it holding formats in codecs iOS cannot play.
  Each step is now named with what it actually returned.
- **A third place to look**, at no cost: the player response the video overlay is handed,
  which this tweak has been holding for the report since its first release and never read
  when searching for something to download.
- The four attempts in 0.7.3 all came back refused, and their messages are now specific
  enough to be worth reading: two were rejected outright, and two answered properly but
  said the video was unavailable *to them*. That is the request being understood and
  declined, which is different from it being malformed — the headers added in 0.7.3 did
  their job.

## v0.8.0

- **The links were in the app the whole time, in a place nobody had looked.**

- Everything so far read one source: the media layer's streaming data, whose streams
  answer with `?cpn=…` instead of a link because that layer fetches byte ranges rather
  than files. That is a genuine dead end — there is nothing in it to find, which is why
  every probe came back empty and why 0.7.0 went looking on the network instead.

- But the app holds a *second* set of streams for the same video. The player keeps its own
  player response, and inside it the formats do carry links. Same app, same video, a
  different object graph, and seven releases went past it.

- So the player is asked first now. When it has the formats, **nothing is asked of YouTube
  at all** — no request, no borrowed client identity, nothing that can stop working when
  Google changes something. The network path stays as a fallback for when it does not.

- The `HTTP 403` and `HTTP 400` from 0.7.3 are still worth having fixed, and that work
  stays: better headers, four client identities, and the server's own error message in the
  report rather than a bare status code. It is just no longer the first thing tried.

- Found by reading **YouMod** by Tonwalter888 (GPLv3, as this is), which reads both sources
  and takes whichever answers. Every selector was then checked against a real 21.30.5
  binary before being used — the credit is in the code and in the package description too.

## v0.7.3

- **Asking for the video id was fixed in 0.7.2 and it worked** — the request now goes out
  for the video actually on screen. YouTube refused it anyway, with two different errors,
  and 0.7.2 reported only the numbers: `HTTP 403` and `HTTP 400`.
- **The report now shows what the server said**, not just the status. YouTube explains a
  refusal in the reply, and throwing that away meant a report that said the wall was hit
  without saying which wall.
- The request was also missing headers YouTube expects. It declared which client it was
  in the body but not in the headers, and the server checks both — which is what an
  `HTTP 400` on an otherwise well-formed request means.
- **Two more client identities to fall back on**, both embedded-player ones. Those tend to
  outlive the rest, because a page embedding a video has to be served something. The two
  in 0.7.2 came from a tweak whose build predates whatever changed at YouTube's end.
- The report lists one round of attempts instead of every press stacked up.

**Being straight about this:** downloading from YouTube is an arms race, and this release
is a move in it, not a settlement. If these four are refused too, the report will now say
precisely why — and the answer may be that this route is closed and the one worth taking
is YouTube's own download machinery, which is already on the device and already knows how
to fetch these streams.

## v0.7.2

- Fixes the build of 0.7.1, which never shipped: the diagnostics header promised three
  things the code behind it did not have. Everything 0.7.1 describes is in this one.

## v0.7.1

- **The download was asking YouTube about the wrong video.** A report made it plain:
  SponsorBlock was working on one video id while the diagnostics page reported a different
  one as the last played. The download used the second — so it asked YouTube for a video
  nobody was watching, and reported back that it was private or blocked. It was neither.
- The cause: YouTube builds a video object for each clip it *preloads*, not only the one
  on screen, so "the last one made" is not "the one playing". The download now uses the
  video the player actually started, which is the same one SponsorBlock has been using
  correctly all along.
- The diagnostics page prints both ids when they disagree, so this cannot hide again.
- And it now lists every attempt to fetch formats — which client was asked, and what it
  answered. "No downloadable formats" covered a client being refused, a client answering
  without links, and a client never replying; those need different fixes and now they read
  differently.

## v0.7.0

- **Downloading works.** This is the release the last six were leading to.

- The reason it did not work before is worth writing down. Every format the app was
  holding had no link on it — just `?cpn=…`, a fragment. Four of them were in H.264, which
  iOS plays perfectly well, so the codec was never the problem: YouTube 21.30.5 simply is
  not given file links any more. It streams in pieces, asking for ranges. Nothing this
  tweak could read out of the app was ever going to produce a downloadable file.

- So it asks YouTube directly instead, the same way every working YouTube downloader does:
  a fresh request for the video's formats, made as one of the clients that is still served
  plain links. Those come back ready to fetch, and the rest of the pipeline — pick a
  quality, fetch, join picture and sound, save — already worked.

- **What that means for privacy, plainly:** the video's id goes to YouTube. Not to anyone
  else, on the same connection, for the video it is already streaming to your phone a
  second earlier. That is a different thing from the SponsorBlock lookup, which is asked
  by fingerprint precisely so a *third party* cannot learn what you are watching.

- When YouTube refuses a video — private, age restricted, blocked in your country — the
  message now says which, in YouTube's own words rather than a guess.

- No extra weight. A well-known tweak does this by carrying a 25 MB media library to join
  the audio and video back together; this joins them with what iOS already has, which is
  possible because the formats are filtered to the codecs iOS can handle in the first
  place.

## v0.6.1

- **Holding the video works now.** In 0.6.0 the gesture was added and never fired once.
  A gesture added to a view in an app that already has its own does not simply share the
  screen with them — iOS lets one win, and YouTube's player is covered in them. Ours lost
  every time, silently, which looks exactly like a gesture that was never added.
- **The "nothing to save" message was misleading, and this is the important part.** A
  report showed twelve formats: eight in codecs iOS cannot play, and **four in H.264,
  which it can**. The message said "all in a codec iOS will not play", because eight is
  more than four. What was actually stopping the download is that those four carried no
  link to fetch.
- So the message now names the wall that blocks the formats that would otherwise work,
  not the one that happens to affect the most of them.
- The diagnostics page now also opens up what is nested inside each stream, which is the
  one place a link could still be hiding. If it is not there either, then this build of
  YouTube hands out no file links at all — and that is worth knowing for certain rather
  than assuming, because it decides whether downloading is a small feature or a different
  project entirely.

## v0.6.0

- **Hold the video to save it.** No need to open settings first. The settings row is
  still there, but nobody opens a settings screen to save the thing they are watching.
  One finger, a little over half a second, and the gesture never swallows a touch — tap
  to pause, scrubbing and YouTube's own hold-to-speed all keep working.

- **Audio on its own.** Last entry in the quality list. It saves to Files rather than
  Photos, because Photos refuses audio, and the share sheet opens on it so it can go
  into Files, Music or a message in one step.

- **"Nothing to download" now says why.** It stood for three completely different
  situations: no stream information yet, formats with no link to fetch, and formats in a
  codec iOS cannot play. Each gets its own sentence now, and the codec one names the
  format numbers — so a report of this actually says what to do about it.

- Fixes, all found reading the 0.5.0 code rather than on a device:
  - Every download that had to merge audio left **both source files behind** — tens of
    megabytes each, per download. Only the merged file was ever cleaned up.
  - **"Saved without sound" never appeared.** The message was built and then discarded,
    so a silent file was always reported as a clean save.
  - The **"Saving…" alert could stick on screen with no buttons**, needing YouTube to be
    force-quit. Dismissing an alert that is still animating in is ignored by iOS, and a
    link that would not parse triggered exactly that, every time.
  - A **failed merge was reported as success** — you got a silent video and were told it
    saved fine. Neither track insertion was checked at all.
  - The **SponsorBlock markers were rebuilt on every layout pass** of the player bar,
    which runs constantly during playback. They now redraw when something actually
    changes.

- **Next:** the download centre — a list of what you have saved, with the audio player
  and gallery inside the app. Deliberately after this release: a centre for a downloader
  that cannot yet produce a file on your build would be building the hard half first, and
  the message above is what tells us which half is hard.

## v0.5.0

- **Downloads.** Open the panel over a video and there is a row that saves it to Photos,
  at the quality you pick, up to 1080p60.

- **No button is added to YouTube.** Every other tweak that does this puts one in the
  player controls, which means hooking view classes that get renamed between releases —
  the survey behind 0.1.3 found nineteen dead class names in one such tweak. The row
  lives in our own panel, which cannot go stale, and it acts on the video the player is
  already holding.

- Above 360p YouTube sends picture and sound as separate files. Both are fetched and
  joined on the device with AVFoundation; because only H.264 and AAC are offered in the
  list, the join is a copy rather than a re-encode, and no FFmpeg is carried to do it.
  If the sound cannot be fetched, the silent file is still saved and the message says so
  rather than pretending.

- Only formats iOS can actually play are offered, chosen by itag rather than by MIME
  type: YouTube serves VP9 and AV1 in containers that download happily and then show a
  black frame.

- The diagnostics page gains a "Saveable" line, so a video that offers nothing says so
  before you try.

_Method derived from [YouMod](https://github.com/Tonwalter888/YouMod) by Tonwalter888
(GPLv3): where the format list lives, that the real link hangs off the stream's nested
formatStream rather than the stream itself, the itag sets, and the query handling that
makes a link fetchable at full speed. Those cost that project real time to work out._

## v0.4.5

- **The streams section, asked properly this time.** 0.4.4 got the ladder — 22 formats,
  itags, resolutions up to 1080p60 — and then failed on the three things that matter
  next. It listed what a stream "offers" by reading only its own class, and the
  accessors are on the superclass, so it printed nothing at all. It printed the type as
  an address, because MIMEType is a wrapper rather than a string. And it reported the
  URL as `?cpn=…`, a query fragment, without saying which of the possible names that
  came from.

  All three are fixed: the class chain is walked, wrapped values are unwrapped, and
  eleven names a stream might keep a real link under are tried with the answering one
  printed beside it. Whether this build hands out fetchable links is the one question
  standing between here and downloads.

## v0.4.4

- **The diagnostics page opens.** 0.4.3 guessed at why it crashed and guessed wrong —
  it was not the size of the report. The copy button was held only by a weak reference,
  so nothing retained it and it was released before the next line ran; the layout then
  tried to pin the text view to an anchor that was gone, and the exception said so in
  a way that reads like nonsense until you know that. The guard added in 0.4.3 is what
  printed it. It is held properly now.

- **The streams section finally says something.** It printed `<MLStreamingData: 0x…>`
  and nothing else, because that class is not a protobuf and does not describe itself.
  Every format list it carries is now enumerated — itag, type, resolution, frame rate,
  bitrate, and whether there is a plain URL — and if none answers, the report lists what
  the object can be asked instead, from the runtime rather than from guesswork.

  This is the measurement the download feature has been waiting on since 0.1.0.

## v0.4.3

- **The diagnostics page no longer takes YouTube down when opened.** It printed the
  whole player response — a protobuf rendered as text, hundreds of kilobytes on a
  real video — into a single text view. The page now shows the first 40 KB and says
  where it stopped; the file on disk still holds all of it, and the copy button still
  copies the lot.

  The page is also wrapped now, the way the settings panel around it always was. It
  was the one part left unguarded, which is a poor place for the exception to be: a
  page whose job is to explain a failure must never be one.

  Worth saying plainly: this is why the download feature is still "being measured".
  The measurement was written to a page nobody could open.

## v0.4.2

- **The package page, actually readable this time.** 0.4.1 gave Sileo a page but
  filled its What's New tab with the changelog pasted in whole — and Sileo does not
  render headings, so it came out as a literal `## v0.4.1` on top of a wall of prose.
  Each version is now a heading of its own with its changes listed under it, one line
  each. The reasoning stays in this file, where there is room for it.

- The description is shorter and no longer drawn with block characters, which not
  every font has.

## v0.4.1

- **A proper package page.** Sileo had nothing to render but the raw description
  field — a wall of prose, where the Instagram package has a tabbed page with
  headings and a changelog. It has one of its own now: what each feature does, what
  it was tested against, and who is credited.

  Nothing in the tweak changed. The generator that writes Instagram's page simply
  had Instagram written into it, so this taught it the difference between the two
  rather than adding a second script to keep in sync with the first.

## v0.4.0

- **The coloured markers, which 0.3.0 said were not ready.** Each segment is now drawn
  on the progress bar in its SponsorBlock colour, so what is coming is visible before it
  arrives. Its own switch, under SponsorBlock.

  This is the only place the tweak hooks a view, and the reason it is safe now is not
  courage: the markers are laid out with **frames, never constraints**. The layout engine
  is what took 0.1.1 and 0.1.3 down, and a rectangle at start ÷ duration × width does not
  need it. Drawing is wrapped as well — a fault there costs the colours, never the video.

  All three bar classes are hooked, because which one a build renders cannot be read off
  the binary, and the diagnostics page now says which one was found.

- **Credit where it is owed.** The markers are derived from
  [iSponsorBlock](https://github.com/Galactic-Dev/iSponsorBlock) by Galactic Dev, which
  is GPLv3 as this is: the bar class names, the placement arithmetic, and the detail that
  they must be redrawn the moment segments arrive rather than only on layout — which is
  what makes them appear at all, and would have cost several builds to find by trial.
  Credited in the settings screen and the package description as the licence requires.

- Reading the video's identifier no longer depends on one accessor: the video object is
  asked first, then the player controller, which is where iSponsorBlock reads it.

## v0.3.1

- **Fixes skipping, which never once worked in 0.3.0.** The feature asked the video
  object for its identifier under four names, and the one this build actually uses was
  not among them — so every lookup came back empty and the tweak returned before it had
  asked SponsorBlock for anything. Nothing was broken downstream; nothing downstream
  ever ran.

  The right name was already in this repository: the diagnostics page has been reading
  it since 0.1.0, having measured it rather than assumed it. That is the whole lesson
  again, one level down — a class name copied from another project is a lead and not a
  fact, and so is an accessor name.

- **And the report now says which of the three it was.** "Nothing was skipped" looked
  identical whether the ID could not be read, no segments matched your categories, or a
  skip happened and you missed it. The SponsorBlock line names it.

## v0.3.0

- **Skips the sponsored parts.** Paid plugs, the creator's own promotion, and subscribe
  reminders are jumped over automatically, using segments other viewers submitted to
  SponsorBlock. A short line at the top names what was skipped and offers an undo, so a
  wrong segment costs one tap rather than a rewind.

- **Eight categories, each with its own switch.** Sponsor, self-promotion and subscribe
  reminders are on. Intros, endcards, recaps, tangents and non-music sections are off
  until you turn them on — somebody chose to make that content, and deciding for you
  that it is worthless is not this tweak's call.

- **Your video is never sent.** SponsorBlock offers two ways to ask, and this uses the
  one that sends only the first four characters of the video's fingerprint — so the
  reply covers many videos and the server cannot tell which one you are watching. The
  other way is simpler and would report every video you play to a third party, which for
  a tweak with a privacy half would have been a strange thing to do.

  The cost is paid here instead: that endpoint returns the raw submissions rather than
  the server's curated pick, so downvoted and non-skip segments are filtered on the
  phone.

- Nothing is requested at all when the feature is off, or when every category is off.
  Not requested and discarded — not requested.

- Segment data is from SponsorBlock (sponsor.ajay.app), licensed CC BY-NC-SA 4.0 and
  credited in the settings screen. That is a licence condition, not a courtesy.

- **Not yet:** the coloured markers on the progress bar. Those need a hook on a view
  rather than the player, and views are where this tweak's earlier crashes came from —
  it will come once it can be done without risking the skipping that already works.

## v0.2.0

- **No ads.** Blocked at three separate points, because ads arrive by three separate
  routes and stopping one does nothing about the others: the app stops asking YouTube
  for ads at all, promoted rows are dropped out of the feed, and the player refuses ads
  before a video, mid-video, and the kind stitched into the stream itself.

  The feed filter matches on the identifiers YouTube's own servers attach to promoted
  rows — including plain-sounding layouts with no "ad" in the name, which are the ones a
  hand-written list always misses.

- **Background playback.** Audio keeps going when you leave the app or lock the screen.

- **Silence the update prompt**, since updating YouTube replaces the app and removes
  this tweak. And optionally hide the paid-promotion banner — off by default, because
  it is a disclosure and removing one for everybody is not this tweak's call.

- **A real settings screen at last.** Hold two fingers anywhere in YouTube. Sections,
  switches, Arabic and English with right-to-left layout, and a card at the top that
  says whether everything actually attached to *your* build instead of leaving you to
  wonder.

  Built on a standard grouped table this time. Three releases in a row either failed to
  appear or crashed, the last one inside the layout engine while assembling a panel out
  of hand-written constraints. A table has almost none of that surface — the system does
  the layout.

- Ad hiding, background playback and the update prompt are **on by default**; they are
  why you would install this.

## v0.1.4

- **Fixes the crash when opening the panel in 0.1.3.** Install this over it.
- The cause was in the panel's own layout, and the honest version is that the crash
  report could not point at the exact line. So this release does not guess at one — it
  removes the room for the mistake instead. Each row now has a single fixed height set
  in one place, where three different things used to be sizing it at once.
- **And the panel can no longer take YouTube down at all.** Building it is now wrapped:
  if anything in it goes wrong, the panel simply does not open and the report says what
  happened, under "The panel could not be built". A tool whose job is to explain what is
  going on must never be the reason the app dies — that was true of 0.1.1 and 0.1.3 and
  it is now enforced rather than intended.
- Nothing else changed. The report still writes itself to
  `Documents/AlbrhiYT-report.txt` at launch and on every video, so it is readable whether
  or not the panel opens.

## v0.1.3

- **The panel is back, and it is ours.** Hold **two fingers anywhere in YouTube** for
  about half a second and it opens. Inside: verbose logging, and the diagnostics report.
- Why not inside YouTube's own settings, after two goes at it? Because the crash report
  from 0.1.1 named the exact reason, and it is not fixable by trying harder: putting a
  section there means satisfying a contract with tables the tweak has no access to. The
  tweak that this project studied for its hook points does not do it either — it carries
  its own panel. That is the right shape, not a workaround.
- A survey of that tweak's targets also found **nineteen class names it uses that do not
  exist in YouTube 21.30.5 at all** — including the obvious place to hang an entry point.
  So this one hangs off `UIWindow`, which is part of iOS and cannot go missing.
- **Two fingers, not one**, so it never fights YouTube's own long presses — on a video,
  in comments, on the player. And the gesture never swallows a touch: everything under
  it keeps working exactly as before.
- The report is still written to `Documents/AlbrhiYT-report.txt` as well, at launch and
  on every video. The panel is now a second way to reach it, not the only way.

## v0.1.2

- **Fixes the crash when opening YouTube's settings in 0.1.1.** Install this over it.
- The cause: 0.1.1 added a settings section of its own, and a section is not something
  a tweak can simply announce. YouTube looks the new entry up in its own tables for a
  title, an icon and a page identifier — and an entry those tables have never heard of
  is not an empty row, it is a crash.
- So the section is gone again for now, and will come back once the rest of what
  YouTube expects is known rather than assumed. A settings panel that stops the app
  opening its settings is worse than no panel.
- **The report is unaffected**, because it never depended on the panel: it is written
  to `Documents/AlbrhiYT-report.txt` inside YouTube's own folder, at launch and
  whenever a video plays. That is the whole purpose of these early versions and it
  still works.
- The report now also lists YouTube's settings groups with the number each one carries,
  which is exactly what the next attempt needs — measured from your build instead of
  guessed at twice more.

## v0.1.1

- **The Albrhi section now actually appears in YouTube's settings.** In 0.1.0 it did
  not, and the reason is worth writing down: YouTube 21.30.5 builds its settings screen
  out of *groups*, and the list 0.1.0 added itself to is a different, older list that
  the screen no longer reads. The category was added somewhere nobody looks.

  It is now added to the group list the screen is genuinely built from, and which group
  is decided by asking YouTube rather than by picking a number and hoping.

- **The report no longer hides inside the thing that can fail.** 0.1.0 put the only way
  of finding out what went wrong behind the settings section — so when that section did
  not appear, there was nothing to read. The report is now also written to a file inside
  YouTube's own folder (`Documents/AlbrhiYT-report.txt`), refreshed at launch and
  whenever a video plays, and the tweak logs one line at launch saying it loaded.

- The report also lists the settings groups YouTube built, with their names and numbers,
  so a future version that reorders them says so instead of quietly vanishing again.

## v0.1.0

- **First release, and deliberately small.** It adds an *Albrhi* section to YouTube's
  own settings, with two things in it: verbose logging, and a diagnostics page.
- **Nothing about YouTube changes.** No downloads, no ad removal, nothing touched in
  the player. Installing this and using YouTube should feel exactly as it did before —
  if it does not, that is a bug worth reporting.
- **The diagnostics page is the point.** Play a video, then open it: it prints
  everything YouTube told the app about that video — every quality, every format,
  every stream — and copies the lot with one tap.

  That report is what the download feature will be built on. Downloading from YouTube
  is not a matter of grabbing a link, and which of the possible routes is actually
  open cannot be read off the app from the outside. It has to be measured on a real
  phone, on a real video. Guessing instead is how the Instagram quality picker took
  three attempts.
