# Albrhi for Locket — what changed

## v0.3.1

**The self-contained dylib did nothing at all, on a real device — not even the welcome
screen — because v0.3.0's published build predates this fix.** `SCIPanelAllowsThisApp()`
reads an unanswered question as *off* by design, because installing the suite patches
four apps at once and silence should not read as consent for all of them. A sideloaded
dylib is the opposite case: one tweak, installed deliberately, for one app, on a device
that may have no jailbreak on it — so Albrhi Panel (itself a jailbreak package) can never
be installed, the switch can never be turned on, and every hook this tweak has stood down
on every single launch, silently, because that gate sits before all of them. Fixed in
`SCIPanelGate.m` itself: the self-contained build now answers the gate `YES`
unconditionally, restoring the older "installed it deliberately" reading for the case
that is still true of. The rootless and roothide `.deb` packages were never affected —
Albrhi Panel is genuinely reachable there.

## v0.3.0

**Standalone.** Locket has left `com.albrhi` — it is no longer bundled in the suite, has
no Conflicts or Replaces on it any more, and publishes its own releases from its own
workflow, under its own tag namespace, the same way CarPlay's package already does. The
suite still bundles Instagram, YouTube and X; Locket is its own thing now, for anyone who
wants this and nothing else.

**A self-contained dylib, for sideloading.** Alongside the rootless and roothide `.deb`
files, every release now also carries a plain `.dylib` built with its own hooking layer
instead of CydiaSubstrate — provably standalone, checked in CI with `otool` and `nm`
rather than assumed, the same discipline Instagram's own sideload build already uses. It
installs with TrollStore, a developer certificate, SideStore, LiveContainer, or anything
else that can inject a dylib into Locket, with no jailbreak underneath it required.

**The jailbreak-detection bypass is not in that dylib, on purpose — moment-saving is
the whole of it there.** The bypass hooks C functions (`stat`, `access`, `fopen`,
`getenv`) through Substrate's `MSHookFunction`, a genuinely different mechanism from the
Objective-C method hooking the dylib's own standalone replacement already covers.
Building that without Substrate needs real systems work — symbol rebinding or
`DYLD_INTERPOSE` — that has not been built and verified on a device yet, and shipping it
unverified risks a crash on the one feature meant to keep the app usable. The rootless
and roothide `.deb` packages are unaffected: the bypass works exactly as it always has
there, where Substrate is actually present.

**A welcome screen.** What this tweak does was previously reachable only by knowing to
hold two fingers on the app — and finding that out meant reading the depiction first. The
first launch now says it directly: what gets hidden from Locket's own checks, that a
moment saves as the real file rather than a screenshot, and the gesture that opens the
status screen. Shown once, in Arabic or English.

## v0.2.1

**The app was crashing, and the bypass could not work because of it.** The list of paths
to hide included everything under `/private/preboot/` — which is where iPhone keeps its
own system content. From iOS 16 the operating system ships as cryptexes mounted there, and
system libraries are loaded through that path, so telling the app they do not exist was
not a failed jailbreak check. It was a launch that died.

roothide does keep its root under a hash in that folder, and it is still found: it leaves
a marker, and markers were already being looked for. The blanket rule was never needed and
it took the operating system with it. There is now a short list of paths this will never
lie about, checked before anything else, so no future rule can do the same thing again.

**The filesystem checks no longer slow the app down.** Every hidden path was writing a
line for the status screen, from inside libc, on whatever thread asked — and Locket asks
thousands of times a second. The counts are still exact; the examples stop after four
hundred, which is long after the list stopped changing.

A path merely *containing* a jailbreak marker in its name is also no longer treated as one.
The rule was meant to match a whole folder name and did not, so a file the app itself wrote
could have been hidden from it.


## 0.2.0

**Save a moment.** A friend’s photo or video, kept to your Photos at full size — the one they
sent, not a screenshot.

- **Hold two fingers anywhere in Locket** and every moment it has loaded since you opened it
  is listed, newest first. Tap one to save it.
- **Full quality**, photo or video, worked out from what Locket actually downloaded rather
  than guessed.
- Because Locket is built in Swift, a moment is not something a normal tweak can read from
  the screen — so the list is built from what Locket fetches over the network, filtered to
  the moments a friend sent and away from the app’s own artwork. A clear button empties it.

It saves what is already on your phone and does not touch anything you would pay Locket for.
A tool that fakes a paid subscription was asked for and not built — that takes money from the
people who make the app.

## 0.1.0

The first release. It keeps Locket from reporting your phone as jailbroken.

- **Three companies stop being told.** Locket's analytics (OneSignal), its ad attribution
  (AppsFlyer) and its own code each run a jailbreak check and send the answer home. On a
  modified phone that answer can count against your account. All three now come back clean.
- **It answers only the jailbreak questions.** The checks ask the system a small fixed set —
  is this file here, can this app be opened, is this folder writable, is this library
  loaded. This sits underneath and answers only those, only for the handful of paths a
  check looks at. Everything else the app asks the system passes straight through.
- **Hold two fingers anywhere in Locket** for a small screen that shows how many checks were
  answered and which kind, so you can see it is working — Locket itself gives no sign.
- Arabic and English, and it appears in Settings › Albrhi with the rest.

It does not touch payments or subscriptions. A tool that unlocks paid features by faking a
subscription was reviewed and deliberately not built.
