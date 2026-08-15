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
/// ## Why setViewModel:, with didMoveToWindow only as a fallback
///
/// The first version of this placed on `didMoveToWindow` alone, which runs once when a view
/// is first inserted into a window and does not run again for a cell that is scrolled out
/// and back in -- table and collection view reuse keeps the same view instance resident in
/// the window and rebinds it through the model instead. That is why the button appeared on
/// the first screenful of a fresh scroll and nowhere after: every recycled cell got a new
/// post and no signal to say so. Opening a tweet worked because a push creates a genuinely
/// new view, which does enter a window.
///
/// `-setViewModel:` is the bind point, runs on first appearance and on every reuse alike,
/// and it is the same selector `SCITWFirstSaveableInStatusView` already reads through
/// `-viewModel` -- if the getter is there, so is the synthesized setter. `didMoveToWindow`
/// stays only for the rarer case of a view windowed with its model already set and no
/// further bind expected; placement is idempotent either way, found by tag and refreshed
/// rather than duplicated.
///
/// Neither hook activates a constraint or forces a layout pass -- the button is a frame,
/// set once layout has already run -- which is unrelated to this fix but still the reason
/// neither one can retrigger the crash the owner reported earlier.
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

/// Declared as what they are, rather than left to Logos.
///
/// A `%hook` on an undeclared class gets a forward declaration only, and `self` is then an
/// incomplete type -- so `SCITWMediaSubview(self) ?: self` is a ternary between `UIView *`
/// and a type the compiler knows nothing about, which is exactly the error the runner
/// produced three times. The sibling file declares `T1InlineMediaView` for the same reason
/// and says so; this is that lesson, arriving again in a different shape.
///
/// Nothing is claimed about them beyond being views, which is all this file needs.
@interface T1StandardStatusView : UIView
@end

@interface T1TweetDetailsFocalStatusView : UIView
@end

@interface T1ConversationFocalStatusView : UIView
@end

/// Ours. High enough that it cannot collide with a tag X sets for its own reasons.
static const NSInteger kSCISaveButtonTag = 0x5C1D;

/// The item the button is currently offering to save.
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciStandardPresent = NO;
static BOOL sciFocalPresent = NO;
static BOOL sciConversationPresent = NO;
static NSUInteger sciButtonsAdded = 0;
static NSUInteger sciMediaFound = 0;

/// Where the button actually landed, not where the code intends it to. Read from the
/// live view hierarchy at the moment of placement rather than asserted, because a class
/// dump says what a view is called and nothing about whether the search found it -- the
/// same gap that cost this feature four releases the first time.
static NSUInteger sciOnMediaView = 0;
static NSUInteger sciOnFallback = 0;


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
    SEL statusSelector = NSSelectorFromString(@"status");

    // The model, or the view itself when the view *is* the model's holder.
    //
    // **This is why the immersive button attached and still added nothing.** A device report
    // on X 12.15 said `ImmersiveActionsStackView — 0 buttons added`: the rail was found and
    // hooked, and every placement bailed here, at the first line, because the walk upward
    // reaches `ImmersiveCardView` and that class has **no -viewModel**. It answers -status
    // directly — confirmed in the class dump, where its whole interface is -status,
    // -playerView, -playerSessionProducer and gesture plumbing, and no model getter at all.
    //
    // So the view is treated as its own model when it answers -status. Everything below
    // already knows how to go from a status to entities to media; it was only ever the one
    // hop at the top that the immersive hierarchy does not have. The ordinary surfaces are
    // untouched: they answer -viewModel, which is still tried first.
    id model = nil;

    if ([view respondsToSelector:modelSelector]) {
        model = ((id (*)(id, SEL))objc_msgSend)(view, modelSelector);
    } else if ([view respondsToSelector:statusSelector]) {
        model = view;
    }

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
    // statusSelector is declared at the top, where it also decides whether the view can
    // stand in for its own model.
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

/// Places the button, and works out where from what it was handed.
///
/// `host` is where the button goes. `view` is where the search for a model starts, which is
/// not the same thing: the video view's own model answers nothing on this build -- the
/// device said so, "25 models, 0 with media" -- and the tweet's model two views up answers
/// everything. So the two are separate arguments, and every caller says which is which.
///
/// Shared with the inline-media hook, which passes itself as both. That hook is why the
/// button is inside the video at all: `T1InlineMediaView` *is* the video, on every surface X
/// shows one -- timeline, tweet detail, the fullscreen viewer, a quoted post, a DM -- so a
/// button placed on it is inside the picture wherever the picture is, including while
/// swiping from one video to the next.
static void SCITWPlaceSaveButton(UIView *host, UIView *view) {
    if (!host || !view || !view.window) return;

    // NSUserDefaults directly, the way the other button in this tweak reads it.
    //
    // `SCIPrefEnabled(...)` is the YouTube and Locket tweaks' helper and this tweak's
    // Prefs.h has never had one. Five tweaks now share idioms and file layouts, and this
    // is the first time one of them borrowed a symbol that only exists next door -- so
    // check.py grew a rule for it rather than the fix being only this line.
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    // Recycled views arrive with the button they were given last time. Found by tag, which
    // is what makes that cheap and correct -- and searched from the *host*, because that is
    // where it was put and where a second one would end up.
    UIButton *existing = (UIButton *)[host viewWithTag:kSCISaveButtonTag];

    // Up the tree, every ancestor with a model, not just this view's own.
    //
    // This is the whole of what was wrong with the video-view route for four releases. The
    // media view has a `viewModel`; it is simply not the one that knows about media. Asking
    // only it produced the twenty-five zeroes in the report.
    SCITWMediaItem *item = nil;
    for (UIView *at = view; at && !item; at = at.superview) {
        item = SCITWFirstSaveableInStatusView(at);
    }
    if (item) sciMediaFound++;

    // A tweet with nothing to save gets no button, and one that had a button and now holds
    // a text-only post loses it. Hiding rather than removing would leave a gap in a row X
    // laid out itself.
    if (!item) {
        if (existing) existing.hidden = YES;
        return;
    }

    // Whether `host` -- where the button is about to be shown -- is the video itself or
    // the fallback. Matched by the same substring `SCITWMediaSubview` uses to find it, so
    // this reports the same fact that function acted on rather than a second opinion.
    NSString *hostClass = NSStringFromClass([host class]);
    if ([hostClass containsString:@"InlineMedia"] || [hostClass containsString:@"MediaView"]) {
        sciOnMediaView++;
    } else {
        sciOnFallback++;
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

    // Top trailing of whatever it was given, and never the bottom.
    //
    // The first version used the bottom trailing corner of the status view, which is exactly
    // where X's share button is: the owner reported it sitting on top of share and being
    // hard to press, and it was -- two 30-point targets in one place, ours winning some taps
    // and share winning others. The top trailing corner of a video is the one X leaves
    // empty; the ALT badge is bottom leading and the audio toggle bottom trailing.
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


/// The video search and the placement, both one turn of the runloop later.
///
/// `didMoveToWindow` runs before the view has been laid out, so at that moment the media
/// view inside it is very often still zero by zero. The first version of this ran
/// `SCITWMediaSubview` immediately, at the call site, and only deferred the placement --
/// so the search still ran against an unlaid-out tree, found nothing over 120 points,
/// fell back to the status view itself, and the button landed on the tweet's corner
/// instead of the video every single time, not only on a fresh cell. Moving the search
/// inside the dispatched block is the fix: by the time it runs, layout has happened, the
/// video view has its real size, and the button lands inside it -- the frame, not the post
/// around it, the same as Instagram's reel download button.
///
/// A dispatch to the main queue is after that layout pass and still outside it: nothing is
/// invalidated, so none of the recursion the other button caused is possible here. The view
/// is held weakly because a cell can be recycled or released in between, and a strong
/// capture would keep it alive to be decorated for no one.
void SCITWAddSaveButtonSoon(UIView *view) {
    __weak UIView *weakView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongView = weakView;
        if (!strongView) return;

        UIView *host = SCITWMediaSubview(strongView) ?: strongView;
        SCITWPlaceSaveButton(host, strongView);
    });
}


// Written out over four lines each rather than as one-liners.
//
// `%orig` expands with #line directives and has to sit alone on its own line inside a full
// block -- `{ %orig; ... }` fails to compile with "%end does not make sense inside a
// block", which is in CLAUDE.md under toolchain gotchas. I wrote all three the forbidden
// way and tools/check.py caught all three before Theos ever saw them, which is the whole
// reason that rule is a check and not a paragraph.

// -setViewModel: is the real trigger on each of these three, for the reason above:
// -didMoveToWindow fires once for a cell's whole recycled life, -setViewModel: fires on
// every bind. -didMoveToWindow stays as a fallback for the one case a view is windowed
// before its model is ever set.

%group StandardStatus

%hook T1StandardStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

%end

%end


%group FocalStatus

%hook T1TweetDetailsFocalStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

%end

%end


%group ConversationStatus

%hook T1ConversationFocalStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    SCITWAddSaveButtonSoon(self);
}

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

    // "on video" vs "on tweet" -- the answer to whether the button actually landed inside
    // the picture, from the view hierarchy at placement time rather than from what the
    // code was written to do. The two counts move every time a post is shown or a cell is
    // recycled, so a low "on tweet" count next to a high "on video" one means the fallback
    // is doing what it is for -- covering the rare miss -- and not carrying the feature.
    return [NSString stringWithFormat:
        @"%@ · %lu with media, %lu buttons added (%lu on video, %lu on tweet)",
        [attached componentsJoinedByString:@"+"],
        (unsigned long)sciMediaFound, (unsigned long)sciButtonsAdded,
        (unsigned long)sciOnMediaView, (unsigned long)sciOnFallback];
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
