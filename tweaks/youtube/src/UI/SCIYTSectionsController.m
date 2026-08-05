#import "SCIYTSectionsController.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import <objc/runtime.h>

@implementation SCIYTSectionsController

- (instancetype)init {
    // Inset-grouped: the same shape as the settings panel on this repository's Instagram
    // side, so the two tweaks read as one project.
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];

    [self buildSections];
}

/// Rebuilt on every appearance, not only on first load.
///
/// A sub-screen that opened a picker and came back showed the value it had when it was
/// pushed. Its rows are made when the sections are made, so returning to a screen has to
/// remake them -- and the same is true of the first screen after a page changed something.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSettings];
}

- (void)buildSections {
    self.sections = @[];
}

- (void)reloadSettings {
    [self buildSections];
    [self.tableView reloadData];
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].rows.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].title;
}

/// Carried on the section rather than worked out here. Matching on a row count was the first
/// version of this and it is the kind of thing that breaks the day another category is added
/// -- silently, by attaching the licence notice to the wrong list.
- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(__unused UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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

        // The key travels with the control, so the handler cannot read one preference and
        // write another.
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

@end
