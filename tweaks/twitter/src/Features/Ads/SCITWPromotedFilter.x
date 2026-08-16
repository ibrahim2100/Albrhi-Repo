#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITWPromotedFilter.h"
#import "Features/Media/SCITWStatusButton.h"   // T1StandardStatusView and its siblings
#import "Prefs.h"
#import "SCILog.h"

///
/// Hiding a Promoted Tweet where it is drawn, because nothing upstream of drawing will
/// admit the choice is client-side.
///
/// Same three classes the save button already hooks, read from TWIGalaxy's own binary --
/// `T1StandardStatusView`, `T1TweetDetailsFocalStatusView`, `T1ConversationFocalStatusView`.
/// `-setViewModel:` is the bind point, for the same reason the save button moved to it: it
/// runs on first appearance and on every reuse alike, and a cell recycled by a table view
/// keeps the same view instance and rebinds it through the model rather than through a
/// fresh `-didMoveToWindow`.
///
/// ## Why hiding, not removing
///
/// A UITableView's row exists whether or not this hook draws anything into it -- the row
/// height was decided by whoever built the data source, long before this view is asked to
/// show its content, and nothing here has a safe way to reach that decision back. So a
/// hidden promoted tweet leaves an empty gap the height of a tweet rather than the table
/// closing the gap. That is a real limitation, said plainly rather than promised away: the
/// alternative -- guessing at the data-source class and returning nil from whatever hands
/// out row adapters -- was tried on paper and rejected here, because a caller that assumes
/// a non-nil adapter and gets one anyway is exactly the shape of a crash this project has
/// no way to test before shipping.
///
/// ## Why every row is reset, not only the promoted ones
///
/// `self.hidden = YES` on a promoted tweet is only half the rule. A cell is reused, and the
/// same view instance that just hid a Promoted Tweet is handed an ordinary one on the very
/// next scroll -- if only the promoted branch touched `.hidden`, that view would stay
/// hidden forever, showing a real tweet as an empty gap. Both branches write `.hidden`
/// unconditionally, every time, for exactly the reason the save button's own comments
/// already give for refreshing its item on every bind: a recycled view has no memory of
/// what it used to hold unless this code gives it one.
///
/// ## Default off, and named as what it is
///
/// This has not been confirmed on a device. The class names, the property, and the method
/// come from a real class dump; whether X actually asks these three views to build a
/// promoted status, on 12.15, in a session that scrolls one into view, is the one thing
/// only a phone can answer. Shipped off, with a counter that says both how many statuses
/// were checked and how many were promoted -- so the next report either confirms the theory
/// or says plainly that it did not attach to anything.
///

// T1StandardStatusView, T1TweetDetailsFocalStatusView and T1ConversationFocalStatusView
// come from SCITWStatusButton.h, imported above -- see that header for why they are
// declared there and not repeated in every file that hooks them.

static BOOL sciPFStandardPresent = NO;
static BOOL sciPFFocalPresent = NO;
static BOOL sciPFConversationPresent = NO;
static NSUInteger sciPFStatusesSeen = 0;
static NSUInteger sciPFPromotedHidden = 0;


/// The status behind a view, by the same two-shape walk `SCITWFirstSaveableInStatusView`
/// already uses: `-viewModel` first, and the view treated as its own model when it answers
/// `-status` directly instead -- the immersive surfaces' own shape. Kept local rather than
/// shared, because this file needs only the status itself and not everything the save
/// button's version resolves past it.
static id SCITWPFStatusFromView(UIView *view) {
    SEL modelSelector = NSSelectorFromString(@"viewModel");
    SEL statusSelector = NSSelectorFromString(@"status");

    id model = nil;
    if ([view respondsToSelector:modelSelector]) {
        model = ((id (*)(id, SEL))objc_msgSend)(view, modelSelector);
    } else if ([view respondsToSelector:statusSelector]) {
        model = view;
    }
    if (!model) return nil;

    if (![model respondsToSelector:statusSelector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(model, statusSelector);
}

static void SCITWPFApply(UIView *view, id viewModel) {
    if (!view) return;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefHidePromoted]) {
        // Off means off, even for a view this code touched earlier while the switch was on
        // -- otherwise turning the feature off would leave whatever it last hid still
        // hidden, which is a switch that visibly does nothing when someone flips it back.
        view.hidden = NO;
        return;
    }

    id status = SCITWPFStatusFromView(view);
    if (!status) return;

    sciPFStatusesSeen++;

    SEL promotedSelector = NSSelectorFromString(@"isPromoted");
    BOOL promoted = [status respondsToSelector:promotedSelector]
        && ((BOOL (*)(id, SEL))objc_msgSend)(status, promotedSelector);

    view.hidden = promoted;
    view.userInteractionEnabled = !promoted;
    if (promoted) sciPFPromotedHidden++;
}


%group PromotedFilter

%hook T1StandardStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWPFApply(self, viewModel);
}

%end


%hook T1TweetDetailsFocalStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWPFApply(self, viewModel);
}

%end


%hook T1ConversationFocalStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWPFApply(self, viewModel);
}

%end

%end


NSString *SCITWPromotedFilterReport(void) {
    NSMutableArray<NSString *> *attached = [NSMutableArray array];
    if (sciPFStandardPresent) [attached addObject:@"standard"];
    if (sciPFFocalPresent) [attached addObject:@"focal"];
    if (sciPFConversationPresent) [attached addObject:@"conversation"];

    if (!attached.count) return @"no status view class in this build";

    return [NSString stringWithFormat:@"%@ · %lu statuses checked, %lu promoted hidden",
            [attached componentsJoinedByString:@"+"],
            (unsigned long)sciPFStatusesSeen, (unsigned long)sciPFPromotedHidden];
}

void SCITWInstallPromotedFilter(void) {
    sciPFStandardPresent = (NSClassFromString(@"T1StandardStatusView") != nil);
    sciPFFocalPresent = (NSClassFromString(@"T1TweetDetailsFocalStatusView") != nil);
    sciPFConversationPresent = (NSClassFromString(@"T1ConversationFocalStatusView") != nil);

    if (sciPFStandardPresent || sciPFFocalPresent || sciPFConversationPresent) {
        %init(PromotedFilter);
    }

    SCILogV(@"promoted-tweet filter: %@", SCITWPromotedFilterReport());
}
