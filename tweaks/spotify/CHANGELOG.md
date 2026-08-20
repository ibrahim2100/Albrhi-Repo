# Albrhi for Spotify — what changed

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
