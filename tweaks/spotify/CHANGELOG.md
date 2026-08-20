# Albrhi for Spotify — what changed

## v0.2.2

**The crash was one missing line, found by reading the reference's own call site rather than by
bisecting ours.** Upstream writes

```swift
if NSClassFromString("HUBViewModelBuilderImplementation") != nil {
    AdBlockerGroup().activate()
}
```

and this port took the activation while leaving the condition behind. **Activating an Orion group
whose target class is absent does not fail politely** — and a class that exists in the Spotify
version upstream is maintained against is a coin toss on any other.

The rule this project already keeps for `%init`, now written for Orion too: **a hook is installed
only after the thing it hooks is confirmed to be there.** Logos answers that by never attaching to
an absent class; Orion does not, so the caller must.

SponsorBlock is guarded the same way, on **both** of its targets — upstream activates it unguarded
and merely logs whether the player class was found. One of the two is a Swift class, so its runtime
name is mangled and a rename between Spotify releases is silent.

**Two things ruled out by comparing against the upstream package the owner supplied**, rather than
left as suspicions: our dylib links Orion exactly as theirs does, and neither carries the Swift
back-deployment shims — so `-runtime-compatibility-version none`, added earlier to make the link
succeed, is not a difference from a build that works.

## v0.2.1

**0.2.0 crashed Spotify. Clean share links is removed — install this one.**

Its three hooks were **the only ungrouped ones in the port**: eleven of the fourteen hooks here name
a group, and Orion activates an ungrouped hook at startup, before any gate is consulted. So those
three installed themselves whatever Albrhi's master switch said, and a `ClassHook` on a class this
build of Spotify does not have does not fail quietly.

**A switch that cannot reach the thing it names is worse than no switch**, so the feature is out
rather than pretending to be governed. Everything else was already grouped and stays: the ad
blocking, the Premium popups, and SponsorBlock — all behind `%init`-shaped gates, all inert when the
master is off.

The general rule, and the reason this was found in one look rather than by bisecting: **count the
hooks against the groups.** A file with hooks and no group is a file that runs regardless of what
you decided.

## v0.2.0

**SponsorBlock for podcasts, and clean share links** — carried over from EeveeSpotify under GPLv3
alongside the ad blocking.

Sponsored, self-promotion and interruption segments are skipped from SponsorBlock's community
database, with the toast that says one was skipped. **Off by default**: it asks a third-party server
about what is playing, and this project does not pay a privacy cost on somebody's behalf — the same
rule the TikTok tweak's external-download switch already follows, stated on its own row.

**Two switches for one feature is one switch too many.** SponsorBlock keeps its own `enabled` flag,
defaulting off, because upstream drives it from a settings screen this port does not carry. Left
alone the group would activate and skip nothing — a switch that moves and changes nothing. Albrhi's
switch writes that option rather than sitting beside it.

**The submit-and-report screens are not here, and the reason is the SDK.** `iPhoneOS16.2.sdk`
carries a SwiftUI interface built by Swift 5.7.1 and the toolchain here is 6.3.3, which refuses to
rebuild the module from it. Those four files are the only SwiftUI in the port, and they are the part
that *contributes* segments rather than the part that skips them. Their three entry points are kept
as a shim so **every ported file stays byte-for-byte diffable against upstream** — one line in one
file is the only edit made to any of them, and it says so where it is.

Upstream's `writeDebugLog` wrote every message to a file, forever. It goes to `NSLog` here, for the
reason Albrhi NextUp's log was switched off: a growing record of what somebody is listening to, from
a tweak whose neighbours exist to stop watching being reported at all.

## v0.1.2

**Nothing was hooked. Orion never started, and the build gave no sign of it.**

The package compiled, linked, installed and loaded; it logged its version and read its switches. It
installed **zero hooks**, because Orion's runtime has to be started and nothing started it. Found by
asking the built dylib instead of trusting the build — and proved by building it both ways:

| | `__init_offsets` |
|---|---|
| without the constructor | **0** — no initialiser section at all |
| with it | **1** |

An empty initialiser section means no code ran at load. The reference tweak calls `orion_init()`
from a constructor of its own, which is what prompted the check; **a build succeeding is not a hook
being installed**, and this is the first tweak here where those two came apart.

Worth keeping for the next Swift tweak: Logos writes its own `%ctor` and a Theos Swift/Orion tweak
does not.

## v0.1.1

Part of `com.albrhi` rather than a package of its own: it installs with the rest, the way Instagram
and TikTok do. Its own package identity stays reserved — `com.albrhi.spotify` — and the suite
declares `Conflicts` and `Replaces` on it, plus removes it in `preinst`, because `dpkg -i` honours
neither.

## v0.1.0

**No ads in Spotify — and no Premium.** Three hooks, carried over from EeveeSpotify under GPLv3:
the ad services are refused at load (`AdsServiceImpl`, `InStreamAdsService`,
`EmbeddedNPVService`), the home feed's ad components are filtered out of the JSON before it is
rendered, and the "go Premium" popups are dropped at `presentPopUp(_:)`.

**This tweak does not unlock a paid subscription.** It does not touch your account, does not
report you as a subscriber, and does not remove the skip limit. The upstream tweak's headline
feature is exactly that, and it is the one thing not carried over — this project refused the same
thing once already, by name, when Locket's `Check0verPlus` was reviewed and left alone.

**Why those three files could be taken and the rest could not** is a fact about how they were
written, not a judgement: none of them asks what the account is. The ad blocking is independent of
the subscription state upstream too, which was measured before a line was copied rather than
assumed.

> **The ad blocking is not this project's work.** It is
> [EeveeSpotify](https://github.com/SideloadLabs/EeveeSpotifyReincarnated) by **Eevee** and the
> **SideloadLabs** team, under GPLv3 — the same licence this repository ships under, which is what
> makes carrying it over lawful. Albrhi adds the gate, the settings page, the bilingual interface
> and the diagnostics.
