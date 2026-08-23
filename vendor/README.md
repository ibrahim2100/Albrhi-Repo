# Vendored third-party code

These directories hold code this repository did not write. They are copied into
the tree so a tweak builds without extra submodules, and **they are not covered
by this repository's GPL-3.0 licence** — each remains under its original author's
terms.

| Directory | Project | Author | Source |
|---|---|---|---|
| `LightMessaging/` | LightMessaging — header-only mach IPC for jailbroken iOS | Ryan Petrich | https://github.com/rpetrich/lightmessaging |
| `libSandy/` | libSandy public header (`libSandy.h`) | opa334 | https://github.com/opa334/libSandy |
| `dav1d/` | dav1d — VideoLAN's AV1 decoder, built for iOS | VideoLAN | see `dav1d/README.md` |

Neither of the first two is linked as a binary: LightMessaging is header-only,
and libSandy is loaded at runtime through `dlopen`, with the device installing
`com.opa334.libsandy` as a package dependency. `dav1d/` is different in kind —
prebuilt static libraries, but built from VideoLAN's own source at a pinned tag
by this repository's own CI, and its own README states that provenance in full.

## Why this file exists

The first two arrived with **Albrhi NextUp**, the GPLv3 port of
[NextUp 3](https://github.com/Yves000/NextUp3) by Yves. Upstream ships exactly
this table in its own `vendor/README.md`; the port carried the headers and left
the table behind, so two directories of somebody else's code sat here for
several releases saying nothing about whose it was or under what terms.

That is the one thing this project treats as an obligation rather than a
courtesy — the same reason SCInsta is credited in Instagram's package metadata
and Yves's authorship is in NextUp's `control`, changelog and settings footer.
`dav1d/` was never affected: it documented itself from the day it was added,
and it is listed above so this table describes the whole directory rather than
the two entries that prompted it.
