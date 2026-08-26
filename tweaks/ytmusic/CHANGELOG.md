# Albrhi for YouTube Music — what changed

## v0.6.0

**The advertisement for Premium is hidden. The subscription is still not claimed.**

The upgrade page, the periodic *subscribe* prompt, the upsell dialogs, the promo sheets and
interstitials, the memento promotions, the side-panel upgrade entry, the offline and background
upsell renderers, and the throttle that decides when to show the next one — all refused.

**This required reading upstream's file method by method rather than judging it whole.** 0.2.0
refused `PremiumStatus.x` entirely, which was right at the time and too blunt: it is two different
things in one file. Hooks that answer *is this account paying* with YES are taking money from the
app's developers. Hooks that stop the app **asking you to pay** are closing an advertisement, and
the app behaves for a free account exactly as it did before.

**What did not come, named rather than implied:** `-isPremiumSubscriber` and its setter on five
classes; `isCurrentUserPremium`, `isMobileAudioTier` and the queue's version of it; the flags that
pretend the build is internal or under test; and a `-init` that wrote `_isMobileAudioTierMode` into
a private ivar by KVC — the same claim, written by hand.

Forty-six one-line `if (…) %orig;` bodies were opened out for the Logos this repository pins, which
check.py caught before the compiler did.

## v0.5.0

**Audio or video, and a default between them** — the one feature of the upstream port whose
neighbours were carried over and which was left behind.

YouTube Music decides for itself whether a track plays as audio or as its video, and hides the
switch on most of them. These hooks open it everywhere — the mode controller, the queue config, the
quality pickers, the playability renderer — and honour a stored default.

**And the settings row for it was already here, writing a key nobody read.** `Player settings`
carried the audio/video segmented control from the moment the settings screen was ported in 0.4.0:
it stored `audioVideoMode` faithfully, and nothing in the tweak ever looked at it. A control that
saves a value no code consults is the same lie as a switch that changes nothing, and it shipped for
two releases.

Audio is the default, which is what a music app is for and what upstream chose too. It is written
only when unset, so a choice made on that screen survives an update.

## v0.4.1

**The settings screen crashed the moment it opened, and the cause is one this project had already
written down — twice, in this very file.**

The pages it offers were three parallel things: a title array, a destination array, and a row
*count*. Removing the Premium and scrobbling rows meant editing all three. Two were edited. The
count still said seven for five entries, so the table asked for row 5 of a five-item array and threw
before anything was drawn.

**A rule written beside two of three copies is not a check.** The comment restating "a parallel
array must be walked in lockstep" was added to this file in the same commit, ten lines above the
number that was wrong. There is one array now — `+settingsPages` — and the count, the cell and the
destination all read it, so a row cannot exist without somewhere to go.

**Two links repointed while fixing it, and the first is close to a licence matter.** *Source code*
pointed at upstream's repository; this binary is a modified GPLv3 work, so that has to mean *this*
source — sending someone to upstream hands them code that is not what they are running. The Telegram
row was upstream's support channel, where a person with a problem in Albrhi's build would have been
sent to a project that never shipped it; it is now a credit row naming YTMEnhanced and its licence.

## v0.4.0

**The settings screen, which ten features were shipped without.**

0.2.0 and 0.3.0 carried the hooks and not the page that controls them. The report was exactly that
— *no settings, no options, nothing, and I never saw the lyrics* — and it was right: there was no
way to reach a single switch, no source picker, no romanisation toggle, and nothing to confirm that
lyrics were even turned on. A tweak whose options cannot be reached is a tweak with no options.

It is carried over from YTMEnhanced under GPLv3 like the rest: a row in YouTube Music's own account
menu that opens the page, with Player, Theme, Navigation bar, Tab bar and Translation inside it.

**Two rows deliberately did not come.** *Premium* drives `-isPremiumSubscriber`, which this project
refused by name for Locket and again for Spotify — and keeping a switch for hooks that were refused
would be a screen that lies. *Scrobbling* configures code that is not here at all, which is the same
lie pointing the other way. The destination list was edited in lockstep with the row list, because
two parallel arrays edited apart is a fault this project has already paid for once, and it stays
plausible while being wrong throughout.

## v0.3.0

**Synced lyrics**, carried over from YTMEnhanced under GPLv3: a panel on the now-playing screen fed
by six providers -- LRCLib, Genius, MusixMatch, NetEase, the video description, and YouTube Music's
own lyrics where it has them -- with romanisation, a source picker, a timing offset, and selectable
text. It ships **on**, because that is what was asked for; upstream leaves it off.

**What that costs is in the package description rather than left to be found.** A lyrics feature
asks outside services what is playing. There is no version of it that does not. Translating those
lyrics is a separate switch, off, and inert without a key the user supplies.

**And this release is the first here that was verified rather than only compiled.**

`tests/host/run.sh` builds the pure modules -- the LRC parser, the matching pipeline, the caches,
the romaniser, the description extractor -- against the macOS SDK's iOSSupport frameworks and runs
them on the Mac. **29 tests, 0 failures**, in about a second. The arrangement is upstream's; what is
ours is the source list and the resource bundle.

This matters beyond one feature. CLAUDE.md has always said compilation is the second of three gates
and the third is a device -- **true of every hook, and never true of everything**. Three of this
project's most expensive bugs lived in exactly this layer: a quality ladder that needed
`raw → parsed → deduped` counted separately, a parallel array walked by value instead of in
lockstep, and a date label measured in one coordinate space and drawn in another. All three are pure
functions of their input. All three could have failed on this Mac in a second.

Two of the three findings came from the tests themselves rather than from the compiler: a paths test
that fails unless the run script sets `YTMU_CACHES_ROOT` (trimmed out of the first draft), and a
localization test asserting a resource bundle this package did not ship. The second one was fixed by
**shipping the bundle** -- 27 languages including Arabic -- rather than by deleting the test, which
is the difference between a suite that proves something and one that agrees with you.

check.py also gained a fix rather than a rule: `'"'` is a character literal, not the start of a
string, and three lines of a hand-written parser in the carried-over module were being reported as
unterminated. The oracle settled it in one command, as it has every time.

## v0.2.0

Seven more features, carried over from **YTMEnhanced** by py233 (github.com/py233/YTMEnhanced) under
GPLv3 -- itself derived from YTMusicUltimate, which this tweak was already built from. The
attribution ships in `control`, here, and in the package notice.

- **The speed control YouTube Music already has and hides**, on the player.
- **Seek buttons**: previous and next become back and forward, with the original behaviour still
  there on a long press.
- **No autoplay radio** after the queue ends, refused on every class that decides it.
- **Casting**, enabled where the app gates it.
- **The history, cast and filter buttons** in the navigation bar, hidden on request.
- **A true-black theme**, keyboard included.
- **SponsorBlock**, for the one category a music app has: `music_offtopic`.

**Three of them are off until switched on, each for its own reason.** SponsorBlock sends the track's
id to sponsor.ajay.app, which is a third party learning what is being played -- the same cost
tikwm.com carries in the TikTok tweak, and the same answer: a switch that starts off and a row that
says what turning it on does. The theme and the hidden buttons are appearance, and changing how
somebody's app looks on the day they update is not a default anyone asked for.

**`PremiumStatus.x` is not here, and that is the fourth time this project has said so.** It answers
`-isPremiumSubscriber` with YES on six classes. The same shape was refused by name for Locket's
`Check0verPlus` and again for Spotify. Nothing carried over here ever asks what the account is.

Four edits were needed to make the carried-over files build, and each is a rule this repository
already had:

- One-line `%orig` bodies opened out, and `cond ? %orig(NO) : %orig;` split -- the Logos pinned here
  needs `%orig` alone in a full block and refuses two of them in one expression.
- **`%orig` as the middle operand of a ternary** does not compile, while `? nil : %orig` and
  `%orig ?: fallback()` do. check.py grew a rule for it, narrowed twice against the other tweaks
  before it landed.
- `NavBar` renamed from `.xm` to `.x`: nothing in it is C++, and in a `.xm` its installer is emitted
  with C++ mangling while the header declares it plainly, so the link fails on a symbol that is
  there under another name.
- The seek buttons' `-valueForKey:` on `_nowPlayingView` is now guarded by a real runtime question.
  `-valueForKey:` runs the app's own code; this project crashed Instagram once by trusting it.

## v0.1.1

**The rootless build failed and every local build had passed, because every local build was
roothide.** Upstream writes one method body as a ternary whose branches are `%orig(YES)` and
`%orig` — two different argument structures in one expression. The Logos in the roothide Theos
accepts it; the Logos in stock Theos answers `Invalid argument structure in %orig` and stops.

`%orig` must sit alone on its own line inside a full block, which this repository already knew and
had written down. What it did not have written down is the reason it went unnoticed: **the two
Theos installs here carry different versions of Logos, so a local build proves one flavour and
guesses at the other.** CI builds rootless first, which is why it was the one to say so.

Fixed as a plain `if`/`return`, and both flavours now build locally before anything is pushed.

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
