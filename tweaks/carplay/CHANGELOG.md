# Albrhi CarPlay — what changed

## v0.3.0

**The first real step toward running other apps on the CarPlay dashboard — the feature
this whole project exists for, and the riskiest release yet.** Enter bundle
identifiers in Settings › Albrhi CarPlay › Apps on the CarPlay dashboard and, on iOS
16 or 17, that app's real interface appears on the car screen instead of a template
scene when CarPlay opens it.

**How it works, and where the risk actually sits.** A second dylib, AlbrhiCPApp,
loads into every app that links UIKit — the standard MobileSubstrate idiom for
"every foreground app" — and rewrites its own incoming CarPlay scene role from
CPTemplateApplicationSceneSessionRoleApplication to the ordinary
UIWindowSceneSessionRoleApplication, but only for a bundle identifier actually on the
list; every other app loads the same hooks and they do nothing. Both hooked
selectors, `-[UISceneConfiguration initWithName:sessionRole:]` and
`-[UISceneSession role]`, are public, documented UIKit API intercepted for a purpose
Apple did not intend — not private symbols. A bug here can only crash the one app
that was actually enabled, never SpringBoard. SpringBoard's own dylib gained a
matching admission spoof: it answers CarPlay's `CARCapableApp`/`SBStarkCapable`
questions for an enabled bundle by hooking `LSBundleProxy`'s entitlement getters,
which is the runtime admission path CarPlay used before iOS 18.

**Known to work on iOS 16 and 17 only.** iOS 18 moved the real admission gate to
`+[CRCarPlayAppDeclaration requiredEntitlementKeys]`, which reads code-signed
entitlements at app-registration time — outside any process a tweak can inject into.
Reaching it needs an on-disk patch (re-signing the target app's binary and trusting
its cdhash in the jailbreak's own trustcache), which is a meaningfully bigger,
harder-to-reverse step than anything else in this project so far and is deliberately
not in this release. On iOS 18 the admission spoof installs and does nothing
useful, same as everywhere else it cannot help.

**What this deliberately does not do yet.** An app with no scene manifest at all has
nothing for the role rewrite to resolve against and simply never gets a car scene —
no crash, the feature just does not reach that app; moving its one window onto the
car display and back is a separate piece for later. Multi-scene support is not
forced for an app that has not already declared it in its own Info.plist, so such an
app may not hold both a phone scene and a car scene at once. Dashboard-widget and
instrument-cluster scene roles are left alone on purpose — putting a full app UI
where the car expects a small widget is not an improvement.

**Not validated on-device, more than anything else in this project so far.** Built,
checked, and reasoned from public documentation plus architecture read from two
open-source references (see CLAUDE.md) — never run against a real CarPlay head unit.
Settings › Albrhi CarPlay's master switch still turns every hook in both dylibs off
without uninstalling anything if a device does not get on with this release, and
leaving the bridged-apps list empty (the default) means AlbrhiCPApp's hooks load
into every app on the phone and do nothing, everywhere, until an identifier is
actually entered.

## v0.2.0

**A real settings page, and settings that actually reach across the sandbox.** Settings
› Albrhi listed "Camera" and "SpringBoard" as if they were two separate apps this
project patches — they are the two processes one CarPlay tweak happens to need, and the
panel now shows one "Albrhi CarPlay" row for both, which pushes to a full page: the
master switch, the recording-audio fix on its own switch, a three-way microphone choice
(iPhone, Car, Automatic), and verbose logging.

**And those settings were never actually reachable before this.** 0.1.0 registered its
preferences with `NSUserDefaults standardUserDefaults`, which is local to whichever
process loaded the dylib — Camera's defaults and SpringBoard's defaults are not the same
storage, and neither is reachable from Albrhi Panel running inside Settings. Every
preference this tweak has moves to the same cross-sandbox path
`shared/src/SCIPanelGate.h` already built and proved for the per-app on/off switch:
`SCIPanelReadBool`/`SCIPanelReadString`, generalized from what was a bool-only,
switch-only reader. The on/off switch itself moves too, from asking "is *this* process
enabled" (which would have split into two unrelated answers, one for Camera and one for
SpringBoard) to asking about CarPlay's own identity by name, from either process, through
the domain's one shared key.

Nothing about the audio fix or the screen watcher changed — same two features, same
public API, still not validated on-device.

## v0.1.0

**The first release, and it does one thing: keeps your car's speakers in high quality
while Camera is recording.** Nothing else the owner asked for — the app launcher, the
dashboard, wallpapers, themes — is in this version.

That was a deliberate choice, not a shortcut. This project's own ground rules, learned
across every other tweak here, are to read the device rather than guess at it and to
never claim something works before it has actually been tried. Neither is possible yet
for showing another app's screen on CarPlay: doing that means walking through private
SpringBoard classes this project has only read about in a licensed, open-source
reference (`carplay-cast` by Ethan Arbuckle, Apache-2.0 — credited here because its
architecture is what this project's own design is informed by), never confirmed
against a real device, and a mistake at that layer does not crash one app — it can
crash the whole home-screen experience. That is worth building carefully, in the open,
with a device to test each step against, not in one large release nobody has run yet.

The audio fix does not have that problem. It is two calls to public, documented
`AVAudioSession` API — asking for the car's speakers to stay on their high-quality
Bluetooth profile while the microphone comes from the iPhone instead of the car — and
it only ever does anything while a recording is actually running, restoring exactly
what it found the moment recording stops.

**Not validated on-device.** This has been written and checked with `tools/check.py`,
which catches build-time mistakes, but nothing here has been run on a real phone in a
real car yet. The first install is the actual test.

There is no settings screen yet either — the fix defaults on, and the microphone
preference defaults to "iPhone". Both are already read from `NSUserDefaults` with
named keys, so a settings page can be added without touching the hooks themselves.

Next: confirm the audio fix actually helps on a real device, then start the CarPlay
screen detection already in this release (`SCICPScreenWatch`, SpringBoard-side, reads
only public `UIScreen` notifications — no private API yet) toward an app launcher.
