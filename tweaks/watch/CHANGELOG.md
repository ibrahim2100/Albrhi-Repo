# Albrhi Watch — what changed

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
