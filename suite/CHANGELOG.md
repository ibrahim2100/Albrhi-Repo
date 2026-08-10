# Albrhi Changelog

## v1.1.0

**A third app: X.** Albrhi now patches X too, and it arrived the way this package was
built to let things arrive — inside it. Nothing extra to install, and it is already in
the list in Settings › Albrhi with its own switch.

**What the X tweak does.** X decides what your app is allowed to show from one place: a
list of switches every part of the app asks before doing anything. This tweak sits at
that one place. It shows you every switch your copy of X really asked about while you
were using it, what X answered, and how often it asked — and lets you answer any of them
yourself.

**Hold two fingers anywhere in X** to open it. There is a search box, a filter for the
ones you changed, one button to undo all your answers, and a report you can save to the
Files app.

Nothing on that list is guessed. It is what your own phone saw, which is the point: what
it reports is what decides which switches the next release turns on by name.

Includes the X tweak 0.1.0.


## v1.0.12

**Settings › Albrhi: the blanks are filled in.** "Made by" and every other value on the
page were empty, the version shown was the panel component's number rather than the
Albrhi you installed, and the Versions section could vanish instead of admitting it did
not know. All three are fixed.

**And a Respring button**, at the bottom of the page, behind a confirmation.

Includes Panel 0.6.1.


## v1.0.11

**Settings › Albrhi has a face.** The Albrhi mark, the name and the version above the
list, the same icon on the row itself, and each app shown with its own icon — Instagram
and YouTube are now told apart before their names are read.

**And a Versions section.** Every tweak states the app versions it was last verified
against, and the page shows that beside the version actually on your phone: "410.1.0 ·
tested" when they agree, "412.0.0 · tested on 410, 439, 441" when they do not. Nothing
is switched off on a mismatch — a newer app usually works fine. It is there so that when
something does break, the fact that explains it is already on screen.

Includes Panel 0.6.0, Instagram 4.1.5 and YouTube 1.12.4.

## v1.0.10

- The source updates properly now. It had started working already — the site was
  serving an older Albrhi rather than none — but the build was still finishing when
  the run checked, so a working publish was reported as a failure. The run now waits
  for the build to actually finish before looking.

## v1.0.9

- **Settings › Albrhi now really turns a tweak off.** The switch moved but the app
  carried on as before; the setting is read directly now. Close and reopen the app for
  a change to take effect, as before.

## v1.0.8

- The source updates again. The step that published it had been getting stuck every
  run, holding the whole thing for as long as it was allowed to. It is gone, and the
  package list is now served straight from the branch it was already being written
  to — the simpler arrangement, with nothing to wait on.

## v1.0.7

- Fixes the source not updating. Publishing now works with how the repository is
  actually set up instead of assuming one particular setting, so the package list
  is refreshed either way, and the run checks the live source afterwards rather
  than reporting that a step finished.

## v1.0.6

- The package page in Sileo now describes this package rather than the old separate
  Instagram one, and is generated from this changelog so it cannot go stale.

## v1.0.5

- The roothide package is now checked properly before it is built, by reading the
  libraries each part links against rather than only where the files sit. A package
  can look right and still be built the wrong way, and that is what Sileo was
  refusing.

## v1.0.4

- Fixes the build, which 1.0.3 broke before it produced anything.
- The roothide package is now checked to actually be one before it is built, instead
  of being found out after installing it.

## v1.0.3

- Fixes the roothide package installing as a rootless one. The combined package was
  built with its own description, which threw away the details the build tool fills
  in to say which kind of jailbreak a package is for.

## v1.0.2

- Includes the Instagram fix that brings back the reels download button.
- **Now really builds both flavours.** 1.0.0 and 1.0.1 produced a rootless package
  only — the roothide one was never built, and nothing was counting.

## v1.0.1

- **Now really removes the old separate packages.** 1.0.0 declared that it replaced
  them, which a package manager honours when installing from a source but which is
  ignored when you install a .deb by hand — so both copies stayed and both were
  loaded. It removes them itself now, however you install it.

## v1.0.0

**Everything Albrhi makes, in one package.**

- Install one thing. You get the Instagram tweak, the YouTube tweak and the settings page.
- Update one thing. Every tweak updates together.
- **Settings › Albrhi** lists every app Albrhi patches, with a switch each. Turn one off
  and Albrhi does nothing inside that app, without uninstalling anything and without
  losing your settings. Close and reopen the app for the change to take effect.
- New Albrhi tweaks will arrive in this same package and appear in the same list, so
  there is never a second thing to install.

Installing this removes the separate Instagram, YouTube and Panel packages. Your settings
live inside each app and are not touched.
