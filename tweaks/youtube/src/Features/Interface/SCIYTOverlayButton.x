#import <objc/runtime.h>
#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../Download/SCIYTDownload.h"

///
/// A save button inside YouTube's own player, and the clock time the video ends at.
///
/// Until now the tweak had no presence on the layer over the video at all: a tab at the
/// bottom of the app and buttons in Shorts, and nothing where a video is actually being
/// watched. Saving meant leaving the player, which is the one moment nobody wants to.
///
/// **The technique is read from YTVideoOverlay by PoomSmart (MIT), not copied from it.**
/// That tweak is a framework other tweaks register buttons with; this is one button for one
/// tweak, so the registry, the settings integration and the per-tweak metadata table it
/// carries are all left out. What is taken is the answer to the only question that mattered:
/// *which two classes own the two places a button can go*, which is exactly the kind of
/// thing this project reads open source for rather than guessing at.
///
/// **Both classes are leads.** Neither appears in a class dump this project has taken of
/// this build, so nothing here assumes either exists:
///
///   - a `%hook` on an absent class never attaches, which is the cheap half;
///   - every selector is behind `-respondsToSelector:`, because a class that exists with a
///     renamed accessor is the case that crashes rather than no-ops;
///   - the diagnostics report names which of the two attached, so "no button" is never two
///     silent reasons at once. That loop is what this project uses instead of guessing, and
///     it is the whole reason the X tweak's three button surfaces are all still in place.
///
/// The end time is a label rather than a fourth thing drawn on the progress bar. The bar is
/// two points of usable height -- the SponsorBlock markers sit *on* it at that thickness --
/// and a time needs a line of text, so it goes in the container beside the icons where
/// there is room for one.
///

///
/// What this surface is actually doing, in numbers rather than in one overwritten sentence.
///
/// **This button shipped with no report at all for eight releases.** Its only record went into
/// `-recordMarkerBar:`, which is the SponsorBlock progress-bar line — so a feature that was off
/// by default and unconfirmed had its one piece of evidence filed under an unrelated heading,
/// and no report has ever mentioned it. A diagnostic written into the wrong slot is worse than
/// none: it reads as covered.
static NSUInteger sciOverlaysSeen = 0;
static NSUInteger sciOverlayButtonsMade = 0;
static NSUInteger sciOverlayTaps = 0;

static char kSCIOverlaySaveButton;
static char kSCIOverlayJoined;

static void SCIReportOverlayState(BOOL joined) {
    [SCIYTDiagnostics recordOverlayButton:
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_counts"),
            (unsigned long)sciOverlaysSeen,
            (unsigned long)sciOverlayButtonsMade,
            joined ? SCILocalized(@"diag_overlay_native") : SCILocalized(@"diag_overlay_placed"),
            (unsigned long)sciOverlayTaps]];
}

static const NSInteger SCIOverlayButtonTag = 0x5C10B7;
static const NSInteger SCIEndTimeTag       = 0x5C10B8;

/// The clock time a video ends at, from now plus what is left of it.
///
/// Formatted with the user's own locale and 24-hour preference rather than a hand-built
/// string: "ends 23:40" and "ends 11:40 PM" are the same fact, and which one is right is a
/// setting the phone already holds.
static NSString *SCIEndTimeText(double totalTime, double elapsed) {
    double remaining = totalTime - elapsed;
    if (!isfinite(remaining) || remaining <= 0) return nil;

    static NSDateFormatter *clock = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        clock = [[NSDateFormatter alloc] init];
        clock.dateStyle = NSDateFormatterNoStyle;
        clock.timeStyle = NSDateFormatterShortStyle;
    });

    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:remaining];
    return [NSString stringWithFormat:SCILocalized(@"overlay_ends_at"), [clock stringFromDate:end]];
}

/// Walks up to the view controller a view belongs to.
///
/// The sheet has to be presented from something, and a button knows only its own view. The
/// responder chain is the one route that needs no class name at all -- which is the point,
/// on a surface where every class name is already a lead.
static UIViewController *SCIOwningController(UIView *view) {
    UIResponder *responder = view;
    while ((responder = responder.nextResponder)) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}


%group SCIOverlayTop

%hook YTMainAppControlsOverlayView

///
/// The row of buttons across the top of the player, with ours added to it.
///
/// **Handed to YouTube's own layout rather than floated over it.** `-topControls` returns the
/// array the player positions, so appending to that array is the same move the X tweak needed
/// four releases to find: a button that is *in* the arrangement cannot be swept out by the next
/// layout pass, and needs no constant of ours to say where it sits.
///
/// **And the button is built by YouTube's own factory**, which is what makes appending honest.
/// `-playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:`
/// hands back a YTQTMButton measured the way the app measures its own — so the array holds the
/// kind of object its other members are, rather than a plain UIButton hoping nothing asks it a
/// question. A build without that factory is not guessed at: the button is placed by us against
/// the safe area instead, exactly as every release before this one did, and the report says
/// which of the two happened.
///
- (NSArray *)topControls {
    NSArray *controls = %orig;

    if (!SCIPrefEnabled(SCIPrefOverlayButton)) return controls;

    @try {
        sciOverlaysSeen++;

        UIButton *save = objc_getAssociatedObject(self, &kSCIOverlaySaveButton);
        BOOL joined = [objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue];

        if (!save) {
            UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle"];

            if ([self respondsToSelector:@selector(playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:)]) {
                // 0 padding and a 48pt target: the padding is the app's to decide from its own
                // metrics and 0 asks for that default, while 48 is the size a finger needs and
                // the one number here that is about people rather than about YouTube.
                id built = [self playerButtonWithImage:icon
                                         selectedImage:icon
                                    accessibilityLabel:SCILocalized(@"overlay_save")
                                verticalContentPadding:0
                                      minHitTargetSize:48];

                // Checked rather than cast. A factory that answers with something that is not a
                // control would otherwise be found out by -addTarget:, in the player, at the
                // worst moment.
                if ([built isKindOfClass:[UIControl class]]) {
                    save = (UIButton *)built;
                    joined = YES;
                }
            }

            if (!save) {
                save = [UIButton buttonWithType:UIButtonTypeSystem];
                save.tintColor = [UIColor whiteColor];
                save.accessibilityLabel = SCILocalized(@"overlay_save");
                [save setImage:icon forState:UIControlStateNormal];
            }

            save.tag = SCIOverlayButtonTag;
            [save addTarget:self action:@selector(sciSaveTapped:)
           forControlEvents:UIControlEventTouchUpInside];

            objc_setAssociatedObject(self, &kSCIOverlaySaveButton, save, OBJC_ASSOCIATION_RETAIN);
            objc_setAssociatedObject(self, &kSCIOverlayJoined, @(joined), OBJC_ASSOCIATION_RETAIN);

            if (!joined) {
                // The fallback, unchanged from the releases that shipped it. Pinned to this
                // view's own safe area rather than laid out beside YouTube's controls: a
                // constraint against a guide that always exists, rather than a frame recomputed
                // against siblings whose positions this tweak does not own.
                save.translatesAutoresizingMaskIntoConstraints = NO;
                [self addSubview:save];
                [NSLayoutConstraint activateConstraints:@[
                    [save.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor
                                                        constant:-52],
                    [save.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor
                                                    constant:8],
                    [save.widthAnchor constraintEqualToConstant:32],
                    [save.heightAnchor constraintEqualToConstant:32]
                ]];
            }

            sciOverlayButtonsMade++;
        }

        SCIReportOverlayState(joined);

        // Only when the button is one of YouTube's own. Appending a plain UIButton to an array
        // whose other members are YTQTMButtons is exactly the guess this file refuses to make
        // everywhere else -- and it would be made inside the player, where being wrong is a
        // crash rather than a missing button.
        if (joined && ![controls containsObject:save]) {
            NSMutableArray *withOurs = [controls mutableCopy] ?: [NSMutableArray array];
            [withOurs addObject:save];
            return withOurs;
        }
    } @catch (NSException *exception) {
        // A button is a convenience and the player is not. Anything thrown here costs the
        // button and nothing else -- the same trade every drawing hook in this tweak makes.
        SCILogV(@"overlay: top button — %@", exception.reason);
        [SCIYTDiagnostics recordOverlayButton:
            [NSString stringWithFormat:SCILocalized(@"diag_overlay_threw"), exception.reason]];
    }

    return controls;
}

// The parameter carries no __unused, and must not.
//
// %new builds the method's type encoding by pasting the parameter's written type straight
// into @encode(...), so `__unused UIButton *` became `@encode(__unused UIButton *)` -- an
// attribute inside @encode, which clang reports as ignored-while-parsing-a-type and
// -Werror turns into three fatal errors in one generated line. Every other %new in this
// project writes a plain typed parameter for the same reason; an unused one is not warned
// about in an Objective-C method the way it would be in a C function.
%new
- (void)sciSaveTapped:(UIButton *)sender {
    sciOverlayTaps++;
    SCIReportOverlayState([objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue]);

    UIViewController *host = SCIOwningController(self);
    if (!host) {
        [SCIYTDiagnostics recordOverlayButton:SCILocalized(@"diag_overlay_no_host")];
        return;
    }
    [SCIYTDownload presentFrom:host];
}

%end

%end


%group SCIOverlayBottom

%hook YTInlinePlayerBarContainerView

- (void)layoutSubviews {
    %orig;

    if (!SCIPrefEnabled(SCIPrefOverlayEndTime)) {
        UIView *stale = [self viewWithTag:SCIEndTimeTag];
        if (stale) [stale removeFromSuperview];
        return;
    }

    @try {
        double total = [self respondsToSelector:@selector(totalTime)] ? self.totalTime : 0;
        if (!isfinite(total) || total <= 0) return;

        // The elapsed side is not asked for. This container does not advertise one, and
        // guessing an accessor on a lead class is how 0.1.1 died -- so the label says when
        // the video ends if it runs from *here*, which is the question anyone reading it is
        // actually asking, and it needs only the duration this class does answer.
        NSString *text = SCIEndTimeText(total, 0);
        if (!text) return;

        UILabel *label = (UILabel *)[self viewWithTag:SCIEndTimeTag];
        if (!label) {
            label = [[UILabel alloc] init];
            label.tag = SCIEndTimeTag;
            label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            label.textColor = [UIColor colorWithWhite:1 alpha:0.75];
            label.userInteractionEnabled = NO;
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:label];

            [NSLayoutConstraint activateConstraints:@[
                [label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
                [label.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:-2]
            ]];

            [SCIYTDiagnostics recordMarkerBar:@"YTInlinePlayerBarContainerView(endtime)" count:1];
        }

        label.text = text;
        [self bringSubviewToFront:label];
    } @catch (NSException *exception) {
        SCILogV(@"overlay: end time — %@", exception.reason);
    }
}

%end

%end


%ctor {
    // Bound by name rather than by scanning. The reels button broke for a whole release
    // because a search over objc_copyClassList replaced a name that objc_getClass still
    // answered to -- a search is a fallback for an unknown name, never a replacement for a
    // known one.
    if (NSClassFromString(@"YTMainAppControlsOverlayView")) {
        %init(SCIOverlayTop);
    } else {
        SCILogV(@"overlay: YTMainAppControlsOverlayView is not in this build");
    }

    if (NSClassFromString(@"YTInlinePlayerBarContainerView")) {
        %init(SCIOverlayBottom);
    } else {
        SCILogV(@"overlay: YTInlinePlayerBarContainerView is not in this build");
    }
}
