#!/usr/bin/env bash
#
# Downloads the .deb assets of the newest published releases into one directory.
#
# Usage: tools/fetch-published-debs.sh <out-dir> <owner/repo> [keep-per-package]
#
# This exists so the APT index can be built from what is *published* rather than
# from whatever the current run happened to compile. That distinction is what lets
# more than one workflow in this repository rebuild the index safely.
#
# make-repo.sh wipes the published debs/ directory and rebuilds it, deliberately, so
# that a package deleted from the source disappears from Sileo instead of lingering
# forever. The moment a second tweak got its own workflow, that same wipe became a
# hazard: an index built from one tweak's build output would erase the other tweak
# from the source. Deriving the index from the releases removes the hazard at its
# root -- every workflow sees the same complete set, and whichever finishes last
# publishes a correct index rather than a partial one.
#
# It also closes a gap that existed with one tweak: when a build was skipped because
# the version was already released, the index depended on a separate download step
# succeeding. Now there is only one source of truth.
#
# Requires: gh (authenticated via GH_TOKEN) and dpkg-deb.

set -euo pipefail

OUT_DIR="${1:?output directory required}"
REPO="${2:?owner/repo required}"

# How many versions of each package stay installable.
#
# A published version must stay reachable after the next one goes out: if a build
# turns out to be broken on a device, rolling back has to be possible from Sileo
# rather than by hunting for an asset on the releases page. Three, not all of them --
# the source is a rollback path, not an archive.
KEEP="${3:-3}"

# Directories of freshly built .deb files to fold in, space separated.
#
# Asking the API for "every published release" a minute after publishing one does not
# reliably include it: a YouTube release published at 17:05:28 was missing from the
# listing the run asked for at 17:06:41. The listing is eventually consistent and this
# script runs inside the "eventually", so the run's own output is copied in as well.
#
# It goes through the same renaming as everything else, and that is the whole point of
# it being here rather than a `cp` in the workflow. The first attempt copied the build
# straight in under its own name -- com.albrhi.youtube_0.6.0+rootless.deb next to the
# gathered com.albrhi.youtube_0.6.0_iphoneos-arm64.deb -- two files, one identity, and
# the collision guard in make-repo.sh stopped the release. One naming rule, one place.
LOCAL_DIRS="${4:-}"

# Which tweak this run is responsible for, as a directory name under tweaks/.
#
# A run is strict about its own tweak and forgiving about the others, and that asymmetry is
# the whole point. The first version of this guard required every tweak's current version to
# be present in every run, which made the two workflows fail each other: YouTube's run could
# not see Instagram's release, Instagram's run could not see YouTube's, and both refused to
# deploy. Neither was broken. The index simply stopped being published at all, which is a
# worse failure than the stale index this was written to prevent -- a stale index serves an
# old version, a guard that never passes serves nothing new ever again.
OWNER_TWEAK="${5:-}"

# How far back to look. Bounded, because every push rebuilds the index and walking
# the entire release history each time would cost more the longer the project lives.
SCAN=40

mkdir -p "$OUT_DIR"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# Newest first, and prereleases included -- /releases/latest skips those, and this
# project's releases have been published as prereleases before.
tags=$(gh api "repos/${REPO}/releases?per_page=${SCAN}" \
       --jq '.[] | select(.draft == false) | .tag_name')

if [ -z "$tags" ]; then
    echo "::warning::No published releases found in ${REPO}"
    exit 0
fi

# Package id -> how many versions of it have been taken so far. Kept in a file
# rather than an associative array so this runs the same under bash 3, which is
# still what macOS ships as /bin/bash.
counts="${staging}/counts"
: > "$counts"

taken_for() {
    awk -v key="$1" '$1 == key { print $2; found = 1 } END { if (!found) print 0 }' "$counts"
}

record_for() {
    local key="$1" value="$2"
    grep -v "^${key} " "$counts" > "${counts}.new" 2>/dev/null || true
    mv "${counts}.new" "$counts"
    echo "${key} ${value}" >> "$counts"
}

for tag in $tags; do
    dir="${staging}/${tag//\//_}"
    mkdir -p "$dir"

    # A release with no .deb -- a dylib-only one, say -- must not count against the
    # limit, or it would push a real one out of the index.
    if ! gh release download "$tag" --repo "$REPO" \
            --pattern '*.deb' --dir "$dir" --clobber 2>/dev/null; then
        echo "No .deb in ${tag} — skipping."
        continue
    fi

    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue

        # Grouped by the package's own identity, read from the archive rather than
        # guessed from the filename: the rootless and roothide builds of one tweak
        # are separate packages and each is entitled to its own rollback copies.
        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        if [ -z "$package" ]; then
            echo "::warning::${deb##*/} has no Package field — skipping."
            continue
        fi

        count=$(taken_for "$package")
        if [ "$count" -ge "$KEEP" ]; then
            continue
        fi

        version=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")

        # Renamed to the Debian convention on the way in. Two flavours of one tweak
        # have collided on a single filename before, and the second silently replaced
        # the first; name plus version plus architecture is exactly what tells them
        # apart.
        target="${OUT_DIR}/${package}_${version}_${arch}.deb"
        cp -f "$deb" "$target"

        record_for "$package" "$((count + 1))"
        echo "Kept ${package} ${version} ${arch} (from ${tag})"
    done
done

# Folded in after the gather, so a locally built package always wins over the copy the
# listing returned. They are the same bytes; the local one is certainly current.
for dir in $LOCAL_DIRS; do
    [ -d "$dir" ] || continue

    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue

        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        [ -n "$package" ] || continue

        version=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")

        cp -f "$deb" "${OUT_DIR}/${package}_${version}_${arch}.deb"
        echo "Added this run's ${package} ${version} ${arch}"
    done
done

#
# Every tweak's current version has to be here before this counts as complete.
#
# Both workflows build and deploy this index, and the note in CLAUDE.md said that made
# the order they run in irrelevant. It does not -- that only holds if both gathers see
# the same set of releases, and a release published *between* them breaks it. Exactly
# that happened: both runs started at 11:53:02, YouTube published 0.10.1 at 11:54:36,
# and the run that gathered first deployed an index without it, last. The release was
# fine, the packages were fine, and the source served a version older than both.
#
# So the index states what it must contain and checks. Each tweak's control names the
# version that has to be present for its package; anything missing means the listing was
# read too early, which is worth one more look and then worth failing over. A source that
# quietly serves a version behind the release is the failure this whole arrangement
# exists to prevent.
#
verify_versions() {
    local missing=""

    # Relative to the script, not to the working directory: the workflow runs this
    # from the workspace with the repository checked out into main/, the same reason
    # extra-debs is reached that way above.
    for control in "$(dirname "$0")"/../tweaks/*/control; do
        [ -f "$control" ] || continue

        local package version
        package=$(awk -F': *' '/^Package:/ {print $2; exit}' "$control")
        version=$(awk -F': *' '/^Version:/ {print $2; exit}' "$control")
        [ -n "$package" ] && [ -n "$version" ] || continue

        # The rootless build publishes as name_version+rootless_arch.deb and the roothide
        # one as name.roothide_version_arch.deb, so the version is matched inside the
        # filename rather than against the whole of it.
        if ! ls "$OUT_DIR" 2>/dev/null | grep -q "^${package}_${version}"; then
            missing="${missing} ${package} ${version}"
        fi
    done

    printf '%s' "$missing"
}

#
# Fetches one release by tag, rather than waiting for it to show up in the listing.
#
# This is the actual fix for the eventual consistency, and it took a failed deploy of both
# tweaks to see it. The listing endpoint is what lags; a release asked for *by name* is
# served as soon as it exists. Every version that has to be present is already known -- it
# is written in the tweak's own control -- so there is no reason to go looking for it in a
# list. The two tag shapes are the two this repository uses: Instagram tags vX.Y.Z and
# YouTube tags youtube-vX.Y.Z, so the second one is tried when the first is not there.
#
fetch_by_tag() {
    local tweak="$1" version="$2"
    local dir="${staging}/direct-${tweak}-${version}"
    mkdir -p "$dir"

    local tag
    for tag in "${tweak}-v${version}" "v${version}" "${version}"; do
        if gh release download "$tag" --repo "$REPO" \
                --pattern '*.deb' --dir "$dir" --clobber 2>/dev/null; then
            echo "Fetched ${tag} directly."
            break
        fi
    done

    local deb package version_read arch
    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue
        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        [ -n "$package" ] || continue
        version_read=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")
        cp -f "$deb" "${OUT_DIR}/${package}_${version_read}_${arch}.deb"
    done
}

missing="$(verify_versions)"

if [ -n "$missing" ]; then
    echo "::warning::Missing from the listing:${missing} — asking for those releases by name."

    for control in "$(dirname "$0")"/../tweaks/*/control; do
        [ -f "$control" ] || continue
        tweak=$(basename "$(dirname "$control")")
        version=$(awk -F': *' '/^Version:/ {print $2; exit}' "$control")
        [ -n "$version" ] || continue
        fetch_by_tag "$tweak" "$version"
    done

    missing="$(verify_versions)"
fi

if [ -n "$missing" ]; then
    # Strict about this run's own tweak: if the version this run just built is not in the
    # set, the run itself is wrong and publishing would serve something older than what it
    # released.
    for entry in $missing; do
        # The list alternates package and version. Told apart by the first character, not by
        # counting dots -- com.albrhi.tweak has two dots as surely as 3.8.2 does, and the
        # pattern that seemed to distinguish them skipped every entry instead.
        case "$entry" in
            [0-9]*) continue ;;
        esac

        if [ -n "$OWNER_TWEAK" ] && \
           grep -q "^Package: ${entry}$" "$(dirname "$0")/../tweaks/${OWNER_TWEAK}/control" 2>/dev/null; then
            echo "::error::This run's own package is missing from the index: ${entry}"
            echo "::error::Refusing to publish a source older than the release this run made."
            exit 1
        fi
    done

    # Another tweak's newest release is not visible yet. Warned, not failed -- that tweak's
    # own workflow is what guarantees its version lands, and it rebuilds this same index
    # from the same releases when it runs. Failing here would only mean neither ever
    # publishes.
    echo "::warning::Publishing without:${missing}"
    echo "::warning::That tweak's own workflow will put it in when it next runs."
fi

echo
echo "Published packages gathered into ${OUT_DIR}:"
ls -la "$OUT_DIR"
