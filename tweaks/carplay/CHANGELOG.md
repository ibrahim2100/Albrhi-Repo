# Albrhi CarPlay — what changed

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
