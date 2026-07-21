# Repository and tooling changelog

Work on the source repository, its build pipeline and its tools. None of this
reaches the package a user installs — that history lives in `CHANGELOG.md`, which
also feeds the release notes and the Sileo package page.

## Unreleased
- **Publishing keys the filename on the package identity**
  (`package_version_architecture.deb`) instead of reusing the uploaded file's name.
  A rootless package and its roothide conversion keep the same source filename, so
  the second silently replaced the first in the source.
- Replacing an existing package now asks first rather than overwriting quietly.
- Packages added to the source are now labelled by jailbreak automatically —
  `(rootless)`, `(roothide)` or `(rootful)`, read from the package's own
  architecture. Several flavours of one tweak no longer appear under identical
  names with no way to tell them apart.
- Control archives compressed with xz are converted to gzip by the build, so a
  package that the browser editor cannot read becomes editable after one push.
- The browser editor accepts those packages instead of refusing them: it offers to
  publish the file untouched, which is what the error text had been telling people
  to do without giving them a way to do it.

## Alongside v3.1.8

- CI no longer rebuilds a version it has already released. It reads the version from
  `control`, and if that release exists it reuses the published packages instead of
  spending minutes compiling identical output. Bump the version to build, or run the
  workflow manually with *force rebuild* to override.

**Repo tooling**
- The deb editor is now a control panel: a Packages tab listing what is in the
  source with a Remove button for each, an Add-or-edit tab, and a Connection tab.
- gzip support is detected when it is used rather than at page load, so a browser
  that has the API but fails on it still falls back cleanly.

## Alongside v3.1.7

- The deb editor works on iOS 16.1 and older. It relied on `DecompressionStream`,
  which Safari only gained in 16.4 — and since every browser on iOS is WebKit, no
  browser on an older phone had it. It now falls back to a DEFLATE decoder written
  out longhand, verified against gzip files produced elsewhere.
- Removing a package from `extra-debs/` now removes it from the source. The repo
  index was copied over rather than rebuilt, so deleted packages lingered on the
  published branch and kept being listed in Sileo.

## Alongside v3.1.5

- The repo landing page builds its package list from the live index, so it stays
  accurate as packages are added.
