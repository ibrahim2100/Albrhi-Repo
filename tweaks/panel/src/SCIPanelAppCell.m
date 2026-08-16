#import "SCIPanelAppCell.h"
#import <Preferences/PSSpecifier.h>
#import "Localization/SCILocalize.h"

///
/// The keys this cell reads off its specifier.
///
/// Set by SCIPanelRoot when it builds the row. Named here beside the code that reads them
/// rather than spelled out at both ends — two spellings of a specifier key is a subtitle
/// that is always empty and nothing that says why.
///
NSString *const SCIPanelCellSubtitleKey = @"sciSubtitle";
NSString *const SCIPanelCellAccentKey   = @"sciSubtitleIsWarning";

@implementation SCIPanelAppCell {
    UILabel *_subtitle;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    // The style Preferences asked for, passed through untouched.
    //
    // An earlier version forced UITableViewCellStyleSubtitle here, to get -detailTextLabel.
    // That was unnecessary -- this cell draws its own label and never touches
    // -detailTextLabel -- and overriding the style a PSControlTableCell was constructed
    // with is meddling with how Preferences builds its own control for no gain.
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (!self) return nil;

    // Its own label rather than -detailTextLabel.
    //
    // PSTableCell lays out and restyles the labels it owns on every refresh, and a colour
    // set on -detailTextLabel is reset the next time the specifier is reapplied. A label
    // this class owns is not part of that arrangement, so what it is told stays true.
    _subtitle = [[UILabel alloc] init];
    _subtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _subtitle.textColor = [UIColor secondaryLabelColor];
    _subtitle.numberOfLines = 1;
    _subtitle.adjustsFontSizeToFitWidth = YES;
    _subtitle.minimumScaleFactor = 0.85;
    [self.contentView addSubview:_subtitle];

    self.imageView.layer.cornerRadius = 8;
    self.imageView.layer.cornerCurve = kCACornerCurveContinuous;
    self.imageView.clipsToBounds = YES;

    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];

    NSString *text = [specifier propertyForKey:SCIPanelCellSubtitleKey];
    _subtitle.text = text;
    _subtitle.hidden = !text.length;

    // Amber, not red. A version this tweak has not been verified against is a caution and
    // usually works — the tested numbers are the newest builds the developer's own phone
    // accepts, not a compatibility ceiling, and this file's own footer says so. Red would
    // claim a fault where there is only an unknown.
    BOOL warn = [[specifier propertyForKey:SCIPanelCellAccentKey] boolValue];
    _subtitle.textColor = warn ? [UIColor systemOrangeColor] : [UIColor secondaryLabelColor];

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (_subtitle.hidden) return;

    // Positioned against the title Preferences has already placed, not against the content
    // view's own edges.
    //
    // PSTableCell decides where the title goes — the inset changes with the icon, with the
    // switch, and between iOS versions — so measuring from the content view would put the
    // second line under the icon on some rows and under the text on others. Reading the
    // frame the superclass just set is the only arrangement that stays aligned without
    // knowing any of those rules.
    CGRect title = self.textLabel.frame;
    if (CGRectIsEmpty(title)) return;

    CGFloat height = ceil(_subtitle.font.lineHeight);
    CGFloat available = CGRectGetWidth(self.contentView.bounds) - CGRectGetMinX(title) - 16;

    // Both frames computed from the row's own centre, not from where the title currently is.
    //
    // The first version subtracted half the subtitle's height from the title's existing
    // origin on every pass. That is only correct if -layoutSubviews runs exactly once:
    // it reads a value it wrote last time and moves it again, so the title creeps upward
    // for as long as the row is laid out -- and a table lays a visible row out repeatedly.
    // Deriving both positions from the content height instead gives the same answer every
    // pass, however many times it runs.
    CGFloat pair = CGRectGetHeight(title) + 1 + height;
    CGFloat top = floor((CGRectGetHeight(self.contentView.bounds) - pair) / 2);

    CGRect lifted = title;
    lifted.origin.y = top;
    self.textLabel.frame = lifted;

    _subtitle.frame = CGRectMake(CGRectGetMinX(title),
                                 top + CGRectGetHeight(title) + 1,
                                 MAX(available, 0),
                                 height);
}

@end
