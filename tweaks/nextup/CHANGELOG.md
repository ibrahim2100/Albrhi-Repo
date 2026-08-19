# Albrhi NextUp — what changed

## v0.1.0 — packaging notes

The port compiles: ten thousand lines built clean for arm64 and arm64e, linked, signed,
packaged both flavours, and released. Getting there took four packaging failures, none
of them in the ported code and every one of them now a `tools/check.py` rule or a
documented rule in `CLAUDE.md`:

- **`shared/tweak.mk` was appending JGProgressHUD, `SCIPanelGate.m` and
  `SCISubstrateShim.m`** to a tweak that uses none of them, and compiling code written
  for a 15.0 deployment target at this tweak's 14.2. This is the only tweak here that
  does not include that file; the flags worth having are copied into its Makefile.
- **An unclosed parenthesis in `control`** — opened on one line of the Description and
  closed on the next. Theos reads that file line by line and refuses to package.
  check.py rule 20.
- **`layout/DEBIAN/postinst` was mode 644.** `chmod +x` is a no-op on Windows, so git
  stored a script CI would not run. check.py rule 21 reads the mode from the git index
  rather than the filesystem, for exactly that reason.
- **`build.sh`'s roothide identity swap assumed `Conflicts` named nothing but the other
  flavour.** NextUp also conflicts with `com.yves.nextup3`, and the second list entry
  made an anchored pattern match zero times. It now swaps the identifier as a list
  element; checked against all seven controls.

The generator registry also needed a `nextup` entry — the workflow was passing the
depiction *slug* where its *key* belongs. That step runs locally in seconds, and running
it once before pushing would have caught it; this project's own rule about testing
scripts before shipping them applies to more than shell one-liners.

## v0.1.0

**A port of [NextUp 3](https://github.com/Yves000/NextUp3) 1.1.2 by Yves, under the GNU
GPL v3.** This is not an original tweak and the changelog should not read like one: the
design, the private-API research and very nearly all of the implementation are Yves's
work. What made carrying the code over lawful — rather than reading it for architecture
the way this project treats the unlicensed TikTok references — is that upstream is
GPLv3, the same licence this repository ships under.

**What it does.** A row under the now-playing controls showing what plays next: title,
artist and cover, on the Lock Screen, in Control Center and in the Dynamic Island. Tap
the cover to play that track now, or skip it, without opening the app. Five apps —
Apple Music, Apple Podcasts, YouTube, YouTube Music and Spotify — each read through
that app's own playback queue, so the row shows what the app itself would play next.

**How it is built, because it is unlike every other tweak here.** Seven injected
processes doing two different jobs: five providers inside media apps that read the
queue, and a display side in SpringBoard and MediaRemoteUI that draws the row. They
cannot see each other's memory, so they talk over a LightMessaging mach service (with a
libSandy profile, since an app sandbox cannot register a bootstrap service on its own)
plus Darwin notifications for the change and skip signals. One binary serves all seven;
every hook is chosen at runtime from the host process and the iOS major version, which
is how iOS 14.2 through 26 are covered from a single build.

### What this port changed

**The Settings pane was replaced by a page in Albrhi Panel.** Upstream shipped its own
PreferenceLoader bundle; every Albrhi tweak is configured from one place instead, so the
filter plist declares `SCIPanelGroupIdentifier` / `SCIPanelDetailController` and
`SCIPanelScan` collapses the seven-process filter into a single row that pushes to
`SCINUSettingsController`. Exactly the arrangement CarPlay already uses, and for the same
reason: nine switches do not fit in one switch cell.

**What the port deliberately did *not* change is the mechanism underneath.** The new page
writes to upstream's own CFPreferences domain and publishes upstream's own
`notify_state` token, bit layout included, because the reader compiled into the tweak
(`NUPrefs.m`, unchanged) has those names built in. Rebranding the domain would have been
a silent disconnect — every switch writing somewhere the tweak never looks. Both channels
are still written: CFPreferences is the value that survives a reboot, the token is what
makes a switch take effect without a respring.

**The `.lproj` tree is kept and the Settings bundle became resources-only.**
`NULocalization.h` finds its strings by walking from the tweak's own dylib path to
`NUPrefs.bundle`, so that bundle's name and location are load-bearing and stayed
upstream's. Twenty-seven languages survive, Arabic among them — which is how this port
satisfies the repository's bilingual rule without a second string table that would
duplicate what upstream already ships.

**Five `%orig` sites were reformatted, and nothing else in the sources was touched.**
`@try { %orig; }` and two one-line method bodies are fine under upstream's build, but
this repository has a ground rule about `%orig` needing its own line — bought with real
failed builds — and `tools/check.py` enforces it. Whitespace only; the semantics are
identical.

**A `Conflicts` on `com.yves.nextup3`.** Both packages register the same mach service
names, so they can never be installed together.

### Not confirmed on a device

Nothing here has run on a phone yet, and this one injects into **SpringBoard**. The
package is deliberately not published: `buildnextup.yml` builds it and stops, the same
withholding CarPlay is under. A wrong hook in an ordinary app kills that app; a wrong
hook in SpringBoard takes the home screen with it.

### Two `tools/check.py` rules were narrowed, not worked around

Both fired on this port and both were wrong, and the fix went into the rule rather than
into the code being checked:

- **Duplicate `@interface`** reported twelve pairs that never share a translation unit —
  `NUMusicProvider.m` imports neither `NUPrivate.h` nor the header that does. The rule
  now resolves each compiled unit's transitive quoted-import closure and reports only
  what clang would actually reject. The Instagram bug it was written for is still caught.
- **"Both a property and a method"** flagged seven ordinary hand-written getters. Its own
  comment names the real failure — `- (void)close` cannot be a getter *because it returns
  void* — so it now fires only on a void return.

`CLAUDE.md` already says a check that cries wolf gets ignored, and that the other tweaks
are the oracle: all six still pass unchanged after both edits.
