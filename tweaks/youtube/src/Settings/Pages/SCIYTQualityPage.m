#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

///
/// Quality: two ceilings and the full picker.
///
/// The caps are their own rows rather than one "data saver" switch because the two
/// connections are not one decision: a phone on home Wi-Fi and the same phone on a metered
/// plan abroad want different answers, and a single switch makes you choose which of the two
/// to be wrong about.
///
@interface SCIYTQualityPage : NSObject
@end

/// The ceilings offered, highest first, with "no limit" as the default.
///
/// Real resolutions, not menu positions: the stored value is 1080 rather than "the third one
/// down", so reordering this list can never quietly change what someone chose.
static NSArray<NSNumber *> *SCIQualityCaps(void) {
    return @[@0, @2160, @1440, @1080, @720, @480, @360, @144];
}

static NSString *SCIQualityLabel(NSInteger cap) {
    if (cap <= 0) return SCILocalized(@"quality_auto");
    return [NSString stringWithFormat:SCILocalized(@"quality_cap_format"), (long)cap];
}

/// Asks which ceiling, and remembers the answer.
///
/// Presented from the screen it was tapped on rather than from the key window: the settings
/// panel is itself presented over YouTube, and a sheet asking the window would arrive
/// underneath it.
static void SCIAskForCap(SCIYTSettingsHostController *host, NSString *key) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"set_cap_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *cap in SCIQualityCaps()) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCIQualityLabel(cap.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:cap.integerValue forKey:key];

            // Rebuilt, not just reloaded: the row's subtitle is the chosen value, and it is
            // made when the section is made.
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // Required on iPad and harmless on a phone. Without it the sheet has nothing to point at
    // and UIKit raises rather than guessing.
    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 0, 0);

    [host presentViewController:sheet animated:YES completion:nil];
}

@implementation SCIYTQualityPage

+ (void)load {
    [SCIYTSettingsRegistry registerSectionsWithOrder:20
                                             builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *quality = [[SCISection alloc] init];
        quality.title = SCILocalized(@"section_quality");
        quality.footer = SCILocalized(@"set_cap_note");
        quality.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_cap_wifi")
                           detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapWiFi))
                           symbol:@"wifi"
                           action:^{ SCIAskForCap(host, SCIPrefCapWiFi); }],
            [SCIRow disclosureRow:SCILocalized(@"set_cap_cellular")
                           detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapCellular))
                           symbol:@"antenna.radiowaves.left.and.right"
                           action:^{ SCIAskForCap(host, SCIPrefCapCellular); }],
            [SCIRow switchRow:SCILocalized(@"set_classic_quality")
                       detail:SCILocalized(@"set_classic_quality_note")
                       symbol:@"list.bullet"
                      prefKey:SCIPrefClassicQuality],
        ];
        return @[quality];
    }];
}

@end
