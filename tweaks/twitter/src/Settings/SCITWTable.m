#import "SCITWTable.h"
#import <objc/runtime.h>

/// Ties a switch back to the row that made it. An index would be the parallel-list mistake
/// this whole arrangement exists to remove.
static char kSCIRowForSwitch;


/// A small colour-badge icon, drawn the way Settings.app draws its own rows: a rounded
/// square in a colour with a white glyph centred in it.
///
/// `UITableViewCell.imageView` is a plain `UIImageView` with no way to give it a background
/// layer of its own, so the background is baked into the image itself -- the badge is one
/// flat bitmap, not a glyph over a separately-drawn square. That is the whole trick behind
/// every icon in iOS's own Settings app, and it needs no custom cell class here: setting
/// `cell.imageView.image` is enough, and the built-in cell styles already size and place it.
///
/// Returns nothing to draw -- an empty, transparent 29-point square -- when the symbol name
/// does not exist on this iOS version, rather than crashing on a nil image or silently
/// drawing a coloured square with nothing in it that looks like a rendering bug.
///
/// **Deliberately not used on the raw switch list.** Three hundred and more rows redrawing
/// a bitmap each would be spending real work on a list built to be lean and searchable, for
/// a section where every row is already told apart by its own name -- the curated sections
/// below are few enough, and different enough from each other, that an icon is worth its
/// keep on them and would be noise repeated three hundred times on that one.
UIImage *SCITWBadgeOfSide(NSString *symbolName, UIColor *color, CGFloat side) {
    CGSize size = CGSizeMake(side, side);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                                format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *background =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                        cornerRadius:side * 0.24];
        [(color ?: [UIColor systemGrayColor]) setFill];
        [background fill];

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:side * 0.52
                                                             weight:UIImageSymbolWeightMedium];
        UIImage *glyph = [[UIImage systemImageNamed:symbolName withConfiguration:config]
            imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (!glyph) return;

        [glyph drawAtPoint:CGPointMake((size.width - glyph.size.width) / 2,
                                       (size.height - glyph.size.height) / 2)];
    }];
}

/// The ordinary row size, which is every caller but the prominent one.
UIImage *SCITWBadge(NSString *symbolName, UIColor *color) {
    return SCITWBadgeOfSide(symbolName, color, 29);
}


@implementation SCITWTable

#pragma mark - Table

///
/// The whole screen, from what the sections registered.
///
/// Rebuilt on every reload rather than kept: an info row reads its value through a block at
/// draw time, and a section whose feature is switched off returns no rows and disappears.
/// Nothing here knows what any section contains, which is the point -- the version this
/// replaced addressed rows by index through five section constants and seven row constants,
/// and a `switch` per section deciding what each number meant.
///
- (NSArray<SCITWSection *> *)buildSections {
    return @[];
}

- (void)reload {
    self.sections = [self buildSections];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.sections[(NSUInteger)section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section].footer;
}

- (SCITWRow *)rowAt:(NSIndexPath *)indexPath {
    return self.sections[(NSUInteger)indexPath.section].rows[(NSUInteger)indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCITWRow *row = [self rowAt:indexPath];

    // Never dequeued across kinds. A switch cell reused as an info row keeps its accessory
    // view, which is how a settings screen ends up with a switch beside a number.
    NSString *identifier = [NSString stringWithFormat:@"row-%ld", (long)row.kind];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        UITableViewCellStyle style = row.kind == SCITWRowKindInfo ? UITableViewCellStyleValue1
                                                                  : UITableViewCellStyleSubtitle;
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
    }

    cell.textLabel.text = row.title;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    // A prominent row is the same row drawn larger, not a different cell class: a bigger
    // badge, a bold title and a tinted panel behind it. Everything reset on the other
    // branch as well, because cells are reused and a font left bold is how one setting
    // starts looking like the heading of the next.
    if (row.prominent) {
        cell.imageView.image = row.symbol.length ? SCITWBadgeOfSide(row.symbol, row.tint, 40)
                                                 : nil;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.backgroundColor = [(row.tint ?: [UIColor systemBlueColor]) colorWithAlphaComponent:0.10];
    } else {
        cell.imageView.image = row.symbol.length ? SCITWBadge(row.symbol, row.tint) : nil;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }

    // A warning colour rather than only a note. Every cautious row removes a disclosure,
    // changes what X is told about the device, or turns on something X ships switched off,
    // and a note nobody reads is not a warning.
    cell.textLabel.textColor = row.cautious ? [UIColor systemOrangeColor] : [UIColor labelColor];

    switch (row.kind) {
        case SCITWRowKindSwitch: {
            cell.detailTextLabel.text = row.note;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;

            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.prefKey];
            objc_setAssociatedObject(toggle, &kSCIRowForSwitch, row, OBJC_ASSOCIATION_RETAIN);
            [toggle addTarget:self
                       action:@selector(switchFlipped:)
             forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case SCITWRowKindAction: {
            cell.detailTextLabel.text = row.note;
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case SCITWRowKindInfo: {
            cell.detailTextLabel.text = row.value ? row.value() : nil;
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
    }

    return cell;
}

- (void)switchFlipped:(UISwitch *)toggle {
    SCITWRow *row = objc_getAssociatedObject(toggle, &kSCIRowForSwitch);
    if (!row.prefKey) return;

    [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:row.prefKey];
    if (row.onChange) row.onChange(toggle.isOn);

    // Reloaded because a switch can change which sections exist -- turning the switch layer
    // off takes the whole feature list away. Deferred by a runloop turn so the switch
    // finishes its own animation rather than being torn out mid-slide.
    dispatch_async(dispatch_get_main_queue(), ^{ [self reload]; });
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCITWRow *row = [self rowAt:indexPath];
    if (row.kind == SCITWRowKindAction && row.action) row.action();
}

@end
