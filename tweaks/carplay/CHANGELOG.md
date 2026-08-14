# Albrhi CarPlay — what changed

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
