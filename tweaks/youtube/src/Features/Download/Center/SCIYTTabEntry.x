#import <UIKit/UIKit.h>
#import "../../../Tweak.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCIYTDownloadCenter.h"
#import "SCIYTIcon.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"

///
/// The way into the Download Centre, as one of YouTube's own tabs.
///
/// The first version of this drew a red circle over the tab bar. It worked and it looked
/// exactly like what it was: a button sitting on top of the bar rather than in it, with no
/// label, no selected state, no indicator dot, and no share of the width when the bar
/// re-laid itself out.
///
/// This does not draw anything. YouTube's tab bar is built from a protobuf -- a
/// YTIPivotBarRenderer holding one YTIPivotBarItemRenderer per tab -- and the bar is handed
/// that renderer through -setRenderer:. One more item is appended on the way through, and
/// YouTube then builds the tab itself: its own item view, its own label font, its own
/// selection behaviour, its own spacing. There is nothing to keep in sync because there is
/// nothing of ours being drawn.
///
/// **The fields are set with KVC, deliberately.** These are GPBMessage subclasses and their
/// fields are resolved dynamically, so -respondsToSelector: answers NO for a field that
/// -setValue:forKey: sets perfectly well. That is recorded in CLAUDE.md and it is the whole
/// reason this reads as key paths rather than as method calls.
///
/// **The icon is not set through the renderer.** A YTIIcon wants an iconType, which is an
/// enum whose names are not in the binary in any form that can be read -- so choosing a
/// value would be guessing at what draws, which is the one thing this project does not do.
/// The item view's own image view is given our symbol after YouTube has built it. If that
/// fails the tab is a label with no icon, which is a smaller loss than a wrong picture.
///
/// The failure is soft at every step. If the pivot bar classes are not there, or the append
/// throws, no tab appears and the old floating button is left in place instead -- so the
/// entrance never disappears entirely.
///

/// Ours, and nothing else's. Long enough that YouTube could not have one like it.
static NSString *const kSCIPivotIdentifier = @"albrhi.downloads.pivot";

/// Whether a real tab was built. The floating button stands down when one was.
static BOOL sciNativeTabAttached = NO;

/// Marks the one item view showing our tab. Item views are reused between tabs, so this
/// belongs on the view and not in a variable.
static char kSCIIsOurItemView;

/// Which of YouTube's own tabs was open before ours took over.
///
/// Kept because telling the bar our identifier is selected leaves it holding a name it has
/// no page for. YouTube works out the next transition from whatever it thinks is currently
/// selected, and an identifier it does not recognise gives it nothing to transition *from*
/// -- so it falls back to its default, which is Home. Every tab tapped after visiting the
/// Centre opened Home, whichever tab was tapped.
///
/// So its own answer is put back before it is asked to move, and the pair it computes from
/// is one it knows.
static NSString *sciPivotBeforeOurs = nil;


/// Whether a pivot item renderer is the one we added.
static BOOL SCIIsOurRenderer(id renderer) {
    if (!renderer) return NO;

    @try {
        return [[renderer valueForKey:@"pivotIdentifier"] isEqualToString:kSCIPivotIdentifier];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

/// Builds one tab, as the protobuf YouTube expects.
static id SCIMakePivotItem(void) {
    Class itemClass = NSClassFromString(@"YTIPivotBarItemRenderer");
    Class wrapperClass = NSClassFromString(@"YTIPivotBarSupportedRenderers");
    if (!itemClass || !wrapperClass) return nil;

    id item = [[itemClass alloc] init];
    [item setValue:kSCIPivotIdentifier forKey:@"pivotIdentifier"];

    // The label, as the formatted string every other tab carries. A plain NSString in this
    // field is not a shorter label, it is a tab that does not draw.
    Class stringClass = NSClassFromString(@"YTIFormattedString");
    SEL make = NSSelectorFromString(@"formattedStringWithString:");
    if (stringClass && [stringClass respondsToSelector:make]) {
        id title = ((id (*)(id, SEL, id))objc_msgSend)(stringClass, make,
                                                       SCILocalized(@"dl_centre_title"));
        if (title) [item setValue:title forKey:@"title"];
    }

    id wrapper = [[wrapperClass alloc] init];
    [wrapper setValue:item forKey:@"pivotBarItemRenderer"];
    return wrapper;
}

/// Puts our mark into the item view YouTube built.
///
/// **The button, not the first image view.** The first version of this walked for a
/// UIImageView and set its image, and the tab came up blank. A pivot tab is drawn by a
/// YTQTMButton -- the controller has a -YTQTMButtonFromPivotBarItemView: to fetch one, so
/// the button is what holds the picture -- and a UIButton's own image view either does not
/// exist until it has an image or is overwritten by the button on its next layout. Setting
/// it through the button is what sticks, and it also lets the selected state be set, which
/// the image view alone could not do.
///
/// Returns whether anything was found to paint, so the report can say which.
static BOOL SCIPaintIcon(UIView *view) {
    if (!view) return NO;

    UIImage *mark = [SCIYTIcon downloadMarkOfSize:24 filled:NO];
    UIImage *filled = [SCIYTIcon downloadMarkOfSize:24 filled:YES];
    if (!mark) return NO;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    UIImageView *fallback = nil;

    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)next;
            [button setImage:mark forState:UIControlStateNormal];
            [button setImage:filled forState:UIControlStateSelected];
            [button setImage:filled forState:UIControlStateHighlighted];
            button.tintColor = SCIAccent();
            return YES;
        }

        // Remembered but not used yet: a button deeper in the tree is the better answer,
        // and taking the first image view would stop the search before finding it.
        if (!fallback && [next isKindOfClass:[UIImageView class]]) fallback = (UIImageView *)next;

        [queue addObjectsFromArray:next.subviews];
    }

    if (fallback) {
        fallback.image = mark;
        fallback.tintColor = SCIAccent();
        return YES;
    }
    return NO;
}


#pragma mark - The bar

%hook YTPivotBarView

- (void)setRenderer:(id)renderer {
    if (!SCIPrefEnabled(SCIPrefTabButton) || !renderer) {
        %orig;
        return;
    }

    @try {
        NSMutableArray *items = [renderer valueForKey:@"itemsArray"];

        // Appended once. -setRenderer: is called again on every page style change, on
        // rotation, and when the account switches; without this the bar would gain a tab
        // each time until it ran out of item views.
        BOOL already = NO;
        for (id entry in items) {
            id inner = nil;
            @try { inner = [entry valueForKey:@"pivotBarItemRenderer"]; } @catch (__unused NSException *e) { }
            if (SCIIsOurRenderer(inner)) { already = YES; break; }
        }

        // The bar holds six item views and no more. Five tabs is the usual shape, so ours
        // is the sixth and it fits -- but a build that already fills all six gets left
        // alone rather than handed a seventh that has nowhere to be drawn.
        if (already) {
            // Nothing to say. This runs on every style change and a report that repeats
            // itself is one nobody reads to the end of.
        } else if (!items) {
            [SCIYTDiagnostics recordTabState:@"the bar has no items array"];
        } else if (items.count >= 6) {
            [SCIYTDiagnostics recordTabState:
                [NSString stringWithFormat:@"the bar is already full (%lu tabs)",
                    (unsigned long)items.count]];
        } else {
            id wrapper = SCIMakePivotItem();
            if (!wrapper) {
                [SCIYTDiagnostics recordTabState:@"the pivot bar classes are not on this build"];
            } else {
                [items addObject:wrapper];
                sciNativeTabAttached = YES;
                [SCIYTDiagnostics recordTabState:
                    [NSString stringWithFormat:@"item added, now %lu tabs",
                        (unsigned long)items.count]];
            }
        }
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordTabState:
            [NSString stringWithFormat:@"refused: %@", exception.reason ?: @"?"]];
    }

    %orig;
}

%end


#pragma mark - The tab itself

%hook YTPivotBarItemView

- (void)setRenderer:(id)renderer {
    %orig;

    // Cast because inside a %hook, self is the hooked class, which Logos only
    // forward-declares -- it has no way to know it descends from UIView.
    // Marked on the view itself rather than remembered in a variable. YTPivotBarItemView
    // has a -setRenderer: and no -renderer, so on the next layout pass there is no way to
    // ask the view what it is showing -- and item views are reused, so one global "ours"
    // flag would paint whichever tab inherited the view next.
    objc_setAssociatedObject(self, &kSCIIsOurItemView,
                             SCIIsOurRenderer(renderer) ? @YES : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (!SCIIsOurRenderer(renderer)) return;

    [SCIYTDiagnostics recordTabState:
        SCIPaintIcon((UIView *)self) ? @"tab built, mark painted"
                                     : @"tab built, nothing found to paint"];
}

/// Painted again on layout, because once is not enough.
///
/// -setRenderer: can arrive before the button exists -- the tab's insides are built lazily
/// -- and the button reloads its own image when its state changes. A tab that came up blank
/// and stayed blank is what this is for; it is idempotent, so running on every pass costs a
/// cache lookup.
- (void)layoutSubviews {
    %orig;

    if (objc_getAssociatedObject(self, &kSCIIsOurItemView)) SCIPaintIcon((UIView *)self);
}

%end


#pragma mark - The tap

/// Declared because the hook calls it on self. Inside a %hook, self is the hooked class and
/// Logos only forward-declares it, so a selector sent to self needs to be visible from here.
@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(NSString *)identifier;
@end

%hook YTPivotBarViewController

/// The one place every route through the bar passes.
///
/// Taking the page down only on a tap was the mistake, and it read as correct because a tap
/// is how a person leaves a tab. It is not how the *app* leaves one. A modal being dismissed
/// restores a selection, a notification opens a tab, YouTube's own code calls
/// -selectItemWithPivotIdentifier: — none of those is a tap, and after any of them our page
/// was still sitting in the content area, on top, while YouTube swapped its pages underneath
/// it. Every tab then showed the same thing, which is exactly what it looked like.
///
/// So the page comes down whenever the bar stops saying our name, whoever said so. A tap is
/// now one caller of this rather than the only one that works.
- (void)setSelectedPivotIdentifier:(NSString *)identifier {
    %orig;

    if (![identifier isEqualToString:kSCIPivotIdentifier]) {
        [SCIYTDownloadCenter removeFromPivotBar];
    }
}

- (void)didTapItemWithRenderer:(id)renderer {
    if (!SCIIsOurRenderer(renderer)) {
        // Leaving. The page comes down first so YouTube's own tab is not laid out behind
        // ours -- and it is taken down whether or not it was up, which costs nothing and
        // means there is no state to get wrong.
        [SCIYTDownloadCenter removeFromPivotBar];

        // And the bar is handed back its own answer before it is asked to move.
        //
        // %orig works out the transition from what it believes is selected, and what it
        // believed was our identifier -- which names no page it has. Given nothing to
        // transition from it went to its default, so every tab tapped after a visit to the
        // Centre opened Home. Restoring first means the pair it computes from is one it
        // knows, and the tab actually tapped is where it goes.
        if (sciPivotBeforeOurs) {
            @try {
                [self setValue:sciPivotBeforeOurs forKey:@"selectedPivotIdentifier"];
            } @catch (__unused NSException *exception) { }
            sciPivotBeforeOurs = nil;
        }

        %orig;
        return;
    }

    // %orig is deliberately not reached. Our item carries no browse endpoint YouTube could
    // resolve, and asking it to navigate to a page that does not exist is how a tab bar
    // ends up on a blank screen it cannot leave.
    SCILogV(@"tab: download centre");

    // In the content area, under the bar, the way Home and You are. Presenting it slid the
    // whole screen up over YouTube and covered the tab bar, which read as something bolted
    // on -- because a modal is exactly that.
    if ([SCIYTDownloadCenter showInsidePivotBar:self]) {
        [SCIYTDiagnostics recordTabState:@"page shown in the content area"];

        // Remembered before it is overwritten, and only the first time -- tapping our own
        // tab twice must not record our own identifier as the one to go back to.
        if (!sciPivotBeforeOurs) {
            @try {
                NSString *current = [self valueForKey:@"selectedPivotIdentifier"];
                if ([current isKindOfClass:[NSString class]] &&
                    ![current isEqualToString:kSCIPivotIdentifier]) {
                    sciPivotBeforeOurs = [current copy];
                }
            } @catch (__unused NSException *exception) { }
        }

        // So the tab lights up like any other. Without this the bar still shows whichever
        // tab was open before, and the page underneath belongs to nothing.
        if ([self respondsToSelector:@selector(selectItemWithPivotIdentifier:)]) {
            [self selectItemWithPivotIdentifier:kSCIPivotIdentifier];
        }
        return;
    }

    // Only if the bar is not arranged the way that expects. A window over the app is worse
    // than a page in it, and better than no way in at all.
    [SCIYTDiagnostics recordTabState:@"content area not reachable, presented instead"];
    [SCIYTDownloadCenter present];
}

%end


#pragma mark - The fallback

static char kSCITabButtonAdded;

/// Whether this controller is the bar along the bottom.
///
/// Only consulted for the floating button, which is now what happens when the real tab
/// could not be built.
static BOOL SCIIsTabBarController(UIViewController *controller) {
    NSString *name = NSStringFromClass([controller class]);
    if (![name hasPrefix:@"YT"]) return NO;

    return [name containsString:@"PivotBar"] || [name containsString:@"TabBar"];
}

static void SCIAddTabButton(UIViewController *controller) {
    if (!controller.view || objc_getAssociatedObject(controller, &kSCITabButtonAdded)) return;
    objc_setAssociatedObject(controller, &kSCITabButtonAdded, @YES, OBJC_ASSOCIATION_RETAIN);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    [button setImage:[SCIYTIcon downloadMarkOfSize:24 filled:YES]
            forState:UIControlStateNormal];

    button.tintColor = SCIAccent();
    button.translatesAutoresizingMaskIntoConstraints = NO;

    [button addTarget:[SCIYTDownloadCenter class]
               action:@selector(present)
     forControlEvents:UIControlEventTouchUpInside];

    [controller.view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-6],
        [button.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [button.widthAnchor constraintEqualToConstant:38],
        [button.heightAnchor constraintEqualToConstant:38]
    ]];

    SCILogV(@"tab: fallback button added to %@", NSStringFromClass([controller class]));
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!SCIPrefEnabled(SCIPrefTabButton)) return;

    // Only when there is no real tab. The old behaviour, kept for the case the renderer
    // route does not attach -- a build that changed the pivot bar should cost the tab its
    // looks, not cost anyone the way in.
    if (sciNativeTabAttached) return;
    if (!SCIIsTabBarController(self)) return;

    SCIAddTabButton(self);
}

%end
