#import "SCIYTHistoryTab.h"
#import <objc/message.h>
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

NSString *const SCIYTHistoryPivot = @"FEhistory";

static NSString *sciHistoryState = nil;
static BOOL sciHistoryBuilt = NO;

BOOL SCIYTHistoryTabWanted(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefTabHistory];
}

/// KVC throughout, deliberately.
///
/// These are GPBMessage subclasses whose fields resolve dynamically, so
/// `-respondsToSelector:` answers NO for a field `-setValue:forKey:` sets perfectly well.
/// That is recorded in CLAUDE.md and is why this file reads as keys rather than as messages.
static BOOL SCISet(id object, id value, NSString *key, NSString *what) {
    if (!object || !value) return NO;
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (NSException *exception) {
        sciHistoryState = [NSString stringWithFormat:@"%@ refused: %@",
                           what, exception.reason ?: @"?"];
        return NO;
    }
}

BOOL SCIYTIsHistoryRenderer(id renderer) {
    if (!renderer) return NO;
    @try {
        id identifier = [renderer valueForKey:@"pivotIdentifier"];
        return [identifier isKindOfClass:[NSString class]] &&
               [identifier isEqualToString:SCIYTHistoryPivot];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

id SCIYTMakeHistoryItem(void) {
    Class itemClass = NSClassFromString(@"YTIPivotBarItemRenderer");
    Class wrapperClass = NSClassFromString(@"YTIPivotBarSupportedRenderers");
    Class commandClass = NSClassFromString(@"YTICommand");
    Class browseClass = NSClassFromString(@"YTIBrowseEndpoint");

    if (!itemClass || !wrapperClass || !commandClass || !browseClass) {
        sciHistoryState = @"the pivot bar or endpoint classes are not on this build";
        return nil;
    }

    id item = [[itemClass alloc] init];
    if (!SCISet(item, SCIYTHistoryPivot, @"pivotIdentifier", @"pivotIdentifier")) return nil;

    // The label, as the formatted string every other tab carries. A plain NSString in this
    // field is not a shorter label, it is a tab that does not draw -- learned once already
    // by the Download Centre tab and not worth learning twice.
    Class stringClass = NSClassFromString(@"YTIFormattedString");
    SEL make = NSSelectorFromString(@"formattedStringWithString:");
    if (stringClass && [stringClass respondsToSelector:make]) {
        id title = ((id (*)(id, SEL, id))objc_msgSend)(stringClass, make,
                                                       SCILocalized(@"tab_history"));
        if (title) SCISet(item, title, @"title", @"title");
    }

    // The whole reason this tab needs no tap handling: the endpoint is what YouTube
    // resolves, so the page, its loading, its back behaviour and its selection state are
    // all YouTube's own.
    id browse = [[browseClass alloc] init];
    if (!SCISet(browse, SCIYTHistoryPivot, @"browseId", @"browseId")) return nil;

    id command = [[commandClass alloc] init];
    if (!SCISet(command, browse, @"browseEndpoint", @"browseEndpoint")) return nil;
    if (!SCISet(item, command, @"navigationEndpoint", @"navigationEndpoint")) return nil;

    id wrapper = [[wrapperClass alloc] init];
    if (!SCISet(wrapper, item, @"pivotBarItemRenderer", @"wrapper")) return nil;

    sciHistoryBuilt = YES;
    sciHistoryState = @"built";
    return wrapper;
}

BOOL SCIYTPaintHistoryIcon(UIView *view) {
    if (!view) return NO;

    UIImage *clock = [UIImage systemImageNamed:@"clock.arrow.circlepath"];
    if (!clock) return NO;

    // Breadth-first to the first button, exactly as the Download Centre tab does: a pivot
    // tab is drawn by a YTQTMButton, and a UIButton's own image view either does not exist
    // until it has an image or is overwritten on the button's next layout.
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)next;
            [button setImage:clock forState:UIControlStateNormal];
            [button setImage:clock forState:UIControlStateSelected];
            [button setImage:clock forState:UIControlStateHighlighted];
            button.tintColor = SCIAccent();
            return YES;
        }
        [queue addObjectsFromArray:next.subviews];
    }
    return NO;
}

NSString *SCIYTHistoryTabReport(void) {
    if (!SCIYTHistoryTabWanted()) return @"history tab: off";
    if (!sciHistoryState) return @"history tab: on, the bar has not been built yet";
    return [NSString stringWithFormat:@"history tab: on, %@%@",
            sciHistoryState, sciHistoryBuilt ? @"" : @" (not added)"];
}
