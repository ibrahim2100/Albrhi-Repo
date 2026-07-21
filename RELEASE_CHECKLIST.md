# New Version - Release Checklist

### Does this even need a version?

Bump only if the change touches `src/`, `control`, `Makefile` or `build.sh`.
Changes to `tools/`, the workflow or the docs alter nothing users install — a bump
there costs a full rebuild and shows everyone an update containing no change.
Put those under **Unreleased — repo tooling only** in the changelog instead.

### Before git pushing
- [ ] Update version string in `control`
- [ ] Update version string in `src/Tweak.x`
- [ ] Update version string at top of `README.md` 
- [ ] Update compatible Instagram app version at top of `README.md`
- [ ] Update features list in  `README.md`
- [ ] (Optional) Update screenshots

### Creating new release
- [ ] Ensure new tag is created with proper format
- [ ] Make sure to include full changelog in release notes
- [ ] Include rootful & rootless deb files in release