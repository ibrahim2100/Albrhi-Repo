#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"

///
/// Our own section inside YouTube's own settings.
///
/// Three hooks, and each one is needed for a different reason:
///
///   +settingsCategoryOrder      puts our row on the list of categories at all
///   -updateSectionForCategory:  answers when that row is opened
///   -settingsViewController...  is where the answer has to be handed to
///
/// Leave out the first and nothing appears. Leave out the second and the row appears
/// but opens an empty page, which reads as a broken tweak rather than an unfinished
/// one.
///
/// This is the same shape as Instagram's SCISettingsRegistry: the app's own widgets,
/// filled by us, so the panel looks like it shipped with the app instead of being a
/// foreign screen bolted on.
///

/// Our category number.
///
/// YouTube's own categories are small integers, and a collision would mean our page
/// replacing one of theirs. Deliberately far outside their range rather than
/// "probably free" -- there is no runtime error for picking an occupied number, only
/// a missing settings page that would be blamed on something else entirely.
static const NSInteger SCIYTSettingsCategory = 774100;

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;

    // Appended, not prepended: YouTube's own settings stay where the user learned
    // to find them, and ours sits at the end where an addition belongs.
    return [order arrayByAddingObject:@(SCIYTSettingsCategory)];
}

%end


%hook YTSettingsSectionItemManager

- (void)updateSectionForCategory:(NSInteger)category withEntry:(id)entry {
    if (category != SCIYTSettingsCategory) {
        %orig;
        return;
    }

    YTSettingsViewController *host = self.settingsViewControllerDelegate;
    if (!host) {
        // Nothing to hand the rows to. Reported rather than ignored: an empty page
        // with no explanation is exactly the kind of silent failure the diagnostics
        // page exists to end.
        SCILogV(@"settings: no view controller delegate, section not built");
        return;
    }

    NSMutableArray *rows = [NSMutableArray array];

    Class itemClass = %c(YTSettingsSectionItem);

    // Verbose logging. Ours, not YouTube's, so it is stored in the app's own
    // defaults exactly as the Instagram tweak stores its own.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    YTSettingsSectionItem *logging =
        [itemClass switchItemWithTitle:SCILocalized(@"verbose_logging")
                     titleDescription:SCILocalized(@"verbose_logging_note")
              accessibilityIdentifier:nil
                             switchOn:[defaults boolForKey:@"verbose_logging"]
                          switchBlock:^BOOL(id cell, BOOL value) {
            [defaults setBool:value forKey:@"verbose_logging"];
            return YES;
        }
                        settingItemId:0];
    if (logging) [rows addObject:logging];

    // Diagnostics. The reason this release exists: it reports what YouTube actually
    // told the app about the last video, which is what decides how downloading can
    // work at all.
    YTSettingsSectionItem *diagnostics =
        [itemClass itemWithTitle:SCILocalized(@"diagnostics")
               titleDescription:SCILocalized(@"diagnostics_note")
        accessibilityIdentifier:nil
                detailTextBlock:nil
                    selectBlock:^BOOL(id cell) {
            UIViewController *page = [SCIYTDiagnostics viewController];
            [host.navigationController pushViewController:page animated:YES];
            return YES;
        }];
    if (diagnostics) [rows addObject:diagnostics];

    [host setSectionItems:rows
              forCategory:SCIYTSettingsCategory
                    title:SCILocalized(@"settings_section_title")
                     icon:nil
         titleDescription:SCILocalized(@"settings_section_note")
             headerHidden:NO];

    SCILogV(@"settings: built %lu rows", (unsigned long)rows.count);
}

%end
