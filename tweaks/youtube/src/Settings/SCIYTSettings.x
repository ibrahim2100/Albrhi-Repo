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

/// Which group our category is appended to, learned rather than guessed.
///
/// YTSettingsGroupData's -type is an unsigned enum, and its values cannot be read out
/// of the binary. So instead of picking a number and hoping: +orderedGroups is asked
/// first, a group is taken from the list it returns, and its type is remembered. From
/// then on the category is appended to exactly that group. Nothing here has to know
/// what the number means.
///
/// The *first* group, not the last. YTSettingsGroupData also knows about a
/// developmentCategories set, and a group of internal switches is exactly the kind
/// that a release build hides -- landing our category in it would look identical to
/// this hook not working at all. Whatever sits first on a settings screen is on it.
///
/// Sentinel rather than 0, because 0 is a perfectly plausible real group type and
/// would make "not learned yet" indistinguishable from "the first group".
static unsigned long long sciHostGroupType = ULLONG_MAX;

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    if (!order) return order;

    // Appended, not prepended: YouTube's own settings stay where the user learned
    // to find them, and ours sits at the end where an addition belongs.
    //
    // This alone was the whole of the first attempt, and the section never appeared:
    // in this build the screen is assembled from groups, and this list is not read.
    // Left in place because it is free and older builds may still consult it.
    return [order arrayByAddingObject:@(SCIYTSettingsCategory)];
}

%end


%hook YTAppSettingsGroupPresentationData

+ (NSArray *)orderedGroups {
    NSArray *groups = %orig;

    YTSettingsGroupData *host = [groups firstObject];
    if ([host respondsToSelector:@selector(type)]) {
        sciHostGroupType = host.type;
        SCILogV(@"settings: attaching to group %llu (%@) of %lu",
                sciHostGroupType, host.title, (unsigned long)groups.count);
    } else {
        SCILogV(@"settings: %lu groups and none that answers -type", (unsigned long)groups.count);
    }

    // Reported whether or not it worked, and read from the real objects rather than
    // assumed: if a future build reorders or renames these, the report says so
    // instead of the section quietly vanishing again.
    [SCIYTDiagnostics recordSettingsGroups:groups];

    return groups;
}

%end


%hook YTSettingsGroupData

- (NSArray *)orderedCategories {
    NSArray *categories = %orig;

    if (!categories || sciHostGroupType == ULLONG_MAX || self.type != sciHostGroupType) {
        return categories;
    }

    return [categories arrayByAddingObject:@(SCIYTSettingsCategory)];
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
