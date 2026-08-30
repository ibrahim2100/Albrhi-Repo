#import "../Model/SCITWPageRegistry.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// The named features, built from the table rather than written out here.
///
/// One row per feature, in the order the table lists them, so adding a feature adds a row
/// and there is no second list to forget. Each carries its own icon and colour from the
/// table too -- kept there rather than here, because a feature and the way it is drawn
/// drifting apart is exactly what happens when a table gains a row and a screen fifty lines
/// below does not.
///
@interface SCITWPageFeatures : NSObject
@end

@implementation SCITWPageFeatures

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:60
                                   title:SCILocalized(@"section_features")
                                    note:SCILocalized(@"features_footer")
                                  symbol:@"switch.2"
                                    tint:[UIColor systemPurpleColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSwitchLayer]) {
            // The layer is off, so the rows would be switches that decide nothing. Shown as
            // nothing at all rather than as a section that silently does not apply.
            return @[];
        }

        NSMutableArray<SCITWRow *> *rows = [NSMutableArray array];
        for (SCITWFeature *feature in [SCITWFeatures all]) {
            SCITWRow *row =
                [SCITWRow switchRow:SCILocalized(feature.titleKey)
                               note:SCILocalized(feature.noteKey)
                             symbol:feature.iconName
                               tint:feature.iconColor
                            prefKey:[SCIPrefFeaturePrefix stringByAppendingString:feature.identifier]];
            row.cautious = feature.cautious;

            // Recomputed rather than edited. The feature layer builds its whole map from
            // every switched-on feature on each change, so there is no bookkeeping here to
            // get wrong -- which is the reason this project keeps named features and
            // hand-set keys as two maps instead of one.
            row.onChange = ^(__unused BOOL on) { [SCITWFeatures apply]; };
            [rows addObject:row];
        }

        return @[[SCITWSection titled:SCILocalized(@"section_features")
                               footer:SCILocalized(@"features_footer")
                                 rows:rows]];
    }];
}

@end
