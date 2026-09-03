#import <UIKit/UIKit.h>
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
/// download sheet instead. Nothing about that could be fixed by tuning a duration: the
/// gesture was in the wrong place, and the right place was already on screen.
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

/// Counted separately, and this is the third time in this repository that mattered.
///
/// "Taps seen" and "taps answered" have different causes when the button does nothing:
/// none seen means the hook is on a class this build does not draw, some seen and none
/// answered means the download button was never among them. One number cannot say which,
/// and a release has been spent on that ambiguity in this project's TikTok tweak already.
static NSUInteger sciTapsSeen = 0;
static NSUInteger sciTapsAnswered = 0;

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

- (void)didTapButton:(id)sender {
    if (!SCIPrefEnabled(SCIPrefNativeDownload)) {
        %orig;
        return;
    }

    sciTapsSeen++;

    // Two questions, asked in this order on purpose. Whether the class answers at all is a
    // fact about the build; whether this instance is the download button is a fact about
    // the row. Conflating them is how "not in this build" and "not this button" become one
    // silent branch -- which is a shape this file's own project notes name three times.
    if (![self respondsToSelector:@selector(hasOfflineButton)]) {
        [SCIYTDiagnostics recordNativeDownloadButton:
            SCILocalized(@"diag_native_button_unknown")];
        %orig;
        return;
    }

    if (![self hasOfflineButton]) {
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
        [SCIYTDiagnostics recordNativeDownloadButton:
            SCILocalized(@"diag_native_button_no_presenter")];
        %orig;
        return;
    }

    sciTapsAnswered++;
    [SCIYTDiagnostics recordNativeDownloadButton:
        [NSString stringWithFormat:SCILocalized(@"diag_native_button_ok"),
            (unsigned long)sciTapsSeen, (unsigned long)sciTapsAnswered]];

    SCILogV(@"native download: answering the offline button");
    [SCIYTDownload presentFrom:presenter];
}

/// The long press on that same button.
///
/// YouTube uses it for the quality picker on the download button. Left entirely alone: this
/// feature is about answering a tap that means "save this video", and taking a second
/// gesture would be repeating on a button the exact mistake that is being undone on the
/// player. Declared here only so the hook file names every entry point the class has, and
/// so nobody adds one later believing it was never considered.

%end
