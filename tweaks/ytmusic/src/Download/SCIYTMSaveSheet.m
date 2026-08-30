#import "SCIYTMSaveSheet.h"
#import "../Localization/SCILocalize.h"

/// Albrhi's red, the one the settings screen and the banner already use. Named once here so a
/// third surface cannot drift from the other two.
static UIColor *SCIYTMAccent(void) {
    return [UIColor colorWithRed:230/255.0 green:75/255.0 blue:75/255.0 alpha:1];
}

@interface SCIYTMSaveSheet ()
@property (nonatomic, strong) UIView *dimmer;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *sectionField;
@property (nonatomic, copy) void (^onSave)(NSString *, NSString *);
@end

@implementation SCIYTMSaveSheet

/// Held while it is on screen. Nothing else owns this object -- it is not a controller in anybody's
/// hierarchy -- so without a reference of its own it would be released the moment the method that
/// built it returned, taking its handlers with it.
static SCIYTMSaveSheet *sciLiveSheet = nil;

+ (void)askForName:(NSString *)suggestedName
           section:(NSString *)suggestedSection
          sections:(NSArray<NSString *> *)existingSections
            onSave:(void (^)(NSString *, NSString *))onSave {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *key = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { key = window; break; }
        }

        // No window to ask on is not a reason to lose the download: the caller is handed exactly
        // what the card would have offered. Refusing here would protect a question at the cost of
        // the thing somebody actually asked for.
        if (!key) {
            if (onSave) onSave(suggestedName, suggestedSection);
            return;
        }

        SCIYTMSaveSheet *sheet = [[SCIYTMSaveSheet alloc] init];
        sheet.onSave = onSave;
        sciLiveSheet = sheet;
        [sheet presentIn:key name:suggestedName section:suggestedSection sections:existingSections];
    });
}

- (void)presentIn:(UIWindow *)window
             name:(NSString *)name
          section:(NSString *)section
         sections:(NSArray<NSString *> *)sections {
    self.dimmer = [[UIView alloc] initWithFrame:window.bounds];
    self.dimmer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.dimmer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmer.alpha = 0;
    [window addSubview:self.dimmer];

    // Tapping away cancels, which is what a card that asks a small question should do -- and it
    // is the gesture people try first.
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(cancel)];
    [self.dimmer addGestureRecognizer:tap];

    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.card.layer.cornerRadius = 22;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dimmer addSubview:self.card];

    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    mark.tintColor = SCIYTMAccent();

    // Sized, and told not to stretch. An image view in a horizontal stack has only its
    // intrinsic size to argue with, and a symbol rendered at 26 points does not stop the
    // stack handing it the width left over from a short title -- which is how a small mark
    // comes out as a wide one.
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [mark.widthAnchor constraintEqualToConstant:30].active = YES;
    [mark.heightAnchor constraintEqualToConstant:30].active = YES;
    [mark setContentHuggingPriority:UILayoutPriorityRequired
                            forAxis:UILayoutConstraintAxisHorizontal];
    [mark setContentCompressionResistancePriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"dl_confirm_title");
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[mark, title]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.alignment = UIStackViewAlignmentCenter;
    heading.spacing = 10;

    UILabel *note = [[UILabel alloc] init];
    note.text = SCILocalized(@"dl_confirm_note");
    note.font = [UIFont systemFontOfSize:13];
    note.textColor = [UIColor secondaryLabelColor];
    note.numberOfLines = 0;

    //
    // **The row is what comes back, and the field is handed over separately.**
    //
    // The first version returned the field and put `field.superview` into the stack. A view
    // retains its *subviews*, never its superview -- so the row, owned by nothing once the
    // helper returned, was released immediately and `superview` was left pointing at freed
    // memory. That is the crash: it happened the moment the card was built, which is the
    // moment the download button was pressed.
    //
    UIView *nameRow = [self rowWithText:name placeholder:SCILocalized(@"dl_confirm_name")
                                 symbol:@"textformat" field:&_nameField];
    UIView *sectionRow = [self rowWithText:section placeholder:SCILocalized(@"dl_confirm_section")
                                    symbol:@"folder" field:&_sectionField];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading, note,
                                                                        nameRow, sectionRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:stack];

    // The sections that already exist, as taps rather than as text somebody has to copy. A folder
    // is far easier to choose than to spell, and the field is still there for a new one.
    if (sections.count) {
        UIScrollView *strip = [[UIScrollView alloc] init];
        strip.showsHorizontalScrollIndicator = NO;

        UIStackView *chips = [[UIStackView alloc] init];
        chips.axis = UILayoutConstraintAxisHorizontal;
        chips.spacing = 8;
        chips.translatesAutoresizingMaskIntoConstraints = NO;

        for (NSString *existing in sections) {
            UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
            [chip setTitle:existing forState:UIControlStateNormal];
            chip.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            [chip setTitleColor:SCIYTMAccent() forState:UIControlStateNormal];
            chip.backgroundColor = [SCIYTMAccent() colorWithAlphaComponent:0.12];
            chip.layer.cornerRadius = 14;
            chip.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
            [chip addTarget:self action:@selector(chipTapped:)
           forControlEvents:UIControlEventTouchUpInside];
            [chips addArrangedSubview:chip];
        }

        [strip addSubview:chips];
        [NSLayoutConstraint activateConstraints:@[
            [chips.topAnchor constraintEqualToAnchor:strip.topAnchor],
            [chips.bottomAnchor constraintEqualToAnchor:strip.bottomAnchor],
            [chips.leadingAnchor constraintEqualToAnchor:strip.leadingAnchor],
            [chips.trailingAnchor constraintEqualToAnchor:strip.trailingAnchor],
            [chips.heightAnchor constraintEqualToAnchor:strip.heightAnchor],
            [strip.heightAnchor constraintEqualToConstant:32],
        ]];
        [stack addArrangedSubview:strip];
    }

    UIButton *cancel = [self buttonWithTitle:SCILocalized(@"cancel") filled:NO
                                      action:@selector(cancel)];
    UIButton *save = [self buttonWithTitle:SCILocalized(@"dl_confirm_save") filled:YES
                                    action:@selector(save)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, save]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 10;
    [stack addArrangedSubview:buttons];

    [NSLayoutConstraint activateConstraints:@[
        [self.card.centerXAnchor constraintEqualToAnchor:self.dimmer.centerXAnchor],
        [self.card.centerYAnchor constraintEqualToAnchor:self.dimmer.centerYAnchor constant:-40],
        [self.card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.dimmer.leadingAnchor constant:20],
        [self.card.widthAnchor constraintLessThanOrEqualToConstant:420],
        [stack.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18],
        [stack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-18],
        [buttons.heightAnchor constraintEqualToConstant:44],
    ]];

    self.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0
                        options:0 animations:^{
        self.dimmer.alpha = 1;
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

/// A field inside its own rounded row, with an icon. **The row is returned** and the field is
/// written into `outField`, because whoever holds the row is the only thing keeping it alive.
- (UIView *)rowWithText:(NSString *)text
            placeholder:(NSString *)placeholder
                 symbol:(NSString *)symbol
                  field:(UITextField * __strong *)outField {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    row.layer.cornerRadius = 12;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.tintColor = [UIColor secondaryLabelColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UITextField *field = [[UITextField alloc] init];
    field.text = text;
    field.placeholder = placeholder;
    field.font = [UIFont systemFontOfSize:15];
    field.textColor = [UIColor labelColor];
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:field];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:46],
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [field.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    if (outField) *outField = field;
    return row;
}

- (UIButton *)buttonWithTitle:(NSString *)title filled:(BOOL)filled action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 12;

    if (filled) {
        button.backgroundColor = SCIYTMAccent();
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)chipTapped:(UIButton *)chip {
    self.sectionField.text = chip.currentTitle;
}

- (void)save {
    NSString *name = self.nameField.text;
    NSString *section = self.sectionField.text;
    void (^callback)(NSString *, NSString *) = self.onSave;

    [self dismissThen:^{
        if (callback) callback(name, section);
    }];
}

- (void)cancel {
    [self dismissThen:nil];
}

- (void)dismissThen:(void (^)(void))then {
    [self.card endEditing:YES];

    [UIView animateWithDuration:0.2 animations:^{
        self.dimmer.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(__unused BOOL finished) {
        [self.dimmer removeFromSuperview];
        if (sciLiveSheet == self) sciLiveSheet = nil;
        if (then) then();
    }];
}

@end
