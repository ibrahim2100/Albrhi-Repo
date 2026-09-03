#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCIYTDownload.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../YouTubeHeaders.h"

///
/// YouTube's own download button, answered by this tweak.
///
/// **The gesture this replaces was competing with YouTube's own.** Holding the picture was
/// the only way to save a video for eleven releases, and holding the picture is also how
/// YouTube speeds one up — two long presses over one surface, both armed, ours arriving
/// first often enough that a habit built around the app's feature started producing a
/// download sheet. Nothing about that could be fixed by tuning a duration: the gesture was
/// in the wrong place, and the right place was already on screen.
///
/// **Which button this is, is not measured, positioned or matched against a title — the
/// class is asked.** `YTSlimVideoDetailsActionView` declares `-hasOfflineButton`, read out
/// of 21.34.3's class metadata beside the tap it answers. Every other route to "which of
/// these buttons is Download" that this project has tried on any app — a frame, a subview
/// index, a localised label, an icon enum — has been wrong on some build; a BOOL the app
/// maintains for its own layout cannot be.
///
/// It is behind `-respondsToSelector:` all the same, and a build that does not answer it
/// gets `%orig` untouched. A gate that cannot identify its target must fail toward leaving
/// the app alone, never toward intercepting a button it has not recognised.
///
/// What is deliberately *not* done here: YouTube's own offline download is not disabled,
/// broken, or reached into. The button is answered before it starts one, and when this
/// switch is off the whole class behaves exactly as it does with nothing installed.
///
/// **Riding `YTOfflineVideoStreamsDownloadController` instead was considered and refused.**
/// That class is in this build and the diagnostics page has been naming it as "the path
/// worth riding" for releases — but it is downstream of the account check. An account
/// without Premium is shown the upsell and never reaches it, which is the whole reason this
/// tweak downloads at all. A hook there would fire only for the people who least need it.
///

// MARK: - What is actually happening

///
/// Four numbers, because "no download button" has four causes and they need four different
/// pieces of work.
///
/// **1.26.0 shipped one number and it answered none of them.** It counted taps and wrote the
/// count out only on the branch where a download button was answered, so tapping Like moved
/// a counter nobody could read and the report still said `no tap has reached this hook` —
/// the exact ambiguity that release claimed to have removed, reintroduced one branch away
/// from the paragraph explaining it.
///
/// Built separates "this build does not draw the class" from everything else, and needs no
/// tap at all. Offline separates "the class is drawn but this row has no download button"
/// from "it has one and nobody pressed it". Seen and answered separate the two ends of the
/// tap itself.
static NSUInteger sciViewsBuilt = 0;
static NSUInteger sciOfflineViewsSeen = 0;
static NSUInteger sciTapsSeen = 0;
static NSUInteger sciTapsAnswered = 0;

static void SCIReportButtonState(void) {
    [SCIYTDiagnostics recordNativeDownloadButton:
        [NSString stringWithFormat:SCILocalized(@"diag_native_button_counts"),
            (unsigned long)sciViewsBuilt,
            (unsigned long)sciOfflineViewsSeen,
            (unsigned long)sciTapsSeen,
            (unsigned long)sciTapsAnswered]];
}

/// One instance counted once. These views are built per video and moved in and out of a
/// window repeatedly, and a count that climbs with scrolling is a log, not a measurement.
static char kSCICountedOffline;

/// The controller to present from, found by walking up rather than by naming a class.
///
/// The action row lives inside whatever YouTube currently calls the video details panel,
/// and that has been renamed between builds. The responder chain has not.
static UIViewController *SCIControllerAbove(UIView *view) {
    UIResponder *responder = view;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }

    UIViewController *presenter = (UIViewController *)responder;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    return presenter;
}


%hook YTSlimVideoDetailsActionView

// MARK: - The tap

- (void)didTapButton:(id)sender {
    if (!SCIPrefEnabled(SCIPrefNativeDownload)) {
        %orig;
        return;
    }

    sciTapsSeen++;

    // Two questions, asked in this order on purpose. Whether the class answers at all is a
    // fact about the build; whether this instance is the download button is a fact about
    // the row. Conflating them is how "not in this build" and "not this button" become one
    // silent branch -- which is a shape this project's own notes name three times.
    if (![self respondsToSelector:@selector(hasOfflineButton)]) {
        SCIReportButtonState();
        [SCIYTDiagnostics recordNativeDownloadNote:
            SCILocalized(@"diag_native_button_unknown")];
        %orig;
        return;
    }

    // Reported even though nothing is done about it. A tap on Like is what "the hook is
    // attached and this simply was not the download button" looks like, and with no line
    // saying so it reads identically to a hook that never fired.
    if (![self hasOfflineButton]) {
        SCIReportButtonState();
        %orig;
        return;
    }

    UIViewController *presenter = SCIControllerAbove(self);
    if (!presenter) {
        // Never swallow the tap we could not act on. YouTube's own download is a working
        // feature, and a button that does nothing at all is worse than one that does what
        // it always did -- the same rule that keeps a failed confirmation from blocking a
        // repost elsewhere in this repository.
        SCILogV(@"native download: nothing to present from");
        SCIReportButtonState();
        [SCIYTDiagnostics recordNativeDownloadNote:
            SCILocalized(@"diag_native_button_no_presenter")];
        %orig;
        return;
    }

    sciTapsAnswered++;
    SCIReportButtonState();
    [SCIYTDiagnostics recordNativeDownloadNote:SCILocalized(@"diag_native_button_ok")];

    SCILogV(@"native download: answering the offline button");
    [SCIYTDownload presentFrom:presenter];
}

/// The long press on that same button is YouTube's quality picker, and it is left alone.
/// Taking a second gesture would repeat on this button the exact mistake being undone on
/// the player. Named here so nobody adds one later believing it was never considered.


// MARK: - Whether the class is drawn at all

///
/// Both initialisers, counted and otherwise untouched.
///
/// Two of them because the class declares two: the element one is what a modern build uses
/// and the plain one is still there. Hooking only the modern name is how a feature works
/// until an older screen is opened.
///
- (id)initWithElementSlimMetadataButtonSupportedRenderer:(id)renderer parentResponder:(id)responder {
    id view = %orig;
    if (view) { sciViewsBuilt++; SCIReportButtonState(); }
    return view;
}

- (id)initWithSlimMetadataButtonSupportedRenderer:(id)renderer {
    id view = %orig;
    if (view) { sciViewsBuilt++; SCIReportButtonState(); }
    return view;
}

///
/// And whether any of them is the download button — asked here rather than at `init`.
///
/// **A view is not configured when its initialiser returns.** `-setOfflineStatus:offlineability:`
/// is a separate call, so asking `-hasOfflineButton` at construction would answer NO for a
/// button that becomes the download button a moment later, and the report would say `0 of 6`
/// on a build where the feature works perfectly. That is this project's own "asked too early"
/// trap — the one that had YouTube Music reporting a class as missing from a build that
/// certainly had it.
///
/// `-didMoveToWindow` is declared on this class and fires once it is on screen and set up.
///
- (void)didMoveToWindow {
    %orig;

    if (!self.window) return;
    if (objc_getAssociatedObject(self, &kSCICountedOffline)) return;
    if (![self respondsToSelector:@selector(hasOfflineButton)]) return;
    if (![self hasOfflineButton]) return;

    objc_setAssociatedObject(self, &kSCICountedOffline, @YES, OBJC_ASSOCIATION_RETAIN);
    sciOfflineViewsSeen++;
    SCIReportButtonState();
}

%end
