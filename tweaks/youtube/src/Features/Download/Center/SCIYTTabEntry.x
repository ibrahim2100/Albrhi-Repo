#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCIYTDownloadCenter.h"
#import "SCIYTIcon.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"

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

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

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

/// Puts our symbol into the item view YouTube built.
static void SCIPaintIcon(UIView *view) {
    if (!view) return;

    // Ours, drawn, not an SF Symbol. Apple's glyphs carry Apple's weight, and beside five
    // tabs drawn to a different rule the odd one out is the one you see. The label under it
    // is YouTube's, from the renderer's title.
    UIImage *symbol = [SCIYTIcon downloadMarkOfSize:24 filled:NO];
    if (!symbol) return;

    // The first image view in the subtree, which is where the tab's icon lives. Searched
    // rather than named: the item view's internals are not part of any contract, and a
    // wrong name here should cost the icon and nothing else.
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)next).image = symbol;
            ((UIImageView *)next).tintColor = SCIAccent();
            return;
        }
        [queue addObjectsFromArray:next.subviews];
    }
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
        if (!already && items && items.count < 6) {
            id wrapper = SCIMakePivotItem();
            if (wrapper) {
                [items addObject:wrapper];
                sciNativeTabAttached = YES;
            }
        }
    } @catch (NSException *exception) {
        SCILogV(@"tab: could not add the item — %@", exception.reason);
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
    if (SCIIsOurRenderer(renderer)) SCIPaintIcon((UIView *)self);
}

%end


#pragma mark - The tap

%hook YTPivotBarViewController

- (void)didTapItemWithRenderer:(id)renderer {
    if (!SCIIsOurRenderer(renderer)) {
        %orig;
        return;
    }

    // %orig is deliberately not reached. Our item carries no browse endpoint YouTube could
    // resolve, and asking it to navigate to a page that does not exist is how a tab bar
    // ends up on a blank screen it cannot leave.
    SCILogV(@"tab: download centre");
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
