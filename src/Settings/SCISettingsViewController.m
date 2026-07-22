#import "SCISettingsViewController.h"
#import "../SCILog.h"

static char rowStaticRef[] = "row";

@interface SCISettingsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray *sections;
@property (nonatomic) BOOL reduceMargin;

// Search: a flat index of every leaf setting across the whole tree, and the
// filtered sections shown while a query is active.
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<SCISetting *> *searchIndex;
@property (nonatomic, copy) NSArray *filteredSections;

@end

///

@implementation SCISettingsViewController

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin {
    self = [super init];
    
    if (self) {
        self.title = title;
        self.reduceMargin = reduceMargin;
        
        // Exclude development cells from release builds
        NSMutableArray *mutableSections = [sections mutableCopy];
        
        [mutableSections enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *section, NSUInteger index, BOOL *stop) {
        
            if ([section[@"header"] hasPrefix:@"_"] && [section[@"footer"] hasPrefix:@"_"]) {
                if (![[SCIUtils IGVersionString] isEqualToString:@"0.0.0"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }

            else if ([section[@"header"] isEqualToString:@"Experimental"]) {
                if (![[SCIUtils IGVersionString] hasSuffix:@"-dev"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }
            
        }];
        
        self.sections = [mutableSections copy];
    }
    
    
    return self;
}

- (instancetype)init {
    return [self initWithTitle:[SCITweakSettings title] sections:[SCITweakSettings sections] reduceMargin:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    // Albrhi accent — tint interactive elements with the brand colour
    UIColor *accent = [SCIUtils SCIColor_Primary];
    self.view.tintColor = accent;
    self.navigationController.navigationBar.tintColor = accent;

    // Right-to-left layout when the active language is Arabic
    UISemanticContentAttribute semantic = [SCILocalize isRTL]
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.view.semanticContentAttribute = semantic;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(self.reduceMargin ? -30 : -10, 0, 0, 0);
    self.tableView.delegate = self;
    self.tableView.semanticContentAttribute = semantic;
    self.tableView.tintColor = accent;

    [self.view addSubview:self.tableView];

    // Search only on the root page — sub-pages are already short lists.
    if (self.reduceMargin) {
        self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        self.searchController.searchResultsUpdater = self;
        self.searchController.obscuresBackgroundDuringPresentation = NO;
        self.searchController.searchBar.placeholder = SCILocalized(@"p_search_placeholder");
        self.searchController.searchBar.tintColor = accent;
        self.searchController.searchBar.semanticContentAttribute = semantic;
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
        self.definesPresentationContext = YES;
    }
}

// MARK: - Search

// Which sections the table shows right now: the filtered results while searching,
// otherwise the full tree.
- (NSArray *)activeSections {
    if (self.searchController.isActive && self.searchController.searchBar.text.length) {
        return self.filteredSections ?: @[];
    }
    return self.sections;
}

// Every searchable leaf across the whole tree, flattened once. Navigation rows are
// kept (so a page name is findable) and also recursed into.
- (NSArray<SCISetting *> *)flattenSections:(NSArray *)sections {
    NSMutableArray<SCISetting *> *out = [NSMutableArray array];
    for (NSDictionary *section in sections) {
        for (SCISetting *row in section[@"rows"]) {
            if (row.type == SCITableCellNavigation && row.navSections.count > 0) {
                [out addObject:row];
                [out addObjectsFromArray:[self flattenSections:row.navSections]];
            } else {
                [out addObject:row];
            }
        }
    }
    return out;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];

    if (!query.length) {
        self.filteredSections = nil;
        [self.tableView reloadData];
        return;
    }

    if (!self.searchIndex) self.searchIndex = [self flattenSections:self.sections];

    NSMutableArray<SCISetting *> *matches = [NSMutableArray array];
    for (SCISetting *row in self.searchIndex) {
        BOOL hit = (row.title.length && [row.title rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound)
                || (row.subtitle.length && [row.subtitle rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound);
        if (hit) [matches addObject:row];
    }

    self.filteredSections = matches.count ? @[@{@"header": @"", @"rows": matches}] : @[];
    [self.tableView reloadData];
}

// The "hold ☰ to reopen settings" alert that used to fire here is now a row on the
// welcome screen, which is a better place to say it and doesn't ambush the user on
// the way out.

// MARK: - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = [self activeSections][indexPath.section][@"rows"][indexPath.row];
    if (!row) return nil;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *cellContentConfig = cell.defaultContentConfiguration;
    
    cellContentConfig.text = row.title;
    
    // Subtitle
    if (row.subtitle.length) {
        cellContentConfig.secondaryText = row.subtitle;
        cellContentConfig.textToSecondaryTextVerticalPadding = 4.5;
    }
    
    // Icon
    if (row.icon != nil) {
        cellContentConfig.image = [row.icon image];
        cellContentConfig.imageProperties.tintColor = row.icon.color;
    }
    
    // Image url
    if (row.imageUrl != nil) {
        [self loadImageFromURL:row.imageUrl atIndexPath:indexPath forTableView:tableView];
        
        cellContentConfig.imageToTextPadding = 14;
    }
    
    switch (row.type) {
        case SCITableCellStatic: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellLink: {
            cellContentConfig.textProperties.color = [UIColor systemBlueColor];
            cellContentConfig.textProperties.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                                      weight:UIFontWeightMedium];
            
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"safari"]];
            imageView.tintColor = [UIColor systemGray3Color];
            cell.accessoryView = imageView;
            
            break;
        }
            
        case SCITableCellSwitch: {
            UISwitch *toggle = [UISwitch new];
            toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
            toggle.onTintColor = [SCIUtils SCIColor_Primary];
            
            objc_setAssociatedObject(toggle, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellStepper: {
            UIStepper *stepper = [UIStepper new];
            stepper.minimumValue = row.min;
            stepper.maximumValue = row.max;
            stepper.stepValue = row.step;
            stepper.value = [[NSUserDefaults standardUserDefaults] doubleForKey:row.defaultsKey];
            
            objc_setAssociatedObject(stepper, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [stepper addTarget:self
                        action:@selector(stepperChanged:)
              forControlEvents:UIControlEventValueChanged];
            
            // Template subtitle
            if (row.subtitle.length) {
                cellContentConfig.secondaryText = [self formatString:row.subtitle withValue:stepper.value label:row.label singularLabel:row.singularLabel];
            }
            
            cell.accessoryView = stepper;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellButton: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
            
        case SCITableCellMenu: {
            UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [menuButton setTitle:@"•••" forState:UIControlStateNormal];
            menuButton.menu = [row menuForButton:menuButton];
            menuButton.showsMenuAsPrimaryAction = YES;
            menuButton.titleLabel.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                           weight:UIFontWeightMedium];
            
            UIButtonConfiguration *config = menuButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            menuButton.configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
            menuButton.configuration = config;

            [menuButton sizeToFit];
            
            cell.accessoryView = menuButton;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellNavigation: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
    }
    
    cell.contentConfiguration = cellContentConfig;

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self activeSections][section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self activeSections][section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [self activeSections][section][@"footer"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self activeSections].count;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = [self activeSections][indexPath.section][@"rows"][indexPath.row];
    if (!row) return;

    // Navigating away from a search result: dismiss the search so the pushed page
    // and the back stack behave normally.
    if (row.type == SCITableCellNavigation && self.searchController.isActive) {
        self.searchController.active = NO;
    }

    if (row.type == SCITableCellLink) {
        [[UIApplication sharedApplication] openURL:row.url options:@{} completionHandler:nil];
    }
    else if (row.type == SCITableCellButton) {
        if (row.action != nil) {
            row.action();
        }
    }
    else if (row.type == SCITableCellNavigation) {
        if (row.navSections.count > 0) {
            UIViewController *vc = [[SCISettingsViewController alloc] initWithTitle:row.title sections:row.navSections reduceMargin:NO];
            vc.title = row.title;
            [self.navigationController pushViewController:vc animated:YES];
        }
        else if (row.navViewController) {
            [self.navigationController pushViewController:row.navViewController animated:YES];
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// MARK: - Actions

- (void)switchChanged:(UISwitch *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:row.defaultsKey];
    
    SCILogV(@"Switch changed: %@", sender.isOn ? @"ON" : @"OFF");
    
    if (row.requiresRestart) {
        [SCIUtils showRestartConfirmation];
    }
}

- (void)stepperChanged:(UIStepper *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setDouble:sender.value forKey:row.defaultsKey];
    
    SCILogV(@"Stepper changed: %f", sender.value);
    
    [self reloadCellForView:sender];
}

- (void)menuChanged:(UICommand *)command {
    NSDictionary *properties = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setValue:properties[@"value"] forKey:properties[@"defaultsKey"]];
    
    SCILogV(@"Menu changed: %@", command.propertyList[@"value"]);
    
    [self reloadCellForView:command.sender animated:YES];
    
    if (properties[@"requiresRestart"]) {
        [SCIUtils showRestartConfirmation];
    }
}

// MARK: - Helper

- (NSString *)formatString:(NSString *)template withValue:(double)value label:(NSString *)label singularLabel:(NSString *)singularLabel {
    // Singular or plural labels
    NSString *applicableLabel = fabs(value - 1.0) < 0.00001 ? singularLabel : label;
    
    // Force value to 0 to prevent it being -0
    if (fabs(value) < 0.00001) {
        value = 0.0;
    }

    // Get correct decimal value based on step value
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = [SCIUtils decimalPlacesInDouble:value];

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    return [NSString stringWithFormat:template, stringValue, applicableLabel];
}

- (void)reloadCellForView:(UIView *)view animated:(BOOL)animated {
    UITableViewCell *cell = (UITableViewCell *)view.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)cell.superview;
    }
    if (!cell) return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;
    
    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
}
- (void)reloadCellForView:(UIView *)view {
    [self reloadCellForView:view animated:NO];
}

- (void)loadImageFromURL:(NSURL *)url atIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        if (!data || error) return;

        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (!cell) return;

            UIListContentConfiguration *config = (UIListContentConfiguration *)cell.contentConfiguration;
            config.image = image;
            config.imageProperties.maximumSize = CGSizeMake(45, 45);
            cell.contentConfiguration = config;
        });
    }];

    [task resume];
}

@end
