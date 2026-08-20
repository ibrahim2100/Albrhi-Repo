# Albrhi for Spotify — what changed

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
