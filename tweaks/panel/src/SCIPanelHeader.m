#import "SCIPanelHeader.h"
#import "Localization/SCILocalize.h"

@implementation SCIPanelHeader

+ (UIImage *)mark {
    // From this bundle, not from the main one. The main bundle here is Settings, and
    // +imageNamed: without a bundle looks there and finds nothing.
    NSBundle *bundle = [NSBundle bundleForClass:self];
    return [UIImage imageNamed:@"AlbrhiMark" inBundle:bundle compatibleWithTraitCollection:nil];
}

+ (UIView *)viewForWidth:(CGFloat)width version:(NSString *)version {
    UIImage *mark = [self mark];
    if (!mark) return nil;

    UIImageView *logo = [[UIImageView alloc] initWithImage:mark];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.layer.cornerRadius = 16;
    logo.layer.cornerCurve = kCACornerCurveContinuous;
    logo.clipsToBounds = YES;
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
    [badge.heightAnchor constraintEqualToConstant:18].active = YES;

    // Wrapped so the pill is its own width rather than the full column. A label in a
    // vertical stack stretches; a label centred inside a wrapper does not.
    UIStackView *badgeRow = [[UIStackView alloc] initWithArrangedSubviews:@[badge]];
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
