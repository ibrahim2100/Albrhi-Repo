#import "SCIDiagnosticsViewController.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"

// Recorded facts. Written from feature code, read on the main thread by the page.
static NSMutableArray<NSString *> *_actionRowClasses = nil;
static NSInteger _lastQualityCount = -1;
static NSString *_lastVideoClass = nil;
static NSInteger _storySeenIntercepts = 0;

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

+ (void)recordStorySeenIntercept {
    _storySeenIntercepts += 1;
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

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(copyReport)];
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

    if (!attached.count) {
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

    return @[
        @{@"header": SCILocalized(@"diag_section_classes"), @"rows": rows},
        @{@"header": SCILocalized(@"diag_section_attached"), @"rows": attached},
        @{@"header": SCILocalized(@"diag_section_quality"), @"rows": @[
            @{@"title": SCILocalized(@"diag_quality_last"), @"detail": qualityDetail, @"ok": @(qualityOK)},
            @{@"title": SCILocalized(@"diag_quality_source"),
              @"detail": _lastVideoClass ?: @"—",
              @"ok": @(_lastVideoClass != nil)},
            @{@"title": SCILocalized(@"show_quality_picker_title"),
              @"detail": [SCIUtils getBoolPref:@"show_quality_picker"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
              @"ok": @([SCIUtils getBoolPref:@"show_quality_picker"])}
        ]},
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
