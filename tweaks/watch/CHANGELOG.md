# Albrhi Watch — what changed

## v0.4.4

**The stage counters answered it in one line**, which is the whole reason they were added:

```
stamp: 5 call(s) → 11 asked → 2 row(s), 4 with a footer → 1 stamped
      — last stop: no row on this page carries footer text
```

The six-row page that offers the update carries footers. The **two-row page it settles into** —
"your Apple Watch is up to date" — carries none. So the notice was being stamped onto rows that
were about to be thrown away, and the page a person actually ends up looking at had nothing to
stamp. Three passes did not help, because the problem was never timing.

A group with no footer is not a page refusing one: `footerText` is a property, and setting it on a
group that had none draws a footer under that group. So when nothing carries text, **the last group
is given it** rather than the pass giving up. A group is recognised as a row with no title of its
own, which is exactly how `TITLE_GROUP` and `INSTALL_BUTTON_GROUP` appear in the page's own dump —
structure again, not words.

**And the report records both shapes now**: the page as first seen, which is what named
`INSTALL_BUTTON_GROUP` and made the install rows findable, and the page as it settled, which is
what a person is looking at. Keeping only the first is how a settled page went four releases
without ever being described.

## v0.4.3

**"It shows, then a few seconds later the watch says it is up to date."** Both halves of this
feature were working, and they were working against each other.

The scan-result hook settles the page to *nothing found* — that is what stops the update — and
settling **rebuilds the rows**, which throws away the notice just stamped onto the rows before it.
So the page ended on Apple's own up-to-date screen with nothing to say who decided that, which is
precisely the dishonesty this notice exists to remove.

The stamp runs three times now, at 0.4, 1.5 and 3.0 seconds, rather than once. A single pass at a
fixed delay is a guess about when the rebuilding stops, and this project has a rule about guessing
at durations: every time a sleep was replaced by asking, the answer came back immediately and was
right. There is nothing to ask here, so the next best thing is to stamp again after each state the
page can settle into — and the stamp is idempotent by content, so a pass that finds its own work
already done costs one string comparison.

A pass that finds the notice already there no longer records itself as the "last stop" either: it
is the steady state, and reporting it as the last thing that happened buries the one stop that
would actually explain a failure.

## v0.4.2

**Confirmed on a device: no crash, and `held: watchOS 26.6 (major 26)`.** The filter works and four
separate refusals sit behind it. What the page still did was **offer** the update — the report's own
dump listed `INSTALL_BUTTON_GROUP` and a `Download and Install` row.

Those rows are **disabled and renamed**, not removed. `-removeSpecifier:` changes the list the
controller is iterating and leaves it holding rows it may still call `-reloadSpecifier:` on, and
this tweak crashed the app one release ago by being clever about Apple's own bookkeeping. Renaming
and disabling uses only what a device has already proven here: `-setProperty:forKey:` and
`-reloadSpecifier:`, which stamped the footer without incident.

**They are found by structure, not by their words.** The rows that follow the group whose identifier
is `INSTALL_BUTTON_GROUP` — matching on "Download and Install" would be matching a localised string,
right in English and wrong in every other language this page is drawn in.

`-downloadSize` is read now as well: its encoding is `q`, and the shape report had been declining
every scalar rather than risk a wrong cast.

## v0.4.1

**0.4.0 crashed the Watch app when the update page was opened. Both hooks it added are gone.**

`-setUpdate:` and `-handleManagerState:update:error:` fed **nil** into Apple's own state machine
while the state still said an update had been found. Nil-messaging is safe in Objective-C, and that
is exactly what made this look safe — what is not safe is the code *after* the message, which has
been told a descriptor exists and reads something out of it. **Refusing a delivery is not the same
as never having had one**, and a controller's own flow is not ours to half-answer.

The rule this project already keeps decided it: **a crash is worse than the thing being
prevented** — the same reason TikTok 0.12.1 exists.

What replaces them is smaller and cannot corrupt anything: **the two actions the install button
invokes are refused**, `-downloadAndInstall:` and `-install:`, both `v24@0:8@16`. The update may
still be listed; nothing can start it, and `-startDownload:` and `-installUpdate:` still sit behind
that as they have since 0.2.7. Same placement rule as the TikTok download button — refuse at the
irreversible action, never at the machinery leading to it.

The descriptor the scan handed over is kept **weakly** so those actions can ask about it: a strong
reference would keep it alive past the page that made it, and a tweak that changes an app's object
lifetimes has stopped being an observer.

## v0.4.0

**"Stop watchOS 26" is what this now does, and it took the device naming the descriptor.**

```
the update it saw: SUBDescriptor; -humanReadableUpdateName = watchOS 26.6;
                   -productVersion = 26.6; -productBuildVersion = 23U67
```

Until that came back the hold was necessarily coarse — it withheld everything, which is not what was
asked for and was described in the last release as not being it. The comparison is on the **major**
number alone: `26.6`, `26.0.1` and `26` all answer 26, and a string compare would put `26.6` before
`9.5`. **An update whose version cannot be read is let through, not held** — a hold that fires when
it cannot tell what it is holding is the coarse behaviour wearing a filter's name, and the
irreversible direction here is the one that stops a security fix for the watchOS the watch is on.

**Withholding the scan result was not enough, and the page's own dump said so.** Every hook
installed, `watchOS 26.6` recorded as seen, and the report still listed `INSTALL_BUTTON_GROUP` and a
`Download and Install` row. The descriptor reaches the page by more than one road: the controller
**stores** it in `-setUpdate:` and is driven by `-handleManagerState:update:error:`. Both are hooked
now, both encodings read off the device. This is the watermark fix's shape from the TikTok tweak — a
value that is stored is true for every reader afterwards, while intercepting one delivery answers
one caller.

The report says which version was held and which was let through, because "it allowed one" and "it
never saw one" are two different things and only one of them is a bug.

## v0.3.3

**`stamp: 0 call(s)` was not the hooks failing — it was my own report describing a process that had
just started.** The drop carrying the report is written from `%ctor`, so every counter in it is a
launch-time counter, and nothing that happens while the app is *used* was ever in it. A diagnostic
with no refresh describes one instant and is read as describing the run: this project's own
tally-versus-snapshot rule, arriving in the diagnostic instead of the feature.

The drop is rewritten now after anything worth reporting — a stamp, a withheld update, or a stamp
that gave up and named why — throttled to once every two seconds, because a redrawing table can
call it several times a second and a diagnostic has no business being the busiest writer in the
process.

**And the domain probe answered the important half: the accessor is bound.** `bound to the active
device, pairingID = 53DE7DDA-…`, and then nothing in all sixteen candidates. A live accessor over
an empty domain means **the names are wrong**, and sixteen guesses are still guesses however
carefully chosen.

So the names are read instead of proposed. NanoPreferencesSync keeps a watch's synced domains on
disk under the paired device's own registry directory, one file per domain, and SpringBoard is not
sandboxed — so the directory is listed and **the file names are the domain names**. Same move as
dumping a class's method list rather than trying selectors, which is what unblocked the update work
two releases ago.

## v0.3.2

**Two zeroes came back, and neither of them is a result.**

`the page was stamped 0 time(s)` is true for five different reasons — the hook never fired, the
controller does not answer `-specifiers`, the list was empty because the rows are not built yet,
no row carries a footer, or it was already stamped — and one counter cannot say which. This is the
quality picker's own lesson: it was fixed three times against the wrong stage until it reported
`raw → parsed → deduped` separately. Each stage counts itself now, and the last stop is named.

**Sixteen domains answering `0 byte(s), no keys` is one answer, not sixteen.** Every candidate came
back empty — including `com.apple.Bridge`, which the Watch app plainly uses. A uniform zero across
unrelated things is the signature of a broken measurement, and this project has met it before, when
every bitrate entry scored zero because one selector name was wrong on all of them. The class says
what to ask: it declares `-initializedWithActiveDevice`, `-shouldNotDoWork`, `-pairingID` and
`-requiresDeviceUnlockedSinceBoot`, and it offers `-initWithDomain:pairedDevice:` beside the plain
`-initWithDomain:` this probe used. So the accessor is asked whether it is bound to anything, and
the size stops being read as a fact about the domain.

`NRPairedDeviceRegistry`'s 127 methods are dumped filtered to the ones naming a device, because
that is where a paired device would come from — measured before the next attempt, not guessed at.

## v0.3.1

**"Checking for updates…" never stopped, and the fix is the lesson this project already paid for in
the YouTube tweak.** Handing the page a nil update is not the same as telling it nothing was found:
the wait is not inferred from the argument, the page keeps it in **its own flags**. So
`-setIsExpectingScanResult:`, `-setNoUpdateFoundOrIsComplete:` and
`-setHasReceivedValidFirstScanResult:` are set explicitly — every one declared on the class as
`v20@0:8B16`, checked against the runtime before being sent. Code that keeps its own copy is never
reached by answering a getter, which is exactly why `-bypassOnesie` failed.

**And the notice never appeared because it was waiting for the wrong moment.**
`-manager:scanRequestDidLocateUpdate:error:` fires only when a scan finds something, and once the
hold has answered the app may not ask again for the rest of a launch. The page's own signals are
hooked now — `-startSUBUpdates` when it goes live and `-updateTableViewWithTask:` when it redraws —
and the stamp is **idempotent by content rather than by a flag**: returning to the page rebuilds
the rows, so a one-shot stamp would be applied once and silently absent afterwards, while the same
flag would double the text on a row that was not rebuilt. The report counts the stamps.

**NanoPreferencesSync is asked what it actually holds.** Sixteen candidate domains — the Nano
spelling and the app's own bundle id for photos, music, companion apps and Maps — are opened
read-only and asked for `-domainSize` and `-copyKeyList`. **Nothing is written**: a
`-setObject:forKey:` on a domain that syncs to a watch is not a diagnostic, it is a change to a
paired device. It runs on a background queue eight seconds after SpringBoard starts, because every
one of those calls is XPC and a diagnostic that stalls the home screen is worse than none.

## v0.3.0

**The hold works, and it made iOS tell its owner something untrue.** "Your Apple Watch is up to
date with all the latest bug fixes and security enhancements" is a sentence this tweak caused and
iOS believes — a fact about the watch, where what happened is a consequence of a switch. That is
worse than the update being hidden.

So the Software Update page now says who withheld it, in both languages, above Apple's own text
rather than instead of it. The footer is **edited in place and redrawn with `-reloadSpecifier:`**:
`-reloadSpecifiers` would ask the controller to build its rows again and discard the edit in the
same breath as making it.

**Which footer is a heuristic, and the report says so.** It takes the last row carrying footer
text, which on this page is the one under the version. The whole specifier list — every row's name,
identifier and footer — is recorded the first time the page is stamped, so the next release can
name Apple's own row precisely instead of inferring it. A heuristic described as one is a different
thing from a heuristic trusted quietly.

## v0.2.9

**Confirmed on a device: all five update hooks are installed**, and the switch was read from
`…/.jbroot-<random>/var/mobile/Library/Preferences/com.albrhi.watch.plist` — the preferences daemon
answered the Watch app with nothing and the file answered, from the roothide path. The
`dladdr`-derived prefix was not belt-and-braces: the plain `/` candidate never answered at all.

The probe now dumps `NPSManager` and `NPSDomainAccessor` in full. Counts said the classes are here;
only the method lists can say what to call, and **NanoPreferencesSync is the route the four sync
features have to be written from** — it is the phone's own way of pushing a preference domain to
the watch, present in SpringBoard where this tweak already works, needing no IDS, no injection into
a system app, and nothing installed on the watch.

## v0.2.8

**The master switch was never off. The Watch app could not read it.**

The report said `master OFF, hold updates ON` — and those are exactly the two defaults, NO and YES,
which is what an **empty domain** produces. The line was written from inside the Watch app, which
is sandboxed, and a sandboxed process asking cfprefsd for another application's domain is answered
with an absence rather than an error. SpringBoard, unsandboxed, was reading the same switch
correctly the whole time.

This is `shared/src/SCIPanelGate.m`'s own lesson arriving in a second tweak, and the fix is
deliberately the same one rather than a new idea: try the daemon first — where it works it is
cheaper and it sees a value written but not yet flushed — then **read the plist directly**, which a
jailbroken device permits even where the daemon redirects the domain. The jailbreak prefix comes
from `dladdr` on this code's own address, the only way to get it right on roothide.

`Prefs.h` had said in a comment that no libSandy was needed here "because SpringBoard is not
sandboxed" — true of SpringBoard, and this tweak stopped being only SpringBoard three releases ago.
**A comment that was right when written is not a check that it is still right.**

**And the report prints where the answer came from**, beside the values: a switch read from nowhere
and a switch genuinely off produce the same two words, and that ambiguity cost a full round trip.

## v0.2.7

**Refusing `-scanForUpdates` was wrong, and the device's own method list is what showed it.** The
scan is asynchronous: its answer arrives through the delegate, and the Software Update page tracks
the wait in `-isExpectingScanResult` and `-hasReceivedValidFirstScanResult`. Swallow the call and no
answer ever arrives — **a spinner that never stops, not a phone that is up to date.** A principle
applied at the wrong point removes the working behaviour instead of the unwanted one, which is a
mistake this project has shipped before in another shape.

So the answer is replaced rather than the question refused — the same way the TikTok ad filter lets
the app build its object and then declines it. `-manager:scanRequestDidLocateUpdate:error:` on
`COSSoftwareUpdateController` (confirmed `v40@0:8@16@24@32`) is called with **no update and no
error**, which is Apple's own "nothing found" path; the page has `-noUpdateFoundOrIsComplete` for
exactly that state.

**And the download and the install are refused too**, because one intercepted answer is a single
point of failure for something irreversible: `-startDownload:`, `-startDownload:passcode:`,
`-installUpdate:`, `-installUpdate:passcode:`, each in its own group, each installed only if its
runtime encoding matches.

**The version filter is not written yet, on purpose.** The switch was asked for as "stop watchOS
26", and holding every update is not that — but the update descriptor's class and accessors are in
no header on this machine, and guessing at them is the exact mistake the last four releases have
been undoing. The first update this ever sees is **described into the report** instead, behind
`-respondsToSelector:` at every step and reading only object-returning accessors, so the filter gets
written against a name a device confirmed.

**`not reached` had two meanings** — the Watch app has not run this build, and the tweak is switched
off — so the switches now travel with the report and say which.

## v0.2.6

**The channel works, and the first real answer from inside the Watch app corrects two things at
once.** `SUBManager` is there — 33 methods — and `-scanForUpdates` encodes exactly `v16@0:8`, what
these hooks were compiled for. **`-checkForSoftwareUpdate:` is not on the class at all.**

So the guard demanded both and installed neither. A device carrying a perfectly hookable
`-scanForUpdates` got no hold, reported as a signature mismatch — the same shape as a capability
check narrower than the capability it guards, failing silently in the direction of doing less.
Each selector decides for itself now, in its own `%group`, because **a `%hook` on a method a class
does not declare does not politely do nothing — Logos adds it**, and the tweak would be installing
an API Apple never calls.

**The verdict could not travel either, for the reason 0.2.5 had just found.** It is written by the
same sandboxed process whose preference write is redirected, which is why a build that had computed
a verdict reported "no verdict". It rides in the dropped file now, behind a marker SpringBoard
splits on, and the Watch app announces a second time once the hold has decided.

**And the probe prints whole method lists.** A name and a count answer "is it here" and cannot
answer "what do I hook" — `SUBManager` came back with 33 methods and the one selector this tweak
had guessed at was not among them. `SUBManager` and the automatic-update controller are printed in
full; `COSSoftwareUpdateController` has 161 methods, so it is filtered, with the empty filter
written deliberately to mean *everything*.

## v0.2.5

**The report said the Watch app wrote its own report, and the section under it said the Watch app
was never reached. Both were true, and the contradiction is the finding.**

0.2.4 wrote the report into the shared preference domain, read it back, and announced success.
cfprefsd had not refused the write — it **redirected** it into the Watch app's own container, where
the read-back found it exactly where it had been put. **A self-verifying write verifies the wrong
thing when the failure is redirection rather than refusal**, which is a sharper edge of this
project's own rule about a sandboxed process being answered with nothing rather than an error.

So the report travels as a file, in the one direction that needs no permission either side lacks:
the Watch app writes inside **its own container**, which a sandbox always allows, and SpringBoard —
not sandboxed — finds it and copies it into the shared domain. The container is a UUID assigned at
install time, so it is searched for by a file name no other package uses rather than computed. The
Darwin notification now only says *when to look*, which is all it ever had to carry.

**And the report printed `in com.apple.springboard` twice.** The probe writes its own header line
and the panel added a second — one thing described by two lists again, the same shape as a row
added to a screen and not to the text that claims to mirror it.

## v0.2.4

**Nothing ran at all, and the gate was mine.** `SCIPanelAllowsThisApp()` asks whether
`app_enabled_<bundleid>` is set; the panel only ever sets that from an *app's* own row, and this
tweak is deliberately collapsed into one grouped row — so the answer was no, forever. No hooks, no
probe, an empty report, and a device reporting that not one feature worked. The tweak's own master
switch is the gate now, which is what Albrhi NextUp already does.

**The pairing answers are installed in every process that asks them**, not in SpringBoard alone.
The preference *writes* stay in SpringBoard: one correct writer for a global value.

**The record corrected.** An earlier note credited those extra hooks with fixing the Watch app. The
device says otherwise: it opened on 0.2.1, with the hooks in SpringBoard alone, after a full
userspace restart. So the mechanism is the **NanoRegistry preference writes** — global values
written once, read by every process at its *next* launch. A respring restarts SpringBoard and
leaves the Watch app and the daemons holding what they cached at boot; a userspace restart brings
them all up to read what was already written. Same build, two kinds of restart, two behaviours. The
settings page says so, and its buttons are named as the lesser version rather than the equivalent.

**One report key per process.** Both processes wrote the same key, so whichever launched last was
the only one ever read — and the section that mattered was always the missing one.

**The update hold's verdict is published.** It was computed inside the Watch app and shown nowhere:
either it installed, or it names both encodings that disagreed, and the second is what the next
release gets written from.

**And an empty section stops meaning two things at once.** `NOT REACHED` cannot tell apart "never
injected here" from "ran, and the sandbox refused the write". The Watch app now reads its own write
back and announces the outcome over a Darwin notification — `notify_set_state` carries 64 bits
beside the name, which is exactly the size of this question — and SpringBoard, which can always
write, records the answer. The report prints that line first, because it decides how to read the
emptiness underneath it.

## v0.2.0

**The Watch app, the update hold, and a probe that asks the device what its own classes look like.**

Reading a commercial tweak's package answered one question with a negative worth having: **its
update feature does not hook the phone's update screen at all** — it talks to the watch over IDS
with protobufs. What *is* on the phone is `SUBManager`, from `SoftwareUpdateBridge`, and the Watch
app's own `General.plist` names `COSSoftwareUpdateController` as its Software Update page. Those
two facts are the entire basis for the hold; no logic was taken from anyone.

**A hold, and it says so.** `-scanForUpdates` and `-checkForSoftwareUpdate:` are how the Watch app
goes looking, and refusing them means it finds nothing to offer — which stops an update being
presented or installed through the phone. It is **not a version filter**: refusing only watchOS 26
needs the update descriptor's own API, which lives in the dyld shared cache that iOS 16 does not
expose as a file. Off by default, because every other switch here answers a question iOS asks and
this one refuses to ask it.

**Nothing is installed unless the runtime agrees with what the hooks were compiled for.**
`class_getInstanceMethod` returning non-NULL proves a selector exists and says nothing about its
types, and a `%hook` with wrong argument types does not fail politely — arguments arrive in the
wrong registers. This project crashed one app four times learning that, the worst of them a `^q`
out-parameter declared as an `NSInteger`. So the real encoding is read with
`method_getTypeEncoding` and compared against what the hook declares; a mismatch installs nothing
and **reports both encodings**, which is exactly what the next release needs.

**And a probe that hooks nothing.** Every class this tweak wants next — the update path, the sync
subsystems — lives in the shared cache, which cannot be read as a file here. So they are asked at
runtime, in the processes where they exist, and what they answer is written to a preference the
settings page can read: present or absent, how many methods, and the verbatim type encoding of
every selector a hook is being considered for. One copied report answers what extracting a
three-gigabyte cache would have.

The tweak now loads into `com.apple.Bridge` as well as SpringBoard, and each process installs only
its own half: pairing is answered in SpringBoard, the update surface exists only in the Watch app.

## v0.1.0

**A pairing tweak, from `watched` by 34306 under the MIT licence, with Albrhi's switches around it.**

iOS refuses to pair with an Apple Watch whose watchOS is newer than it expects, and refuses to
install companion apps onto it. The core that answers those questions — ten compatibility-version
answers on `NRPairingCompatibilityVersionInfo`, `-supportsCapability:` on `NRDevice`, the
`ACXRemoteApplication` runtime check, and the NanoRegistry preference writes behind them — is
carried over as code rather than reimplemented. **MIT permits exactly that**, which is the same
reading that let NextUp be carried over under GPLv3 and the opposite of what the unlicensed TikTok
references get. `LICENSE-watched` ships *inside the package*, not only beside the source: a `.deb`
on somebody's phone is a copy, and MIT asks that its notice travel with every copy.

**What this project added is entirely in the guards.**

- **A master switch, off until it is turned on.** Upstream installs everything the moment it is
  loaded, which is right for a tweak with no settings; this one answers the questions iOS asks
  before it agrees to pair with a watch, and nothing about that should begin because a package
  landed. The three feature switches default *on*, so one switch is enough to get a working tweak.
- **Three switches rather than one**, because "pairing is allowed", "this watch can do that" and
  "this app may install" are three different claims. A watch that pairs but misbehaves can have
  one third turned off instead of the package removed.
- **Every answer is counted.** A pairing failure looks exactly like a tweak that never loaded, and
  the only screen that could tell them apart is the pairing screen, which shows neither. The page
  reports which classes were present at launch, how many times each gate answered, and the last
  watch version that was read against this phone's.

**The switches live in a shared CFPreferences domain, and that is not a detail.** They are written
by Albrhi Panel inside Settings and read by this tweak inside SpringBoard; `NSUserDefaults` means
"the calling process's own domain", so that arrangement would have written Settings' preferences
and read SpringBoard's — two files, one name, a switch that appears to work and changes nothing.
This project has already shipped that bug once.

**A restart button sits on the page, under the switches.** The answers are installed while
SpringBoard starts, so turning the tweak on or off does nothing until it restarts — and a page
that hides that reports success while nothing has changed.

The version arithmetic is upstream's and worth keeping in mind: watchOS trailed iOS by seven for
years, and from **26** the numbers align. So a major below 26 gets the offset added before the
comparison and one at or above it does not.

**Not yet here, and named rather than implied:** photo, music and Maps support, and blocking a
watchOS update, each live in a different process with its own private framework — Photos, Music,
Maps and the Watch app respectively. Nothing about them can be written from what the pairing core
shows, and this project does not hook a class it has not confirmed.
