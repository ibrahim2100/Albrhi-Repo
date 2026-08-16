#import "SCIPanelHeader.h"
#import "Localization/SCILocalize.h"

@implementation SCIPanelHeader

+ (UIImage *)mark {
    // From this bundle, not from the main one. The main bundle here is Settings, and
    // +imageNamed: without a bundle looks there and finds nothing.
    NSBundle *bundle = [NSBundle bundleForClass:self];
    return [UIImage imageNamed:@"AlbrhiMark" inBundle:bundle compatibleWithTraitCollection:nil];
}

+ (UIView *)viewForWidth:(CGFloat)width
                 version:(NSString *)version
                      on:(NSInteger)on
                      of:(NSInteger)total {
    UIImage *mark = [self mark];
    if (!mark) return nil;

    UIImageView *logo = [[UIImageView alloc] initWithImage:mark];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.layer.cornerRadius = 16;
    logo.layer.cornerCurve = kCACornerCurveContinuous;
    logo.clipsToBounds = YES;

    // Turned off before a size is asked for, not after.
    //
    // A UIImageView made with -initWithImage: comes with the autoresizing mask translated
    // into constraints and its own image's size as an intrinsic one. Activating a width
    // beside those is a conflict, and the only reason it does not show as one is that
    // UIStackView switches the flag off when the view becomes an arranged subview -- which
    // happens later in this method. Depending on the order of two lines to avoid an
    // unsatisfiable layout is how the Instagram panel died in CoreAutoLayout twice.
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    [logo.widthAnchor constraintEqualToConstant:72].active = YES;
    [logo.heightAnchor constraintEqualToConstant:72].active = YES;

    UILabel *name = [[UILabel alloc] init];
    name.text = SCILocalized(@"panel_title");
    name.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    name.textColor = [UIColor labelColor];
    name.textAlignment = NSTextAlignmentCenter;

    UILabel *tagline = [[UILabel alloc] init];
    tagline.text = SCILocalized(@"panel_tagline");
    tagline.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    tagline.textColor = [UIColor secondaryLabelColor];
    tagline.textAlignment = NSTextAlignmentCenter;
    tagline.numberOfLines = 0;

    UILabel *badge = [[UILabel alloc] init];
    badge.text = [NSString stringWithFormat:@"  %@  ", version];
    badge.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    badge.textColor = [UIColor secondaryLabelColor];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = [UIColor tertiarySystemFillColor];
    badge.layer.cornerRadius = 9;
    badge.clipsToBounds = YES;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    [badge.heightAnchor constraintEqualToConstant:18].active = YES;

    // The one thing this screen exists to say, said before anything is read.
    //
    // The list below already shows a switch per app, but "how much of this is actually on"
    // takes counting them -- and on a fresh install, where everything is off by design,
    // nothing on the screen says so plainly. The pill does.
    //
    // Green when anything is patched, plain when nothing is: not red, because none-on is a
    // deliberate and valid state here, not a fault. Colour is reserved for what is wrong.
    UILabel *status = [[UILabel alloc] init];
    status.text = [NSString stringWithFormat:@"  %@  ",
        [NSString stringWithFormat:SCILocalized(@"panel_on_count"), (long)on, (long)total]];
    status.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    status.textAlignment = NSTextAlignmentCenter;
    status.textColor = on > 0 ? [UIColor systemGreenColor] : [UIColor secondaryLabelColor];
    status.backgroundColor = on > 0
        ? [[UIColor systemGreenColor] colorWithAlphaComponent:0.14]
        : [UIColor tertiarySystemFillColor];
    status.layer.cornerRadius = 9;
    status.clipsToBounds = YES;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [status.heightAnchor constraintEqualToConstant:18].active = YES;

    // Wrapped so the pills are their own width rather than the full column. A label in a
    // vertical stack stretches; labels centred inside a wrapper do not.
    UIStackView *badgeRow = [[UIStackView alloc] initWithArrangedSubviews:@[badge, status]];
    badgeRow.spacing = 6;
    badgeRow.axis = UILayoutConstraintAxisHorizontal;
    badgeRow.alignment = UIStackViewAlignmentCenter;
    badgeRow.distribution = UIStackViewDistributionEqualCentering;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[logo, name, tagline, badgeRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(24, 20, 20, 20);

    [stack setCustomSpacing:14 afterView:logo];
    [stack setCustomSpacing:2 afterView:name];
    [stack setCustomSpacing:12 afterView:tagline];

    CGFloat height = [stack systemLayoutSizeFittingSize:CGSizeMake(width, 0)
                          withHorizontalFittingPriority:UILayoutPriorityRequired
                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;

    stack.frame = CGRectMake(0, 0, width, height);
    return stack;
}

@end
