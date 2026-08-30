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
/// `-drawViewHierarchyInRect:afterScreenUpdates:` rather than a layer render: the second
/// draws the layer tree and misses anything UIKit composites afterwards, which on a post is
/// most of the text. Walking up to the row's own superview gets the whole cell rather than
/// the button.
static UIImage *SCIRenderAncestor(UIView *view) {
    UIView *subject = view;
    for (int depth = 0; depth < 8 && subject.superview; depth++) {
        subject = subject.superview;
        if (subject.bounds.size.height > 80 && subject.bounds.size.width > 200) break;
    }
    if (subject.bounds.size.width < 1 || subject.bounds.size.height < 1) return nil;

    UIGraphicsBeginImageContextWithOptions(subject.bounds.size, NO, 0);
    [subject drawViewHierarchyInRect:subject.bounds afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
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

    if (!sciSharePresent) [parts addObject:@"share button absent"];
    else [parts addObject:[NSString stringWithFormat:@"rendered %lu", (unsigned long)sciRendered]];

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
