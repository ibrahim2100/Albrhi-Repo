#import <objc/runtime.h>
#import "shared/src/SCIResponder.h"
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

/// How many times YouTube told us the controls were appearing or disappearing.
///
/// Counted because the whole fade rides on those two calls arriving: a zero here and a button
/// that never moves is "this build does not call these setters", while a rising count and a
/// button that never moves is a placement or alpha problem. Those need different work, and one
/// symptom cannot say which -- the same reason the button's own construction is counted
/// separately from its taps.
static NSUInteger sciOverlayFadeSignals = 0;

/// Where the button ended up vertically, so "it overlaps the title" has a number next to it.
static CGFloat sciOverlayTopInset = 8;

static char kSCIOverlaySaveButton;
static char kSCIOverlayJoined;

/// The button's own frame, and whether it is in a window.
///
/// **1.27.0's report said the button was made and handed to YouTube's layout, and nothing was on
/// screen — because a button appended to an array had never been added to any view.** The report
/// was accurate about everything it measured and measured the wrong thing: it counted the making
/// and not the placing. Both are here now, and a frame of zero says which half failed without
/// another release to find out.
static NSString *sciOverlayPlacement = nil;

static void SCIReportOverlayState(BOOL joined) {
    [SCIYTDiagnostics recordOverlayButton:
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_counts"),
            (unsigned long)sciOverlaysSeen,
            (unsigned long)sciOverlayButtonsMade,
            joined ? SCILocalized(@"diag_overlay_native") : SCILocalized(@"diag_overlay_placed"),
            (unsigned long)sciOverlayTaps,
            (unsigned long)sciOverlayFadeSignals,
            sciOverlayPlacement ?: SCILocalized(@"diag_overlay_unplaced")]];
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


///
/// Fading with YouTube's own controls, on YouTube's own signal.
///
/// The button used to sit there permanently, over the picture, whether or not the controls were
/// showing — which is wrong in the ordinary way a guest is wrong: everything else on that layer
/// comes and goes with a tap, and one thing that does not reads as stuck rather than as ours.
///
/// **Two flags rather than one, because the app has two.** `-setOverlayVisible:` governs the
/// whole control layer and `-setTopOverlayVisible:isAutonavCanceledState:` governs the top row
/// alone, which is the row this button is in — so it shows only when both say so. The top flag
/// starts YES and is only ever changed by its own setter: a build that never calls it would
/// otherwise leave the button invisible forever, which is the failure direction that looks like
/// the feature was never installed.
///
/// **Nothing is polled.** `-layoutSubviews` runs at times unrelated to a fade and does not run
/// during one; these are the two moments YouTube itself decides.
static char kSCIOverlayShown;
static char kSCIOverlayTopShown;
static char kSCIOverlayTopConstraint;

/// How far below the safe area the button belongs, measured rather than chosen.
///
/// **In fullscreen YouTube draws the video's title across the top row**, and a button pinned
/// eight points below the safe area lands on top of it — reported from the device exactly that
/// way. The obvious fix is to detect fullscreen and add a number, which is two guesses: that the
/// detection is right, and that the number is. The class measures the row itself
/// (`-topControlsHeight`, `d16@0:8`), so the button goes underneath whatever is in it, in both
/// layouts, by construction.
///
/// A height of zero is a row that has not been laid out yet rather than a row with no height, so
/// the previous value is kept instead of collapsing the button onto the title for one frame.
static CGFloat SCITopInsetFor(YTMainAppControlsOverlayView *overlay) {
    if (![overlay respondsToSelector:@selector(topControlsHeight)]) return 8;

    double height = [overlay topControlsHeight];
    if (!(height > 0) || !isfinite(height)) return 0;   // 0 == "leave it where it is"

    return (CGFloat)height + 6;
}


/// **Placement happens once per overlay, and never from inside a layout pass.**
///
/// `-topControls` is a getter YouTube calls *while it is laying out*, and 1.27.1 put
/// `-bringSubviewToFront:` in it, plus two localized format strings and a diagnostics write, on
/// every single call. Bringing a subview to the front marks the hierarchy as needing layout;
/// laying out asks for `-topControls` again; and that is a loop with nothing to stop it. On top
/// of it 1.28.2 set a constraint constant from `-layoutSubviews`, measured with
/// `-topControlsHeight` — the height of the row this button is inside — so the measurement moved
/// every time the button did. Two feedback loops on the main thread, in the player, which is why
/// YouTube sat on its own logo and never finished launching.
///
/// The rule this leaves behind is worth more than the fix: **a hook on a getter that layout calls
/// must be free the second time.** Do the work when there is work — build the button once, place
/// it once — and hand back `%orig` untouched ever after.
static const NSUInteger kSCIOverlayInsetWriteCap = 16;

static char kSCIOverlayInsetWrites;

/// Writes the top constraint, bounded twice: only for a real change, and only so many times for
/// one overlay. A measurement that will not settle then costs a button six points out of place
/// rather than an app that will not start.
static void SCIApplyTopInset(YTMainAppControlsOverlayView *overlay) {
    NSLayoutConstraint *top = objc_getAssociatedObject(overlay, &kSCIOverlayTopConstraint);
    if (!top) return;

    NSNumber *written = objc_getAssociatedObject(overlay, &kSCIOverlayInsetWrites);
    if (written.unsignedIntegerValue >= kSCIOverlayInsetWriteCap) return;

    CGFloat wanted = SCITopInsetFor(overlay);
    if (wanted <= 0) return;

    // Half a point, because a difference smaller than that is rounding, and writing rounding
    // back into a constraint is how a settled layout is made to move again.
    if (ABS(top.constant - wanted) < 0.5) return;

    top.constant = wanted;
    sciOverlayTopInset = wanted;
    objc_setAssociatedObject(overlay, &kSCIOverlayInsetWrites,
                             @(written.unsignedIntegerValue + 1), OBJC_ASSOCIATION_RETAIN);
}


/// Where the button actually ended up, read on a visibility signal rather than during layout.
///
/// It used to be built on every `-topControls` call — two localized format strings per call, on a
/// getter layout asks for constantly. Here it costs two strings each time the controls appear or
/// disappear, which is a handful a minute, and the numbers in it are real: the button has been
/// laid out by the time these fire, so a frame of zero means something rather than "too early".
static void SCIRecordOverlayPlacement(YTMainAppControlsOverlayView *overlay) {
    UIButton *save = objc_getAssociatedObject(overlay, &kSCIOverlaySaveButton);
    if (!save) return;

    sciOverlayPlacement =
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_frame_inset"),
            (double)sciOverlayTopInset,
            [overlay respondsToSelector:@selector(topControlsHeight)]
                ? (double)[overlay topControlsHeight] : -1.0];
    sciOverlayPlacement = [sciOverlayPlacement stringByAppendingFormat:@" · %@",
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_frame"),
            (double)save.frame.origin.x, (double)save.frame.origin.y,
            (double)save.frame.size.width, (double)save.frame.size.height,
            save.window ? SCILocalized(@"diag_overlay_in_window")
                        : SCILocalized(@"diag_overlay_no_window")]];

    SCIReportOverlayState([objc_getAssociatedObject(overlay, &kSCIOverlayJoined) boolValue]);
}


static void SCISyncSaveButton(YTMainAppControlsOverlayView *overlay, BOOL animated) {
    UIButton *save = objc_getAssociatedObject(overlay, &kSCIOverlaySaveButton);
    if (!save) return;

    NSNumber *shown = objc_getAssociatedObject(overlay, &kSCIOverlayShown);
    NSNumber *topShown = objc_getAssociatedObject(overlay, &kSCIOverlayTopShown);

    // Absent reads as visible for the top flag and as "ask the view" for the whole layer, so a
    // button built before either setter has fired matches whatever is on screen right now.
    BOOL wanted = (topShown ? topShown.boolValue : YES) &&
                  (shown ? shown.boolValue
                         : ([overlay respondsToSelector:@selector(isOverlayVisible)]
                            ? [overlay isOverlayVisible] : YES));

    CGFloat target = wanted ? 1.0 : 0.0;
    if (save.alpha == target) return;

    // The duration is YouTube's own fade to within a frame, and a reduced-motion setting is
    // honoured by skipping it rather than by leaving the button behind.
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        save.alpha = target;
        return;
    }

    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:^{ save.alpha = target; }
                     completion:nil];
}


%group SCIOverlayTop

%hook YTMainAppControlsOverlayView

///
/// The row of buttons across the top of the player, and where ours is made.
///
/// `-topControls` is not modified — 1.27.0 appended the button to the array this returns on the
/// reasoning that the player would then place it, and a view in an array is not a view in a
/// hierarchy: it had no superview and nothing drew it. This hook is simply a moment that fires
/// once the overlay exists, which is when the button can be built and added.
///
/// **The button is built by YouTube's own factory where there is one.**
/// `-playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:`
/// hands back a YTQTMButton measured the way the app measures its own, so it looks like the
/// controls beside it rather than like a guest. A build without that factory is not guessed at:
/// a plain button is used instead and the report says which of the two happened.
///
- (NSArray *)topControls {
    NSArray *controls = %orig;

    if (!SCIPrefEnabled(SCIPrefOverlayButton)) return controls;

    @try {
        UIButton *save = objc_getAssociatedObject(self, &kSCIOverlaySaveButton);
        BOOL joined = [objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue];

        // **Nothing at all once the button is placed.** Everything below belongs to building it,
        // and this method is called during layout: anything it does on every call is something
        // layout does on every call, and two of those together stopped the app from starting.
        if (save && save.superview == self) return controls;

        sciOverlaysSeen++;

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

            //
            // **Added to the view, always — this is the whole of 1.27.1.**
            //
            // 1.27.0 built the button with YouTube's own factory and returned it inside the
            // array `-topControls` answers with, on the reasoning that the player would then
            // position it. A view that is in an array is not a view that is in a hierarchy:
            // it had no superview, so there was nothing to lay out and nothing to draw, and
            // the report said "made and handed to its layout" while the screen was empty.
            //
            // The array append is gone rather than kept alongside this. It placed nothing,
            // and a mechanism that decides nothing is worse than a missing one -- it reads as
            // a thing that works.
            //
            // Top-left, past the collapse chevron. The right of that bar carries cast,
            // subtitles and the overflow menu on a build that has them all, and this project
            // has no way to measure their widths from here; the left of it carries one button
            // and then nothing.
            //
            save.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:save];

            // The top constraint is kept rather than activated and forgotten: how far down the
            // button belongs is a measurement of the app's own top row, and that row is a
            // different height in fullscreen than it is inline.
            NSLayoutConstraint *top =
                [save.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor
                                               constant:8];
            objc_setAssociatedObject(self, &kSCIOverlayTopConstraint, top, OBJC_ASSOCIATION_RETAIN);

            [NSLayoutConstraint activateConstraints:@[
                [save.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor
                                                   constant:56],
                top,
                [save.widthAnchor constraintEqualToConstant:36],
                [save.heightAnchor constraintEqualToConstant:36]
            ]];

            sciOverlayButtonsMade++;

            // Matched to what is on screen the instant it exists, without animating: a button
            // that fades in the moment it is built would read as something appearing on its own.
            SCISyncSaveButton(self, NO);
        }

        // Kept in front of whatever the player draws over the picture. Ours is the last thing
        // added and the first thing a redraw of YouTube's own controls would bury.
        [self bringSubviewToFront:save];

        // The frame is not read here: at build time it is zero, because nothing has been laid
        // out yet, and a report of 0×0 would say the placement failed when it has not happened
        // yet. It is recorded on the visibility signals below, where the button has a frame and
        // where the work is not on a layout path.
        SCIReportOverlayState(joined);
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
// **There is no -layoutSubviews hook here any more, and that is the fix rather than a tidy-up.**
//
// 1.28.2 read `-topControlsHeight` in it and wrote the constraint constant from what it found.
// The button sits in the row being measured, so writing the constant changed the measurement,
// which asked for another layout, which wrote again. The inset is applied on the two visibility
// signals below instead — moments YouTube itself decides — which is where this file's own note
// about not polling from -layoutSubviews already said the work belonged.

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    sciOverlayFadeSignals++;
    objc_setAssociatedObject(self, &kSCIOverlayShown, @(visible), OBJC_ASSOCIATION_RETAIN);
    SCIApplyTopInset(self);
    SCISyncSaveButton(self, YES);
    SCIRecordOverlayPlacement(self);
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)cancelled {
    %orig;
    sciOverlayFadeSignals++;
    objc_setAssociatedObject(self, &kSCIOverlayTopShown, @(visible), OBJC_ASSOCIATION_RETAIN);
    SCIApplyTopInset(self);
    SCISyncSaveButton(self, YES);
    SCIRecordOverlayPlacement(self);
}

%new
- (void)sciSaveTapped:(UIButton *)sender {
    sciOverlayTaps++;
    SCIReportOverlayState([objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue]);

    UIViewController *host = SCIControllerForView(self);
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

        // **Only when it changed, and the reorder only when it is not already on top.**
        //
        // This ran on every layout pass: `-setText:` invalidates the label's layout and
        // `-bringSubviewToFront:` reorders this view's subviews, and each of those asks for
        // another layout pass, which arrives here and does both again. A loop on the main
        // thread inside the player — the second of the two in this file that kept YouTube
        // sitting on its own logo.
        //
        // A clock time changes once a minute, so the comparison is nearly always the answer,
        // and the button below is added last anyway.
        if (![label.text isEqualToString:text]) label.text = text;
        if (self.subviews.lastObject != label) [self bringSubviewToFront:label];
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
