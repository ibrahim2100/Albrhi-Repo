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

// Pulls an IGMedia-like object off an arbitrary owner using the accessor names
// Instagram uses across its cell/delegate/view-model layers.
static id SCIMediaFromOwner(id owner) {
    if (!owner) return nil;

    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[@"media", @"post", @"feedItem", @"_media", @"_post"];
    });

    for (NSString *key in keys) {
        id candidate = nil;
        @try { candidate = [owner valueForKey:key]; } @catch (__unused id e) {}

        if (!candidate) continue;

        // Only accept objects that actually expose media payloads.
        BOOL hasVideo = NO, hasPhoto = NO;
        @try { hasVideo = ([candidate valueForKey:@"video"] != nil); } @catch (__unused id e) {}
        @try { hasPhoto = ([candidate valueForKey:@"photo"] != nil); } @catch (__unused id e) {}

        if (hasVideo || hasPhoto) return candidate;
    }

    return nil;
}

// Walks the delegate chain first, then the view hierarchy, looking for the media
// backing this action row.
static id SCIMediaForButtonBar(UIView *bar) {
    id delegate = nil;
    @try { delegate = [bar valueForKey:@"delegate"]; } @catch (__unused id e) {}

    id media = SCIMediaFromOwner(delegate);
    if (media) return media;

    // IGFeedItemUFICell forwards to its own delegate, which is created with the media.
    id nested = nil;
    @try { nested = [delegate valueForKey:@"delegate"]; } @catch (__unused id e) {}

    media = SCIMediaFromOwner(nested);
    if (media) return media;

    // Last resort: the enclosing cell.
    UIView *ancestor = bar.superview;
    while (ancestor) {
        media = SCIMediaFromOwner(ancestor);
        if (media) return media;

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
    // Everything — quality picker, queue routing, delegate choice — lives in the
    // coordinator, so the button behaves identically to a long press.
    [SCIMediaDownloader downloadMedia:media
                          sourceLabel:SCIUsernameForMedia(media)
                               anchor:anchorView];
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

        UIView *bottom = byY.lastObject;
        CGFloat y = CGRectGetMaxY(bottom.frame) + gap;

        // No room below — tuck in above the top-most control instead.
        if (y + side > CGRectGetHeight(bar.bounds)) {
            y = CGRectGetMinY(byY.firstObject.frame) - side - gap;
        }

        frame = CGRectMake(CGRectGetMidX(bottom.frame) - side / 2.0, y, side, side);
        button.hidden = (y < 0);
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

    NSLog(@"[Albrhi] Inline download: attached to %@ (%ld controls, bounds %@)",
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

    SCIDownloadMedia(SCIMediaForButtonBar((UIView *)self), sender);
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

    SCIDownloadMedia(SCIMediaForButtonBar((UIView *)self), sender);
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

    SCIDownloadMedia(SCIMediaForButtonBar((UIView *)self), sender);
}

%end
