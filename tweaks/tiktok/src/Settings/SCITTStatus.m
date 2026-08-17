#import "SCITTStatus.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCITTDiagnostics.h"
#import "../Features/Download/SCITTMedia.h"
#import "../Features/Download/SCITTDownload.h"

static const NSInteger kSCIRowAds = 0;
static const NSInteger kSCIRowBypass = 1;
static const NSInteger kSCIRowPrivacy = 2;

@interface SCITTStatus ()
@property (nonatomic, strong) UITextView *report;
@property (nonatomic, strong) NSArray<SCITTMediaItem *> *items;
@end

@implementation SCITTStatus

+ (void)present {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) window = candidate;
        }
    }
    if (!window) return;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        if ([top.presentedViewController isKindOfClass:[SCITTStatus class]]) return;
        top = top.presentedViewController;
    }
    if (!top) return;

    SCITTStatus *status = [[SCITTStatus alloc] init];
    status.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:status animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"title");
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    [done setTitle:SCILocalized(@"done") forState:UIControlStateNormal];
    done.tintColor = SCIAccent();
    [done addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[title, done]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.distribution = UIStackViewDistributionEqualSpacing;
    header.alignment = UIStackViewAlignmentCenter;

    UIView *adsRow = [self rowWithLabel:SCILocalized(@"row_ads") key:SCIPrefHideAds tag:kSCIRowAds];
    UIView *bypassRow = [self rowWithLabel:SCILocalized(@"row_bypass") key:SCIPrefBypass tag:kSCIRowBypass];
    UIView *privacyRow = [self rowWithLabel:SCILocalized(@"row_privacy") key:SCIPrefPrivacy tag:kSCIRowPrivacy];

    self.items = [SCITTMedia recent];

    UILabel *mediaTitle = [[UILabel alloc] init];
    mediaTitle.text = SCILocalized(@"media_title");
    mediaTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    mediaTitle.textColor = [UIColor colorWithWhite:1 alpha:0.6];

    UIStackView *mediaStack = [[UIStackView alloc] initWithArrangedSubviews:@[mediaTitle]];
    mediaStack.axis = UILayoutConstraintAxisVertical;
    mediaStack.spacing = 10;

    if (!self.items.count) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = SCILocalized(@"media_empty");
        empty.textColor = [UIColor colorWithWhite:1 alpha:0.4];
        empty.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        empty.numberOfLines = 0;
        [mediaStack addArrangedSubview:empty];
    } else {
        NSInteger index = 0;
        for (SCITTMediaItem *item in self.items) {
            [mediaStack addArrangedSubview:[self mediaRowForItem:item index:index]];
            index++;
        }
    }

    self.report = [[UITextView alloc] init];
    self.report.editable = NO;
    self.report.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    self.report.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    self.report.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.report.layer.cornerRadius = 12;
    self.report.layer.cornerCurve = kCACornerCurveContinuous;
    self.report.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.report.text = [SCITTDiagnostics report];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[header, adsRow, bypassRow, privacyRow, mediaStack, self.report]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.report.heightAnchor constraintGreaterThanOrEqualToConstant:200],
    ]];
}

/// One row: a label and a switch bound to `key`. The switch's tag says which key it
/// is when it fires, so no side table has to be kept in step with the switches
/// themselves.
- (UIView *)rowWithLabel:(NSString *)label key:(NSString *)key tag:(NSInteger)tag {
    UILabel *text = [[UILabel alloc] init];
    text.text = label;
    text.textColor = [UIColor whiteColor];
    text.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = SCIAccent();
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    toggle.tag = tag;
    [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[text, toggle]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)toggled:(UISwitch *)toggle {
    NSString *key = (toggle.tag == kSCIRowAds) ? SCIPrefHideAds
                   : (toggle.tag == kSCIRowBypass) ? SCIPrefBypass
                   : (toggle.tag == kSCIRowPrivacy) ? SCIPrefPrivacy
                   : nil;
    if (!key) return;
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
}

/// One row: when it was seen, and a Save button tagged with its position in `self.items`
/// -- the same array a tap reads back from, so the button never has to hold the item
/// itself.
- (UIView *)mediaRowForItem:(SCITTMediaItem *)item index:(NSInteger)index {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = NSDateFormatterNoStyle;

    UILabel *label = [[UILabel alloc] init];
    label.text = [formatter stringFromDate:item.seen];
    label.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:SCILocalized(@"media_save") forState:UIControlStateNormal];
    save.tintColor = SCIAccent();
    save.tag = index;
    [save addTarget:self action:@selector(saveTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, save]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)saveTapped:(UIButton *)button {
    if (button.tag < 0 || (NSUInteger)button.tag >= self.items.count) return;
    [SCITTDownload save:self.items[button.tag]];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
