#import <UIKit/UIKit.h>
#import "SCIYTDislikes.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../YouTubeHeaders.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// Putting the number back on the button.
///
/// The count arrives from the archive; this is only the part that writes it on screen, and
/// it is the part this project has historically got wrong. Everything else in the tweak
/// hooks the model layer for that reason. A counter is a view and there is no model-layer
/// way to do this, so the risk is taken and then contained:
///
///   * only -updateRollingNumberView is touched, and only after %orig, so whatever YouTube
///     wanted drawn is drawn first and this is an edit of the result;
///   * the label is found by walking the node's own view, not by naming an internal class;
///   * every node this sees is written to the diagnostics page with its text, so "no number
///     appeared" is answerable from the phone rather than by guessing.
///
/// **Which node is the dislike one is decided by what it says, not by where it sits.**
/// YouTube stopped publishing the count, so that button shows a word where the like button
/// shows a number. A node whose text does not begin with a digit is therefore the one to
/// write into. The known miss is a video with no likes at all, where the like button is
/// wordy too -- rare, and the report is what will say whether it is rarer than that.
///

/// The nodes seen for the video on screen, held weakly.
///
/// A count usually arrives after the button has been drawn with the word on it, and nothing
/// would ask again -- the button is laid out and settled. These are what the arrival
/// notification reaches back to. Weak, because a node belongs to a list that scrolls and
/// keeping it alive to update it later would be keeping a screenful of dead views alive.
static NSHashTable *sciNodes = nil;

static BOOL SCILooksLikeCount(NSString *text) {
    if (!text.length) return NO;

    unichar first = [text characterAtIndex:0];
    return (first >= '0' && first <= '9');
}

static UILabel *SCIFindLabel(UIView *view) {
    if (!view) return nil;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:[UILabel class]]) return (UILabel *)next;
        [queue addObjectsFromArray:next.subviews];
    }
    return nil;
}

/// Writes the count into one node, if that node is the wordy one.
static void SCIApplyToNode(YTRollingNumberNode *node, BOOL report) {
    NSString *videoID = [SCIYTDiagnostics activeVideoID];
    if (!videoID.length || !node) return;

    UILabel *label = SCIFindLabel(node.view);
    if (!label) return;

    if (report) [SCIYTDiagnostics recordCounterNode:label.text];
    if (SCILooksLikeCount(label.text)) return;

    // Asking also starts the fetch when the answer is not known yet, and the notification
    // below brings us back here once it is.
    NSString *count = [SCIYTDislikes cachedCountFor:videoID];
    if (!count.length) return;

    label.text = count;
    [label sizeToFit];
}

%hook YTRollingNumberNode

- (void)updateRollingNumberView {
    %orig;

    if (!SCIPrefEnabled(SCIPrefDislikes)) return;

    // Off the layout pass. This runs while the node is being drawn, and walking a view tree
    // there is already more than belongs in it -- setting text as well would be editing a
    // layout from inside it.
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf) node = weakSelf;
        if (!node) return;

        @synchronized (sciNodes) { [sciNodes addObject:node]; }
        SCIApplyToNode(node, YES);
    });
}

%end


%ctor {
    sciNodes = [NSHashTable weakObjectsHashTable];

    [[NSNotificationCenter defaultCenter] addObserverForName:SCIYTDislikesDidArriveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        NSArray *nodes = nil;
        @synchronized (sciNodes) { nodes = [sciNodes allObjects]; }

        // Not reported a second time: these are the same nodes the first pass already wrote
        // down, and a report that repeats itself once per video is a report nobody reads.
        for (YTRollingNumberNode *node in nodes) {
            SCIApplyToNode(node, NO);
        }
    }];
}
