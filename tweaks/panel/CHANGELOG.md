# Albrhi Panel Changelog

## v0.9.22

Four things the panel could not do before.

**A master switch, above everything it governs.** When an app update breaks something, the answer
until now was eight switches or removing the package -- and that is the worst possible moment to
be hunting through rows. It is one value, read inside the call every tweak already makes, so no
tweak needed changing to obey it. **It defaults to on, and that is not the opt-in reading being
reversed**: the per-app switch answers "did anyone ask for this app to be patched", where silence
must not mean yes; this answers "has the user pulled the handle", where an absent value that read
as off would have switched off every working install on the day it shipped. With it off, the apps
footer says so -- a row that cannot act must not look as though it does.

**A guide page**, built from the device rather than from a list written into it: every tweak on
this phone, one line on what it does, the app version it was verified against, and the version
actually installed. A hand-maintained list of eight tweaks goes stale the first time one is added
or renamed, which this project has already paid for twice.

**A copy of your settings, out of the phone and back.** It goes out through the share sheet on
purpose -- a rootless or roothide prefix is removed with the bootstrap, so a backup written beside
the preferences it copies would be destroyed by exactly the event it exists for. **What it holds
is stated rather than implied**: the panel's own domain, which is the master switch and the
per-app switches. Each tweak's sub-options live inside that app's container where the Settings app
may not read, and a backup claiming "all your settings" would be quietly wrong about most of them.
A file that is not one of ours is refused whole rather than half-applied.

**And an update check, on a tap and never on its own.** A page that phones home when it opens is a
page that decided for its user. It asks Albrhi's own source and nothing else, takes the highest
published version rather than the first listed (the index carries several on purpose), and treats
"the source could not be reached" as a different answer from "you are up to date". A device with no
package manager to compare against is told the published version rather than a guess.

## v0.9.21

The clean-share-links switch is gone with the feature it named.

## v0.9.20

The Spotify page gains podcast and sharing sections: skip sponsored segments, and clean share links.

## v0.9.19

**A page is not what decides the section; being about one app is.** The Tweaks section exists for a
tweak that runs *across* apps — NextUp reads five media apps, Watch answers inside SpringBoard and
the Watch app — where an app row would have to pick one of them to be about. A tweak that patches
exactly one app belongs with the apps, whether or not it also wants a page: Albrhi for Spotify is
collapsed into a group only so it can carry two switches, and that is a fact about its settings, not
about what it patches.

Such a row **pushes to its page instead of carrying a switch**. Giving it both would be two controls
for one thing — the master already lives on the page, and a switch here would write
`app_enabled_<bundleid>`, which a tweak gated on its own master never reads. A switch that moves and
changes nothing is a failure this project has shipped once and does not intend to again.

## v0.9.18

**A grouped row that names exactly one app now carries that app's own icon.** The drawn badge exists
because a filter naming SpringBoard and Camera is one feature rather than two apps, and no icon can
be resolved from a tweak's group identifier. A filter naming one real app is the opposite case:
Albrhi for Spotify is collapsed only because it wants a page, and a music-note glyph where
Spotify's own mark belongs makes it the odd row in a list that is read by eye rather than by name.

Iconless and *no app to take an icon from* are two different conditions, and they are asked
separately now.

## v0.9.17

A page for Albrhi for Spotify: the master, the two ad switches, and — above them — what the tweak
does **not** do. The ad blocking is carried over from a tweak known for unlocking a paid
subscription, and somebody who installs this expecting that should read it on the page rather than
find out by trying to skip a track.

## v0.9.16

A switch for the watch's domain reading, off by default: it is a diagnostic that runs inside
SpringBoard, and the release that added it put a phone into safe mode.

## v0.9.15

The watchOS update row says what the hold actually does: watchOS 26 and newer, with the version read
from the update itself, older updates still offered, and an unreadable version let through.

## v0.9.14

The Watch report carries a nano-domains section: what NanoPreferencesSync actually holds on this
device, which is what the photo, music, apps and Maps features get written from. It is read on a
delay from a background queue, so its absence means "not yet" and the section says so.

## v0.9.13

**The Watch page says whether it is on, above the switches rather than only inside a report.**
Every row below the master is inert while it is off — no pairing answers, no update hold — and the
only place that said so was a diagnostics line at the bottom of a report somebody had to think to
copy. A page whose switches look live while nothing is installed costs a round trip to a device to
explain, and this one did.

The line is rebuilt when the master moves, since it states the value that just changed.

## v0.9.12

The Watch report no longer prints each process's header twice: the probe writes its own, and this
page was adding a second.

## v0.9.11

A restart button for the Watch app beside the one for SpringBoard: they are two processes, they
load Albrhi Watch separately, and the update hold lives entirely in the second — so a respring
reloads half of it. The footer now says what a device proved: a full userspace restart is what
applies a pairing change, and these buttons are the lesser version.

The Watch report is merged from both processes rather than one shared key, carries the update
hold's own verdict, and leads with what the Watch app announced about itself — whether it ran there
at all, and whether its own report survived being written from inside a sandbox.

## v0.9.7

**A tweak whose settings page is missing is now shown and explained, not hidden.**

0.9.4 skipped those rows outright, which was right for one of the two situations that produce them
and badly wrong for the other:

- The tweak is **gone** and its filter plist outlived the package — Albrhi CarPlay, removed from
  this repository, whose `AlbrhiCP.plist` still sits beside a dylib for anyone who installed it. A
  row there is a door drawn on a wall.
- The tweak is **newer than the panel**. Albrhi Watch ships as its own package while its page lives
  in this bundle, so installing the tweak before the suite update that carries the page is an
  ordinary sequence — **and hiding the row then tells somebody who just installed a tweak that it
  did not install.** Reported exactly that way, within an hour of the first release.

The second is the one people meet, and silence is the worst available answer to it. The row is
drawn, dimmed, and carries the reason: *installed, but its settings page is not — update Albrhi
from Sileo*. That sentence is also true of the first case, and costs nothing there.

## v0.9.6

**Albrhi Watch's page gains the update hold and the report.** The hold is a switch like the others;
the report is a button that copies what the tweak found inside SpringBoard and the Watch app —
which classes are present on this build and what their methods really look like. Those classes live
in the shared cache, which iOS 16 does not expose as a file, so asking them at runtime and copying
the answer out is the only way to read them.

## v0.9.5

**Albrhi Watch's settings page**, reached from its own row under the Tweaks section: the master
switch, the three answers it gives while pairing, and a restart button directly under them —
because those answers are installed while SpringBoard starts, so a switch moved here does nothing
until it restarts, and a page that hides that reports success while nothing has changed.

Its switches are written to `com.albrhi.watch`, the domain the tweak itself reads, rather than to
the panel's own. The panel's domain answers "may Albrhi act in this process at all"; a tweak's
switches belong where that tweak looks.

## v0.9.4

**Albrhi CarPlay's page left with the tweak**, which was removed from this repository to be rebuilt
in one of its own.

**And a row whose page is not in this build is no longer drawn.** The panel finds these rows from
filter plists on disk, and a filter outlives the package that installed it: anyone who installed
CarPlay from one of its old releases still has `AlbrhiCP.plist` beside a dylib, while the page it
names is gone. A `PSLinkCell` with a nil detail class is a row that answers a tap by doing nothing
— a door drawn on a wall. Asking the runtime whether the class exists costs one lookup and is the
only thing that knows.

## v0.9.3

**A diagnostic-log switch for Albrhi NextUp**, under a new Advanced section, off by default. The
tweak's own log stopped writing unless it is turned on (NextUp 0.1.4); this is where it is turned
on, with the path and the "turn it off afterwards" written on the row.

**And a row's default now travels on the row.** The page inferred it from the key —
`[key isEqualToString:@"Enabled"]` — which is a list of opt-in keys written as a comparison:
correct while there was one, and wrong the moment a second arrived. The log switch would have
defaulted *on*, which is the exact failure that switch exists to prevent.

## v0.9.2

**A section of its own for the tweaks that are not apps, each with a mark.**

The list mixed two kinds of row. An app row is a switch — "does Albrhi touch Instagram". A row for
Albrhi NextUp or Albrhi CarPlay pushes to a page and is not about an app at all: those run across
SpringBoard and five media apps, or SpringBoard and Camera. Sorted in among the apps they read as
apps this project patches, which is the same misreading `SCIPanelGroupIdentifier` was added to fix
one level down — it collapsed seven rows into one, and the one was still in the wrong list. They
now sit under the apps, under their own heading, and the split is made from what each entry
declares rather than from a list of names here, so the next tweak with a page lands correctly
without this file being edited.

**And those rows had no icon at all**, because the scan finds an app icon by bundle identifier and
a group identifier names a tweak rather than an app. They are drawn here now — an SF Symbol on a
coloured badge, keyed on the identifier the filter plist already declares rather than on the
displayed name, which is translated and would lose its icon in Arabic.

**The count above the list was wrong in both halves.** It read "N of M on" over a list of app
switches while counting rows that are not app switches: NextUp keeps its state in its own
preference domain and never touches the panel's key, so it counted as off forever *and* inflated
the total it was measured against. It counts apps now, which is what it sits above.

**Albrhi NextUp's page was rebuilt in this project's own identity.** A page reached from a list
has to say what it is for: it opens with the accent disc and the mark the tweaks use in their own
screens, the name, a line saying what the tweak does, and a pill stating whether it is doing
anything — which nine switches cannot say at a glance. Every switch carries its own badge, so the
row wanted is found before the reading starts. The pill is rebuilt when the master moves rather
than only when the page is reopened; a header that kept saying "On" over a switch that had just
been turned off is the screen-disagreeing-with-itself failure this page was fixed for once already.

**And each app row now says which build of that app it was written against** — YouTube 21.32.4,
YouTube Music 9.28.4, Spotify 9.1.62 — in the row it is about, on the same cell the root list uses
for exactly this. A provider reads one app version's private classes, so that number is not trivia:
it is what somebody checks first when a row goes blank after an app update. The section's footer
carries the one real difference between the apps, which no version number can state — YouTube has a
queue for a playlist or a mix, and for a standalone video it has none, so what is shown is YouTube's
own autoplay suggestion: playable, not skippable, and 16:9 rather than square.

The apps carry a symbol for what they play rather than a brand glyph: an app's own icon is not
this bundle's to draw, and an imitation that looks nearly right is worse than an honest symbol.

## v0.9.1

**The NextUp page showed its master switch as on while the tweak read it as off.**
Albrhi NextUp 0.1.1 made that switch opt-in — this repository's own rule that absence
reads as *off*, applied to a tweak that injects into SpringBoard and five media apps.
The page still defaulted it to on, which is worse than either default on its own: a
screen stating the opposite of what is happening.

Both halves of the page now use the same split — the master reads and publishes NO when
nothing is stored, every other switch keeps YES — because this page writes the live
notify token as well as the stored value, and publishing a different default than the
rows display would have put the two in disagreement before any value was ever saved.

## v0.9.0

**A settings page for Albrhi NextUp**, reached from the single row `SCIPanelScan`
collapses that tweak's seven-process filter down to — the second tweak to use the
grouped-row mechanism CarPlay introduced, and the first time it has served a tweak with
more than three switches: a master, three surfaces (Lock Screen, Dynamic Island, Control
Center) and five apps.

**It writes to the ported tweak's own preference domain, not the panel's.** Every other
page here writes to `com.albrhi.panel`; this one writes to `com.yves.nextup3` and
publishes that tweak's own `notify_state` token, because the reader compiled into
Albrhi NextUp has those names built in and is upstream's code kept unchanged. Rebranding
the domain would have produced a page whose switches all appear to work and change
nothing — the exact failure `SCIPanelGate.h` already documents from the other direction.

Both channels are written on every toggle: CFPreferences for the value that survives a
reboot, the notify token for the one that takes effect without a respring.

**A row's preference key travels on its own specifier.** Fifteen switches mapped back to
keys by a second `if` ladder is how a switch ends up writing the wrong preference; here
adding a row costs one line and nothing anywhere else.

## v0.8.1

**Settings crashed the moment the Albrhi page was opened.** 0.8.0's fault, and the fix is
one word.

The new row was registered by setting `cellClass` to the string `@"SCIPanelAppCell"`.
Preferences takes that property as a **Class** and sends class messages to it — so it sent
`+alloc` to an `NSString` instance, which does not answer it, and Settings died. The name
reads identically in the source and is a completely different kind of object.

Two more things went with it, both found by reading the file back rather than by anyone
hitting them:

- The cell forced `UITableViewCellStyleSubtitle` on its superclass to get
  `-detailTextLabel`, which it never used — it draws its own label. Overriding the style a
  `PSControlTableCell` was constructed with, for nothing.
- `-layoutSubviews` moved the title up by half the subtitle's height **relative to where the
  title already was**. That is only correct if it runs once; a visible row is laid out
  repeatedly, so it read a value it had written and moved it again, and the title would
  creep upward for as long as the row stayed on screen. Both frames are computed from the
  row's own centre now, which gives the same answer however many times it runs.

## v0.8.0

**One row per app, carrying everything.**

The page listed every app twice: once as a switch, and again in a Versions section stating
two version numbers. Two passes down the same list to answer one question about one app —
and the switch was in the first pass while the reason you might want to move it was in the
second.

Each app is one row now, with its icon, its name, and a line underneath saying which version
is on this phone and which one that tweak was last verified against. The Versions section is
gone; its explanation moved into the footer above, where it now describes something visible.

**Amber, not red**, when the app is newer than the tested build. That is a caution, not a
fault — the tested numbers are the newest builds the developer's own phone accepts, never a
compatibility ceiling, and colouring it red would claim a problem where there is only an
unknown. An app that is not installed says so on its own row instead of showing a dead
switch with no explanation.

The row is a `PSSwitchTableCell` subclass. Theos ships headers for both that and
`PSTableCell`, so the switch, its wiring and its enabled state keep working exactly as the
plain cell's did, and **no private property is guessed at** — the rule that keeps CarPlay's
microphone choice three switch cells instead of a private list picker.

Two things the layout had to be careful about, both recorded in the cell itself: the second
line is positioned against the title frame Preferences has already set rather than the
content view, because the title inset changes with the icon, the switch and the iOS version;
and the subtitle is the cell's own label rather than `-detailTextLabel`, which `PSTableCell`
restyles on every refresh.

## v0.7.0

**The panel says how much of Albrhi is actually on, before anything is read.**

The list already shows a switch per app, but knowing how much is patched meant counting
them — and since the switch became opt-in, a fresh install is a page of switches that are
all off with nothing saying so plainly. A pill beside the version now reads "2 of 5 on".

Green when anything is patched, plain grey when nothing is. **Not red**: none-on is a
deliberate and valid state here, not a fault, and colour is kept for what is actually wrong.

The count is taken when the header is built rather than cached, so it cannot disagree with
the switches under it — the page reloads its rows on every return, and a header holding its
own tally would show yesterday's answer. It reads through one shared accessor with the rows,
for the reason this project already learned the hard way: the same question is answered in
three places across two processes, and the third one was missed once.

## v0.6.7

**The CarPlay page now says to respring, not just reopen the app, after editing the
bridged-apps list or the master switch** — SpringBoard's own app-library cache is
what CarPlay 0.4.1 actually fixed, and it does not always re-evaluate an app just
because that app relaunched. The bridged-apps footer also names the exact identifier
format expected and the known "car or phone, not both" limitation for an app that
has not opted into running two windows at once.

## v0.6.6

**The CarPlay page can set a custom dashboard wallpaper.** A photo picker
(`PHPickerViewController` — no photo-library permission prompt needed, the modern
picker Apple built for exactly that) saves the chosen image for Albrhi CarPlay's new
wallpaper hook to pick up. Not validated on-device.

## v0.6.5

**The CarPlay settings page opened to a black screen.** Reported on-device: tapping
"Albrhi CarPlay" pushed a page with nothing on it. `-specifiers` was building the row
list and returning it, but never assigning it to the `_specifiers` ivar the way
`SCIPanelRoot.m`'s own root page already does — `PSListController`'s own plumbing
reads that ivar directly in places an override's return value never reaches, so a
subclass that only returns the array renders nothing. Assigned now, matching the
pattern the root page has used since it first worked.

## v0.6.4

**Albrhi CarPlay's settings page now has the app-bridging list.** A second dylib the
tweak gained in 0.3.0 has no row of its own — `SCIPanelHidden` in a filter plist now
tells the scan to skip it entirely rather than turning its framework-identity filter
into rows of its own, the same class of mistake `SCIPanelGroupIdentifier` fixed for a
different shape of it last release.

## v0.6.3

**A tweak can now declare a real settings page of its own, and CarPlay is the first
to.** Any filter that names a `SCIPanelDetailController` collapses to one row and pushes
to it instead of showing a switch — built because CarPlay's filter names two processes,
SpringBoard and Camera, which was showing up as two confusing rows, "Camera" and
"SpringBoard", as if they were separate apps this project patches. It is one "Albrhi
CarPlay" row now, and it opens the master switch, the recording-audio fix, a
microphone choice and verbose logging, all in one page.

## v0.6.2

Three faults found by reading 0.6.1 back rather than by anyone hitting them.

**The header could have laid itself out wrongly.** The logo and the version pill were
given sizes while they still carried their own automatic ones — a conflict that only went
unnoticed because the container happened to clear it two lines later. Depending on the
order of two lines to avoid a broken layout is exactly how this project's other settings
page died twice.

**The mark existed at one size only**, so a phone that is not the highest resolution had
nothing exact to draw. All three are there now.

**And the version could have read as unknown on some devices.** The installed version is
found by its stanza in dpkg's records, and the first stanza in that file has no line
break in front of it — so a device where Albrhi happened to be the first package
installed would never have been found, and would have shown the fallback instead. That
file is also a few megabytes, and it was being read twice every time the page laid itself
out; it is read once now.


## v0.6.1

**Four things reported from a phone, all of them real.**

**"Made by" was blank, and so was every other value on the page.** A row that shows a
fixed value still has to be *asked* for it — the value was set and no getter was given,
so Settings had nothing to ask and drew nothing. That is why the Versions rows looked
empty too.

**The version shown was the wrong number.** Someone who installed Albrhi 1.0.11 was
being told "v0.6.0" — the panel component's own version, which nothing on the device or
on the source ever called it. It now reads what dpkg records as installed, so the page
quotes the number you would quote back.

**The Versions section could disappear entirely.** It skipped any app whose version it
could not read, so a failed lookup produced no section at all — indistinguishable from
the feature not being there. Every installed app has a row now, reading "not known" when
it is not known, and the version is asked for under more than one name before giving up.

**A Respring button**, at the bottom, behind a confirmation. It asks the system for a
relaunch the way Settings itself does rather than trying to signal SpringBoard, and if
the device refuses it says so instead of appearing to do nothing.


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
