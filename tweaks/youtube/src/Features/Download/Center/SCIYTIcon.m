#import "SCIYTIcon.h"

@implementation SCIYTIcon

+ (UIImage *)downloadMarkOfSize:(CGFloat)size filled:(BOOL)filled {
    if (size <= 0) return nil;

    static NSCache<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });

    NSString *key = [NSString stringWithFormat:@"%.1f-%d", size, filled ? 1 : 0];
    UIImage *ready = [cache objectForKey:key];
    if (ready) return ready;

    // Proportions are fractions of the box, not point values. The tab bar asks for one
    // size and the settings row for another, and a mark drawn from constants looks correct
    // at whichever size it was tuned for and wrong at the other.
    CGFloat stroke = MAX(1.5, size * 0.085);
    CGFloat inset = stroke;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef ctx = context.CGContext;
        CGContextSetLineWidth(ctx, stroke);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        [[UIColor blackColor] setStroke];
        [[UIColor blackColor] setFill];

        CGFloat middle = size / 2.0;

        // The tray: a flat base with two short uprights, open at the top so the arrow can
        // fall into it. Drawn as one path so the corners join rather than butt.
        CGFloat trayTop = size * 0.66;
        CGFloat trayBottom = size - inset - stroke / 2;
        CGFloat left = inset + stroke / 2;
        CGFloat right = size - inset - stroke / 2;

        UIBezierPath *tray = [UIBezierPath bezierPath];
        [tray moveToPoint:CGPointMake(left, trayTop)];
        [tray addLineToPoint:CGPointMake(left, trayBottom)];
        [tray addLineToPoint:CGPointMake(right, trayBottom)];
        [tray addLineToPoint:CGPointMake(right, trayTop)];
        tray.lineWidth = stroke;
        tray.lineCapStyle = kCGLineCapRound;
        tray.lineJoinStyle = kCGLineJoinRound;
        [tray stroke];

        // The arrow: a stem and a head, the head wide enough to read at tab size and no
        // wider. Its point stops short of the tray so the two never touch.
        CGFloat top = inset + stroke / 2;
        CGFloat point = size * 0.52;
        CGFloat spread = size * 0.20;

        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(middle, top)];
        [arrow addLineToPoint:CGPointMake(middle, point)];

        [arrow moveToPoint:CGPointMake(middle - spread, point - spread)];
        [arrow addLineToPoint:CGPointMake(middle, point)];
        [arrow addLineToPoint:CGPointMake(middle + spread, point - spread)];

        arrow.lineWidth = stroke;
        arrow.lineCapStyle = kCGLineCapRound;
        arrow.lineJoinStyle = kCGLineJoinRound;
        [arrow stroke];

        // Selected state: the tray fills in. The same mark rather than a second one, so the
        // tab does not appear to change shape when it becomes the open one -- which is how
        // YouTube's own tabs behave.
        if (filled) {
            UIBezierPath *solid = [UIBezierPath bezierPath];
            [solid moveToPoint:CGPointMake(left, trayTop + stroke)];
            [solid addLineToPoint:CGPointMake(left, trayBottom)];
            [solid addLineToPoint:CGPointMake(right, trayBottom)];
            [solid addLineToPoint:CGPointMake(right, trayTop + stroke)];
            [solid closePath];
            [solid fill];
        }
    }];

    UIImage *template = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [cache setObject:template forKey:key];
    return template;
}

@end
