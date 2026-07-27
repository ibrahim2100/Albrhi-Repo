#import "SCIAppIcon.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

@implementation SCIAppIcon

// MARK: - Discovery

+ (NSArray<NSString *> *)availableIconNames {
    if (![[UIApplication sharedApplication] supportsAlternateIcons]) return @[];

    // CFBundleIcons → CFBundleAlternateIcons is a dictionary keyed by icon name.
    // A plain dictionary has no order, so nothing here promises the icons appear in
    // the order Instagram authored them — only that the set is complete.
    NSDictionary *icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *alternates = icons[@"CFBundleAlternateIcons"];
    if (![alternates isKindOfClass:[NSDictionary class]]) return @[];

    return [alternates.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

+ (NSString *)currentIconName {
    return [[UIApplication sharedApplication] alternateIconName];
}

// MARK: - Preview image

// The icon files are declared alongside each name; the largest is good enough for a
// menu thumbnail. Missing art is not an error — the entry simply shows without one.
+ (UIImage *)previewForIconNamed:(NSString *)name {
    NSDictionary *icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *alternates = icons[@"CFBundleAlternateIcons"];
    NSDictionary *entry = alternates[name];
    NSArray *files = entry[@"CFBundleIconFiles"];
    UIImage *image = files.lastObject ? [UIImage imageNamed:files.lastObject] : nil;

    if (!image) return nil;

    // Rounded down to a small, even size so a full-resolution icon does not dominate
    // the row.
    CGSize target = CGSizeMake(28, 28);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, target.width, target.height)
                                                        cornerRadius:6];
        [clip addClip];
        [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    }];
}

// MARK: - Apply

+ (void)applyIconNamed:(NSString *)name {
    UIApplication *app = [UIApplication sharedApplication];
    if (![app supportsAlternateIcons]) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"appicon_unsupported")];
        return;
    }

    // Already there: setting the same name still fires Apple's confirmation alert, so
    // skip the no-op entirely.
    NSString *current = [self currentIconName];
    if ((name == nil && current == nil) || [name isEqualToString:current]) return;

    [app setAlternateIconName:name completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [SCIUtils showErrorHUDWithDescription:SCILocalized(@"appicon_failed")];
            } else {
                [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"appicon_changed")];
            }
        });
    }];
}

// MARK: - Menu

+ (UIMenu *)iconMenu {
    NSArray<NSString *> *names = [self availableIconNames];
    if (!names.count) return nil;

    NSString *current = [self currentIconName];
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];

    UIAction *defaultAction =
        [UIAction actionWithTitle:SCILocalized(@"appicon_default")
                            image:nil
                       identifier:nil
                          handler:^(__kindof UIAction *action) { [self applyIconNamed:nil]; }];
    defaultAction.state = (current == nil) ? UIMenuElementStateOn : UIMenuElementStateOff;
    [actions addObject:defaultAction];

    for (NSString *name in names) {
        UIAction *action =
            [UIAction actionWithTitle:name
                                image:[self previewForIconNamed:name]
                           identifier:nil
                              handler:^(__kindof UIAction *a) { [self applyIconNamed:name]; }];
        action.state = [name isEqualToString:current] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:action];
    }

    return [UIMenu menuWithTitle:SCILocalized(@"appicon_title") children:actions];
}

@end
