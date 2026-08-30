#import <UIKit/UIKit.h>
#import "SCITWActionRow.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Localization/SCILocalize.h"

static BOOL sciRowPresent = NO, sciSharePresent = NO;
static NSUInteger sciHidViewCount = 0, sciHidBookmark = 0, sciRendered = 0;

static BOOL sciOn(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// Hides, or shows again, every button of one class inside a row.
///
/// Both directions on every pass, because these views are reused: the row that hid an
/// analytics button is handed another post a moment later, and writing only the hiding
/// branch is how a switch turned off stays on until the app is restarted.
static NSUInteger SCISetHidden(UIView *root, NSString *className, BOOL hidden) {
    Class target = NSClassFromString(className);
    if (!root || !target) return 0;

    NSUInteger touched = 0;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([view isKindOfClass:target]) {
            if (view.hidden != hidden) {
                view.hidden = hidden;
                if (hidden) touched++;
            }
            continue;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return touched;
}


%group ActionRow

%hook TTAStatusInlineActionsView

- (void)setViewModel:(id)viewModel
             options:(NSUInteger)options
         displayType:(NSInteger)displayType
  displayTextOptions:(NSUInteger)textOptions
             account:(id)account {
    %orig;

    sciHidViewCount += SCISetHidden((UIView *)self, @"TTAStatusInlineAnalyticsButton",
                                    sciOn(SCIPrefHideViewCount));
    sciHidBookmark += SCISetHidden((UIView *)self, @"TTAStatusInlineBookmarkButton",
                                   sciOn(SCIPrefHideBookmark));
}

%end

%end


#pragma mark - A post as a picture

/// Renders the post the share button belongs to, exactly as it is drawn.
///
/// **`-drawViewHierarchyInRect:afterScreenUpdates:NO` was the wrong call, and it is the one
/// every tweak that does this uses.** `NO` does not copy the pixels already on screen -- it
/// asks the render server for whatever it last had for these layers, which for a view that
/// has not been composited in its current state is stale or incomplete. `YES` commits the
/// pending changes and renders properly, which is also the only version that re-runs text
/// layout with the view's real environment rather than with whatever the cached run held.
///
/// It returns a BOOL, and that return is checked here rather than ignored: a failed draw
/// falls back to the layer, which copies each layer's own rasterised contents and cannot
/// re-lay-out anything at all.
///
/// **What this does not claim to fix is Arabic coming out reversed** -- reported against
/// every tweak that offers this feature. Two different faults produce that complaint and
/// they need opposite repairs: a *mirrored* image, where the avatar and the icons are
/// flipped too, versus *reordered* text, where the pictures are fine and only the letters
/// are out of order. The report says which path drew the picture so the next round starts
/// from a fact.
static NSUInteger sciDrewByHierarchy = 0, sciDrewByLayer = 0;

static UIImage *SCIRenderAncestor(UIView *view) {
    UIView *subject = view;
    for (int depth = 0; depth < 8 && subject.superview; depth++) {
        subject = subject.superview;
        if (subject.bounds.size.height > 80 && subject.bounds.size.width > 200) break;
    }
    if (subject.bounds.size.width < 1 || subject.bounds.size.height < 1) return nil;

    // Laid out before it is drawn. A subject mid-layout renders as it is, not as it will be.
    [subject layoutIfNeeded];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:subject.bounds.size format:format];

    __block BOOL drawn = NO;
    UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        drawn = [subject drawViewHierarchyInRect:subject.bounds afterScreenUpdates:YES];
        if (!drawn) [subject.layer renderInContext:UIGraphicsGetCurrentContext()];
    }];

    if (drawn) sciDrewByHierarchy++;
    else sciDrewByLayer++;
    return image;
}

%group ActionRowShare

%hook TTAStatusInlineShareButton

- (void)didLongPressActionButton:(UILongPressGestureRecognizer *)gesture {
    if (!sciOn(SCIPrefTweetToImage)) {
        %orig;
        return;
    }

    // Only once per gesture. A long press reports began, changed and ended, and rendering
    // on each would put three sheets on screen.
    if (gesture.state != UIGestureRecognizerStateBegan) {
        %orig;
        return;
    }

    UIImage *image = SCIRenderAncestor((UIView *)self);
    if (!image) {
        // Nothing rendered, so X's own long press is left to run. Refusing both would be a
        // feature that quietly removes an existing gesture.
        %orig;
        return;
    }

    sciRendered++;

    UIActivityViewController *sheet =
        [[UIActivityViewController alloc] initWithActivityItems:@[image]
                                         applicationActivities:nil];

    UIWindow *key = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { key = window; break; }
    }
    UIViewController *top = key.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) {
        %orig;
        return;
    }

    sheet.popoverPresentationController.sourceView = (UIView *)self;
    sheet.popoverPresentationController.sourceRect = ((UIView *)self).bounds;
    [top presentViewController:sheet animated:YES completion:nil];
}

%end

%end


NSString *SCITWActionRowReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (!sciRowPresent) {
        [parts addObject:@"TTAStatusInlineActionsView not in this build"];
    } else {
        [parts addObject:[NSString stringWithFormat:@"view count hidden %lu · bookmark hidden %lu",
                          (unsigned long)sciHidViewCount, (unsigned long)sciHidBookmark]];
    }

    if (!sciSharePresent) {
        [parts addObject:@"share button absent"];
    } else {
        [parts addObject:[NSString stringWithFormat:@"rendered %lu (%lu hierarchy, %lu layer)",
                          (unsigned long)sciRendered, (unsigned long)sciDrewByHierarchy,
                          (unsigned long)sciDrewByLayer]];
    }

    return [@"action row: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}

void SCITWInstallActionRow(void) {
    sciRowPresent = (NSClassFromString(@"TTAStatusInlineActionsView") != nil);
    if (sciRowPresent) {
        %init(ActionRow);
    }

    sciSharePresent = (NSClassFromString(@"TTAStatusInlineShareButton") != nil);
    if (sciSharePresent) {
        %init(ActionRowShare);
    }

    SCILogV(@"action row: row %d, share %d", sciRowPresent, sciSharePresent);
}
