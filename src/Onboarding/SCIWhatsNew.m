#import "SCIWhatsNew.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"

/// Last version whose welcome screen the user actually saw.
static NSString *const SCILastSeenVersionKey = @"albrhi_last_seen_version";

@implementation SCIWhatsNewItem

+ (instancetype)itemWithSymbol:(NSString *)symbolName
                         title:(NSString *)title
                        detail:(NSString *)detail
                          tint:(UIColor *)tint {
    SCIWhatsNewItem *item = [[SCIWhatsNewItem alloc] init];
    if (!item) return nil;

    item->_symbolName = [symbolName copy];
    item->_title = [title copy];
    item->_detail = [detail copy];
    item->_tint = tint;

    return item;
}

@end

@implementation SCIWhatsNew

// MARK: - Presentation decision

+ (NSString *)lastSeenVersion {
    return [[NSUserDefaults standardUserDefaults] stringForKey:SCILastSeenVersionKey];
}

+ (BOOL)isFirstInstall {
    // The legacy key means an older Albrhi ran here — an update, not a fresh install.
    BOOL ranBefore = [[NSUserDefaults standardUserDefaults] objectForKey:@"SCInstaFirstRun"] != nil;

    return ![self lastSeenVersion] && !ranBefore;
}

+ (BOOL)shouldPresent {
    return ![[self lastSeenVersion] isEqualToString:SCIVersionString];
}

+ (void)markCurrentVersionSeen {
    [[NSUserDefaults standardUserDefaults] setObject:SCIVersionString forKey:SCILastSeenVersionKey];
}

// MARK: - Copy

+ (NSString *)headlineForFirstInstall:(BOOL)firstInstall {
    if (firstInstall) return SCILocalized(@"wn_welcome_title");

    return [NSString stringWithFormat:SCILocalized(@"wn_update_title"), SCIVersionString];
}

+ (NSString *)subheadlineForFirstInstall:(BOOL)firstInstall {
    return firstInstall ? SCILocalized(@"wn_welcome_sub") : SCILocalized(@"wn_update_sub");
}

+ (NSString *)footnoteForFirstInstall:(BOOL)firstInstall {
    return firstInstall ? SCILocalized(@"wn_footnote_welcome") : SCILocalized(@"wn_footnote_update");
}

+ (NSArray<SCIWhatsNewItem *> *)itemsForFirstInstall:(BOOL)firstInstall {
    UIColor *accent = [SCIUtils SCIColor_Primary];

    // First install answers "what is this and where do I start".
    // An update answers "what changed since you last looked".
    if (firstInstall) {
        return @[
            [SCIWhatsNewItem itemWithSymbol:@"arrow.down.circle.fill"
                                      title:SCILocalized(@"wn_w1_title")
                                     detail:SCILocalized(@"wn_w1_detail")
                                       tint:accent],
            [SCIWhatsNewItem itemWithSymbol:@"eye.slash.fill"
                                      title:SCILocalized(@"wn_w2_title")
                                     detail:SCILocalized(@"wn_w2_detail")
                                       tint:[UIColor systemIndigoColor]],
            [SCIWhatsNewItem itemWithSymbol:@"sparkles"
                                      title:SCILocalized(@"wn_w3_title")
                                     detail:SCILocalized(@"wn_w3_detail")
                                       tint:[UIColor systemTealColor]],
            [SCIWhatsNewItem itemWithSymbol:@"hand.tap.fill"
                                      title:SCILocalized(@"wn_w4_title")
                                     detail:SCILocalized(@"wn_w4_detail")
                                       tint:[UIColor systemPinkColor]],
            [SCIWhatsNewItem itemWithSymbol:@"stethoscope"
                                      title:SCILocalized(@"wn_w5_title")
                                     detail:SCILocalized(@"wn_w5_detail")
                                       tint:[UIColor systemOrangeColor]]
        ];
    }

    return @[
        [SCIWhatsNewItem itemWithSymbol:@"eye.circle.fill"
                                  title:SCILocalized(@"wn_u1_title")
                                 detail:SCILocalized(@"wn_u1_detail")
                                   tint:accent],
        [SCIWhatsNewItem itemWithSymbol:@"scissors"
                                  title:SCILocalized(@"wn_u2_title")
                                 detail:SCILocalized(@"wn_u2_detail")
                                   tint:[UIColor systemPurpleColor]],
        [SCIWhatsNewItem itemWithSymbol:@"stethoscope"
                                  title:SCILocalized(@"wn_u3_title")
                                 detail:SCILocalized(@"wn_u3_detail")
                                   tint:[UIColor systemTealColor]],
        [SCIWhatsNewItem itemWithSymbol:@"shippingbox.fill"
                                  title:SCILocalized(@"wn_u4_title")
                                 detail:SCILocalized(@"wn_u4_detail")
                                   tint:[UIColor systemGreenColor]]
    ];
}

@end
