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

/// Whether a rendered picture is entirely transparent.
///
/// Sampled at nine points rather than scanned: this runs on a long press, on the main
/// thread, and reading every pixel of a full-width cell to answer "did anything draw" would
/// cost more than the drawing did. Nine points across the frame cannot miss a picture and
/// cannot be fooled by one that is genuinely blank.
static BOOL SCIImageIsBlank(UIImage *image) {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return YES;

    size_t width = CGImageGetWidth(cgImage), height = CGImageGetHeight(cgImage);
    if (!width || !height) return YES;

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    for (int row = 1; row <= 3; row++) {
        for (int column = 1; column <= 3; column++) {
            uint8_t pixel[4] = {0, 0, 0, 0};
            CGContextRef context =
                CGBitmapContextCreate(pixel, 1, 1, 8, 4, space,
                                      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            if (!context) { CGColorSpaceRelease(space); return NO; }

            CGContextTranslateCTM(context,
                                  -(CGFloat)(width * column / 4),
                                  -(CGFloat)(height * row / 4));
            CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), cgImage);
            CGContextRelease(context);

            if (pixel[3] != 0) { CGColorSpaceRelease(space); return NO; }
        }
    }
    CGColorSpaceRelease(space);
    return YES;
}


/// Renders the post the share button belongs to, exactly as it is drawn.
///
/// **The whole picture came out laid out left-to-right, and the cause is re-layout, not a
/// mirror.** A mirrored image would have mirrored the glyphs too; these were the right way
/// round and merely in the wrong order, and the share button had moved from the bottom left
/// of the screen to the bottom right of the picture. That is UIKit's right-to-left support
/// doing exactly what it does — **RTL is implemented as mirrored layout, decided at layout
/// time from the view's trait environment** — and being asked to lay the subtree out again
/// inside an image context, which has no window and no traits, so it resolves as
/// left-to-right and rebuilds the whole thing the other way round. The text goes with it:
/// re-laid-out runs get an LTR base direction, so a word reads from its last letter.
///
/// `-drawViewHierarchyInRect:afterScreenUpdates:YES` asks for precisely that re-layout, and
/// 0.17.2 turned it on for an unrelated and real reason. **The answer is not to re-lay-out
/// at all.** `-renderInContext:` walks the layer tree and draws what each layer already
/// holds — text that was rasterised while the view was on screen, in the order it was drawn
/// there — so there is no layout pass to get the direction wrong, and nothing for the
/// bidirectional algorithm to redo.
///
/// The hierarchy call is kept as the fallback, with `NO`, which at least does not re-lay-out
/// either. The report names which path drew each picture.
static NSUInteger sciDrewByLayer = 0, sciDrewByHierarchy = 0;

static UIImage *SCIRenderAncestor(UIView *view) {
    UIView *subject = view;
    for (int depth = 0; depth < 8 && subject.superview; depth++) {
        subject = subject.superview;
        if (subject.bounds.size.height > 80 && subject.bounds.size.width > 200) break;
    }
    if (subject.bounds.size.width < 1 || subject.bounds.size.height < 1) return nil;

    // Laid out before it is drawn, on screen where the traits are real. Nothing after this
    // point is allowed to lay anything out again.
    [subject layoutIfNeeded];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:subject.bounds.size format:format];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [subject.layer renderInContext:context.CGContext];
    }];
    sciDrewByLayer++;

    // A layer tree that rendered nothing leaves a fully transparent picture -- a visual
    // effect view or a hosted surface is the usual reason. Falling back is worth it there,
    // and the fallback uses NO so it cannot reintroduce the re-layout this exists to avoid.
    if (image && SCIImageIsBlank(image)) {
        image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            [subject drawViewHierarchyInRect:subject.bounds afterScreenUpdates:NO];
        }];
        sciDrewByLayer--;
        sciDrewByHierarchy++;
    }

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
