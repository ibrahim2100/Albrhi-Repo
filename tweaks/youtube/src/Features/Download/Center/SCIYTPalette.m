#import "SCIYTPalette.h"

/// The grid the cover is reduced to. Twelve squared is 144 samples, which is plenty to find
/// what a picture is mostly made of and few enough that the whole thing is free.
static const size_t kSCIGrid = 12;

/// How dark the background is allowed to get to.
///
/// White text sits on this, so the ceiling is not a matter of taste. A pale cover that kept
/// its own brightness would produce a screen nobody can read the title on.
static const CGFloat kSCIBackgroundCeiling = 0.34;


@implementation SCIYTPalette

/// The cover as 144 pixels, or NULL.
static uint8_t *SCISamples(UIImage *image, size_t *countOut) {
    if (!image.CGImage) return NULL;

    size_t bytesPerRow = kSCIGrid * 4;
    uint8_t *pixels = calloc(kSCIGrid * bytesPerRow, 1);
    if (!pixels) return NULL;

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, kSCIGrid, kSCIGrid, 8, bytesPerRow,
                                                 space,
                                                 kCGImageAlphaPremultipliedLast |
                                                 kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);

    if (!context) { free(pixels); return NULL; }

    // Interpolation on, deliberately: each of the 144 pixels should be an average of the
    // region it stands for rather than one sampled point, or a cover with a small bright
    // logo on black would report itself as that logo.
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    CGContextDrawImage(context, CGRectMake(0, 0, kSCIGrid, kSCIGrid), image.CGImage);
    CGContextRelease(context);

    *countOut = kSCIGrid * kSCIGrid;
    return pixels;
}

/// The most colourful pixel in the grid, and the average of all of them.
///
/// Two answers rather than one, because they are wanted for different things. The average is
/// what the picture *is*, which makes an honest background. The most colourful is what the
/// picture is *about*, which makes an accent worth looking at -- and on most covers those are
/// nothing like each other, since most covers are mostly dark.
static void SCIRead(UIImage *image,
                    CGFloat *avgH, CGFloat *avgS, CGFloat *avgB,
                    CGFloat *vividH, CGFloat *vividS, CGFloat *vividB) {

    *avgH = 0; *avgS = 0; *avgB = 0.18;
    *vividH = 0; *vividS = 0; *vividB = 0.6;

    size_t count = 0;
    uint8_t *pixels = SCISamples(image, &count);
    if (!pixels) return;

    double sumR = 0, sumG = 0, sumB = 0;
    CGFloat bestScore = -1;
    size_t used = 0;

    for (size_t i = 0; i < count; i++) {
        const uint8_t *p = pixels + (i * 4);
        if (p[3] < 128) continue;   // transparent, and not part of the picture

        CGFloat r = p[0] / 255.0, g = p[1] / 255.0, b = p[2] / 255.0;
        sumR += r; sumG += g; sumB += b;
        used++;

        CGFloat h, s, v;
        [[UIColor colorWithRed:r green:g blue:b alpha:1] getHue:&h saturation:&s brightness:&v alpha:NULL];

        // Colourful *and* bright enough to see. Saturation alone picks a dark red that is
        // technically the most saturated pixel and useless as an accent.
        CGFloat score = s * (v > 0.25 ? v : 0);
        if (score > bestScore) {
            bestScore = score;
            *vividH = h; *vividS = s; *vividB = v;
        }
    }

    free(pixels);
    if (!used) return;

    UIColor *mean = [UIColor colorWithRed:sumR / used green:sumG / used blue:sumB / used alpha:1];
    [mean getHue:avgH saturation:avgS brightness:avgB alpha:NULL];
}

+ (NSArray<UIColor *> *)backgroundFor:(UIImage *)image {
    CGFloat h, s, b, vh, vs, vb;
    SCIRead(image, &h, &s, &b, &vh, &vs, &vb);

    // The average hue, held to a readable brightness, and a little of the vivid one mixed in
    // so a nearly-grey cover still gets a background with some life in it.
    CGFloat hue = (s > 0.08) ? h : vh;
    CGFloat saturation = MIN(MAX(s, vs * 0.45), 0.55);

    UIColor *top = [UIColor colorWithHue:hue
                              saturation:saturation
                              brightness:MIN(b + 0.10, kSCIBackgroundCeiling)
                                   alpha:1];

    // The bottom is the same colour with the light taken out of it rather than a second
    // colour. Two unrelated hues in one gradient reads as a decoration; one hue fading into
    // its own shadow reads as depth.
    UIColor *bottom = [UIColor colorWithHue:hue
                                 saturation:saturation * 0.8
                                 brightness:0.06
                                      alpha:1];

    return @[top, bottom];
}

+ (UIImage *)squareArtwork:(UIImage *)image side:(CGFloat)side {
    if (!image || side <= 0) return image;

    // Already square enough. A cover that is within a few per cent of square is left alone
    // rather than redrawn onto a ground it does not need.
    CGFloat ratio = image.size.width / MAX(image.size.height, 1);
    if (ratio > 0.95 && ratio < 1.05) return image;

    NSArray<UIColor *> *pair = [self backgroundFor:image];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef ctx = context.CGContext;

        // The ground, from the picture's own colours -- so the bars that used to be black are
        // now the album's colour, and the whole tile reads as one object.
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat stops[2] = {0, 1};
        NSArray *colors = @[(id)pair.firstObject.CGColor, (id)pair.lastObject.CGColor];
        CGGradientRef gradient =
            CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, stops);

        CGContextDrawLinearGradient(ctx, gradient,
                                    CGPointMake(0, 0), CGPointMake(0, side), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);

        // The picture, whole, centred, and inset a little so it sits *on* the ground rather
        // than butting against its edges.
        CGFloat inset = side * 0.06;
        CGFloat room = side - (inset * 2);
        CGFloat scale = MIN(room / image.size.width, room / image.size.height);
        CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);

        CGRect frame = CGRectMake((side - drawn.width) / 2,
                                  (side - drawn.height) / 2,
                                  drawn.width, drawn.height);

        // A soft edge under it, which is what separates the picture from a ground made of
        // the same colours as the picture.
        // Saved and restored around the clip.
        //
        // -addClip narrows the context permanently, and a shadow set outside a saved state
        // applies to everything drawn afterwards. Nothing is drawn after this today, which
        // is exactly the kind of "correct until someone adds a line" that is worth two calls
        // to avoid.
        CGContextSaveGState(ctx);

        CGContextSetShadowWithColor(ctx, CGSizeMake(0, side * 0.012), side * 0.03,
                                    [UIColor colorWithWhite:0 alpha:0.5].CGColor);

        UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:frame
                                                          cornerRadius:side * 0.035];

        // The layer is what makes one shadow for the rounded picture rather than a shadow
        // per drawing operation inside it.
        CGContextBeginTransparencyLayer(ctx, NULL);
        [rounded addClip];
        [image drawInRect:frame];
        CGContextEndTransparencyLayer(ctx);

        CGContextRestoreGState(ctx);
    }];
}

+ (UIColor *)accentFor:(UIImage *)image {
    CGFloat h, s, b, vh, vs, vb;
    SCIRead(image, &h, &s, &b, &vh, &vs, &vb);

    // A floor under both, because this has to be visible against the background above --
    // which came from the same picture, so a washed-out cover would otherwise produce a
    // control the same colour as what it sits on.
    return [UIColor colorWithHue:vh
                      saturation:MAX(vs, 0.55)
                      brightness:MAX(vb, 0.82)
                           alpha:1];
}

@end
