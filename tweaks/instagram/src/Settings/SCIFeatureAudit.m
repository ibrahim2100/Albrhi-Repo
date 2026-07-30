#import "SCIFeatureAudit.h"
#import "../Localization/SCILocalize.h"

#import <objc/runtime.h>

@implementation SCIFeatureAuditResult
@end

@implementation SCIFeatureAudit

/// Does this build have the class, and — when one is named — the method?
///
/// class_getInstanceMethod walks superclasses, so a method a class inherits still
/// counts, which is the same test the hooks themselves make before installing.
static BOOL SCITargetExists(NSString *className, NSString *selectorName) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    if (!selectorName.length) return YES;

    SEL selector = NSSelectorFromString(selectorName);
    if (!selector) return NO;

    return class_getInstanceMethod(cls, selector) != NULL
        || class_getClassMethod(cls, selector) != NULL;
}

static SCIFeatureAuditResult *SCICheck(NSString *feature, NSString *className, NSString *selectorName) {
    SCIFeatureAuditResult *result = [[SCIFeatureAuditResult alloc] init];
    result.feature = feature;
    result.attached = SCITargetExists(className, selectorName);
    result.detail = selectorName.length ? [NSString stringWithFormat:@"%@ · %@", className, selectorName]
                                        : className;
    return result;
}

/// A feature that has more than one way in — a different class per Instagram
/// version — counts as attached when any of them is here.
static SCIFeatureAuditResult *SCICheckAny(NSString *feature, NSArray<NSArray<NSString *> *> *targets) {
    SCIFeatureAuditResult *result = [[SCIFeatureAuditResult alloc] init];
    result.feature = feature;

    for (NSArray<NSString *> *target in targets) {
        NSString *className = target.firstObject;
        NSString *selectorName = target.count > 1 ? target[1] : nil;

        if (SCITargetExists(className, selectorName)) {
            result.attached = YES;
            result.detail = selectorName.length ? [NSString stringWithFormat:@"%@ · %@", className, selectorName]
                                                : className;
            return result;
        }
    }

    result.attached = NO;
    result.detail = [targets.firstObject firstObject] ?: @"—";
    return result;
}

+ (NSArray<SCIFeatureAuditResult *> *)run {
    NSMutableArray<SCIFeatureAuditResult *> *results = [NSMutableArray array];

    // Downloads
    [results addObject:SCICheckAny(SCILocalized(@"audit_inline_button"), @[
        @[@"IGUFIInteractionCountsView", @"layoutSubviews"],
        @[@"IGSundialViewerVerticalUFI", @"layoutSubviews"],
        @[@"_TtC26IGSundialViewerVerticalUFI26IGSundialViewerVerticalUFI", @"layoutSubviews"],
        @[@"IGUFIButtonBarView", @"layoutSubviews"]
    ])];

    [results addObject:SCICheck(SCILocalized(@"audit_story_download"),
                                @"IGStoryViewerViewController", @"viewDidAppear:")];

    // Reels
    [results addObject:SCICheckAny(SCILocalized(@"audit_reels_autoscroll"), @[
        @[@"IGSundialFeedViewController", @"scrollToNextItemAnimated:"],
        @[@"IGSundialFeedViewController", @"advanceToNextReelForAutoScroll"]
    ])];

    [results addObject:SCICheck(SCILocalized(@"audit_reels_progress"),
                                @"IGSundialViewerVideoCell",
                                @"updateProgressIndicatorWithProgress:remainingDuration:elapsedDuration:totalDuration:")];

    // Privacy
    [results addObject:SCICheck(SCILocalized(@"audit_story_seen"),
                                @"IGStorySeenStateUploader", @"networker")];

    [results addObject:SCICheck(SCILocalized(@"audit_typing"),
                                @"IGDirectTypingStatusService", nil)];

    // Messages
    [results addObject:SCICheckAny(SCILocalized(@"audit_keep_unsent"), @[
        @[@"IGDirectRealtimeIrisDeltaApplicator", @"_applyThreadUpdates:"],
        @[@"IGDirectCacheUpdatesApplicator", @"_applyThreadUpdates:completion:"],
        @[@"IGDirectCacheUpdatesApplicator", @"_applyThreadUpdates:completion:userAccess:"],
        @[@"MDCoreDelta", @"matchAddMessageDelta:deleteThreadDelta:createReactionDelta:deleteMessageDelta:deleteReactionDelta:"]
    ])];

    [results addObject:SCICheck(SCILocalized(@"audit_call_buttons"),
                                @"IGDirectThreadCallButtonsCoordinator", nil)];

    [results addObject:SCICheck(SCILocalized(@"audit_send_file"),
                                @"IGDirectThreadViewController",
                                @"composerOverflowButtonMenuWillPrepareExpandWithPlusButton:")];

    // Appearance
    [results addObject:SCICheckAny(SCILocalized(@"audit_dates"), @[
        @[@"NSDate", @"formattedDateRelativeToNow"],
        @[@"NSDate", @"shortenedFormattedDateRelativeToNow"]
    ])];

    // Feed cleanup
    [results addObject:SCICheck(SCILocalized(@"audit_hide_ads"),
                                @"IGMainFeedListAdapterDataSource", nil)];

    [results addObject:SCICheck(SCILocalized(@"audit_meta_ai"),
                                @"IGStickerTrayListAdapterDataSource", @"objectsForListAdapter:")];

    [results addObject:SCICheck(SCILocalized(@"audit_explore"),
                                @"IGExploreViewController", nil)];

    // Confirmations
    [results addObject:SCICheck(SCILocalized(@"audit_like_confirm"),
                                @"IGSundialViewerVideoCell", @"controlsOverlayControllerDidTapLikeButton:")];

    return results;
}

+ (NSString *)summaryForResults:(NSArray<SCIFeatureAuditResult *> *)results {
    NSInteger attached = 0;
    for (SCIFeatureAuditResult *result in results) {
        if (result.attached) attached++;
    }

    return [NSString stringWithFormat:SCILocalized(@"audit_summary"),
            (long)attached, (long)results.count];
}

@end
