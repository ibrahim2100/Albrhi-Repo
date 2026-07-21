# extra-debs

Drop `.deb` files here to publish them through the Albrhi source.

On the next push to `main`, CI indexes everything in this folder alongside the
Albrhi builds and pushes the result to the `gh-pages` branch. Nothing else to do —
no version numbers to edit, no index to regenerate by hand.

The repo generator refuses to publish two packages that share a name, version and
architecture, since a package manager cannot tell them apart. If that happens the
build fails with the offending pair named.

## Before adding someone else's tweak

Redistributing a package you did not write is a licensing question, not a technical
one. Check that its licence permits redistribution, or ask the author. Paid and
closed-source tweaks generally do not permit it, and mirroring them without
permission is how repos get taken down.
