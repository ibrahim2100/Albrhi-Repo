# Albrhi Changelog

## v1.6.0

**The Locket tweak saves moments now.** Hold two fingers anywhere in Locket and every moment
it has loaded is listed, newest first — tap one to keep a friend’s photo or video to your
Photos at full size, the one they sent rather than a screenshot. Locket is a Swift app, so
the list is built from what it fetches over the network, filtered to real moments and away
from the app’s own artwork.

The jailbreak-hiding from 1.5.0 stays. And the X download button fix from this release rides
along.

It saves what is already on your phone and does not touch anything you would pay Locket for.

Includes the Locket tweak 0.2.0 and the X tweak 0.4.0.

## v1.5.0

**A fourth app: Locket.** Albrhi now keeps Locket from reporting your phone as jailbroken —
to its analytics, its ad-attribution SDK and its own code, all three of which check on a
modified phone and send the answer home, where it can count against your account. They now
come back clean.

It answers only the jailbreak questions — is this file here, can this app be opened, is this
folder writable — and only for the handful of paths a check looks at; everything else the app
asks the system passes straight through. Hold two fingers anywhere in Locket to see how many
checks were answered.

It does not touch payments or subscriptions, on purpose.

Includes the Locket tweak 0.1.0.

## v1.4.0

**The X tweak puts the download button on the video.** In the corner beside play and mute,
where you would reach for it — tap and the video is in Photos at the best quality X offers.
The list under the two-finger hold stays as a fallback, so saving keeps working even on a
build where X has renamed the video view.

Includes the X tweak 0.4.0.

## v1.3.0

**The X tweak saves videos now.** Hold two fingers anywhere in X and everything it has shown
you since you opened it is listed, newest first. Tap one and it is in Photos — videos at the
best quality X offers, photos at the size they were uploaded rather than the smaller copy the
timeline was showing, and GIFs as the video files X actually serves.

There is no button added to X, and that is deliberate: a button lives inside one of X's own
views, and those get renamed. The list is in our own screen, so it keeps working when X moves
things around.

Includes the X tweak 0.3.0.

## v1.2.0

**The X tweak has its features.** Seventeen switches in plain language: hide ads, hide the
Promote button, hide Grok, stop X translating by itself, hide Premium ads, send less about
you, clean up the interface, hide view counts, hide Spaces, show sensitive posts directly,
stop GIFs playing alone, pinch to zoom in the timeline, more gestures, more tabs, keep your
likes private, open faster, and X's own speed work that it ships switched off.

Each one sets a group of X's own switches at once and says what it does before you turn it
on. The full list of switches is still there underneath, and your own answer always beats a
feature.

Nothing here was guessed: every switch a feature touches is one a real phone reported —
341 of them over 345,902 questions on X 12.14.

Includes the X tweak 0.2.0.

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
