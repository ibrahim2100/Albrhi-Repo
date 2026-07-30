# Albrhi for YouTube — Changelog

**Tested on YouTube 21.30.5.** Nothing is pinned to a version number: every class the
tweak touches is looked up at runtime and skipped if it is not there.

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
