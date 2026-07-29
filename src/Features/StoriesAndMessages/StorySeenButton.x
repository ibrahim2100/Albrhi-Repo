#import "../../InstagramHeaders.h"
#import <objc/message.h>

extern NSString * const SCIStorySeenSentNotification;
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"
#import "../../Downloader/SCIMediaDownloader.h"

///
/// Floating controls over the story viewer.
///
/// - Mark-as-seen (eye): `no_seen_receipt` blocks the receipt entirely; this eye
///   toggle lets you opt a specific story back in. Flag lives here, read by
///   DisableStorySeen.x. Bottom-leading.
/// - Download: a visible download button so stories can be saved without knowing
///   the long-press gesture. Bottom-trailing.
///

BOOL storySeenOverrideEnabled = NO;

static const NSInteger SCIStorySeenButtonTag = 0x5CE7E;
static const NSInteger SCIStoryDownloadButtonTag = 0x5C00D;

static void SCIUpdateSeenButtonAppearance(UIButton *button) {
    // One action, one look: an eye with a tick, meaning "let this one count, then
    // move on". It used to be a toggle whose two states were easy to misread as
    // whether hiding was on at all.
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];

    UIImage *glyph = [UIImage systemImageNamed:@"eye.circle.fill" withConfiguration:config]
                     ?: [UIImage systemImageNamed:@"eye.fill" withConfiguration:config];

    [button setImage:glyph forState:UIControlStateNormal];

    button.tintColor = [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"story_seen_mark_skip");
}

/// The paged scroll view the stories sit in, for builds that expose no section
/// controller. Reels are paged the same way, and it is the only route the older
/// Instagram leaves open: it has no -currentlyDisplayedSectionController at all,
/// which is why the skip did nothing there.
static UIScrollView *SCIStoryPager(UIView *view, NSInteger depth) {
    if (!view || depth > 4) return nil;

    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scroller = (UIScrollView *)sub;

            // Horizontal and at least a page wide — the story pager, not the reply
            // bar's own scrolling or a nested carousel.
            if (scroller.contentSize.width > scroller.bounds.size.width + 1
                && scroller.bounds.size.width > 100) {
                return scroller;
            }
        }

        UIScrollView *nested = SCIStoryPager(sub, depth + 1);
        if (nested) return nested;
    }
    return nil;
}

/// The section controller driving the story on screen, which is what knows how to
/// move to the next one. Reached by trying the accessors the two builds use, and
/// nil where none of them fit — the pager above covers that case.
static id SCICurrentStorySection(UIViewController *viewer) {
    for (NSString *key in @[@"currentlyDisplayedSectionController",
                            @"currentSectionController",
                            @"focusedSectionController",
                            @"_currentFullscreenSectionController"]) {
        @try {
            id candidate = [viewer valueForKey:key];
            if ([candidate respondsToSelector:@selector(advanceToNextItemWithNavigationAction:)]) {
                return candidate;
            }
        } @catch (__unused id error) {}
    }
    return nil;
}

%hook IGStoryViewerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    [self sciEnsureStorySeenButton];
    [self sciEnsureStoryDownloadButton];
}

%new - (void)sciEnsureStorySeenButton {
    if (![SCIUtils getBoolPref:@"story_seen_button"]) return;
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return;  // nothing to override

    if ([self.view viewWithTag:SCIStorySeenButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIStorySeenButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // Dark circular backdrop so the glyph stays legible over any story content.
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;

    SCIUpdateSeenButtonAppearance(button);

    [button addTarget:self action:@selector(sciToggleStorySeen:) forControlEvents:UIControlEventTouchUpInside];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sciSeenReceiptWasSent:)
                                                 name:SCIStorySeenSentNotification
                                               object:nil];

    [self.view addSubview:button];

    // Bottom-leading, clear of the reply bar and the progress bars up top.
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:14.0],
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-72.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new - (void)sciEnsureStoryDownloadButton {
    if (![SCIUtils getBoolPref:@"story_download_button"]) return;

    if ([self.view viewWithTag:SCIStoryDownloadButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIStoryDownloadButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;
    button.tintColor = [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"p_story_dl_title");

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.to.line" withConfiguration:config] forState:UIControlStateNormal];

    [button addTarget:self action:@selector(sciDownloadStory:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    // Bottom-trailing, mirroring the seen button.
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14.0],
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-72.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new - (void)sciSeenReceiptWasSent:(NSNotification *)note {
    UIButton *button = (UIButton *)[self.view viewWithTag:SCIStorySeenButtonTag];
    if (!button) return;

    // Green means the author has been told — not merely that the button was pressed.
    // It is posted from the uploader, so it cannot appear unless a receipt really
    // went out.
    dispatch_async(dispatch_get_main_queue(), ^{
        button.tintColor = [UIColor systemGreenColor];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            button.tintColor = [UIColor whiteColor];
        });
    });
}

%new - (void)sciToggleStorySeen:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    // Let the receipt for the story on screen through, then move on. The flag is
    // global and momentary: it is put back shortly afterwards so the stories that
    // follow stay private, which is the whole point of the setting.
    storySeenOverrideEnabled = YES;

    [SCIUtils showToastForDuration:1.4 title:SCILocalized(@"story_seen_marked_toast")];

    // Given a moment so the receipt for this story is on its way before the view
    // moves on; advancing instantly can cut it off.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id section = SCICurrentStorySection(self);

        if (section) {
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(section, @selector(advanceToNextItemWithNavigationAction:), 0);
            return;
        }

        UIScrollView *pager = SCIStoryPager(self.view, 0);
        if (!pager) return;

        CGFloat page = pager.bounds.size.width;
        CGFloat next = pager.contentOffset.x + page;
        if (page < 1.0 || next > pager.contentSize.width - page + 1.0) return;

        [pager setContentOffset:CGPointMake(next, pager.contentOffset.y) animated:YES];
    });

    // Long enough for the receipt to have been built and sent for this story, short
    // enough that the next one is still covered.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        storySeenOverrideEnabled = NO;
    });
}

%new - (void)sciDownloadStory:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    [SCIMediaDownloader downloadVisibleStoryInView:self.view anchor:sender];
}

%end
