#import <UIKit/UIKit.h>
#import "SCITWActionRow.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Localization/SCILocalize.h"

static BOOL sciRowPresent = NO, sciSharePresent = NO;
static NSUInteger sciHidBookmark = 0, sciRendered = 0;

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

    // The view count is not hidden here. It has its own named feature, which answers
    // `view_counts_public_visibility_enabled` -- a question X asks nearly four thousand
    // times in a session -- so the count is never drawn rather than drawn and covered. Two
    // switches for one intention is the mistake this removes, and the better half wins:
    // this row lays its buttons out by hand, so a hidden one can leave its space behind.
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
/// **The picture came back mirrored, and the emblem in it is what proved that.** 0.17.3
/// read the report as re-layout -- the share button had moved sides and Arabic read from
/// the wrong end -- and re-layout cannot reverse a *bitmap*. A photograph in the post was
/// mirrored too, and `@SaudiDCD` came out as `DCDibuaS@` with the letters themselves the
/// wrong way round. Only a horizontal flip of the whole context does that.
///
/// **Where the flip comes from: UIKit mirrors right-to-left content with a transform, and
/// `-renderInContext:` does not apply the receiver's own.** So on screen the subtree is laid
/// out one way and flipped by a transform above it, which reads correctly; rendered without
/// that transform it is the raw, unflipped -- that is, mirrored -- arrangement, bitmaps
/// included, because the bitmaps are stored pre-mirrored to survive the flip.
///
/// **It is measured rather than assumed.** Two points of the subject's own bounds are
/// converted into window coordinates: if its left edge lands to the *right* of its right
/// edge, everything between here and the window is mirrored, whatever applied it and
/// wherever it sits in the ancestry. The context is then flipped to match before anything is
/// drawn. A build that stops mirroring this way measures as not mirrored and nothing is
/// applied, so the correction cannot become the next bug.
static NSUInteger sciDrewByLayer = 0, sciDrewByHierarchy = 0, sciDrewMirrored = 0;

/// Whether this view is drawn through a horizontal flip somewhere above it.
static BOOL SCISubtreeIsMirrored(UIView *view) {
    UIView *reference = view.window ?: view.superview;
    if (!reference) return NO;

    CGPoint left = [view convertPoint:CGPointZero toView:reference];
    CGPoint right = [view convertPoint:CGPointMake(view.bounds.size.width, 0) toView:reference];
    return right.x < left.x;
}

static UIImage *SCIRenderAncestor(UIView *view) {
    UIView *subject = view;
    for (int depth = 0; depth < 8 && subject.superview; depth++) {
        subject = subject.superview;
        if (subject.bounds.size.height > 80 && subject.bounds.size.width > 200) break;
    }
    if (subject.bounds.size.width < 1 || subject.bounds.size.height < 1) return nil;

    // Laid out before it is drawn, on screen where the traits are real. Nothing after this
    // point lays anything out again -- the layer render draws what is already rasterised.
    [subject layoutIfNeeded];

    CGSize size = subject.bounds.size;
    BOOL mirrored = SCISubtreeIsMirrored(subject);
    if (mirrored) sciDrewMirrored++;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        if (mirrored) {
            CGContextTranslateCTM(context.CGContext, size.width, 0);
            CGContextScaleCTM(context.CGContext, -1, 1);
        }
        [subject.layer renderInContext:context.CGContext];
    }];
    sciDrewByLayer++;

    // A layer tree that rendered nothing leaves a fully transparent picture -- a visual
    // effect view or a hosted surface is the usual reason. The fallback uses NO, which does
    // not re-lay-out, and takes the same correction.
    if (image && SCIImageIsBlank(image)) {
        image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            if (mirrored) {
                CGContextTranslateCTM(context.CGContext, size.width, 0);
                CGContextScaleCTM(context.CGContext, -1, 1);
            }
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
        [parts addObject:[NSString stringWithFormat:@"bookmark hidden %lu",
                          (unsigned long)sciHidBookmark]];
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
