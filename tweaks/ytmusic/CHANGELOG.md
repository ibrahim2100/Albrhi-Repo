# Albrhi for YouTube Music — what changed

## v0.1.0

**No ads, and background playback left alone — and no Premium.** Two files carried over from
YTMusicUltimate under GPLv3: the advertising hooks (`YTAdsInnerTubeContextDecorator`, `YTDataUtils`,
`YTAdShieldUtils`, and the monetisation flags on `YTIPlayerResponse`) and the background-playback
ones, including the upsell notification that interrupts it.

**This tweak does not unlock a paid subscription.** The tweak these files come from answers
`-isPremiumSubscriber` with YES on six classes, which tells YouTube Music the account is a paying
one. That is the same line this project drew for Locket's `Check0verPlus` and again for Spotify, and
it is the one thing not carried over.

**Why these two files could be taken and that one could not is a fact, not a judgement:** neither of
them ever asks what the account is. `RemoveAds.x` does not contain the word. That was measured in
the upstream sources before a line was copied.

**Three edits, all about who decides**, and each written where it is rather than left to a diff:

- Each file's hooks are wrapped in a `%group`. Logos installs an ungrouped `%hook` from its own
  constructor, **before Albrhi's gate is consulted** — so "off" would still mean hooks in the
  process. The Spotify port learned this the expensive way, where three ungrouped hooks crashed the
  app whatever the switch said.
- Each file gains a one-line installer, because a Logos group's `%init` is file-scoped and cannot be
  reached from another file. Albrhi Watch does the same.
- Upstream's own `%ctor` is removed. It seeded five keys to 1 whenever they were missing, turning
  every feature on at load no matter what anyone had decided. Albrhi's switch composes that
  dictionary now — **two switches for one feature is one switch too many.**

It patches one app, so it takes an ordinary row on Albrhi's app list rather than a page of its own.

> **The hooks are not this project's work.** They are
> [YTMusicUltimate](https://github.com/dayanch96/YTMusicUltimate) by **dayanch96**, under GPLv3 —
> the same licence Albrhi ships under, which is what makes carrying them over lawful. Albrhi adds
> the gate and the packaging.
