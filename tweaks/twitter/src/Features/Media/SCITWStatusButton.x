#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITWStatusButton.h"
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// A save button on the tweet itself, beside reply, retweet and like.
///
/// **This exists because the owner uses TWIGalaxy and said plainly that it has a button
/// you press, and reading its binary said where.** No otool on this machine, so the fat
/// header and load commands were parsed to pull `__objc_classname`, `__objc_methname` and
/// `__cstring` out of the arm64 slice. What came back settles three things this project
/// had been guessing at:
///
///   - `T1InlineMediaView`, which the other button hooks, appears **nowhere** in a binary
///     that demonstrably works. Not as a class, not in a string, not in a selector.
///   - What it does name is `T1StandardStatusView`, `T1TweetDetailsFocalStatusView`,
///     `T1ConversationFocalStatusView` and the `TTAStatusInline*Button` family -- the
///     tweet's own view and its action row.
///   - It injects on `didMoveToWindow`, finds its button again with `-viewWithTag:`, and
///     reaches media through `viewModel` → `status` → `entities`.
///
/// So this is that arrangement, and every part of it is read rather than supposed.
///
/// ## Why didMoveToWindow and not layoutSubviews
///
/// The other button adds itself during `-layoutSubviews`, and that is very likely the
/// crash the owner reported: adding a subview and activating constraints inside a layout
/// pass invalidates the layout that is running, which asks for another. `didMoveToWindow`
/// runs when the view enters a window -- once per appearance, outside layout, with the view
/// already sized. Nothing here asks for a new layout at all.
///
/// ## Why a tag and not an associated object
///
/// Because that is what the working tweak does, and the reason holds: these views are
/// recycled, and a tag lives on the view for exactly as long as the view does. An
/// associated object needs the same lifetime and buys nothing over an integer.
///
/// Three near-identical hooks rather than one clever one. `%init` names a group and cannot
/// be reached through a function pointer, and the same choice is already made and explained
/// in SCITWSwitchHooks.x. Each attaches only if its class is in this build, and the report
/// says which did -- so "no button" can never again mean four things at once.
///

/// Ours. High enough that it cannot collide with a tag X sets for its own reasons.
static const NSInteger kSCISaveButtonTag = 0x5C1D;

static BOOL sciStandardPresent = NO;
static BOOL sciFocalPresent = NO;
static BOOL sciConversationPresent = NO;
static NSUInteger sciButtonsAdded = 0;
static NSUInteger sciMediaFound = 0;


@interface SCITWStatusButtonTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

@implementation SCITWStatusButtonTarget

+ (instancetype)shared {
    static SCITWStatusButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITWStatusButtonTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    // Resolved on the tap, from the view the button is sitting in.
    //
    // The other button resolves at model-set time and keeps the item, which is faster and
    // is also how it came to hold the previous post's video after a cell was recycled.
    // Here the answer is asked for at the moment it is needed, from the view that is on
    // screen -- one message chain, on a tap, which is not a hot path.
    UIView *view = button.superview;
    while (view && ![view respondsToSelector:NSSelectorFromString(@"viewModel")]) {
        view = view.superview;
    }
    if (!view) { SCILogV(@"status button: no view model above the button"); return; }

    SCITWMediaItem *item = SCITWFirstSaveableInStatusView(view);
    if (!item) { SCILogV(@"status button: nothing saveable on this tweet"); return; }

    [SCITWDownload save:item];
}

@end


/// Every media entity a status view's model can be asked for, in the order the working
/// tweak asks.
///
/// `viewModel.status.entities` is its path. `-mediaEntity` and `-primaryMediaInfo` are ours
/// and are kept: they are what the other surface already uses and they cost one
/// `-respondsToSelector:` each. Whichever answers first wins.
SCITWMediaItem *SCITWFirstSaveableInStatusView(UIView *view) {
    SEL modelSelector = NSSelectorFromString(@"viewModel");
    if (![view respondsToSelector:modelSelector]) return nil;

    id model = ((id (*)(id, SEL))objc_msgSend)(view, modelSelector);
    if (!model) return nil;

    NSMutableArray *candidates = [NSMutableArray array];

    // The direct ones first, cheapest and already proven on the other surface.
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

    // Then the path TWIGalaxy takes: the status behind the model, and its entities.
    SEL statusSelector = NSSelectorFromString(@"status");
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

/// Adds the button, or leaves the one already there alone.
static void SCITWAddSaveButton(UIView *view) {
    if (!view || !view.window) return;

    // NSUserDefaults directly, the way the other button in this tweak reads it.
    //
    // `SCIPrefEnabled(...)` is the YouTube and Locket tweaks' helper and this tweak's
    // Prefs.h has never had one. Five tweaks now share idioms and file layouts, and this
    // is the first time one of them borrowed a symbol that only exists next door -- so
    // check.py grew a rule for it rather than the fix being only this line.
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    // Recycled views arrive with the button they were given last time. Found by tag, which
    // is what makes that cheap and correct.
    UIButton *existing = (UIButton *)[view viewWithTag:kSCISaveButtonTag];

    SCITWMediaItem *item = SCITWFirstSaveableInStatusView(view);
    if (item) sciMediaFound++;

    // A tweet with nothing to save gets no button, and one that had a button and now holds
    // a text-only post loses it. Hiding rather than removing would leave a gap in a row X
    // laid out itself.
    if (!item) {
        if (existing) existing.hidden = YES;
        return;
    }

    if (existing) { existing.hidden = NO; return; }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kSCISaveButtonTag;

    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:16
                                                        weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:weight]
            forState:UIControlStateNormal];

    // X's own action-row glyphs are a muted grey and take the tint of the theme. Matching
    // that rather than painting it red: this sits among four of X's buttons and a fifth in
    // a different colour reads as an advert, not as a control.
    button.tintColor = [UIColor secondaryLabelColor];

    [button addTarget:[SCITWStatusButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    // Bottom trailing corner, by frame, with no constraint anywhere.
    //
    // A frame set outside a layout pass cannot invalidate one. X lays this row out itself
    // and will move its own buttons around ours; sitting in the corner rather than in the
    // row means nothing of theirs has to make space.
    CGRect bounds = view.bounds;
    button.frame = CGRectMake(bounds.size.width - 38, bounds.size.height - 38, 30, 30);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;

    [view addSubview:button];
    sciButtonsAdded++;
}


// Written out over four lines each rather than as one-liners.
//
// `%orig` expands with #line directives and has to sit alone on its own line inside a full
// block -- `{ %orig; ... }` fails to compile with "%end does not make sense inside a
// block", which is in CLAUDE.md under toolchain gotchas. I wrote all three the forbidden
// way and tools/check.py caught all three before Theos ever saw them, which is the whole
// reason that rule is a check and not a paragraph.

%group StandardStatus

%hook T1StandardStatusView

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButton(self);
}

%end

%end


%group FocalStatus

%hook T1TweetDetailsFocalStatusView

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButton(self);
}

%end

%end


%group ConversationStatus

%hook T1ConversationFocalStatusView

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButton(self);
}

%end

%end


NSString *SCITWStatusButtonReport(void) {
    NSMutableArray<NSString *> *attached = [NSMutableArray array];
    if (sciStandardPresent) [attached addObject:@"standard"];
    if (sciFocalPresent) [attached addObject:@"focal"];
    if (sciConversationPresent) [attached addObject:@"conversation"];

    if (!attached.count) return @"no status view class in this build";

    return [NSString stringWithFormat:@"%@ · %lu with media, %lu buttons added",
            [attached componentsJoinedByString:@"+"],
            (unsigned long)sciMediaFound, (unsigned long)sciButtonsAdded];
}

void SCITWInstallStatusButton(void) {
    sciStandardPresent = (NSClassFromString(@"T1StandardStatusView") != nil);
    sciFocalPresent = (NSClassFromString(@"T1TweetDetailsFocalStatusView") != nil);
    sciConversationPresent = (NSClassFromString(@"T1ConversationFocalStatusView") != nil);

    if (sciStandardPresent) %init(StandardStatus);
    if (sciFocalPresent) %init(FocalStatus);
    if (sciConversationPresent) %init(ConversationStatus);

    SCILogV(@"status save button: %@", SCITWStatusButtonReport());
}
