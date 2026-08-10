#import "SCILKStatus.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Features/Bypass/SCILKShield.h"

static const NSInteger SCILKSectionStatus = 0;
static const NSInteger SCILKSectionKinds  = 1;
static const NSInteger SCILKSectionRecent = 2;

@interface SCILKStatus ()
@property (nonatomic, strong) NSArray<NSString *> *kindOrder;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *byKind;
@property (nonatomic, strong) NSArray<NSString *> *recent;
@property (nonatomic, strong) NSTimer *refresh;
@end

@implementation SCILKStatus

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
        if ([top.presentedViewController isKindOfClass:[UINavigationController class]] &&
            [[(UINavigationController *)top.presentedViewController topViewController]
                isKindOfClass:[SCILKStatus class]]) {
            return;
        }
        top = top.presentedViewController;
    }
    if (!top) return;

    SCILKStatus *status = [[SCILKStatus alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host =
        [[UINavigationController alloc] initWithRootViewController:status];
    [top presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"title");
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(dismissSelf)];

    // A fixed order for the kinds, so the rows do not reshuffle each refresh as one counter
    // overtakes another — a list that reorders while you read it is a list you cannot read.
    self.kindOrder = @[@"file", @"scheme", @"env", @"onesignal"];

    [self reload];

    // The checks fire after launch and again in the background, so the count is a moving
    // number. A slow timer keeps the open screen honest without the battery cost of a fast
    // one; two seconds is below noticing and above waste.
    self.refresh = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                    repeats:YES
                                                      block:^(NSTimer *timer) {
        [self reload];
    }];
}

- (void)dealloc {
    [self.refresh invalidate];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reload {
    self.byKind = SCILKInterceptsByKind();
    self.recent = SCILKRecentIntercepts();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SCILKSectionStatus) return 3;
    if (section == SCILKSectionKinds) return self.kindOrder.count;
    return self.recent.count ?: 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == SCILKSectionStatus) return SCILocalized(@"section_status");
    if (section == SCILKSectionKinds) return SCILocalized(@"section_kinds");
    return SCILocalized(@"section_recent");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SCILKSectionKinds) return SCILocalized(@"kinds_footer");
    if (section == SCILKSectionStatus) return SCILocalized(@"about_note");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == SCILKSectionStatus) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = SCILocalized(@"status_gate");
                cell.detailTextLabel.text = SCIPanelAllowsThisApp()
                    ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off");
                cell.detailTextLabel.numberOfLines = 0;
                break;
            case 1:
                cell.textLabel.text = SCILocalized(@"status_bypass");
                cell.detailTextLabel.text =
                    [[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefBypass]
                        ? SCILocalized(@"bypass_on") : SCILocalized(@"bypass_off");
                break;
            default:
                cell.textLabel.text = SCILocalized(@"status_total");
                cell.detailTextLabel.text =
                    [NSString stringWithFormat:@"%lu", (unsigned long)SCILKInterceptCount()];
                break;
        }
        return cell;
    }

    if (indexPath.section == SCILKSectionKinds) {
        NSString *kind = self.kindOrder[indexPath.row];
        cell.textLabel.text = SCILocalized([@"kind_" stringByAppendingString:kind]);
        cell.detailTextLabel.text =
            [NSString stringWithFormat:@"%lu", (unsigned long)self.byKind[kind].unsignedIntegerValue];
        return cell;
    }

    // Named rather than left as the fall-through. The section constant is the third and
    // last, and referring to it here is both clearer and the difference between a build
    // and a -Werror stop on an unused constant.
    if (indexPath.section == SCILKSectionRecent) {
        if (!self.recent.count) {
            cell.textLabel.text = SCILocalized(@"kinds_empty");
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
            return cell;
        }

        cell.textLabel.text = self.recent[indexPath.row];
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
    }
    return cell;
}

@end
