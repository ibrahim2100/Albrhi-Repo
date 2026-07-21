#import "../../InstagramHeaders.h"
#import "../../Tweak.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import <objc/runtime.h>

// Seen buttons (in DMs)
// - Enables no seen for messages
// - Enables unlimited views of DM visual messages
%hook IGTallNavigationBarView
- (void)setRightBarButtonItems:(NSArray <UIBarButtonItem *> *)items {
    NSMutableArray *new_items = [[items filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(UIView *value, NSDictionary *_) {
            if ([SCIUtils getBoolPref:@"hide_reels_blend"]) {
                return ![value.accessibilityIdentifier isEqualToString:@"blend-button"];
            }

            return true;
        }]
    ] mutableCopy];

    // Messages seen
    if ([SCIUtils getBoolPref:@"remove_lastseen"]) {
        UIBarButtonItem *seenButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.message"] style:UIBarButtonItemStylePlain target:self action:@selector(seenButtonHandler:)];
        [new_items addObject:seenButton];
    }

    %orig([new_items copy]);
}

// Messages seen button
%new - (void)seenButtonHandler:(UIBarButtonItem *)sender {
    UIViewController *nearestVC = [SCIUtils nearestViewControllerForView:self];
    if ([nearestVC isKindOfClass:%c(IGDirectThreadViewController)]) {
        [(IGDirectThreadViewController *)nearestVC markLastMessageAsSeen];

        [SCIUtils showToastForDuration:2.5 title:SCILocalized(@"p_toast_marked_seen")];
    }
}
%end

// Messages seen logic
%hook IGDirectThreadViewListAdapterDataSource
- (BOOL)shouldUpdateLastSeenMessage {
    if ([SCIUtils getBoolPref:@"remove_lastseen"]) {
        return false;
    }
    
    return %orig;
}
%end

///
/// View-once "mark as seen", per message.
///
/// Instagram registers a view-once message as seen when playback ends. The tweak
/// suppresses that, so nothing is ever marked automatically — and the button below
/// re-triggers it for exactly one message, on demand.
///
/// The previous design was a toggle: arm it, then close the message and hope the
/// receipt went out. It gave no confirmation, and the armed state could carry into
/// the next message. This replays the original end-of-playback call directly, so a
/// single press marks the message you are looking at and nothing else.
///

// Context captured when a message starts playing, needed to replay the call.
static __weak id sciSeenHandler = nil;
static __weak id sciSeenController = nil;
static id sciSeenMessage = nil;
static NSInteger sciSeenIndex = 0;

// YES only for the instant we re-enter the hook deliberately.
static BOOL sciSeenPassthrough = NO;
// Whether the message on screen right now has already been marked.
static BOOL sciSeenMarkedCurrent = NO;

%hook IGDirectVisualMessageViewerEventHandler

- (void)visualMessageViewerController:(id)arg1 didBeginPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if (![SCIUtils getBoolPref:@"unlimited_replay"]) { %orig; return; }

    // A new message is on screen: capture what marking it would need, and clear the
    // previous message's state so marking never carries over.
    sciSeenHandler = self;
    sciSeenController = arg1;
    sciSeenMessage = arg2;
    sciSeenIndex = arg3;
    sciSeenMarkedCurrent = NO;

    // Opening a message must not register it as seen.
}

- (void)visualMessageViewerController:(id)arg1 didEndPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 mediaCurrentTime:(CGFloat)arg4 forNavType:(NSInteger)arg5 {
    if (![SCIUtils getBoolPref:@"unlimited_replay"]) { %orig; return; }

    // Only the deliberate re-entry from the button gets through.
    if (sciSeenPassthrough) %orig;
}

%end

/// Marks the message currently on screen as seen. Returns NO when there is nothing
/// captured to mark.
static BOOL SCIMarkCurrentVisualMessageSeen(void) {
    id handler = sciSeenHandler;
    id controller = sciSeenController;
    id message = sciSeenMessage;

    if (!handler || !message) return NO;

    SEL sel = @selector(visualMessageViewerController:didEndPlaybackForVisualMessage:atIndex:mediaCurrentTime:forNavType:);
    if (![handler respondsToSelector:sel]) return NO;

    NSMethodSignature *signature = [handler methodSignatureForSelector:sel];
    if (!signature) return NO;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = sel;
    invocation.target = handler;

    CGFloat time = 0.0;
    NSInteger index = sciSeenIndex, navType = 0;
    [invocation setArgument:&controller atIndex:2];
    [invocation setArgument:&message atIndex:3];
    [invocation setArgument:&index atIndex:4];
    [invocation setArgument:&time atIndex:5];
    [invocation setArgument:&navType atIndex:6];

    sciSeenPassthrough = YES;
    @try {
        [invocation invoke];
    } @catch (__unused id e) {
        sciSeenPassthrough = NO;
        return NO;
    }
    sciSeenPassthrough = NO;

    sciSeenMarkedCurrent = YES;

    return YES;
}

// Floating controls inside the view-once photo/video viewer:
//  - eye toggle (leading): off = watch without registering as seen, on = mark read.
//  - save button (trailing): download the view-once media.
static const NSInteger SCIVisualSeenButtonTag = 0x5D5EE7;
static const NSInteger SCIVisualSaveButtonTag = 0x5D5A4E;
static const void *kSCIVisualMsgKey = &kSCIVisualMsgKey;

static void SCIUpdateVisualSeenIcon(UIButton *button) {
    if (!button) return;

    // Two states only: not yet marked, and marked. Pressing is one-way for the
    // message on screen — a seen receipt cannot be recalled.
    NSString *glyph = sciSeenMarkedCurrent ? @"checkmark.circle.fill" : @"eye.slash.fill";

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                         weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];

    button.tintColor = sciSeenMarkedCurrent ? [UIColor systemGreenColor] : [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(sciSeenMarkedCurrent ? @"p_dm_seen_done" : @"p_dm_seen_mark");
}

%hook IGDirectVisualMessageViewerController

// Capture the message being opened so the save button can reach its media. View-once
// media is opened one message at a time, so the initial message is the current one.
- (id)initWithThreadKey:(id)threadKey
   initialVisualMessage:(id)initialVisualMessage
             dataSource:(id)dataSource
             entryPoint:(long long)entryPoint
            threadTheme:(id)threadTheme
  gradientBubbleTracker:(id)gradientBubbleTracker
        eventResponders:(id)eventResponders
              preloader:(id)preloader
   outgoingUpdateSender:(id)outgoingUpdateSender
    messageReplyHandler:(id)messageReplyHandler
 sendAttributionFactory:(id)sendAttributionFactory
            userSession:(id)userSession
          configuration:(id)configuration
        analyticsModule:(id)analyticsModule {

    id vc = %orig(threadKey, initialVisualMessage, dataSource, entryPoint, threadTheme,
                  gradientBubbleTracker, eventResponders, preloader, outgoingUpdateSender,
                  messageReplyHandler, sendAttributionFactory, userSession, configuration, analyticsModule);

    if (vc && initialVisualMessage) {
        objc_setAssociatedObject(vc, kSCIVisualMsgKey, initialVisualMessage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return vc;
}

- (void)didUpdateWithVisualMessages:(id)visualMessages isSendInProgress:(BOOL)sendInProgress {
    %orig;

    // Keep the captured message current as the viewer advances — but only if the
    // entry looks like a visual message (has photo/video), so we never overwrite the
    // reliable init-captured one with a view model of another shape.
    @try {
        id first = [visualMessages respondsToSelector:@selector(firstObject)] ? [visualMessages firstObject] : nil;
        if (first && ([first respondsToSelector:@selector(video)] || [first respondsToSelector:@selector(photo)])) {
            objc_setAssociatedObject(self, kSCIVisualMsgKey, first, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch (__unused id e) {}
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([SCIUtils getBoolPref:@"unlimited_replay"]) [self sciAddVisualSeenButton];
    if ([SCIUtils getBoolPref:@"dm_media_save_button"]) [self sciAddVisualSaveButton];
}

- (void)viewDidLayoutSubviews {
    %orig;
    if ([SCIUtils getBoolPref:@"unlimited_replay"]) [self sciAddVisualSeenButton];
    if ([SCIUtils getBoolPref:@"dm_media_save_button"]) [self sciAddVisualSaveButton];

    UIButton *eye = (UIButton *)[self.view viewWithTag:SCIVisualSeenButtonTag];
    if (eye) { [self.view bringSubviewToFront:eye]; SCIUpdateVisualSeenIcon(eye); }
    UIView *save = [self.view viewWithTag:SCIVisualSaveButtonTag];
    if (save) [self.view bringSubviewToFront:save];
}

%new - (void)sciAddVisualSeenButton {
    if ([self.view viewWithTag:SCIVisualSeenButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIVisualSeenButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;

    SCIUpdateVisualSeenIcon(button);

    [button addTarget:self action:@selector(sciToggleVisualSeen:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:14.0],
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-96.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new - (void)sciToggleVisualSeen:(UIButton *)sender {
    if (sciSeenMarkedCurrent) {
        [SCIUtils showToastForDuration:2.0 title:SCILocalized(@"p_dm_seen_already")];
        return;
    }

    BOOL marked = SCIMarkCurrentVisualMessageSeen();

    UINotificationFeedbackGenerator *haptics = [[UINotificationFeedbackGenerator alloc] init];
    [haptics notificationOccurred:marked ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];

    SCIUpdateVisualSeenIcon(sender);

    [SCIUtils showToastForDuration:2.5
                             title:SCILocalized(marked ? @"p_dm_seen_done" : @"p_dm_seen_failed")];
}

%new - (void)sciAddVisualSaveButton {
    if ([self.view viewWithTag:SCIVisualSaveButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIVisualSaveButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;
    button.tintColor = [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"p_dm_save_t");

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"square.and.arrow.down" withConfiguration:config] forState:UIControlStateNormal];

    [button addTarget:self action:@selector(sciSaveVisualMessage:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14.0],
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-96.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new - (void)sciSaveVisualMessage:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    id message = objc_getAssociatedObject(self, kSCIVisualMsgKey);
    if (!message) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    // The message exposes -video/-photo just like an IGMedia, so let the coordinator
    // resolve and download it (video wins, else photo) — same path as everywhere else.
    [SCIMediaDownloader downloadMedia:message sourceLabel:nil anchor:sender];
}

%end