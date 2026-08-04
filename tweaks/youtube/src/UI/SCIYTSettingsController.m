#import "SCIYTSettingsController.h"
#import "../Settings/SCIYTSettingsRegistry.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"
#import "../Features/Download/SCIYTDownload.h"
#import "../Features/Download/Center/SCIYTDownloadCenter.h"
#import <objc/runtime.h>

/// YouTube's red. Written out rather than read from YTCommonColorPalette: one colour is
/// not worth a dependency on a class whose shape has not been verified, and unverified
/// dependencies are what the last three releases were about.

@interface SCIYTSettingsController ()
@property (nonatomic, strong) NSArray<SCISection *> *sections;
@end

@implementation SCIYTSettingsController

- (instancetype)init {
    // Inset-grouped: the same shape as the settings panel on this repository's
    // Instagram side, so the two tweaks read as one project.
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"panel_title");
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.tableView.tableHeaderView = [self identityHeader];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(close)];

    [self buildSections];
}

- (void)buildSections {
    // Composed rather than built. Every section lives in its own file under Settings/Pages
    // and registers itself in +load; nothing here knows what those are, which is the point.
    // Adding a feature means adding a file, and deleting one means deleting a file.
    self.sections = [SCIYTSettingsRegistry composedSectionsFor:self];
}

/// Rebuilt and redrawn. Called by a page whose row shows a value it has just changed.
- (void)reloadSettings {
    [self buildSections];
    [self.tableView reloadData];
}

///
/// The identity card, and it reports its own health.
///
/// The badge reads the runtime, not a constant: if the classes the features hook are
/// not there, it says so here, at the top, before anything else is read. Every earlier
/// version put that answer somewhere the user had to go looking for -- and in 0.1.0 it
/// was behind the very thing that had failed.
///
- (UIView *)identityHeader {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 108)];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, 12, 0, 84)];
    card.backgroundColor = [SCIAccent() colorWithAlphaComponent:0.10];
    card.layer.borderColor = [SCIAccent() colorWithAlphaComponent:0.28].CGColor;
    card.layer.borderWidth = 0.5;
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    // Sized by the autoresizing mask rather than by constraints. A table header is laid
    // out by the table, which sets its width and asks nothing else of it, so a mask is
    // both sufficient and impossible to over-constrain.
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [host addSubview:card];

    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(14, 20, 44, 44)];
    badge.backgroundColor = SCIAccent();
    badge.layer.cornerRadius = 13;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:badge];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(11, 11, 22, 22)];
    icon.image = [UIImage systemImageNamed:@"play.rectangle.fill"];
    icon.tintColor = UIColor.whiteColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:icon];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(70, 22, 200, 20)];
    name.text = SCILocalized(@"panel_title");
    name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    name.textColor = UIColor.whiteColor;
    [card addSubview:name];

    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(70, 42, 220, 18)];
    version.text = [NSString stringWithFormat:@"%@ · %@ %@",
        SCIVersionString, SCILocalized(@"diag_app_version"), [SCIYTDiagnostics appVersion]];
    version.font = [UIFont systemFontOfSize:12];
    version.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.6];
    [card addSubview:version];

    BOOL healthy = [SCIYTDiagnostics featuresAttached];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(70, 60, 220, 16)];
    status.text = healthy ? SCILocalized(@"identity_attached") : SCILocalized(@"identity_partial");
    status.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    status.textColor = healthy ? [UIColor colorWithRed:0.36 green:0.79 blue:0.65 alpha:1.0]
                              : [UIColor colorWithRed:0.94 green:0.62 blue:0.15 alpha:1.0];
    [card addSubview:status];

    return host;
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].title;
}

/// Under the last section, so how to get back here is written down somewhere the user
/// will actually be when they wonder. A two-finger long press is safe and reliable and
/// completely undiscoverable, which is the trade it makes.
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    // Carried on the section rather than worked out here. Matching on a row count was
    // the first version of this and it is the kind of thing that breaks the day a ninth
    // category is added -- silently, by attaching the licence notice to the wrong list.
    return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIRow *row = self.sections[indexPath.section].rows[indexPath.row];

    // Built fresh rather than dequeued. These are a handful of rows on a screen opened
    // occasionally, and reuse is where a switch ends up wired to the wrong preference.
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];

    cell.textLabel.text = row.title;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15];

    cell.detailTextLabel.text = row.detail;
    cell.detailTextLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.55];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5];
    cell.detailTextLabel.numberOfLines = 0;

    cell.imageView.image = [UIImage systemImageNamed:row.symbol];
    cell.imageView.tintColor = [UIColor.whiteColor colorWithAlphaComponent:0.55];

    if (row.kind == SCIRowKindSwitch) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.onTintColor = SCIAccent();
        toggle.on = SCIPrefEnabled(row.prefKey);

        // The key travels with the control, so the handler cannot read one preference
        // and write another.
        objc_setAssociatedObject(toggle, @selector(prefKey), row.prefKey,
                                 OBJC_ASSOCIATION_RETAIN);
        [toggle addTarget:self
                   action:@selector(toggled:)
         forControlEvents:UIControlEventValueChanged];

        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCIRow *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.action) row.action();
}

// MARK: - Actions

- (void)toggled:(UISwitch *)toggle {
    NSString *key = objc_getAssociatedObject(toggle, @selector(prefKey));
    if (!key.length) return;

    [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:key];
    SCILogV(@"settings: %@ = %@", key, toggle.isOn ? @"on" : @"off");
}


- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Presentation

+ (UIViewController *)topMostController {
    UIWindow *key = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
        if (key) break;
    }

    UIViewController *controller = key.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (void)present {
    UIViewController *host = [self topMostController];
    if (!host) {
        SCILogV(@"settings: nothing to present from");
        return;
    }

    if (host.isBeingPresented || host.isBeingDismissed) {
        SCILogV(@"settings: host is mid-transition, not presenting");
        return;
    }

    // The guard stays even though a table view is far less likely to throw than the
    // hand-built panel it replaces. It is not there because this code is expected to
    // fail; it is there because a tweak whose job is to report what is happening must
    // never be the reason the app stops.
    @try {
        SCIYTSettingsController *settings = [[SCIYTSettingsController alloc] init];
        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:settings];

        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        nav.navigationBar.barStyle = UIBarStyleBlack;
        nav.navigationBar.tintColor = SCIAccent();

        // Forced inside the guard, so a layout fault lands here rather than later
        // inside UIKit's transition where it would be out of reach.
        (void)settings.view;

        [host presentViewController:nav animated:YES completion:nil];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];

        NSLog(@"[AlbrhiYT] the settings screen could not be built: %@ — %@",
              exception.name, exception.reason);
    }
}

@end
