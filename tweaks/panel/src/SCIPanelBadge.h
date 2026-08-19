//
//  SCIPanelBadge.h
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// Albrhi's accent, the same value the tweaks draw with.
///
/// Copied rather than shared, and the reason is what sharing would cost: the tweaks keep it in
/// their own `Tweak.h`, which also pulls in a tweak's localisation and preference plumbing. The
/// panel is a preference bundle inside Settings and needs none of that -- one colour is a cheaper
/// duplicate than a header that drags a runtime behind it.
static inline UIColor *SCIPanelAccent(void) {
    return [UIColor colorWithRed:0.996 green:0.176 blue:0.333 alpha:1.0];
}

///
/// The small rounded colour badge Settings.app draws beside its own rows.
///
/// **A row with a mark on it is found by eye; a row without one is read.** The app rows already
/// carry the real app icon for that reason, and the rows that push to a tweak's own page had
/// nothing at all -- so the one kind of row that is *not* an app looked like an app whose icon
/// failed to load. This draws the mark those rows should have had, from an SF Symbol, at the size
/// Settings gives an icon.
///
static inline UIImage *SCIPanelBadgeImage(NSString *symbolName, UIColor *color) {
    CGSize size = CGSizeMake(29, 29);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                              format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *background =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                      cornerRadius:7];
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

/// The symbol and colour for a tweak that has its own page, by its group identifier.
///
/// Keyed on the identifier the filter plist already declares (`SCIPanelGroupIdentifier`) rather
/// than on the displayed name: the name is translated, and matching a translated string is a row
/// that loses its icon in Arabic.
static inline UIImage *SCIPanelBadgeForGroup(NSString *groupIdentifier) {
    if ([groupIdentifier isEqualToString:@"com.albrhi.nextup"]) {
        return SCIPanelBadgeImage(@"music.note.list", SCIPanelAccent());
    }
    // A tweak this build has never heard of still gets a mark rather than a gap.
    return SCIPanelBadgeImage(@"gearshape.fill", [UIColor systemGrayColor]);
}
