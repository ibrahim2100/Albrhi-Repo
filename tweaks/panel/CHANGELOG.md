# Albrhi Panel Changelog

## v0.6.0

**The page has a face now.** A header with the Albrhi mark, the name and the version
sits above the list, and the row in Settings carries the same icon — so the page is
recognisable from the moment you scroll past it rather than being an unlabelled list of
switches.

**Each app is shown with its own icon.** Instagram and YouTube are told apart before
their names are read, which is the whole job of an icon in a list.

**A Versions section.** Every tweak now declares, in its own filter file, the app
versions it was last verified against — and this shows that beside the version actually
on the phone. "410.1.0 · tested" when they agree, "412.0.0 · tested on 410, 439, 441"
when they do not.

Nothing is disabled on a mismatch and nothing here is pinned to a version number. A
newer app usually works fine; this exists so that when something *does* break, the one
fact that explains it is already on screen instead of taking a report to establish.

The declaration lives with each tweak rather than in a table here, because the tweak is
the only thing that knows what it was built against — a list in this panel would go
stale the first time one was retested and nobody came back to update it.

**The credit is at the bottom of the page**, with the licence and SoCuul's authorship of
SCInsta, which is a condition of using it rather than a courtesy.

## v0.5.0

Released without a changelog entry. It is the release that fixed the switch being
written correctly and read as nothing — see the suite's own notes for that.

## v0.4.0

**Rebuilt around what it is for.** The panel is Albrhi's own settings page and
nothing else.

- Every app Albrhi patches, with a switch each. Turn one off and Albrhi does nothing
  in that app, without uninstalling anything.
- Your settings are kept and come back when you turn it on again.
- Close and reopen the app for a change to take effect.
- An app you do not have installed is shown greyed rather than hidden, so it is
  clear why nothing is happening.
- The list is built from the tweaks actually installed, so a new Albrhi tweak shows
  up here without this page being changed.

**Removed:** listing other developers' tweaks, and the root helper that edited their
filter files. That was a different tool answering a question nobody asked, and a
setuid root program on your device for a feature nobody wanted is a risk with no
return. It is gone rather than switched off.

## v0.3.0

**Real per-app control.** Tap a tweak, see the apps it loads into, and switch it on
or off for each one. Switched off, the tweak is not loaded into that app at all —
this is the filter itself changing, not a setting being ignored.

- Works for **any** tweak on the device, not only Albrhi's.
- Only apps the tweak actually names are listed, so a tweak for social apps does not
  ask you about sixty apps it has nothing to do with.
- An app you switch off stays on the list, so you can switch it back on.
- The original list is copied aside before the first change is made.
- Respring for a change to take effect.
- If the switches are greyed out, the helper did not install correctly — reinstalling
  Albrhi Panel usually fixes it, and the page says so instead of failing quietly.

**Note:** reinstalling or updating a tweak restores its own list, so a change you
made here goes back. That is the package doing its job, not a fault.

## v0.2.0

**The switch.** 0.1.0 described your device and did nothing else.

- **Tap an app** to see what is loaded into it.
- **Turn Albrhi off for one app** without uninstalling anything. Your settings are
  kept and come back when you turn it on again.
- Close and reopen the app for a change to take effect. The panel says so when you
  flip the switch rather than leaving you to wonder.
- Tweaks by other developers are listed, and cannot be switched from here yet —
  that needs a part of the system this version does not touch.

## v0.1.0

**The first build. It reads only — it changes nothing on your device.**

- Adds a page to the iOS Settings app: **Settings › Albrhi Panel**.
- Lists every app a tweak is changing, and how many tweaks are in each.
- Lists every tweak on the device, and how many apps it reaches.
- Reads this from each tweak's own filter file, so it shows what really loads —
  not what a package says it does.
- Arabic and English.

Turning injection on and off per app, and importing tweaks from a file, come after
this one has been shown to describe a real device correctly.
