#import "SCIDiagnosticsViewController.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"
#import "../SCIProject.h"

// Recorded facts. Written from feature code, read on the main thread by the page.
static NSMutableArray<NSString *> *_actionRowClasses = nil;
static NSInteger _lastQualityCount = -1;
static NSString *_lastVideoClass = nil;
static NSInteger _storySeenIntercepts = 0;
static NSString *_seenReplay = nil;
static NSArray<NSString *> *_scanResults = nil;
static NSArray<NSString *> *_timestampResults = nil;
static NSString *_lastButtonMediaClass = nil;
static BOOL _buttonEverPressed = NO;
static NSString *_lastDownloadKind = nil;
static NSString *_lastDashXML = nil;
static NSInteger _lastDashRepresentations = 0;
static NSArray<NSString *> *_lastDashCandidates = nil;
static BOOL _dashProbeRan = NO;
static NSMutableArray<NSString *> *_transcodeStages = nil;

@implementation SCIDiagnostics

+ (void)initialize {
    if (self != [SCIDiagnostics class]) return;

    _actionRowClasses = [NSMutableArray array];
}

+ (void)recordActionRowClass:(NSString *)className controlCount:(NSInteger)controlCount {
    if (![className length]) return;

    NSString *entry = [NSString stringWithFormat:@"%@ (%ld controls)", className, (long)controlCount];

    @synchronized (_actionRowClasses) {
        for (NSString *existing in _actionRowClasses) {
            if ([existing hasPrefix:className]) return;
        }

        [_actionRowClasses addObject:entry];
    }
}

+ (void)recordQualityCount:(NSInteger)count forVideoClass:(NSString *)className {
    _lastQualityCount = count;
    _lastVideoClass = [className copy];
}

+ (void)recordDashManifest:(NSString *)xml candidates:(NSArray<NSString *> *)names {
    _dashProbeRan = YES;
    _lastDashXML = [xml copy];
    _lastDashCandidates = [names copy];

    // Counting <Representation> elements is the number that decides whether this
    // is worth building on: more of them than -videoVersions returned means the
    // renditions the quality picker has been missing are here.
    _lastDashRepresentations = 0;

    if (![xml length]) return;

    NSRange search = NSMakeRange(0, xml.length);
    while (search.length) {
        NSRange hit = [xml rangeOfString:@"<Representation" options:0 range:search];
        if (hit.location == NSNotFound) break;

        _lastDashRepresentations++;
        NSUInteger next = hit.location + hit.length;
        search = NSMakeRange(next, xml.length - next);
    }
}

+ (void)recordButtonMediaClass:(NSString *)className {
    _buttonEverPressed = YES;
    _lastButtonMediaClass = [className copy];
}

+ (void)recordTranscodeStage:(NSString *)name ok:(BOOL)ok detail:(NSString *)detail {
    @synchronized (self) {
        // The first stage of a run starts a clean list.
        if (!_transcodeStages || [name isEqualToString:@"download-video"]) {
            _transcodeStages = [NSMutableArray array];
        }
        NSString *line = [NSString stringWithFormat:@"%@ %@%@",
                          ok ? @"✓" : @"✗", name,
                          detail.length ? [@" — " stringByAppendingString:detail] : @""];
        [_transcodeStages addObject:line];
    }
}

+ (void)recordDownloadKind:(NSString *)kind {
    _lastDownloadKind = [kind copy];
}

+ (void)recordSeenReplayBegan:(BOOL)began ended:(BOOL)ended {
    _seenReplay = [NSString stringWithFormat:@"begin=%@  end=%@",
                   began ? @"sent" : @"failed", ended ? @"sent" : @"failed"];
}

+ (void)recordStorySeenIntercept {
    _storySeenIntercepts += 1;
}

// MARK: - Live hierarchy scan

+ (void)collectCandidatesIn:(UIView *)view into:(NSMutableArray<NSString *> *)out depth:(NSInteger)depth {
    if (!view || depth > 40) return;

    NSInteger controlCount = 0;
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];

    for (UIView *subview in view.subviews) {
        if (![subview isKindOfClass:[UIControl class]]) continue;
        if (subview.hidden || CGRectIsEmpty(subview.frame)) continue;

        controlCount++;

        if ([subview.accessibilityIdentifier length]) {
            [identifiers addObject:subview.accessibilityIdentifier];
        }
    }

    // A post action row is a short, wide strip holding three or more buttons.
    BOOL looksLikeRow = (controlCount >= 3)
        && (CGRectGetHeight(view.bounds) < 120.0)
        && (CGRectGetWidth(view.bounds) > 180.0);

    // Or anything explicitly labelled with the buttons we care about.
    BOOL hasTellingIdentifier = NO;
    for (NSString *identifier in identifiers) {
        NSString *lower = identifier.lowercaseString;

        if ([lower containsString:@"like"] || [lower containsString:@"save"] || [lower containsString:@"comment"]) {
            hasTellingIdentifier = YES;
            break;
        }
    }

    if (looksLikeRow || hasTellingIdentifier) {
        NSString *entry = [NSString stringWithFormat:@"%@ — %ld controls%@",
                           NSStringFromClass([view class]),
                           (long)controlCount,
                           identifiers.count ? [NSString stringWithFormat:@" [%@]", [identifiers componentsJoinedByString:@", "]] : @""];

        if (![out containsObject:entry]) [out addObject:entry];
    }

    for (UIView *subview in view.subviews) {
        [self collectCandidatesIn:subview into:out depth:depth + 1];
    }
}

/// Does this text read like a timestamp Instagram would render?
/// Matches the compact relative forms ("2h", "5 d", "3w"), the worded ones, and
/// month-name dates. Deliberately loose — a false positive costs one noisy line
/// in a report, a false negative costs a whole round of guessing.
+ (BOOL)looksLikeTimestamp:(NSString *)text {
    if (text.length == 0 || text.length > 40) return NO;

    static NSRegularExpression *pattern = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pattern = [NSRegularExpression regularExpressionWithPattern:
                   @"^\\s*\\d+\\s*(s|m|h|d|w|y|mo)\\s*$"
                   @"|ago|منذ|قبل"
                   @"|^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
    });

    return [pattern firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] != nil;
}

+ (void)collectTimestampsIn:(UIView *)view into:(NSMutableArray<NSString *> *)out depth:(NSInteger)depth {
    if (!view || depth > 14 || out.count >= 12) return;

    if ([view isKindOfClass:[UILabel class]]) {
        NSString *text = [(UILabel *)view text];
        if ([self looksLikeTimestamp:text]) {
            // The label's own class is rarely the hook target; the view that owns
            // it usually is, so both are reported.
            NSString *entry = [NSString stringWithFormat:@"\"%@\" — %@ in %@",
                               text,
                               NSStringFromClass([view class]),
                               view.superview ? NSStringFromClass([view.superview class]) : @"—"];
            if (![out containsObject:entry]) [out addObject:entry];
        }
    }

    for (UIView *child in view.subviews) {
        [self collectTimestampsIn:child into:out depth:depth + 1];
    }
}

+ (NSArray<NSString *> *)scanForTimestampLabels {
    NSMutableArray<NSString *> *out = [NSMutableArray array];

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        // Behind the settings sheet is the feed, which is what we want to read.
        if (window.rootViewController.presentedViewController) {
            [self collectTimestampsIn:window.rootViewController.view into:out depth:0];
        } else {
            [self collectTimestampsIn:window into:out depth:0];
        }
    }

    return out;
}

+ (NSArray<NSString *> *)scanForActionRowCandidates {
    NSMutableArray<NSString *> *out = [NSMutableArray array];

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        // Skip the settings sheet itself — it is full of controls and would drown
        // the result in noise.
        if (window.rootViewController.presentedViewController) {
            [self collectCandidatesIn:window.rootViewController.view into:out depth:0];
        } else {
            [self collectCandidatesIn:window into:out depth:0];
        }
    }

    return out;
}

@end

@implementation SCIDiagnosticsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"diag_title");
    self.view.tintColor = [SCIUtils SCIColor_Primary];

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(copyReport)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(runScan)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.bubble"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(reportIssue)]
    ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.tableView reloadData];
}

// MARK: - Report model

/// Classes the inline download button tries to attach to.
- (NSArray<NSString *> *)actionRowCandidates {
    return @[@"IGUFIButtonBarView", @"IGSocialUFIView.IGSocialUFIView", @"IGSocialUFIView.IGSocialUFIButtonView"];
}

- (NSArray<NSDictionary *> *)sections {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    // Which action-row classes exist in this build at all.
    for (NSString *name in [self actionRowCandidates]) {
        BOOL exists = (NSClassFromString(name) != nil);

        [rows addObject:@{
            @"title": name,
            @"detail": exists ? SCILocalized(@"diag_class_present") : SCILocalized(@"diag_class_absent"),
            @"ok": @(exists)
        }];
    }

    NSMutableArray<NSDictionary *> *attached = [NSMutableArray array];

    @synchronized (_actionRowClasses) {
        for (NSString *entry in _actionRowClasses) {
            [attached addObject:@{@"title": entry, @"detail": SCILocalized(@"diag_attached"), @"ok": @YES}];
        }
    }

    [attached addObject:@{
        @"title": SCILocalized(@"diag_button_media"),
        @"detail": !_buttonEverPressed ? SCILocalized(@"diag_button_unpressed")
                                       : (_lastButtonMediaClass ?: SCILocalized(@"diag_button_nomedia")),
        @"ok": @(_lastButtonMediaClass != nil)
    }];

    if (attached.count == 1) {
        [attached addObject:@{
            @"title": SCILocalized(@"diag_none_attached"),
            @"detail": SCILocalized(@"diag_none_attached_hint"),
            @"ok": @NO
        }];
    }

    NSString *qualityDetail;
    BOOL qualityOK = NO;

    if (_lastQualityCount < 0) {
        qualityDetail = SCILocalized(@"diag_quality_never");
    }
    else if (_lastQualityCount <= 1) {
        qualityDetail = [NSString stringWithFormat:SCILocalized(@"diag_quality_single"), (long)_lastQualityCount];
    }
    else {
        qualityDetail = [NSString stringWithFormat:SCILocalized(@"diag_quality_multi"), (long)_lastQualityCount];
        qualityOK = YES;
    }

    [rows addObject:@{
        @"title": SCILocalized(@"inline_download_title"),
        @"detail": [SCIUtils getBoolPref:@"inline_download_button"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
        @"ok": @([SCIUtils getBoolPref:@"inline_download_button"])
    }];

    return @[
        @{@"header": SCILocalized(@"diag_section_classes"), @"rows": rows},
        @{@"header": SCILocalized(@"diag_section_attached"), @"rows": attached},
        @{@"header": SCILocalized(@"diag_section_quality"), @"rows": @[
            @{@"title": SCILocalized(@"diag_quality_last"), @"detail": qualityDetail, @"ok": @(qualityOK)},
            @{@"title": SCILocalized(@"dw_save_to_camera_title"),
              @"detail": [SCIUtils getBoolPref:@"dw_save_to_camera"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
              @"ok": @([SCIUtils getBoolPref:@"dw_save_to_camera"])},
            @{@"title": SCILocalized(@"diag_download_kind"),
              @"detail": _lastDownloadKind ?: @"—",
              @"ok": @(_lastDownloadKind != nil)},
            @{@"title": SCILocalized(@"diag_quality_source"),
              @"detail": _lastVideoClass ?: @"—",
              @"ok": @(_lastVideoClass != nil)}
        ]},
        @{@"header": SCILocalized(@"diag_section_dash"), @"rows": [self dashRows]},
        @{@"header": SCILocalized(@"diag_section_transcode"), @"rows": [self transcodeRows]},
        @{@"header": SCILocalized(@"diag_section_scan"), @"rows": [self scanRows]},
        @{@"header": SCILocalized(@"diag_section_timestamps"), @"rows": [self timestampRows]},
        @{@"header": SCILocalized(@"diag_section_stories"), @"rows": @[
            @{@"title": SCILocalized(@"diag_seen_replay"),
              @"detail": _seenReplay ?: @"—",
              @"ok": @(_seenReplay != nil)},
            @{@"title": SCILocalized(@"diag_story_intercepts"),
              @"detail": [NSString stringWithFormat:@"%ld", (long)_storySeenIntercepts],
              @"ok": @(_storySeenIntercepts > 0)}
        ]},
        @{@"header": SCILocalized(@"diag_section_env"), @"rows": @[
            @{@"title": @"Albrhi", @"detail": SCIVersionString, @"ok": @YES},
            @{@"title": @"Instagram", @"detail": [SCIUtils IGVersionString], @"ok": @YES},
            @{@"title": @"iOS", @"detail": [[UIDevice currentDevice] systemVersion], @"ok": @YES}
        ]}
    ];
}

- (NSArray<NSDictionary *> *)dashRows {
    if (!_dashProbeRan) {
        return @[@{@"title": SCILocalized(@"diag_dash_none"),
                   @"detail": SCILocalized(@"diag_dash_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    // Distinct from "never ran": the probe reached these objects and they had
    // nothing. Which candidates the runtime offered decides what happens next.
    if (!_lastDashXML) {
        [rows addObject:@{@"title": SCILocalized(@"diag_dash_empty"),
                          @"detail": SCILocalized(@"diag_dash_empty_hint"),
                          @"ok": @NO}];
    }

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_candidates"),
                      @"detail": _lastDashCandidates.count
                          ? [_lastDashCandidates componentsJoinedByString:@", "]
                          : SCILocalized(@"diag_dash_no_candidates"),
                      @"ok": @(_lastDashCandidates.count > 0)}];

    if (!_lastDashXML) return rows;

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_found"),
                      @"detail": [NSString stringWithFormat:@"%lu B", (unsigned long)_lastDashXML.length],
                      @"ok": @YES}];

    // Set against the quality count above, this is the whole question: a larger
    // number here is the ladder -videoVersions has been hiding.
    [rows addObject:@{@"title": SCILocalized(@"diag_dash_reps"),
                      @"detail": [NSString stringWithFormat:@"%ld", (long)_lastDashRepresentations],
                      @"ok": @(_lastDashRepresentations > 0)}];

    // The ladder tagged by codec is what decides which phase applies: an H.264 or
    // HEVC video rep higher than 720p is a free win phase one already takes; an
    // AV1-only ladder is what phase two's transcoder exists for.
    NSInteger saveable = 0;
    for (NSDictionary *rep in [SCIUtils dashRepresentationsFromXML:_lastDashXML]) {
        if (![rep[@"type"] isEqualToString:@"video"]) continue;

        NSString *family = rep[@"family"];
        BOOL ok = [family isEqualToString:@"h264"] || [family isEqualToString:@"hevc"];
        if (ok) saveable++;

        [rows addObject:@{
            @"title": [NSString stringWithFormat:@"%@×%@",
                       rep[@"width"], rep[@"height"]],
            @"detail": [NSString stringWithFormat:@"%@ · %.1f Mbps%@",
                        [family length] ? family : rep[@"codecs"],
                        [rep[@"bandwidth"] doubleValue] / 1000000.0,
                        ok ? @"" : SCILocalized(@"diag_dash_needs_transcode")],
            @"ok": @(ok)
        }];
    }

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_saveable"),
                      @"detail": [NSString stringWithFormat:@"%ld", (long)saveable],
                      @"ok": @(saveable > 0)}];

    // Enough of the XML to confirm on screen that it is a real manifest. The
    // full text goes into the copied report instead: these cells self-size, and
    // a manifest pasted whole would push everything below it off the page.
    NSUInteger excerptLength = MIN((NSUInteger)180, _lastDashXML.length);
    NSString *excerpt = [_lastDashXML substringToIndex:excerptLength];

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_excerpt"),
                      @"detail": excerpt,
                      @"ok": @YES}];

    return rows;
}

- (NSArray<NSDictionary *> *)transcodeRows {
    @synchronized ([SCIDiagnostics class]) {
        if (!_transcodeStages.count) {
            return @[@{@"title": SCILocalized(@"diag_transcode_none"),
                       @"detail": SCILocalized(@"diag_transcode_hint"),
                       @"ok": @NO}];
        }

        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
        for (NSString *line in _transcodeStages) {
            [rows addObject:@{@"title": line,
                              @"detail": @"",
                              @"ok": @([line hasPrefix:@"✓"])}];
        }
        return rows;
    }
}

- (NSArray<NSDictionary *> *)scanRows {
    if (!_scanResults) {
        return @[@{@"title": SCILocalized(@"diag_scan_prompt"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }

    if (!_scanResults.count) {
        return @[@{@"title": SCILocalized(@"diag_scan_empty"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (NSString *entry in _scanResults) {
        [rows addObject:@{@"title": entry, @"detail": @"", @"ok": @YES}];
    }

    return rows;
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self sections].count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self sections][section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self sections][section][@"header"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    NSDictionary *row = [self sections][indexPath.section][@"rows"][indexPath.row];

    UIListContentConfiguration *config = [UIListContentConfiguration subtitleCellConfiguration];
    config.text = row[@"title"];
    config.secondaryText = row[@"detail"];
    config.textProperties.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    config.secondaryTextProperties.color = [UIColor secondaryLabelColor];

    BOOL ok = [row[@"ok"] boolValue];
    config.image = [UIImage systemImageNamed:ok ? @"checkmark.circle.fill" : @"exclamationmark.circle.fill"];
    config.imageProperties.tintColor = ok ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];

    cell.contentConfiguration = config;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

- (void)runScan {
    _scanResults = [SCIDiagnostics scanForActionRowCandidates];
    _timestampResults = [SCIDiagnostics scanForTimestampLabels];

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self.tableView reloadData];
}

- (NSArray<NSDictionary *> *)timestampRows {
    if (!_timestampResults) {
        return @[@{@"title": SCILocalized(@"diag_ts_prompt"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }
    if (!_timestampResults.count) {
        return @[@{@"title": SCILocalized(@"diag_ts_empty"),
                   @"detail": SCILocalized(@"diag_ts_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (NSString *entry in _timestampResults) {
        [rows addObject:@{@"title": entry, @"detail": @"", @"ok": @YES}];
    }
    return rows;
}

// MARK: - Report

/// The diagnostics report as plain text. Shared by the copy button and the issue
/// reporter, so a filed bug always carries exactly what the page shows.
- (NSString *)reportText {
    NSMutableString *report = [NSMutableString stringWithFormat:@"Albrhi %@ diagnostics\n", SCIVersionString];

    for (NSDictionary *section in [self sections]) {
        [report appendFormat:@"\n[%@]\n", section[@"header"]];

        for (NSDictionary *row in section[@"rows"]) {
            [report appendFormat:@"  %@: %@\n", row[@"title"], row[@"detail"]];
        }
    }

    // Verbatim, and last so it never buries the rest. The point of capturing a
    // manifest is to read its real attribute names; an excerpt cannot show the
    // full rendition ladder, which is the number that decides whether parsing
    // DASH gains anything over -videoVersions.
    if (_lastDashXML.length) {
        [report appendFormat:@"\n[DASH manifest — verbatim]\n%@\n", _lastDashXML];
    }

    return [report copy];
}

- (void)copyReport {
    [UIPasteboard generalPasteboard].string = [self reportText];

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [SCIUtils showToastForDuration:1.6 title:SCILocalized(@"diag_copied")];
}

/// Opens a new GitHub issue with the report already filled in.
///
/// A tester who hits a problem otherwise has nowhere to go, and "it doesn't work"
/// costs a round trip to turn into something actionable. This makes the useful
/// version of the report the path of least resistance.
- (void)reportIssue {
    // Built line by line rather than as one format string: the report is fenced as a
    // code block so GitHub renders it verbatim.
    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"%@\n\n", SCILocalized(@"diag_issue_what")];
    [body appendFormat:@"%@\n\n", SCILocalized(@"diag_issue_steps")];
    [body appendFormat:@"```\n%@\n```\n", [self reportText]];

    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *encodedBody = [body stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSString *encodedTitle = [[NSString stringWithFormat:@"[%@] ", SCIVersionString]
                              stringByAddingPercentEncodingWithAllowedCharacters:allowed];

    NSString *urlString = [NSString stringWithFormat:@"%@?title=%@&body=%@",
                           SCIIssuesURL, encodedTitle, encodedBody];

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    // The report is also on the clipboard, in case the browser truncates the URL.
    [UIPasteboard generalPasteboard].string = [self reportText];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
