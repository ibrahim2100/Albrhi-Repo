#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITWStatusButton.h"
#import "SCITWMedia.h"

// T1StandardStatusView, T1TweetDetailsFocalStatusView and T1ConversationFocalStatusView are
// declared in SCITWStatusButton.h, not here -- the promoted-tweet filter hooks the same
// three classes and needs the same declarations, and two @interfaces for one class is the
// exact failure rule 1 of tools/check.py exists to catch.

/// Every media entity a status view's model can be asked for, in the order the working
/// tweak asks.
///
/// `viewModel.status.entities` is its path. `-mediaEntity` and `-primaryMediaInfo` are ours
/// and are kept: the immersive button already uses them and they cost one
/// `-respondsToSelector:` each. Whichever answers first wins.
SCITWMediaItem *SCITWFirstSaveableInStatusView(UIView *view) {
    SEL modelSelector = NSSelectorFromString(@"viewModel");
    SEL statusSelector = NSSelectorFromString(@"status");

    // The model, or the view itself when the view *is* the model's holder.
    //
    // **This is why the immersive button attached and still added nothing, once.** A device
    // report on X 12.15 said `ImmersiveActionsStackView — 0 buttons added`: the rail was
    // found and hooked, and every placement bailed here, at the first line, because the walk
    // upward reaches `ImmersiveCardView` and that class has **no -viewModel**. It answers
    // -status directly — confirmed in the class dump, where its whole interface is -status,
    // -playerView, -playerSessionProducer and gesture plumbing, and no model getter at all.
    //
    // So the view is treated as its own model when it answers -status. Everything below
    // already knows how to go from a status to entities to media; it was only ever the one
    // hop at the top that the immersive hierarchy does not have.
    id model = nil;

    if ([view respondsToSelector:modelSelector]) {
        model = ((id (*)(id, SEL))objc_msgSend)(view, modelSelector);
    } else if ([view respondsToSelector:statusSelector]) {
        model = view;
    }

    if (!model) return nil;

    NSMutableArray *candidates = [NSMutableArray array];

    // The direct ones first, cheapest.
    for (NSString *name in @[@"mediaEntity", @"primaryMediaInfo", @"mediaInfo"]) {
        SEL selector = NSSelectorFromString(name);
        if (![model respondsToSelector:selector]) continue;

        id found = ((id (*)(id, SEL))objc_msgSend)(model, selector);
        if (!found) continue;

        SEL inner = NSSelectorFromString(@"mediaEntity");
        if ([found respondsToSelector:inner]) {
            id entity = ((id (*)(id, SEL))objc_msgSend)(found, inner);
            if (entity) [candidates addObject:entity];
        } else {
            [candidates addObject:found];
        }
    }

    // Then the status behind the model, and its entities.
    if ([model respondsToSelector:statusSelector]) {
        id status = ((id (*)(id, SEL))objc_msgSend)(model, statusSelector);

        SEL entitiesSelector = NSSelectorFromString(@"entities");
        if ([status respondsToSelector:entitiesSelector]) {
            id entities = ((id (*)(id, SEL))objc_msgSend)(status, entitiesSelector);

            // `entities` is an object holding arrays, or an array itself depending on the
            // surface. Both shapes are read rather than one being assumed.
            SEL mediaSelector = NSSelectorFromString(@"media");
            if ([entities respondsToSelector:mediaSelector]) {
                id media = ((id (*)(id, SEL))objc_msgSend)(entities, mediaSelector);
                if ([media isKindOfClass:[NSArray class]]) {
                    [candidates addObjectsFromArray:media];
                } else if (media) {
                    [candidates addObject:media];
                }
            } else if ([entities isKindOfClass:[NSArray class]]) {
                [candidates addObjectsFromArray:entities];
            }
        }
    }

    for (id entity in candidates) {
        SCITWMediaItem *item = [SCITWMedia itemForEntity:entity];
        if (item) return item;
    }
    return nil;
}
