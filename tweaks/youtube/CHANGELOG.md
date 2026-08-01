# Albrhi for YouTube — Changelog

**Tested on YouTube 21.30.5.** Nothing is pinned to a version number: every class the
tweak touches is looked up at runtime and skipped if it is not there.

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
