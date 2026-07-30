#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"

///
/// Reads YouTube's settings model. Does not add to it -- yet.
///
/// 0.1.1 injected a category of its own into the group the screen is built from, and
/// YouTube crashed the moment Settings opened. The lesson is that a category id is not
/// a self-contained thing: the screen looks that id up in YouTube's own tables for a
/// title, an icon and a page identifier, and an id those tables have never heard of is
/// not an empty row, it is a fault. Announcing a category is therefore not one hook,
/// it is a contract, and the rest of that contract has to be found before the
/// announcement is made again.
///
/// So the injection is gone and the measurement stays. That ordering is deliberate:
/// a settings panel nobody can open because the app dies is strictly worse than no
/// settings panel, and the diagnostics report -- which is the point of these early
/// versions -- is already reachable without one, through the file written into
/// YouTube's own container.
///
/// What is still hooked here reads and reports. It changes nothing YouTube does.
///

/// Reserved, and unused until the rest of the contract above is understood.
///
/// Kept rather than deleted because the number itself was never the problem: it is
/// far outside YouTube's own small range, so it cannot collide. What was missing is
/// everything the screen needs *about* a category, not the category's name.
static const NSInteger SCIYTSettingsCategory = 774100;

%hook YTAppSettingsGroupPresentationData

+ (NSArray *)orderedGroups {
    NSArray *groups = %orig;

    // Reporting only. Read from the real objects rather than assumed, so the next
    // attempt at a settings section can pick its group from what this build actually
    // has instead of from a guess -- which is what the first two attempts did.
    [SCIYTDiagnostics recordSettingsGroups:groups];

    SCILogV(@"settings: %lu groups", (unsigned long)groups.count);

    return groups;
}

%end


%hook YTSettingsSectionItemManager

- (void)updateSectionForCategory:(NSInteger)category withEntry:(id)entry {
    // Nothing is injected any more, so this can only ever be one of YouTube's own
    // categories. Left in place as the point where a section will be built once
    // announcing one is safe, and meanwhile it forwards everything untouched.
    if (category == SCIYTSettingsCategory) {
        SCILogV(@"settings: asked for our own category, which is not announced yet");
        return;
    }

    %orig;
}

%end
