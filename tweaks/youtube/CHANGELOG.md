# Albrhi for YouTube — Changelog

**Tested on YouTube 21.30.5.** Nothing is pinned to a version number: every class the
tweak touches is looked up at runtime and skipped if it is not there.

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
