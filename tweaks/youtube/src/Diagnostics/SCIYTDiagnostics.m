#import "SCIYTDiagnostics.h"
#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import <objc/runtime.h>

///
/// The classes worth reporting on, and why each one is here.
///
/// A name alone is not enough: a report saying "YTSettingsSectionItem: found" tells
/// nobody anything unless it also says what depends on it. So each row carries the
/// question it answers.
///
static NSArray<NSDictionary *> *SCIAuditTable(void) {
    return @[
        @{@"class": @"YTSettingsSectionItem",         @"why": @"builds our settings rows"},
        @{@"class": @"YTSettingsViewController",      @"why": @"shows our settings section"},
        @{@"class": @"YTSettingsSectionItemManager",  @"why": @"answers for our category"},
        @{@"class": @"YTAppSettingsPresentationData", @"why": @"lists our category"},

        @{@"class": @"YTPlayerOverlayWrapper",        @"why": @"hands us the player response"},
        @{@"class": @"MLVideo",                       @"why": @"carries the streams in use"},
        @{@"class": @"YTIPlayerResponse",            @"why": @"the response itself"},
        @{@"class": @"YTIStreamingData",             @"why": @"the stream list inside it"},

        // The two paths a download could take. Which of these is real decides
        // whether downloading is a week of work or a month, so the report says
        // plainly which one is present rather than leaving it to be assumed.
        @{@"class": @"YTOfflineVideoStreamsDownloadController",
          @"why": @"YouTube's own downloader — the path worth riding"},
        @{@"class": @"MLOnesieUMPController",
          @"why": @"the piecewise stream protocol — the path that needs a client"},
        @{@"class": @"MLServerABROnesieDataLoader",
          @"why": @"server-driven bitrate: no plain file URLs"},
    ];
}

@implementation SCIYTDiagnostics

// Held strongly, and exactly one of each.
//
// Weak was the first attempt and it was wrong: the response is released as soon as
// playback moves on, so by the time anyone walks over to Settings the page had
// nothing left to show — which is the one thing it exists to do. One protobuf
// message and one stream list is a bounded, deliberate cost, and each new video
// replaces them rather than adding to them.
//
// The video object itself is not kept: what the report needs from it is its ID and
// its streams, and holding the whole player-layer object to reach two fields would
// pin far more than this page is worth.
static id sciLastResponse = nil;
static id sciLastStreamingData = nil;
static NSString *sciLastVideoID = nil;

+ (void)recordPlayerResponse:(id)response {
    if (!response) return;
    sciLastResponse = response;
    SCILogV(@"captured player response %@", [response class]);
}

+ (void)recordVideo:(id)video {
    if (!video) return;

    if ([video respondsToSelector:@selector(ID)]) {
        NSString *identifier = ((MLVideo *)video).ID;
        if ([identifier isKindOfClass:[NSString class]]) {
            sciLastVideoID = [identifier copy];
        }
    }

    if ([video respondsToSelector:@selector(streamingData)]) {
        sciLastStreamingData = [(MLVideo *)video streamingData];
    }

    SCILogV(@"captured video %@ (streams: %@)", sciLastVideoID,
            sciLastStreamingData ? @"yes" : @"no");
}

+ (NSString *)appVersion {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length ? version : @"unknown";
}

/// A protobuf message prints its whole tree from -description, which is the entire
/// reason this page can report the truth without a single hard-coded field name.
/// Guarded all the same: an object that is not what we expect must produce a line in
/// the report, not a crash inside a diagnostic.
+ (NSString *)describeMessage:(id)message {
    if (!message) return nil;

    @try {
        NSString *text = [message description];
        return text.length ? text : nil;
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"<%@ could not be described: %@>",
                NSStringFromClass([message class]), exception.reason];
    }
}

+ (NSString *)report {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_build")];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_tweak_version"), SCIVersionString];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_app_version"), [self appVersion]];
    [out appendFormat:@"  %@: %@\n\n", SCILocalized(@"diag_bundle"),
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_attached")];
    for (NSDictionary *row in SCIAuditTable()) {
        NSString *name = row[@"class"];
        BOOL present = objc_getClass([name UTF8String]) != NULL;
        [out appendFormat:@"  [%@] %@ — %@\n",
            present ? SCILocalized(@"diag_present") : SCILocalized(@"diag_absent"),
            name, row[@"why"]];
    }
    [out appendString:@"\n"];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_video")];

    if (!sciLastResponse && !sciLastStreamingData && !sciLastVideoID) {
        [out appendFormat:@"  %@\n", SCILocalized(@"diag_no_video")];
        return out;
    }

    if (sciLastVideoID.length) {
        [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_video_id"), sciLastVideoID];
    }

    NSString *streams = [self describeMessage:sciLastStreamingData];
    if (streams) {
        [out appendFormat:@"\n%@\n%@\n", SCILocalized(@"diag_streams"), streams];
    }

    NSString *full = [self describeMessage:sciLastResponse];
    if (full) {
        [out appendFormat:@"\n%@\n%@\n%@\n",
            SCILocalized(@"diag_response"), SCILocalized(@"diag_response_note"), full];
    }

    return out;
}

+ (UIViewController *)viewController {
    UIViewController *host = [[UIViewController alloc] init];
    host.title = SCILocalized(@"diag_title");
    host.view.backgroundColor = UIColor.systemBackgroundColor;

    // A text view rather than a table: the report is one long body of text whose
    // value is that it can be copied whole, and a table would invite splitting it
    // into rows that each lose the context of the one above.
    UITextView *text = [[UITextView alloc] init];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.backgroundColor = UIColor.clearColor;
    text.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    text.text = [SCIYTDiagnostics report];
    text.textContainerInset = UIEdgeInsetsMake(16, 14, 16, 14);
    [host.view addSubview:text];

    // The button reports back in its own title. A HUD would be another dependency
    // for one line of feedback, and the title is where the user is already looking.
    //
    // UIAction rather than a target/action pair: there is no object here that
    // outlives the page to act as a target, and inventing one to hold a selector is
    // more moving parts than the job needs.
    // Weak inside the handler: the button owns its primaryAction, so a strong
    // capture here would be a button retaining a block retaining the button.
    __block __weak UIButton *copy = nil;
    UIAction *action = [UIAction actionWithTitle:SCILocalized(@"diag_copy")
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction *sender) {
        UIPasteboard.generalPasteboard.string = [SCIYTDiagnostics report];
        [copy setTitle:SCILocalized(@"diag_copied") forState:UIControlStateNormal];
    }];

    copy = [UIButton buttonWithType:UIButtonTypeSystem primaryAction:action];
    copy.translatesAutoresizingMaskIntoConstraints = NO;
    copy.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    copy.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.14];
    copy.layer.cornerRadius = 14;
    copy.layer.cornerCurve = kCACornerCurveContinuous;
    [host.view addSubview:copy];

    UILayoutGuide *safe = host.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [text.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [text.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [text.bottomAnchor constraintEqualToAnchor:copy.topAnchor constant:-12],

        [copy.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [copy.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [copy.heightAnchor constraintEqualToConstant:48],
        [copy.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];

    return host;
}

@end
