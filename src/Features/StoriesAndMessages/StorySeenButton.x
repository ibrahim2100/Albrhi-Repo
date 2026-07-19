#import "../../InstagramHeaders.h"
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
    NSString *glyph = storySeenOverrideEnabled ? @"eye.fill" : @"eye.slash.fill";

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];

    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];

    button.tintColor = storySeenOverrideEnabled ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(storySeenOverrideEnabled ? @"story_seen_on" : @"story_seen_off");
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

%new - (void)sciToggleStorySeen:(UIButton *)sender {
    storySeenOverrideEnabled = !storySeenOverrideEnabled;

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIUpdateSeenButtonAppearance(sender);

    [SCIUtils showToastForDuration:2.0
                             title:SCILocalized(storySeenOverrideEnabled ? @"story_seen_on_toast"
                                                                        : @"story_seen_off_toast")];
}

%new - (void)sciDownloadStory:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    [SCIMediaDownloader downloadVisibleStoryInView:self.view anchor:sender];
}

%end
