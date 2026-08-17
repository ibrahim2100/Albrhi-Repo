# Albrhi for TikTok — what changed

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
