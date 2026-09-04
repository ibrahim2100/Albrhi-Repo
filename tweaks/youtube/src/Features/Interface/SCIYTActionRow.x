#import <objc/runtime.h>
#import <objc/message.h>
#import "shared/src/SCIResponder.h"
#import "shared/src/SCIKVC.h"
#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../Download/SCIYTDownload.h"

///
/// Save, in the row with Like and Share.
///
/// **YouTube builds that row from renderers, so this adds a renderer rather than a view.** The
/// row is `YTSlimVideoScrollableDetailsActionsView` and it is handed its buttons through
/// `-createActionViewsFromSupportedRenderers:` (`v24@0:8@16`); one more entry in that array and
/// YouTube builds the button itself — its own metrics, its own label font, its own collapse
/// behaviour when the row runs out of width, its own scrolling. There is nothing of ours being
/// drawn and so nothing to keep in sync, which is the same reason the Download Centre tab is a
/// pivot renderer rather than a circle painted over the tab bar.
///
/// **Every hop of the chain was read from the app's own class metadata, not guessed:**
///
///   YTISlimMetadataButtonSupportedRenderers . slimMetadataButtonRenderer : YTISlimMetadataButtonRenderer
///   YTISlimMetadataButtonRenderer           . button                     : YTIButtonSupportedRenderers
///   YTIButtonSupportedRenderers             . buttonRenderer             : YTIButtonRenderer
///   YTIButtonRenderer                       . text : YTIFormattedString, targetId : NSString, icon : YTIIcon
///
/// Each class names the next in its declared property *type*, which is what `tools/objc-classes.py`
/// prints and the only kind of chain that has ever worked in this project.
///
/// **`targetId` is why this needs no title matching.** It is a plain string the renderer carries,
/// so the button is recognised at tap time by a value this file wrote — not by comparing an
/// accessibility label against an English word, which is a test that fails on the owner's own
/// Arabic phone.
///
/// **The icon is painted on afterwards, deliberately.** `YTIIcon` wants an `iconType`, an enum
/// whose values are not readable from the binary in any form — so choosing one is guessing at
/// what draws. The Download Centre tab already made that refusal and this makes the same one: the
/// button YouTube built is given our symbol once it exists, and a build where that fails shows a
/// labelled button with no picture rather than the wrong picture.
///
/// **Not on the launch path.** This row is built when a video is opened, which is why the feature
/// can be on by default at all: the tab-bar work next door had to be moved off the launch and this
/// never was on it. The launch guard is still consulted, because a hook that stands down with the
/// others is one fewer thing to reason about when something goes wrong.
///

/// Ours, and nothing else's.
static NSString *const kSCIActionTargetId = @"albrhi.download.action";

/// Set on the action view YouTube built for our renderer, so the tap knows which button it is.
static char kSCIIsOurActionView;

/// How many of these rows the app actually *built*, counted separately from how many times it
/// asked us to fill one.
///
/// **Two different answers hide behind "no button": the class is never constructed, or it is
/// constructed and the method we hook is not the one it uses.** The first means the row is drawn
/// some other way entirely and no renderer can help; the second is a selector to find. One number
/// cannot say which, and this project has paid for that confusion on four features now.
static NSUInteger sciActionRowsBuilt = 0;

static NSUInteger sciActionRowsSeen = 0;
static NSUInteger sciActionRenderersAdded = 0;
static NSUInteger sciActionViewsFound = 0;
static NSUInteger sciActionTaps = 0;
static NSString *sciActionRowState = nil;

static void SCIReportActionRow(void) {
    [SCIYTDiagnostics recordActionRow:
        [NSString stringWithFormat:SCILocalized(@"diag_action_row"),
            (unsigned long)sciActionRowsBuilt,
            (unsigned long)sciActionRowsSeen, (unsigned long)sciActionRenderersAdded,
            (unsigned long)sciActionViewsFound, (unsigned long)sciActionTaps,
            sciActionRowState ?: SCILocalized(@"diag_action_row_nothing")]];
}

/// Sets one protobuf field, reporting rather than throwing.
///
/// KVC on purpose: these are GPBMessage subclasses whose fields resolve dynamically, so
/// `-respondsToSelector:` answers NO for a field `-setValue:forKey:` sets perfectly well. That is
/// recorded in CLAUDE.md and it is why this file reads as keys rather than as messages.
static BOOL SCISetField(id object, id value, NSString *key) {
    if (!object || !value) return NO;
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (NSException *exception) {
        sciActionRowState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_refused"),
                             key, exception.reason ?: @"?"];
        return NO;
    }
}

/// Builds the renderer for one more button in the row.
static id SCIMakeActionRenderer(void) {
    Class supportedClass = NSClassFromString(@"YTISlimMetadataButtonSupportedRenderers");
    Class slimClass      = NSClassFromString(@"YTISlimMetadataButtonRenderer");
    Class buttonsClass   = NSClassFromString(@"YTIButtonSupportedRenderers");
    Class buttonClass    = NSClassFromString(@"YTIButtonRenderer");

    if (!supportedClass || !slimClass || !buttonsClass || !buttonClass) {
        sciActionRowState = SCILocalized(@"diag_action_row_classes");
        return nil;
    }

    id button = [[buttonClass alloc] init];
    if (!SCISetField(button, kSCIActionTargetId, @"targetId")) return nil;

    // The label, as the formatted string every other button in this row carries. A plain
    // NSString here is not a shorter label, it is a button that does not draw -- learned twice
    // already, by the Download Centre tab and by the History tab, and not worth learning again.
    Class stringClass = NSClassFromString(@"YTIFormattedString");
    SEL make = NSSelectorFromString(@"formattedStringWithString:");
    if (stringClass && [stringClass respondsToSelector:make]) {
        id title = ((id (*)(id, SEL, id))objc_msgSend)(stringClass, make,
                                                       SCILocalized(@"action_save"));
        if (title) SCISetField(button, title, @"text");
    }

    id buttons = [[buttonsClass alloc] init];
    if (!SCISetField(buttons, button, @"buttonRenderer")) return nil;

    id slim = [[slimClass alloc] init];
    if (!SCISetField(slim, buttons, @"button")) return nil;

    id supported = [[supportedClass alloc] init];
    if (!SCISetField(supported, slim, @"slimMetadataButtonRenderer")) return nil;

    return supported;
}

/// Whether a supported-renderer is the one this file made.
static BOOL SCIIsOurActionRenderer(id renderer) {
    if (!renderer) return NO;
    @try {
        id slim = SCISafeValueForKey(renderer, @"slimMetadataButtonRenderer");
        id buttons = slim ? SCISafeValueForKey(slim, @"button") : nil;
        id button = buttons ? SCISafeValueForKey(buttons, @"buttonRenderer") : nil;
        id target = button ? SCISafeValueForKey(button, @"targetId") : nil;
        return [target isKindOfClass:[NSString class]] &&
               [(NSString *)target isEqualToString:kSCIActionTargetId];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

/// Puts our mark on the button YouTube built, and marks the view as ours.
///
/// Found by asking each action view what it was built from rather than by comparing labels: the
/// renderer is passed to `-initWithSlimMetadataButtonSupportedRenderer:`, and where a build keeps
/// it under a readable name this is exact. Where it does not, the accessibility label is the
/// fallback -- and it is compared against *our own* string, which this file wrote, so it is not
/// the English-title matching this project refuses elsewhere.
static void SCIMarkOurActionView(UIView *row) {
    static UIImage *mark = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mark = [UIImage systemImageNamed:@"arrow.down.circle"]; });

    Class actionClass = NSClassFromString(@"YTSlimVideoDetailsActionView");
    if (!actionClass) return;

    NSString *ours = SCILocalized(@"action_save");

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:row];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:actionClass]) {
            if (![objc_getAssociatedObject(next, &kSCIIsOurActionView) boolValue]) {
                NSString *label = next.accessibilityLabel;
                if ([label isEqualToString:ours]) {
                    objc_setAssociatedObject(next, &kSCIIsOurActionView, @YES,
                                             OBJC_ASSOCIATION_RETAIN);
                    sciActionViewsFound++;
                    sciActionRowState = SCILocalized(@"diag_action_row_placed");

                    // The button, not the first image view -- the same finding the pivot tab
                    // cost: a UIButton's own image view either does not exist until it has an
                    // image or is overwritten on the button's next layout.
                    if (mark && [next respondsToSelector:@selector(button)]) {
                        UIButton *button = [(YTSlimVideoDetailsActionView *)next button];
                        if ([button isKindOfClass:[UIButton class]] &&
                            [button imageForState:UIControlStateNormal] != mark) {
                            [button setImage:mark forState:UIControlStateNormal];
                        }
                    }
                }
            }
            continue;
        }

        [queue addObjectsFromArray:next.subviews];
    }

    SCIReportActionRow();
}


%group SCIActionRow

%hook YTSlimVideoScrollableDetailsActionsView

- (void)createActionViewsFromSupportedRenderers:(NSArray *)renderers {
    if (SCIYTStoodDown() || !SCIPrefEnabled(SCIPrefActionRowButton) ||
        ![renderers isKindOfClass:[NSArray class]]) {
        %orig;
        return;
    }

    sciActionRowsSeen++;

    @try {
        // Never twice. This is called again when the video changes and on a page style change,
        // and a row that gains a button each time is the pivot bar's own old bug one screen over.
        BOOL already = NO;
        for (id renderer in renderers) {
            if (SCIIsOurActionRenderer(renderer)) { already = YES; break; }
        }

        if (!already) {
            id ours = SCIMakeActionRenderer();
            if (ours) {
                NSMutableArray *widened = [renderers mutableCopy];
                [widened addObject:ours];
                sciActionRenderersAdded++;
                sciActionRowState = SCILocalized(@"diag_action_row_added");
                %orig(widened);

                // After YouTube has built the views, never before: there is nothing to paint
                // until the button exists.
                SCIMarkOurActionView(self);
                return;
            }
        }
    } @catch (NSException *exception) {
        // A button in a row is a convenience; the row is not. Anything thrown here costs the
        // button and leaves YouTube's own row exactly as it was.
        sciActionRowState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_threw"),
                             exception.reason ?: @"?"];
        SCILogV(@"action row: %@", exception.reason);
    }

    %orig;
    SCIMarkOurActionView(self);
}

%end


%hook YTSlimVideoScrollableDetailsActionsView

/// Counted here and nowhere else: `-didMoveToWindow` fires once per instance and changes nothing,
/// so it can say "the app built one of these" without being on a layout path.
- (void)didMoveToWindow {
    %orig;
    sciActionRowsBuilt++;
    SCIReportActionRow();
}

%end


%hook YTSlimVideoDetailsActionView

- (void)didTapButton:(id)sender {
    if (![objc_getAssociatedObject(self, &kSCIIsOurActionView) boolValue]) {
        %orig;
        return;
    }

    sciActionTaps++;
    SCIReportActionRow();

    // Deliberately without %orig. Our renderer carries no command, so YouTube has nothing to do
    // with the tap; calling through would only give it a button it does not recognise to reason
    // about.
    UIViewController *host = SCIControllerForView(self);
    if (host) {
        [SCIYTDownload presentFrom:host];
    } else {
        sciActionRowState = SCILocalized(@"diag_action_row_no_host");
        SCIReportActionRow();
    }
}

%end

%end


%ctor {
    // A `%hook` on an absent class never attaches, so this costs nothing on a build that draws
    // its row some other way -- and the report says which, rather than leaving "no button" to
    // mean two things at once.
    if (NSClassFromString(@"YTSlimVideoScrollableDetailsActionsView")) {
        %init(SCIActionRow);
        sciActionRowState = SCILocalized(@"diag_action_row_hooked");
    } else {
        sciActionRowState = SCILocalized(@"diag_action_row_absent");
    }

    // **Written to the report here, and this is the whole of what 1.30.0 got wrong.**
    //
    // The state was set and never recorded, so the page printed "no action row has been built"
    // -- the empty-slot sentence -- whether the class was missing, present and never called, or
    // hooked and waiting. One sentence for three different investigations, which is the exact
    // failure this file's own diagnostics were written to prevent, one level up: setting a
    // variable is not reporting it.
    SCIReportActionRow();
}
