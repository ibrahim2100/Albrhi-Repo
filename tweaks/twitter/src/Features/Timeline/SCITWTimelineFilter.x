#import <UIKit/UIKit.h>
#import "SCITWTimelineFilter.h"
#import "Prefs.h"
#import "SCILog.h"

@interface TFNItemsDataViewController : UIViewController
- (id)itemAtIndexPath:(id)indexPath;
@end

static BOOL sciItemsPresent = NO;
static NSUInteger sciHidWhoToFollow = 0, sciHidTopics = 0, sciHidTrends = 0;
static NSUInteger sciCellsSeen = 0;

/// Model class names, matched exactly.
///
/// Exactly, and never as a substring of a description: the promoted filter in this same
/// tweak learned that lesson expensively on the YouTube side, where a marker naming an
/// advertisement *inside* a shelf condemned the shelf and every real post in it.
static BOOL SCIMatches(NSString *name, NSArray<NSString *> *wanted) {
    for (NSString *candidate in wanted) {
        if ([name isEqualToString:candidate]) return YES;
    }
    return NO;
}

static NSArray<NSString *> *SCIWhoToFollowModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"T1URTTimelineUserItemViewModel",
            @"T1TwitterSwift.URTTimelineCarouselViewModel",
            @"TwitterURT.URTTimelineCarouselViewModel",
        ];
    });
    return models;
}

static NSArray<NSString *> *SCITopicModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"T1TwitterSwift.URTTimelineTopicCollectionViewModel",
            @"_TtC10TwitterURT26URTTimelinePromptViewModel",
            @"TwitterURT.URTTimelinePromptViewModel",
        ];
    });
    return models;
}

static NSArray<NSString *> *SCITrendVideoModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"TwitterURT.URTTimelineEventSummaryViewModel",
            @"_TtC10TwitterURT32URTTimelineEventSummaryViewModel",
        ];
    });
    return models;
}


%group TimelineFilter

%hook TFNItemsDataViewController

- (id)tableViewCellForItem:(id)item atIndexPath:(id)indexPath {
    UITableViewCell *cell = %orig;
    if (!cell) return cell;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL wantsAny = [defaults boolForKey:SCIPrefHideWhoToFollow] ||
                    [defaults boolForKey:SCIPrefHideTopics] ||
                    [defaults boolForKey:SCIPrefHideTrendVideos];
    if (!wantsAny) return cell;

    // The model is asked for rather than inferred from the cell. A cell is reused and says
    // nothing about what it is showing; the item at this index path is the thing itself.
    id model = nil;
    @try {
        model = [self itemAtIndexPath:indexPath];
    } @catch (__unused NSException *exception) {
        return cell;
    }
    if (!model) return cell;

    sciCellsSeen++;
    NSString *name = NSStringFromClass([model classForCoder]);
    if (!name.length) return cell;

    if ([defaults boolForKey:SCIPrefHideWhoToFollow] && SCIMatches(name, SCIWhoToFollowModels())) {
        cell.hidden = YES;
        sciHidWhoToFollow++;
        return cell;
    }
    if ([defaults boolForKey:SCIPrefHideTopics] && SCIMatches(name, SCITopicModels())) {
        cell.hidden = YES;
        sciHidTopics++;
        return cell;
    }
    if ([defaults boolForKey:SCIPrefHideTrendVideos] && SCIMatches(name, SCITrendVideoModels())) {
        cell.hidden = YES;
        sciHidTrends++;
        return cell;
    }

    // Shown on the way through as well as hidden. Cells are reused, so the same instance
    // that hid a suggestion is handed an ordinary post on the next scroll -- writing only
    // the hiding branch is how a working filter starts eating the timeline.
    cell.hidden = NO;
    return cell;
}

%end

%end


NSString *SCITWTimelineFilterReport(void) {
    if (!sciItemsPresent) return @"timeline filter: TFNItemsDataViewController not in this build";

    return [NSString stringWithFormat:
            @"timeline filter: %lu cell(s) seen · suggestions %lu · topics %lu · trend videos %lu",
            (unsigned long)sciCellsSeen, (unsigned long)sciHidWhoToFollow,
            (unsigned long)sciHidTopics, (unsigned long)sciHidTrends];
}

void SCITWInstallTimelineFilter(void) {
    sciItemsPresent = (NSClassFromString(@"TFNItemsDataViewController") != nil);
    if (!sciItemsPresent) {
        SCILogV(@"timeline filter: TFNItemsDataViewController not in this build");
        return;
    }

    %init(TimelineFilter);
    SCILogV(@"timeline filter attached");
}
