# Albrhi Changelog

## v1.0.8

- The source updates again. The step that published it had been getting stuck every
  run, holding the whole thing for as long as it was allowed to. It is gone, and the
  package list is now served straight from the branch it was already being written
  to — the simpler arrangement, with nothing to wait on.

## v1.0.7

- Fixes the source not updating. Publishing now works with how the repository is
  actually set up instead of assuming one particular setting, so the package list
  is refreshed either way, and the run checks the live source afterwards rather
  than reporting that a step finished.

## v1.0.6

- The package page in Sileo now describes this package rather than the old separate
  Instagram one, and is generated from this changelog so it cannot go stale.

## v1.0.5

- The roothide package is now checked properly before it is built, by reading the
  libraries each part links against rather than only where the files sit. A package
  can look right and still be built the wrong way, and that is what Sileo was
  refusing.

## v1.0.4

- Fixes the build, which 1.0.3 broke before it produced anything.
- The roothide package is now checked to actually be one before it is built, instead
  of being found out after installing it.

## v1.0.3

- Fixes the roothide package installing as a rootless one. The combined package was
  built with its own description, which threw away the details the build tool fills
  in to say which kind of jailbreak a package is for.

## v1.0.2

- Includes the Instagram fix that brings back the reels download button.
- **Now really builds both flavours.** 1.0.0 and 1.0.1 produced a rootless package
  only — the roothide one was never built, and nothing was counting.

## v1.0.1

- **Now really removes the old separate packages.** 1.0.0 declared that it replaced
  them, which a package manager honours when installing from a source but which is
  ignored when you install a .deb by hand — so both copies stayed and both were
  loaded. It removes them itself now, however you install it.

## v1.0.0

**Everything Albrhi makes, in one package.**

- Install one thing. You get the Instagram tweak, the YouTube tweak and the settings page.
- Update one thing. Every tweak updates together.
- **Settings › Albrhi** lists every app Albrhi patches, with a switch each. Turn one off
  and Albrhi does nothing inside that app, without uninstalling anything and without
  losing your settings. Close and reopen the app for the change to take effect.
- New Albrhi tweaks will arrive in this same package and appear in the same list, so
  there is never a second thing to install.

Installing this removes the separate Instagram, YouTube and Panel packages. Your settings
live inside each app and are not touched.
