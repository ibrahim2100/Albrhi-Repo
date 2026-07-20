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

    // DM visual messages viewed
    if ([SCIUtils getBoolPref:@"unlimited_replay"]) {
        UIBarButtonItem *dmVisualMsgsViewedButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"photo.badge.checkmark"] style:UIBarButtonItemStylePlain target:self action:@selector(dmVisualMsgsViewedButtonHandler:)];
        [new_items addObject:dmVisualMsgsViewedButton];

        if (dmVisualMsgsViewedButtonEnabled) {
            [dmVisualMsgsViewedButton setTintColor:SCIUtils.SCIColor_Primary];
        } else {
            [dmVisualMsgsViewedButton setTintColor:UIColor.labelColor];
        }
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
// DM visual messages viewed button
%new - (void)dmVisualMsgsViewedButtonHandler:(UIBarButtonItem *)sender {
    if (dmVisualMsgsViewedButtonEnabled) {
        dmVisualMsgsViewedButtonEnabled = false;
        [sender setTintColor:UIColor.labelColor];

        [SCIUtils showToastForDuration:4.5 title:SCILocalized(@"p_toast_replay_on")];
    }
    else {
        dmVisualMsgsViewedButtonEnabled = true;
        [sender setTintColor:SCIUtils.SCIColor_Primary];

        [SCIUtils showToastForDuration:4.5 title:SCILocalized(@"p_toast_replay_off")];
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

// DM visual-message (view-once) "mark as viewed" logic.
// Only suppress the mark-as-viewed when the feature is on AND the eye toggle is off;
// otherwise let Instagram behave normally (the old code swallowed %orig even when
// the feature was disabled).
%hook IGDirectVisualMessageViewerEventHandler
- (void)visualMessageViewerController:(id)arg1 didBeginPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    // Each message starts unmarked, so marking never leaks to the next one.
    if ([SCIUtils getBoolPref:@"unlimited_replay"]) {
        dmVisualMsgsViewedButtonEnabled = NO;
        return;   // don't register "seen" just for opening it
    }
    %orig;
}
- (void)visualMessageViewerController:(id)arg1 didEndPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 mediaCurrentTime:(CGFloat)arg4 forNavType:(NSInteger)arg5 {
    if ([SCIUtils getBoolPref:@"unlimited_replay"]) {
        if (!dmVisualMsgsViewedButtonEnabled) return;   // you didn't tap the eye — stay unseen
        %orig;                                          // you did — send the seen receipt
        dmVisualMsgsViewedButtonEnabled = NO;           // one-shot: this message only
        return;
    }
    %orig;
}
%end

// Floating controls inside the view-once photo/video viewer:
//  - eye toggle (leading): off = watch without registering as seen, on = mark read.
//  - save button (trailing): download the view-once media.
static const NSInteger SCIVisualSeenButtonTag = 0x5D5EE7;
static const NSInteger SCIVisualSaveButtonTag = 0x5D5A4E;
static const void *kSCIVisualMsgKey = &kSCIVisualMsgKey;

static void SCIUpdateVisualSeenIcon(UIButton *button) {
    if (!button) return;
    NSString *glyph = dmVisualMsgsViewedButtonEnabled ? @"eye.fill" : @"eye.slash.fill";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = dmVisualMsgsViewedButtonEnabled ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];
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
    // Per-message: mark only the message you're viewing now. The flag is reset when
    // the next message opens, so it never leaks to other view-once messages.
    dmVisualMsgsViewedButtonEnabled = !dmVisualMsgsViewedButtonEnabled;

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIUpdateVisualSeenIcon(sender);

    [SCIUtils showToastForDuration:2.5
                             title:SCILocalized(dmVisualMsgsViewedButtonEnabled ? @"p_dm_seen_on" : @"p_dm_seen_off")];
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