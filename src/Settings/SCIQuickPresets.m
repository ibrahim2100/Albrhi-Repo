#import "SCIQuickPresets.h"
#import "../Utils.h"
#import "../InstagramHeaders.h"
#import "../Localization/SCILocalize.h"
#import "../UI/SCIConfirmSheet.h"

@implementation SCIQuickPresets

+ (CGFloat)shortcutsHeight { return 74.0; }

// MARK: - The presets themselves

/// Each preset names only the switches it is about. Anything absent here is left
/// untouched, which is what keeps applying one from behaving like a reset.
+ (NSDictionary<NSString *, NSNumber *> *)valuesForPreset:(NSString *)preset {
    if ([preset isEqualToString:@"private"]) {
        return @{
            @"no_seen_receipt": @YES,
            @"disable_typing_status": @YES,
            @"remove_screenshot_alert": @YES,
            @"remove_lastseen": @YES,
            @"no_recent_searches": @YES,
            @"unlimited_replay": @YES
        };
    }

    if ([preset isEqualToString:@"clean"]) {
        return @{
            @"hide_ads": @YES,
            @"hide_meta_ai": @YES,
            @"no_suggested_users": @YES,
            @"no_suggested_post": @YES,
            @"no_suggested_reels": @YES,
            @"no_suggested_chats": @YES,
            @"hide_trending_searches": @YES,
            @"hide_notes_tray": @YES
        };
    }

    if ([preset isEqualToString:@"downloads"]) {
        return @{
            @"inline_download_button": @YES,
            @"story_download_button": @YES,
            @"dm_media_save_button": @YES,
            @"carousel_download_choice": @YES,
            @"dl_use_queue": @YES,
            @"dw_save_to_camera": @YES
        };
    }

    // "Quiet": every confirmation off, for someone who finds them in the way.
    return @{
        @"like_confirm": @NO,
        @"like_confirm_reels": @NO,
        @"post_comment_confirm": @NO,
        @"refresh_reel_confirm": @NO,
        @"call_confirm": @NO,
        @"shh_mode_confirm": @NO,
        @"sticker_interact_confirm": @NO,
        @"repost_confirm": @NO
    };
}

/// Applies a preset and returns how many switches actually changed, so the toast can
/// say something true rather than a blanket "done".
+ (NSInteger)applyPreset:(NSString *)preset {
    NSDictionary<NSString *, NSNumber *> *values = [self valuesForPreset:preset];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSInteger changed = 0;
    for (NSString *key in values) {
        BOOL wanted = values[key].boolValue;
        if ([SCIUtils getBoolPref:key] == wanted) continue;

        [defaults setBool:wanted forKey:key];
        changed++;
    }

    return changed;
}

// MARK: - The row

+ (UIView *)shortcutsViewWithWidth:(CGFloat)width {
    UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, [self shortcutsHeight])];
    scroller.showsHorizontalScrollIndicator = NO;
    scroller.alwaysBounceHorizontal = YES;

    NSArray<NSArray<NSString *> *> *presets = @[
        @[@"private",   @"lock.fill",              @"preset_private"],
        @[@"clean",     @"wand.and.stars",         @"preset_clean"],
        @[@"downloads", @"arrow.down.circle.fill", @"preset_downloads"],
        @[@"quiet",     @"bell.slash.fill",        @"preset_quiet"]
    ];

    CGFloat x = 16.0;
    for (NSArray<NSString *> *preset in presets) {
        UIButton *chip = [self chipWithSymbol:preset[1] title:SCILocalized(preset[2])];
        [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        chip.accessibilityIdentifier = preset[0];

        CGSize size = [chip sizeThatFits:CGSizeMake(CGFLOAT_MAX, 40)];
        CGFloat chipWidth = MAX(size.width + 28.0, 96.0);

        chip.frame = CGRectMake(x, 17.0, chipWidth, 40.0);
        [scroller addSubview:chip];

        x += chipWidth + 8.0;
    }

    scroller.contentSize = CGSizeMake(x + 8.0, [self shortcutsHeight]);
    return scroller;
}

+ (UIButton *)chipWithSymbol:(NSString *)symbol title:(NSString *)title {
    UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];

    chip.backgroundColor = [[SCIUtils SCIColor_Primary] colorWithAlphaComponent:0.14];
    chip.layer.cornerRadius = 20.0;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    chip.tintColor = [SCIUtils SCIColor_Primary];

    [chip setTitle:title forState:UIControlStateNormal];
    [chip setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    chip.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    [chip setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];

    chip.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    chip.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);

    return chip;
}

// MARK: - Tapping one

+ (void)chipTapped:(UIButton *)sender {
    NSString *preset = sender.accessibilityIdentifier;
    if (!preset.length) return;

    NSString *name = [sender titleForState:UIControlStateNormal] ?: @"";

    // Asked first: a preset moves several switches at once, and the whole point of
    // the shortcut is that the user has not read which.
    [SCIConfirmSheet presentWithTitle:[NSString stringWithFormat:SCILocalized(@"preset_confirm"), name]
                               symbol:@"slider.horizontal.3"
                              confirm:^{
        NSInteger changed = [self applyPreset:preset];

        [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
        [SCIUtils showToastForDuration:2.0
                                 title:[NSString stringWithFormat:SCILocalized(@"preset_applied"), (long)changed]];
    }
                               cancel:nil];
}

@end
