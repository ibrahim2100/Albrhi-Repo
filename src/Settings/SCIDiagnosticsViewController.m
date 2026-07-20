#import "SCIDiagnosticsViewController.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"

// Recorded facts. Written from feature code, read on the main thread by the page.
static NSMutableArray<NSString *> *_actionRowClasses = nil;
static NSInteger _lastQualityCount = -1;
static NSString *_lastVideoClass = nil;
static NSInteger _storySeenIntercepts = 0;
static NSArray<NSString *> *_scanResults = nil;
static NSInteger _lastRawVersionCount = -1;
static NSString *_lastButtonMediaClass = nil;
static BOOL _buttonEverPressed = NO;
static NSString *_lastDownloadKind = nil;
static NSString *_qualityBreakdown = nil;
static NSString *_qualityLabels = nil;
static NSString *_dashInfo = nil;
static NSString *_lastPickedURL = nil;

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

+ (void)recordRawVersionCount:(NSInteger)count {
    _lastRawVersionCount = count;
}

+ (void)recordButtonMediaClass:(NSString *)className {
    _buttonEverPressed = YES;
    _lastButtonMediaClass = [className copy];
}

+ (void)recordDownloadKind:(NSString *)kind {
    _lastDownloadKind = [kind copy];
}

+ (void)recordQualityBreakdownRaw:(NSInteger)raw
                           parsed:(NSInteger)parsed
                          deduped:(NSInteger)deduped
                           labels:(NSString *)labels {
    _qualityBreakdown = [NSString stringWithFormat:@"%ld raw → %ld parsed → %ld deduped",
                         (long)raw, (long)parsed, (long)deduped];
    _qualityLabels = [labels copy];
}

+ (void)recordStorySeenIntercept {
    _storySeenIntercepts += 1;
}

+ (void)recordDashResult:(NSString *)info {
    _dashInfo = [info copy];
}

+ (void)recordPickedURL:(NSString *)url {
    _lastPickedURL = [url copy];
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
                                        action:@selector(runScan)]
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
            @{@"title": SCILocalized(@"diag_quality_raw"),
              @"detail": _lastRawVersionCount < 0 ? @"—" : [NSString stringWithFormat:@"%ld", (long)_lastRawVersionCount],
              @"ok": @(_lastRawVersionCount > 1)},
            @{@"title": SCILocalized(@"dw_save_to_camera_title"),
              @"detail": [SCIUtils getBoolPref:@"dw_save_to_camera"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
              @"ok": @([SCIUtils getBoolPref:@"dw_save_to_camera"])},
            @{@"title": SCILocalized(@"diag_quality_stages"),
              @"detail": _qualityBreakdown ?: @"—",
              @"ok": @(_qualityBreakdown != nil)},
            @{@"title": SCILocalized(@"diag_quality_labels"),
              @"detail": _qualityLabels ?: @"—",
              @"ok": @(_qualityLabels != nil)},
            @{@"title": SCILocalized(@"diag_dash"),
              @"detail": _dashInfo ?: @"—",
              @"ok": @(_dashInfo != nil)},
            @{@"title": SCILocalized(@"diag_picked_url"),
              @"detail": _lastPickedURL ?: @"—",
              @"ok": @(_lastPickedURL != nil)},
            @{@"title": SCILocalized(@"diag_download_kind"),
              @"detail": _lastDownloadKind ?: @"—",
              @"ok": @(_lastDownloadKind != nil)},
            @{@"title": SCILocalized(@"diag_quality_source"),
              @"detail": _lastVideoClass ?: @"—",
              @"ok": @(_lastVideoClass != nil)},
            @{@"title": SCILocalized(@"show_quality_picker_title"),
              @"detail": [SCIUtils getBoolPref:@"show_quality_picker"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
              @"ok": @([SCIUtils getBoolPref:@"show_quality_picker"])}
        ]},
        @{@"header": SCILocalized(@"diag_section_scan"), @"rows": [self scanRows]},
        @{@"header": SCILocalized(@"diag_section_stories"), @"rows": @[
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

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self.tableView reloadData];
}

// MARK: - Report

- (void)copyReport {
    NSMutableString *report = [NSMutableString stringWithFormat:@"Albrhi %@ diagnostics\n", SCIVersionString];

    for (NSDictionary *section in [self sections]) {
        [report appendFormat:@"\n[%@]\n", section[@"header"]];

        for (NSDictionary *row in section[@"rows"]) {
            [report appendFormat:@"  %@: %@\n", row[@"title"], row[@"detail"]];
        }
    }

    [UIPasteboard generalPasteboard].string = report;

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [SCIUtils showToastForDuration:1.6 title:SCILocalized(@"diag_copied")];
}

@end
