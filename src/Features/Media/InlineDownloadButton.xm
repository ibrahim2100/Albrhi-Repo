#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import "../../Localization/SCILocalize.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Inline download button
///
/// Injects a native-looking download glyph into the post action row
/// (like · comment · send · … · save), so media can be saved with a single tap
/// instead of a long press.
///
/// Placement and sizing are derived from the row's own controls at layout time,
/// so the button inherits Instagram's spacing and metrics rather than hard-coding
/// them. Downloading itself is delegated to SCIMediaDownloader, which means the
/// button honours the quality picker and queue exactly as a long press does.
///

static const NSInteger SCIInlineDownloadButtonTag = 0x5CD10;

// Does this object actually carry a downloadable payload?
static BOOL SCIHasMediaPayload(id candidate) {
    if (!candidate) return NO;

    for (NSString *key in @[@"video", @"photo"]) {
        @try {
            if ([candidate valueForKey:key] != nil) return YES;
        } @catch (__unused id e) {}
    }

    return NO;
}

// Pulls an IGMedia-like object off an arbitrary owner, trying every accessor name
// Instagram uses across its cell, delegate, view-model and section-controller
// layers. The owner itself counts — a cell may *be* the media holder.
static id SCIMediaFromOwner(id owner) {
    if (!owner) return nil;

    if (SCIHasMediaPayload(owner)) return owner;

    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[@"media", @"post", @"feedItem", @"mediaCellFeedItem", @"currentMediaItem",
                 @"pagePhotoPost", @"item", @"viewModel", @"configuration",
                 @"_media", @"_post", @"_configuration"];
    });

    for (NSString *key in keys) {
        id candidate = nil;
        @try { candidate = [owner valueForKey:key]; } @catch (__unused id e) {}

        if (SCIHasMediaPayload(candidate)) return candidate;

        // One level deeper: configurations and view models wrap the media.
        if (candidate) {
            for (NSString *inner in @[@"media", @"post", @"feedItem"]) {
                id nested = nil;
                @try { nested = [candidate valueForKey:inner]; } @catch (__unused id e) {}

                if (SCIHasMediaPayload(nested)) return nested;
            }
        }
    }

    return nil;
}

// Walks the delegate chain first, then the view hierarchy, looking for the media
// backing this action row.
static id SCIMediaForButtonBar(UIView *bar) {
    for (NSString *key in @[@"delegate", @"dataSource"]) {
        id owner = nil;
        @try { owner = [bar valueForKey:key]; } @catch (__unused id e) {}

        id media = SCIMediaFromOwner(owner);
        if (media) return media;

        // Delegates commonly forward to another object holding the media.
        id nested = nil;
        @try { nested = [owner valueForKey:@"delegate"]; } @catch (__unused id e) {}

        media = SCIMediaFromOwner(nested);
        if (media) return media;
    }

    // Then the enclosing cell, which is where the long-press path finds it.
    UIView *ancestor = bar.superview;
    while (ancestor) {
        id media = SCIMediaFromOwner(ancestor);
        if (media) return media;

        // The cell's own view controller can hold it instead.
        id nextResponder = [ancestor nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            media = SCIMediaFromOwner(nextResponder);
            if (media) return media;
        }

        ancestor = ancestor.superview;
    }

    return nil;
}

// "@username" for the post's author, used as the queue row subtitle. Best-effort:
// an unknown media shape just yields nil and the row shows no source.
static NSString *SCIUsernameForMedia(id media) {
    id user = nil;
    @try { user = [media valueForKey:@"user"]; } @catch (__unused id e) {}

    NSString *username = nil;
    @try { username = [user valueForKey:@"username"]; } @catch (__unused id e) {}

    return [username length] ? [NSString stringWithFormat:@"@%@", username] : nil;
}

static void SCIDownloadMedia(id media, UIView *anchorView) {
    [SCIDiagnostics recordButtonMediaClass:media ? NSStringFromClass([media class]) : nil];

    // Everything — quality picker, queue routing, delegate choice — lives in the
    // coordinator, so the button behaves identically to a long press.
    [SCIMediaDownloader downloadMedia:media
                          sourceLabel:SCIUsernameForMedia(media)
                               anchor:anchorView];
}

// MARK: - Carousels

// IGMedia answers whether it is a multi-item post and hands back the child media —
// far more reliable than hunting the view hierarchy for the (Swift, non-view)
// IGPageMediaView, whose accessors also changed on IG 410.
static BOOL SCIMediaIsCarousel(id media) {
    if (!media) return NO;
    @try {
        if ([media respondsToSelector:@selector(isCarousel)]) return [[media valueForKey:@"isCarousel"] boolValue];
    } @catch (__unused id e) {}
    return NO;
}

static NSArray *SCICarouselChildren(id media) {
    if (!SCIMediaIsCarousel(media)) return nil;

    for (NSString *key in @[@"carouselMedia", @"items"]) {
        id children = nil;
        @try { children = [media valueForKey:key]; } @catch (__unused id e) {}
        if ([children isKindOfClass:[NSArray class]] && [(NSArray *)children count] > 1) return children;
    }
    return nil;
}

// The child media of the carousel backing this action row. The resolved media may be
// the current slide (not itself a carousel), so the owner chain is walked for the
// parent post that is.
static NSArray *SCICarouselChildrenForBar(UIView *bar) {
    NSArray *children = SCICarouselChildren(SCIMediaForButtonBar(bar));
    if (children) return children;

    UIView *ancestor = bar;
    NSInteger depth = 0;
    while (ancestor && depth++ < 14) {
        for (NSString *key in @[@"media", @"post", @"feedItem", @"mediaCellFeedItem"]) {
            id media = nil;
            @try { media = [ancestor valueForKey:key]; } @catch (__unused id e) {}

            children = SCICarouselChildren(media);
            if (children) return children;

            @try {
                id nested = media ? [media valueForKey:@"media"] : nil;
                children = SCICarouselChildren(nested);
                if (children) return children;
            } @catch (__unused id e) {}
        }

        id responder = [ancestor nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            for (NSString *key in @[@"media", @"post", @"feedItem"]) {
                id media = nil;
                @try { media = [responder valueForKey:key]; } @catch (__unused id e) {}
                children = SCICarouselChildren(media);
                if (children) return children;
            }
        }

        ancestor = ancestor.superview;
    }
    return nil;
}

// The button's action: on a multi-item post, offer "this one" or "all N"; otherwise
// download the single media directly.
static void SCIHandleDownloadForBar(UIView *bar, UIView *anchor) {
    id current = SCIMediaForButtonBar(bar);
    NSArray *children = [SCIUtils getBoolPref:@"carousel_download_choice"] ? SCICarouselChildrenForBar(bar) : nil;

    if (children.count > 1) {
        // If the resolved media is a child (not the carousel itself), it *is* the
        // current slide; otherwise fall back to the first.
        id currentSlide = SCIMediaIsCarousel(current) ? children.firstObject : (current ?: children.firstObject);

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"p_carousel_current")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [SCIMediaDownloader downloadMedia:currentSlide sourceLabel:nil anchor:anchor];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:SCILocalized(@"p_carousel_all"), (long)children.count]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            for (id child in children) [SCIMediaDownloader downloadMedia:child sourceLabel:nil anchor:anchor];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
        [topMostController() presentViewController:sheet animated:YES completion:nil];
        return;
    }

    SCIDownloadMedia(current, anchor);
}

///
/// Injection
///
/// Instagram ships two action-row implementations: the older Objective-C
/// `IGUFIButtonBarView` and the Swift `IGSocialUFIView`, and which one renders a
/// given post varies by build and surface. Both are hooked, and the layout below
/// deliberately avoids per-class accessors (`saveButton` exists on one and not
/// the other) — it measures the row's own controls instead, so it survives
/// whichever implementation is live.
///

// The action row's tappable elements, left to right.
//
// Counting only direct UIControl children finds one button: Instagram wraps like
// and comment in IGUFIButtonWithCountsView containers, which are plain views. A
// subview therefore counts as a control if it *is* one or *contains* one.
static BOOL SCIContainsControl(UIView *view, NSInteger depth) {
    if ([view isKindOfClass:[UIControl class]]) return YES;
    if (depth > 3) return NO;

    for (UIView *subview in view.subviews) {
        if (SCIContainsControl(subview, depth + 1)) return YES;
    }

    return NO;
}

static NSArray<UIView *> *SCIRowControls(UIView *bar) {
    NSMutableArray<UIView *> *controls = [NSMutableArray array];

    for (UIView *subview in bar.subviews) {
        if (subview.tag == SCIInlineDownloadButtonTag) continue;
        if (subview.hidden || subview.alpha < 0.01) continue;
        if (CGRectIsEmpty(subview.frame)) continue;
        if (!SCIContainsControl(subview, 0)) continue;

        [controls addObject:subview];
    }

    [controls sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        if (CGRectGetMinX(a.frame) == CGRectGetMinX(b.frame)) return NSOrderedSame;
        return (CGRectGetMinX(a.frame) < CGRectGetMinX(b.frame)) ? NSOrderedAscending : NSOrderedDescending;
    }];

    return controls;
}

static void SCILayoutInlineButton(UIView *bar, id target) {
    UIButton *button = (UIButton *)[bar viewWithTag:SCIInlineDownloadButtonTag];

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = SCIInlineDownloadButtonTag;
        button.accessibilityIdentifier = @"albrhi-download-button";
        button.accessibilityLabel = SCILocalized(@"inline_download_title");

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                            weight:UIImageSymbolWeightRegular];

        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config]
                forState:UIControlStateNormal];

        [button addTarget:target
                   action:@selector(sciInlineDownloadPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        // The reels UFI is sized exactly to its buttons, so anything appended below
        // lands outside its bounds and gets clipped away — attached but invisible.
        bar.clipsToBounds = NO;

        [bar addSubview:button];
    }

    NSArray<UIView *> *controls = SCIRowControls(bar);

    if (!controls.count || CGRectIsEmpty(bar.bounds)) {
        button.hidden = YES;
        return;
    }

    // Feed posts lay the row out horizontally; the reels UFI stacks vertically down
    // the right edge. Measure the spread on each axis and follow whichever the row
    // is actually using, instead of assuming.
    CGFloat minX = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, minY = CGFLOAT_MAX, maxY = -CGFLOAT_MAX;

    for (UIView *control in controls) {
        minX = MIN(minX, CGRectGetMinX(control.frame));
        maxX = MAX(maxX, CGRectGetMaxX(control.frame));
        minY = MIN(minY, CGRectGetMinY(control.frame));
        maxY = MAX(maxY, CGRectGetMaxY(control.frame));
    }

    BOOL vertical = (maxY - minY) > (maxX - minX);

    UIView *reference = controls.lastObject;
    CGFloat side = MAX(MIN(CGRectGetHeight(reference.frame), CGRectGetWidth(reference.frame)), 22.0);
    CGFloat gap = 14.0;
    CGRect frame;

    if (vertical) {
        // Sort by vertical position and sit below the bottom-most control.
        NSArray<UIView *> *byY = [controls sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
            if (CGRectGetMinY(a.frame) == CGRectGetMinY(b.frame)) return NSOrderedSame;
            return (CGRectGetMinY(a.frame) < CGRectGetMinY(b.frame)) ? NSOrderedAscending : NSOrderedDescending;
        }];

        // Sits above the top-most control — above the like button on reels, where
        // it is immediately visible instead of buried under the action stack.
        // Overflowing the bar's bounds is fine: clipping is off.
        UIView *top = byY.firstObject;
        CGFloat y = CGRectGetMinY(top.frame) - side - gap;

        frame = CGRectMake(CGRectGetMidX(top.frame) - side / 2.0, y, side, side);
        button.hidden = NO;
    }
    else {
        // The save button sits at the trailing edge; slot in just inside it.
        UIView *rightmost = controls.lastObject;
        CGFloat x = CGRectGetMinX(rightmost.frame) - side - gap;

        if (controls.count > 1) {
            UIView *neighbour = controls[controls.count - 2];

            if (x < CGRectGetMaxX(neighbour.frame) + 6.0) {
                x = CGRectGetMaxX(rightmost.frame) + gap;
            }
        }

        if (x < 0 || x + side > CGRectGetWidth(bar.bounds)) {
            x = CGRectGetWidth(bar.bounds) - side - gap;
        }

        frame = CGRectMake(x, CGRectGetMidY(rightmost.frame) - side / 2.0, side, side);
        button.hidden = (x < 0);
    }

    button.tintColor = [UIColor labelColor];
    button.frame = frame;

    [bar bringSubviewToFront:button];
}

static void SCILogRowOnce(UIView *bar) {
    static NSMutableSet<NSString *> *seen = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ seen = [NSMutableSet set]; });

    NSString *className = NSStringFromClass([bar class]);
    if ([seen containsObject:className]) return;

    [seen addObject:className];

    NSInteger controlCount = (NSInteger)SCIRowControls(bar).count;

    [SCIDiagnostics recordActionRowClass:className controlCount:controlCount];

    SCILogV(@"[Albrhi] Inline download: attached to %@ (%ld controls, bounds %@)",
          className, (long)controlCount, NSStringFromCGRect(bar.bounds));
}

static void SCIRefreshInlineButton(UIView *bar, id target) {
    if (![SCIUtils getBoolPref:@"inline_download_button"]) {
        [[bar viewWithTag:SCIInlineDownloadButtonTag] removeFromSuperview];
        return;
    }

    SCILogRowOnce(bar);
    SCILayoutInlineButton(bar, target);
}

// The row Instagram 410 renders, confirmed by scanning the live hierarchy rather
// than by reading class names out of a dump.
%hook IGUFIInteractionCountsView

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end

// The reels action bar — vertical, on the right edge. Confirmed by hierarchy scan.
%hook IGSundialViewerVerticalUFI

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end

// Older Objective-C action row, kept for builds that still use it.
%hook IGUFIButtonBarView

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end
