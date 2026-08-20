# Albrhi Watch — what changed

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
