#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Mark a story as seen, on demand.
///
/// `no_seen_receipt` works by returning nil from IGStorySeenStateUploader, so the
/// receipt is never sent — invisible viewing, but no way to opt back in for a
/// specific story.
///
/// This adds a floating eye toggle over the story viewer. While it is on, the
/// uploader is allowed through and the story you are watching registers as seen;
/// turning it off restores invisible viewing. The flag lives here and is read by
/// DisableStorySeen.x, mirroring how `unlimited_replay` already works for DMs.
///

BOOL storySeenOverrideEnabled = NO;

static const NSInteger SCIStorySeenButtonTag = 0x5CE7E;

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

%new - (void)sciToggleStorySeen:(UIButton *)sender {
    storySeenOverrideEnabled = !storySeenOverrideEnabled;

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIUpdateSeenButtonAppearance(sender);

    [SCIUtils showToastForDuration:2.0
                             title:SCILocalized(storySeenOverrideEnabled ? @"story_seen_on_toast"
                                                                        : @"story_seen_off_toast")];
}

%end
