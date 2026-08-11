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

/// The item the button is currently offering to save.
static const void *kSCIItemKey = &kSCIItemKey;

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
    // What was resolved when the button was placed, kept on the button.
    //
    // It is refreshed every time the tweet comes on screen, so a recycled cell cannot hand
    // over the previous post's video -- which is the failure the other button had, and the
    // reason this was originally written to resolve on the tap instead.
    SCITWMediaItem *item = objc_getAssociatedObject(button, kSCIItemKey);

    // Failing that, up the view tree, trying **every** ancestor that has a model rather
    // than stopping at the first.
    //
    // Stopping at the first was wrong and the device report is what proves it: the button
    // now sits on X's media view, that view has a `viewModel` of its own, and its model
    // yields no media at all -- "25 models, 0 with media" is exactly that object being
    // asked 25 times and answering nothing. The tweet's own model, two views further up,
    // is the one that answers.
    for (UIView *view = button.superview; view && !item; view = view.superview) {
        if (![view respondsToSelector:NSSelectorFromString(@"viewModel")]) continue;
        item = SCITWFirstSaveableInStatusView(view);
    }

    if (!item) { SCILogV(@"status button: nothing saveable above this button"); return; }

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

/// The media view inside a tweet, found by what its class is called.
///
/// By name at runtime, not by a `%hook` on the name -- the difference this project keeps
/// making. Nothing here breaks if X renames the class: the search finds nothing and the
/// button goes on the tweet instead, which is where it was before and still works.
///
/// Size is part of the test. A tweet carries small image views for the avatar, the verified
/// badge and the play glyph, and any of them would match a name search alone; media is the
/// large one. 120 points on the short side is comfortably above every piece of chrome and
/// below the smallest inline photo X will draw.
static UIView *SCITWMediaSubview(UIView *root) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    UIView *best = nil;
    CGFloat bestArea = 0;

    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [queue addObjectsFromArray:view.subviews];

        NSString *name = NSStringFromClass([view class]);
        if (![name containsString:@"InlineMedia"] && ![name containsString:@"MediaView"]) continue;

        CGSize size = view.bounds.size;
        if (MIN(size.width, size.height) < 120) continue;

        // The largest match, because a media view can hold another one: a quoted post's
        // photo is inside the quoting post's media container, and the outer one is the
        // frame the video actually fills.
        CGFloat area = size.width * size.height;
        if (area > bestArea) { bestArea = area; best = view; }
    }

    return best;
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

    if (existing) {
        existing.hidden = NO;
        // Refreshed, because this view has been recycled and may be showing a different
        // post than the one the button was built for.
        objc_setAssociatedObject(existing, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

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

    // On the media, top trailing, and not in the corner of the tweet.
    //
    // The first version put it at the bottom trailing corner of the status view, which is
    // exactly where X's share button is: the owner reported it sitting on top of share and
    // being hard to press, and it was -- two 30-point targets in the same place, ours
    // winning some taps and share winning others.
    //
    // The media view is found at injection rather than assumed, and the report is what says
    // it is there to find: `inline button: 25 models` means T1InlineMediaView is in this
    // build and in the hierarchy. Its own top trailing corner is empty -- X puts the ALT
    // badge bottom leading and the audio toggle bottom trailing -- and it is the corner
    // people already reach for on every other app that saves video.
    UIView *host = SCITWMediaSubview(view) ?: view;

    CGRect bounds = host.bounds;
    button.frame = CGRectMake(bounds.size.width - 44, 8, 36, 36);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

    // 36 rather than 30. The old one was under Apple's 44-point minimum and sharing its
    // space with another button; this one is bigger and has the corner to itself.
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    button.layer.cornerRadius = 18;
    button.layer.masksToBounds = YES;
    button.tintColor = [UIColor whiteColor];

    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [host addSubview:button];
    [host bringSubviewToFront:button];
    sciButtonsAdded++;
}


/// The same, one turn of the runloop later.
///
/// `didMoveToWindow` runs before the view has been laid out, so at that moment the media
/// view inside it is very often still zero by zero -- and the search above rejects anything
/// under 120 points, so it would find nothing and the button would land on the tweet's own
/// corner, which is the placement this release exists to stop.
///
/// A dispatch to the main queue is after that layout pass and still outside it: nothing is
/// invalidated, so none of the recursion the other button caused is possible here. The view
/// is held weakly because a cell can be recycled or released in between, and a strong
/// capture would keep it alive to be decorated for no one.
static void SCITWAddSaveButtonSoon(UIView *view) {
    __weak UIView *weakView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        SCITWAddSaveButton(weakView);
    });
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
    SCITWAddSaveButtonSoon(self);
}

%end

%end


%group FocalStatus

%hook T1TweetDetailsFocalStatusView

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

%end

%end


%group ConversationStatus

%hook T1ConversationFocalStatusView

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButtonSoon(self);
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
