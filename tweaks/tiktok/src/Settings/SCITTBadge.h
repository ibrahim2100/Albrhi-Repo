//
//  SCITTBadge.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The small rounded colour badge Settings.app draws beside its own rows.
///
/// It lived as a `static` inside the settings screen until the diagnostics moved onto a screen
/// of their own, at which point one of the two would have had to draw its icons a second way --
/// and two badge drawers is how two screens in one tweak stop looking like one tweak. Declared
/// `static inline` in a header rather than compiled once, because that is what every other
/// shared helper in this project does and there is no state to share.
///
static inline UIImage *SCITTBadgeImage(NSString *symbolName, UIColor *color) {
    CGSize size = CGSizeMake(29, 29);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                              format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *background =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                      cornerRadius:8];
        [(color ?: [UIColor systemGrayColor]) setFill];
        [background fill];

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:15
                                                           weight:UIImageSymbolWeightSemibold];
        UIImage *glyph = [[UIImage systemImageNamed:symbolName withConfiguration:config]
            imageWithTintColor:[UIColor whiteColor]
                 renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (!glyph) return;

        [glyph drawAtPoint:CGPointMake((size.width - glyph.size.width) / 2,
                                       (size.height - glyph.size.height) / 2)];
    }];
}
