# Albrhi for TikTok — what changed

## v0.4.5

The answer came back: **"model has no -videoModel."** `-videoModel` was always this
tweak's own weakest link -- the header has said so since v0.2.0, marked circumstantial
because neither reference tweak's own hook table ever names it, only string-table
proximity to `playAddr`/`bitratePlayAddr` suggested it. A live device now says outright
it is wrong on this build.

Guessing a replacement name would repeat the exact mistake that produced the
`AWEFeedViewCell` bug two releases ago. Instead, `SCITTMedia` gained
`+candidateAccessorsOnAwemeModel`, a new Status row that reads `AWEAwemeModel`'s own
properties and no-argument methods straight off the *live runtime class on this exact
device* — walking up a few superclasses too, since the accessor may not sit on
`AWEAwemeModel` itself — and lists every one whose name contains "video", "play",
"url", "media", "cover", "download" or "aweme". Not a class dump taken somewhere else:
whatever this row lists is what the chain can actually be pointed at on the build that
matters, the same "ask the device, not the assumption" principle Diagnostics pages use
throughout this project.

## v0.4.4

Still 0 placed on both surfaces after v0.4.3, on a device where the ad filter's own
count (122 feed items seen, 10 dropped) proves `AWEAwemeModel` construction is being
reached. That count alone does not prove the *download* resolution chain succeeds for
any of those models — `-configWithModel:`'s replacement, reading
`[SCITTMedia recent].firstObject`, would show nothing whether the placement hooks
never fire *or* fire correctly and simply have nothing resolved to show. Those need
different fixes, and nothing on the report so far said which.

`SCITTMedia` has carried exactly the diagnostic for this since v0.2.0 —
`+lastAttemptState`, which records which step of `videoModel.playAddr.bestURLtoDownload`
the chain last reached — and it was never wired into the settings screen. It is now, as
its own Status row, separate from the button's own placement count. The next report
names which of "no -videoModel", "-videoModel nil", "no -playAddr", "-playAddr nil", "no
-bestURLtoDownload", a wrong return type, or "resolved a download URL" is actually
happening, rather than leaving "0 placed" to mean any of them.

## v0.4.3

**A real device report settled the button question outright.** The Status screen's
own "In-feed button" row, checked after v0.4.2, said: `cell overlay — 0 placed;
TTKFeedInteractionStackView + TTKFeedRightInteractionStackView — 0 placed; above it:
TTKFeedInteractionStackView < TTKFeedInteractionMainView < TTKFeedInteractionRootView
< UITableViewCellContentView < AWEFeedViewCell < AWENewFeedTableView < … <
AWEFeedSlidingScrollView`. The rail was attached and running — it is what walked that
chain — and the chain names the real cell: **`AWEFeedViewCell`**, not
`AWEFeedViewTemplateCell`, the class both NA9 and VibeTok's own symbol tables name and
the one every placement attempt through v0.4.2 hooked. `AWEFeedViewCell` is in neither
reference's own hook table at all; this build has moved past what either was written
against. `-configWithModel:`/`-configureWithModel:` were therefore never called on a
real cell, and the association they were meant to stash was never there for the rail
or the overlay to read — which is the entire reason both surfaces reported zero.

**The fix drops per-cell precision rather than guess at another bind method.** Nothing
in the walked chain says which selector actually sets `AWEFeedViewCell`'s model, and
guessing one is exactly what produced this bug the first time. `-layoutSubviews` needs
no such guess — inherited from `UIView`, it fires regardless of what TikTok calls its
own bind method. Both surfaces (the cell overlay and the rail) now show
`[SCITTMedia recent].firstObject` — the newest video this tweak has actually resolved
a link for — rather than a specific per-cell association. This is the same "download
the newest capture" shortcut Locket's own quick-save button already takes, for the
same reason: the ad filter's diagnostics already prove `SCITTMedia` is capturing real
items (the report that found this bug also showed 154 feed items seen, 6 dropped),
so the newest one is almost always the video just watched. `AWEFeedViewCell` is hooked
alongside the older `AWEFeedViewTemplateCell` rather than replacing it, at zero cost
if the older name never fires again on this build.

## v0.4.2

v0.4.1's own fixes did not hold, reported directly against a real build: the settings
text was still overlapping and the button still did not appear.

**The overlap had a second, more direct cause than the row height fix addressed.** The
Status section used `UITableViewCellStyleValue1` with a multi-line detail label —
Value1 lays its title and detail side by side on one line by design, and several of
these rows hold a long, dynamically-built diagnostic string (a comma list of hook
names, a whole superview chain). Forcing that onto two lines in a layout built for one
draws the wrapped text over the title beside it rather than under it. Switched to
`UITableViewCellStyleSubtitle`, the same style already used everywhere else on this
screen, which stacks a note under its title instead of beside it.

**The button gained a second, primary placement that does not depend on the interaction
rail at all.** Reported directly: NA9 For TikTok's own download button — its classic
surface, not the sidebar one — has worked without interruption for years, drawn
straight onto `AWEFeedViewTemplateCell` itself via `-layoutSubviews` calling its own
`na9AddDownloadButton`. That is now this tweak's primary surface too: a button added
as a direct subview of the cell, bottom-right, raised to the front on every layout
pass the same way the X tweak's own `ImmersiveCardView` surface does for the identical
reason (the video's own overlays are re-added as the cell renders, and a button under
one of them is a button nobody can tap). It needs only `AWEFeedViewTemplateCell` to
exist — nothing else has to be present for it to have a chance of showing. The
interaction-rail surface (`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView`)
is kept as a second, optional surface exactly as NA9 also carries both. The Status
screen's own report now names both surfaces and how many buttons each has placed.

## v0.4.1

Three things reported directly after v0.4.0 shipped: the in-feed button still did not
appear, privacy was one switch for three different reports, and the settings screen's
own text overlapped itself.

**The overlap was a real, confirmable bug, independent of anything device-specific.**
Every Controls/Privacy row carries a wrapped, multi-line note under its title, and the
table never set an automatic row height -- every cell sat clamped to the fixed 44-point
default, so a two- or three-line note was drawn on top of the row underneath it rather
than pushing it down. `self.tableView.rowHeight = UITableViewAutomaticDimension` with an
estimated height fixes it outright.

**Privacy split into three separate switches**, each its own row in a new Privacy
section: story views, message read receipts, profile views. One switch bundling all
three could never be turned off for just one of them, which is what was asked for
directly. `SCIPrefPrivacy` is gone; `SCIPrefPrivacyStory`/`SCIPrefPrivacyMessages`/
`SCIPrefPrivacyProfile` gate their own hook in `SCITTPrivacy.x` independently.

**The in-feed button's placement no longer depends on the rail's own layout firing.**
`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView -layoutSubviews` and
`-didMoveToWindow` are still hooked as a fallback, but this project's own CLAUDE.md
already documents why neither can be trusted alone on a *reused* cell -- the same
lesson a much earlier X-tweak bug cost a release to learn, and a UIStackView is not
guaranteed a fresh layout pass just because the cell holding it was rebound to a
different model. Placement is now driven directly from `AWEFeedViewTemplateCell`'s own
`-configWithModel:`/`-configureWithModel:` -- confirmed to fire on every reuse -- via a
depth-first search of the cell's own subview tree for the rail, immediately after the
resolved item is stashed on the cell. Whether this actually surfaces the button on a
real device is still unconfirmed; the Status section's own "In-feed button" row now
says exactly which of four states it is in (rail absent, cell hooked but no rail, rail
found with nothing resolved above it, or N buttons placed) rather than a bare yes/no,
so a report from here on names which one rather than only "no button."

## v0.4.0

A download button in the feed itself, and a real settings screen -- both asked for
directly after v0.3.0 shipped only a status-screen list.

**The button.** NA9 For TikTok's and VibeTok's own `_ungrouped$` hook tables were read
again, this time for where a *visible* button belongs rather than for a resolution
chain. NA9 places one on `AWEFeedViewTemplateCell` directly and, on a newer rail, on
`TTKFeedInteractionStackView` / `TTKFeedRightInteractionStackView` -- the vertical stack
of like/comment/bookmark/share icons beside the video. VibeTok, a tweak with no
download feature at all, independently hooks `TTKFeedInteractionStackView
-layoutSubviews` for its own unrelated reason, which is a second, unrelated confirmation
that class is real. Both stack names are confirmed present as literal strings in TikTok
46.4.0's own `MusicallyCore` binary, read directly the same no-`otool` way every class in
this tweak has been.

What is not carried over is how the reference tweaks find out which video to download --
that reads a model accessor on the stack view this project has not independently
confirmed. Instead, the model is caught where it needs no confirmation at all:
`AWEFeedViewTemplateCell -configWithModel:` / `-configureWithModel:` are two of NA9's own
hooked selectors, and a hooked method's own argument is simply what was passed, not a
guess. The resolved URL is stashed on the cell the moment its model is set, and the
button -- nested somewhere inside that cell -- reads it back by walking up its own
superview chain, the same upward search the X tweak's own immersive button already uses
to reach its card from its rail. `SCITTMedia`'s resolution chain was split out into its
own `+resolveURLForModel:`, callable without touching the status screen's recent list, so
there is exactly one resolution implementation behind both surfaces.

**The settings screen.** Replaced entirely -- a plain stack of three switches over one
text-view report is not what "detailed and organized like NA9 and VibeTok" asked for.
Rebuilt as a real grouped `UITableViewController`, in the shape the X tweak's own
settings screen (`SCITWSettings.m`) already settled on: a status card with pass/fail
pills at the top, a Controls section with a coloured icon and an explanation under every
switch, a Download section listing what has actually been resolved (tap a row to save
it, no confirmation sheet), and a Status section with live numbers -- the panel gate,
the ad filter's own count, which interaction rail the button attached to, and what the
bypass and privacy hooks have each answered. Privacy answers now record into their own
set (`SCITTDiagnostics recordPrivacyAnswer:`/`privacyState`) instead of sharing the
bypass tally, so the two numbers cannot be read as one.

**Privacy widened by two more confirmed selectors.** `TTKProfileViewsVisitor -visit:` and
`-p_shouldReportHasVeiwedProfileForUser:` turned up in the same NA9/VibeTok symbol tables
the other three privacy hooks came from, confirmed present in the real binary the same
way -- added alongside `-reportProfileView`/`-p_shouldReportProfileView` on the same
class, all four withheld together.

## v0.3.0

Two more references arrived — NA9 For TikTok's compiled `.deb` and VibeTok's compiled
`.dylib` — both read the same way every closed reference in this project is: with the
precise `_ungrouped$Class$selector` Logos debug-symbol table each carries (both are
unstripped debug builds), which names the exact class-and-selector pairs each one
actually hooks, not just what strings sit near each other. Read for where TikTok is
hookable only; no code is taken from either.

**Download.** `AWEAwemeModel.videoModel.playAddr.bestURLtoDownload` is the chain both
references resolve a video's URL through. `-bestURLtoDownload` is confirmed twice over —
present in this build's own binary and the exact selector NA9's own symbol table hooks.
`-videoModel` and `-playAddr` are not in either reference's own hook table (neither
overrides them, only calls them), so they are held to the lower, circumstantial bar this
project's other "not a hooked selector" findings are — `SCITTMedia.m` walks the chain
behind `-respondsToSelector:` at every step and records which one failed rather than
assuming it holds. A kept (non-ad) model is captured the moment `AWEAwemeModel` finishes
building, resolved synchronously, and only the resulting URL is kept — never the model
itself, so nothing here extends how long a feed cell's own object stays alive. The
status screen lists what has been captured with a Save button per item;
`SCITTDownload.m` fetches and writes it into Photos, or into the app's own Documents for
audio-only content Photos cannot hold, mirroring Locket's and X's own downloader almost
exactly (`JGProgressHUD`, `PHPhotoLibrary requestAuthorizationForAccessLevel:`,
`NSURLSessionDownloadDelegate`).

**Privacy.** Three points where the app reports what was watched back to TikTok's own
servers, cross-validated between both new references before being hooked:
`TTKStoryMarkReadService -markAsRead:` (a story was opened), `AWEIMMessageReadComponent
-p_markReadSyncToServerWithMessage:` (a DM was read — its sibling
`-p_markMessageAsReadLocally:` is deliberately untouched, so the conversation's own
unread badge keeps clearing normally on this device), and `TTKProfileViewsVisitor
-reportProfileView` / `-p_shouldReportProfileView` (a profile was visited). New switch,
off by nothing — on by default like the rest, in the status screen.

**Ad filter widened.** `isAd`, `isAdItem` and `isAdsOrPseudoAds` join `-isAds` as marks
`AWEAwemeModel` can carry — found sitting beside it in the same run of the binary's own
string table, the same circumstantial standard `-videoModel` was already held to.
`-respondsToSelector:` guards each independently; any one answering YES is enough to
drop the model. A separate splash/launch-ad surface is suppressed too — three plausible
manager class names (`AWESplashManager`, `BDASplashManager`, `TTAdSplashManager`) are
each hooked behind their own `NSClassFromString` guard, since the references disagree on
which name a given build actually ships and an absent class's hook simply never
attaches.

**Bypass widened.** Six more jailbreak-detection points, each confirmed present by class
name and cross-validated between both new references: `IOSSecuritySuite +amIJailbroken`,
`AppsFlyerUtils -isJailbrokenWithSkipAdvancedJailbreakValidation:`, `IESLiveDeviceInfo
-isJailBroken`, `TTInstallUtil -isJailBroken`, `UIDevice -btd_isJailBroken`, and a bare
`NSObject -jailbroken` category method. **`PIPOStoreKitHelper -isJailBroken`, also named
by a reference, is deliberately left unhooked** — v0.1.0's own reading already refused
`PIPOStoreKitHelper` and its sibling `PIPOIAPStoreManager` as sitting inside the
in-app-purchase surface, the same boundary Locket's Check0verPlus review drew, and one
confirmed method on that class is not reason enough to cross it. The other six checks
already answer the same underlying question.

## v0.2.0

The real IPA and a real class dump of TikTok 46.4.0 arrived, and every class this tweak
now hooks was confirmed against it directly — `MusicallyCore.framework` (810 MB, the app's
real logic; the main executable is a 92 KB stub) parsed by hand for its own class and
selector names, the same Mach-O-by-hand method this project already uses everywhere else
there is no `otool` available.

**No ads.** `AWEAwemeModel` — confirmed present — carries the server's own `-isAds` mark
on every feed item, confirmed as a real property name in this build's own strings. Refused
at `-init` and `-initWithDictionary:error:`, after `%orig` builds the object (the mark
cannot be read before then) and before anything downstream ever sees it. Not a view hidden
afterward; the object is never returned.

**Hides the jailbreak.** `TTAdSplashDeviceHelper -isJailBroken`, `GULAppEnvironmentUtil`'s
three environment questions, `FBSDKAppEventsUtility -isDebugBuild`, `AWEAPMManager
-signInfo`, `AWESecurity -resetCollectMode`, and `NSBundle` asked for a
`.mobileprovision` — six real checks, each answered the way an unmodified phone would.
Nothing here touches `PIPOIAPStoreManager`/`PIPOStoreKitHelper` or any purchase flag, and
nothing will.

**v0.1.0's own reading corrected itself here, not silently.** `AWEAPMManager` was filed
under "Ads" in that entry, going only by its name — reading BHTikTok's actual hook showed
it answers a signing-info question (`+signInfo` → `"AppStore"`), which is a jailbreak-
detection answer, not an ad control. It is filed correctly above. `AWEPlayVideoPlayerController`
and `TIKTOKProfileHeaderView`, both named in v0.1.0's list, do not exist as exact strings
in the 46.4.0 binary at all — plausible replacements were found
(`AWEPlayVideoPlayerControllerClass`, `AWEVideoPlayerController`; a `TTK`-prefixed profile
header family) but not yet confirmed enough to hook.

Settings: a two-finger hold opens a status screen with a switch for each feature above and
the same diagnostics report `SCITTDiagnostics` builds — how many feed items were seen and
how many dropped as ads, and which bypass hooks have actually answered a real caller.

Next: download. `AWEURLModel` is confirmed present; what shape it answers in — a direct
URL, or another indirection the way most of this project's other download features turned
out to need — is not yet measured.

## v0.1.0

Scaffold only. The tweak's structure exists — Makefile, control, filter plist, source
layout, bilingual localisation table, the panel gate — so `tools/check.py` and
`./build.sh tiktok rootless` both run against it while the real hooks are written. No
feature patches TikTok yet.

Two references were read for architecture, both by the same author family already
credited in the X tweak's own control file: BandarHL's original BHTikTok
(github.com/BandarHL/BHTikTok) and al3raQe's maintained fork
(github.com/al3raQe/BHTikTok). Neither carries a LICENSE file, so both are read the same
cautious way every other unlicensed reference in this project is — for *where* things are
hookable, never for the code itself. Their `Tweak.x` hooks 34 classes; the ones that
matter for what this project would actually build:

- **Ads**: `AWEAPMManager`, `TTAdSplashDeviceHelper`
- **Download / feed model**: `AWEAwemeModel`, `AWEURLModel`, `AWEPlayVideoPlayerController`,
  `AWEFeedVideoButton`, `AWEFeedViewTemplateCell`, `AWEAwemeDetailTableViewCell`
- **Profile**: `TIKTOKProfileHeaderView`, `AWEProfileImagePreviewView`,
  `AWEProfileEditTextViewController`, `AWEUserModel`
- **Confirmations / comments**: `AWECommentPanelCell`, `AWEPlayInteractionUserAvatarElement`
- **Device / jailbreak-detection evasion**: `BDADeviceHelper`, `BDInstallNetworkUtility`,
  `GULAppEnvironmentUtil`, `UIDevice`, `CTCarrier`, `NSFileManager` — the same class of
  check Locket's own bypass answers, not a paywall
- **Settings surface**: `TTKSettingsBaseCellPlugin`, `AWESettingsNormalSectionViewModel`,
  `SparkViewController` (built on Cephei/CepheiPrefs, an external dependency this project
  does not use — a native settings screen would be written instead, the way every other
  tweak here already does it)

**Deliberately not being built, regardless of what a class dump confirms**:
`PIPOIAPStoreManager` and `PIPOStoreKitHelper` — an in-app-purchase / StoreKit fake, the
same shape of thing `Check0verPlus.dylib` was for Locket and was reviewed and refused for
the same reason: that takes money from TikTok's own developers, it is not a device tweak.
Any "fake verified badge" / "fake follower count" cosmetic-spoofing features named in
BHTikTok's own README are being treated the same way as Locket's Check0verPlus review
until there is a reason to think otherwise — parked, not assumed safe.

Next: a real class dump and a real IPA of the current TikTok build, so every hook is
confirmed against what actually exists on this build rather than carried over from a
reference that may target a TikTok years older than today's.
