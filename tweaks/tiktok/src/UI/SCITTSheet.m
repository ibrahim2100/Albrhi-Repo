#import "SCITTSheet.h"
#import "../Tweak.h"

@implementation SCITTSheetAction

+ (instancetype)title:(NSString *)title
               symbol:(NSString *)symbol
              primary:(BOOL)primary
              handler:(void (^)(void))handler {
    SCITTSheetAction *action = [[SCITTSheetAction alloc] init];
    action.title = title;
    action.symbol = symbol;
    action.primary = primary;
    action.handler = handler;
    return action;
}

@end


/// The one sheet on screen, if any. A second question asked while the first is still up would stack
/// two dimmed backdrops and leave the darker one behind when the top one closed.
static UIView *sciSheetOverlay = nil;

/// The handlers, kept alive for as long as the buttons that call them exist.
///
/// A `UIButton` target-action carries no block, and this file has no view controller to hang
/// properties on -- so the actions are held here, keyed by the tag on the button that runs them, and
/// dropped the moment the sheet goes away.
static NSMutableDictionary<NSNumber *, SCITTSheetAction *> *sciSheetActions = nil;

@implementation SCITTSheet

+ (UIWindow *)window {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) return candidate;
        }
    }
    return nil;
}

+ (BOOL)canPresent {
    return [self window] != nil;
}

+ (void)dismiss {
    UIView *overlay = sciSheetOverlay;
    if (!overlay) return;

    sciSheetOverlay = nil;
    sciSheetActions = nil;

    UIView *card = [overlay viewWithTag:1];

    [UIView animateWithDuration:0.2 animations:^{
        overlay.alpha = 0;
        card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

+ (void)backdropTapped {
    [self dismiss];
}

+ (void)actionTapped:(UIButton *)button {
    SCITTSheetAction *action = sciSheetActions[@(button.tag)];
    void (^handler)(void) = action.handler;

    // Dismissed first, then run: a handler that presents anything of its own -- and the photo
    // question's own answer leads straight to a second sheet -- would otherwise be putting it up
    // behind a backdrop that is about to be torn down.
    [self dismiss];
    if (handler) handler();
}

+ (UIButton *)buttonForAction:(SCITTSheetAction *)action tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    button.backgroundColor = action.primary
        ? SCIAccent()
        : [UIColor colorWithWhite:1 alpha:0.1];
    button.layer.cornerRadius = 14;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [UIFont systemFontOfSize:16
                                               weight:action.primary ? UIFontWeightBold
                                                                     : UIFontWeightSemibold];
    [button setTitle:action.title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    if (action.symbol.length) {
        UIImage *glyph = [UIImage systemImageNamed:action.symbol
                                 withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:15
                                                           weight:UIImageSymbolWeightSemibold]];
        [button setImage:glyph forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];
        // A little air between glyph and text, and the same on the other side so the pair stays
        // centred rather than drifting by the width of the gap.
        button.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 5);
    }

    [button.heightAnchor constraintEqualToConstant:52].active = YES;
    [button addTarget:self
               action:@selector(actionTapped:)
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

+ (void)showTitle:(NSString *)title
          message:(NSString *)message
           symbol:(NSString *)symbol
          actions:(NSArray<SCITTSheetAction *> *)actions
           cancel:(NSString *)cancel {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showTitle:title message:message symbol:symbol actions:actions cancel:cancel];
        });
        return;
    }

    UIWindow *window = [self window];
    if (!window) return;

    [self dismiss];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    overlay.alpha = 0;
    [window addSubview:overlay];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped)];
    [overlay addGestureRecognizer:tap];

    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
    card.tag = 1;
    card.layer.cornerRadius = 28;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:card];

    // The icon disc: the same accent disc the settings header and the feed button use.
    UIView *disc = [[UIView alloc] init];
    disc.backgroundColor = [SCIAccent() colorWithAlphaComponent:0.22];
    disc.layer.cornerRadius = 23;
    disc.layer.cornerCurve = kCACornerCurveContinuous;
    disc.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:(symbol.length ? symbol : @"questionmark")
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:21
                                                                                 weight:UIImageSymbolWeightBold]]];
    glyph.tintColor = SCIAccent();
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    [disc addSubview:glyph];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card.contentView addSubview:stack];

    UIStackView *head = [[UIStackView alloc] initWithArrangedSubviews:@[disc]];
    head.axis = UILayoutConstraintAxisVertical;
    head.alignment = UIStackViewAlignmentCenter;
    [stack addArrangedSubview:head];
    [stack setCustomSpacing:14 afterView:head];

    [stack addArrangedSubview:titleLabel];

    if (message.length) {
        UILabel *messageLabel = [[UILabel alloc] init];
        messageLabel.text = message;
        messageLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        messageLabel.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.numberOfLines = 0;
        [stack addArrangedSubview:messageLabel];
        [stack setCustomSpacing:18 afterView:messageLabel];
    } else {
        [stack setCustomSpacing:18 afterView:titleLabel];
    }

    sciSheetActions = [NSMutableDictionary dictionary];

    NSInteger tag = 100;
    for (SCITTSheetAction *action in actions) {
        sciSheetActions[@(tag)] = action;
        [stack addArrangedSubview:[self buttonForAction:action tag:tag]];
        tag++;
    }

    if (cancel.length) {
        SCITTSheetAction *out = [SCITTSheetAction title:cancel symbol:nil primary:NO handler:nil];
        UIButton *button = [self buttonForAction:out tag:tag];
        // The way out is not a choice competing with the answers, so it carries no fill.
        button.backgroundColor = [UIColor clearColor];
        [button setTitleColor:[UIColor colorWithWhite:1 alpha:0.55] forState:UIControlStateNormal];
        sciSheetActions[@(tag)] = out;
        [stack addArrangedSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [disc.widthAnchor constraintEqualToConstant:46],
        [disc.heightAnchor constraintEqualToConstant:46],
        [glyph.centerXAnchor constraintEqualToAnchor:disc.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor],

        [card.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        // Wide enough to read, never wider than the phone: a card pinned to both margins on a
        // small screen and centred on a large one, which is one constraint pair rather than two
        // layouts.
        [card.widthAnchor constraintLessThanOrEqualToConstant:340],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:overlay.leadingAnchor constant:24],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-24],

        [stack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:22],
        [stack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-18],
        [stack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-18],
    ]];

    NSLayoutConstraint *wide = [card.widthAnchor constraintEqualToConstant:340];
    wide.priority = UILayoutPriorityDefaultHigh;
    wide.active = YES;

    sciSheetOverlay = overlay;

    card.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.32
                          delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        overlay.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
