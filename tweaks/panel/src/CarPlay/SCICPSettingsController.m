#import "SCICPSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import "../SCIPanelDomain.h"
#import "../SCIPanelScan.h"
#import "../SCIPanelButtonAction.h"
#import "../Localization/SCILocalize.h"
#import "shared/src/SCICPPrefsKeys.h"

/// "app_enabled_com.albrhi.carplay" -- the exact key SCIPanelGate's SCIPanelAllowsApp
/// derives from the same identifier, so CarPlay's own %ctor and this switch agree on
/// what they are both asking about without either side spelling the whole key out.
static NSString *SCICPEnabledKey(void) {
    return [@"app_enabled_" stringByAppendingString:SCICPBundleIdentifier];
}

@interface SCICPSettingsController () <PHPickerViewControllerDelegate>
@end

@implementation SCICPSettingsController

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *masterGroup = [PSSpecifier preferenceSpecifierNamed:@""
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
    [masterGroup setProperty:SCILocalized(@"carplay_master_footer") forKey:@"footerText"];
    [specifiers addObject:masterGroup];

    PSSpecifier *master = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_master")
                                                          target:self
                                                             set:@selector(setEnabled:specifier:)
                                                             get:@selector(enabledForSpecifier:)
                                                          detail:Nil
                                                            cell:PSSwitchCell
                                                            edit:Nil];
    [specifiers addObject:master];

    PSSpecifier *audioGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_audio_section")
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSGroupCell
                                                               edit:Nil];
    [audioGroup setProperty:SCILocalized(@"carplay_audio_footer") forKey:@"footerText"];
    [specifiers addObject:audioGroup];

    PSSpecifier *audioFix = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_audio_fix")
                                                            target:self
                                                               set:@selector(setAudioFixOn:specifier:)
                                                               get:@selector(audioFixOnForSpecifier:)
                                                            detail:Nil
                                                              cell:PSSwitchCell
                                                              edit:Nil];
    [specifiers addObject:audioFix];

    PSSpecifier *micGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_mic_section")
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
    [micGroup setProperty:SCILocalized(@"carplay_mic_footer") forKey:@"footerText"];
    [specifiers addObject:micGroup];

    // Three switches acting as one three-way choice rather than a picker page: this
    // project's preference bundle only has PSSwitchCell proven to actually build and
    // work against the SDK this repository pins, and guessing at a private list-picker
    // class that has never been compiled here is exactly the mistake CLAUDE.md's ground
    // rules warn against. Selecting one clears the other two in -setMicOn:specifier:.
    for (NSArray<NSString *> *choice in @[
        @[@"iphone", @"carplay_mic_iphone"],
        @[@"car", @"carplay_mic_car"],
        @[@"automatic", @"carplay_mic_automatic"],
    ]) {
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:SCILocalized(choice[1])
                                                           target:self
                                                              set:@selector(setMicOn:specifier:)
                                                              get:@selector(micOnForSpecifier:)
                                                           detail:Nil
                                                             cell:PSSwitchCell
                                                             edit:Nil];
        [row setProperty:choice[0] forKey:@"sciMicValue"];
        [specifiers addObject:row];
    }

    PSSpecifier *wallpaperGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_wallpaper_section")
                                                                 target:self
                                                                    set:NULL
                                                                    get:NULL
                                                                 detail:Nil
                                                                   cell:PSGroupCell
                                                                   edit:Nil];
    [wallpaperGroup setProperty:SCILocalized(@"carplay_wallpaper_footer") forKey:@"footerText"];
    [specifiers addObject:wallpaperGroup];

    [specifiers addObject:[self valueRow:SCILocalized(@"carplay_wallpaper_status")
                                    value:[self wallpaperStatus]]];

    PSSpecifier *chooseWallpaper = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_wallpaper_choose")
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
    SCISetButtonAction(chooseWallpaper, @selector(chooseWallpaperImage));
    [specifiers addObject:chooseWallpaper];

    if ([NSFileManager.defaultManager fileExistsAtPath:SCICPWallpaperImagePath]) {
        PSSpecifier *clearWallpaper = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_wallpaper_clear")
                                                                      target:self
                                                                         set:NULL
                                                                         get:NULL
                                                                      detail:Nil
                                                                        cell:PSButtonCell
                                                                        edit:Nil];
        [clearWallpaper setProperty:@YES forKey:@"isDestructive"];
        SCISetButtonAction(clearWallpaper, @selector(clearWallpaperImage));
        [specifiers addObject:clearWallpaper];
    }

    PSSpecifier *bridgeGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_bridge_section")
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
    [bridgeGroup setProperty:SCILocalized(@"carplay_bridge_footer") forKey:@"footerText"];
    [specifiers addObject:bridgeGroup];

    [specifiers addObject:[self valueRow:SCILocalized(@"carplay_bridge_count")
                                    value:[self bridgedAppsSummary]]];

    PSSpecifier *editBridge = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"carplay_bridge_edit")
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSButtonCell
                                                                edit:Nil];
    SCISetButtonAction(editBridge, @selector(editBridgedApps));
    [specifiers addObject:editBridge];

    PSSpecifier *aboutGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_about")
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
    [aboutGroup setProperty:SCILocalized(@"carplay_about_footer") forKey:@"footerText"];
    [specifiers addObject:aboutGroup];

    [specifiers addObject:[self valueRow:SCILocalized(@"about_version")
                                    value:[self installedVersion]]];

    PSSpecifier *verbose = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"verbose_logging")
                                                           target:self
                                                              set:@selector(setVerboseOn:specifier:)
                                                              get:@selector(verboseOnForSpecifier:)
                                                           detail:Nil
                                                             cell:PSSwitchCell
                                                             edit:Nil];
    [specifiers addObject:verbose];

    // Not just returned: PSListController's own plumbing reads the _specifiers ivar
    // directly in places this override cannot reach, the same reason SCIPanelRoot.m's
    // -specifiers assigns it too. A subclass that only returns the array shows a blank
    // page -- the row pushes, the controller loads, and nothing it built ever appears.
    _specifiers = specifiers;
    return _specifiers;
}

// MARK: - Reading and writing

/// com.albrhi.carplay ships as its own package now, not inside the combined suite, so
/// its own dpkg entry -- rootless or roothide -- is what actually answers "what version
/// is on this phone."
- (NSString *)installedVersion {
    NSString *installed = [SCIPanelScan installedVersionForPackages:@[
        @"com.albrhi.carplay", @"com.albrhi.carplay.roothide"]];
    return installed.length ? installed : SCILocalized(@"versions_unknown");
}

- (id)fixedValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"value"] ?: @"";
}

- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:@selector(fixedValue:)
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"") forKey:@"value"];
    return row;
}

- (BOOL)sci_readBool:(NSString *)key fallback:(BOOL)fallback {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    if (!value) return fallback;

    BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : fallback;
    CFRelease(value);
    return result;
}

- (NSString *)sci_readString:(NSString *)key fallback:(NSString *)fallback {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    if (!value) return fallback;

    // __bridge, not __bridge_transfer: `result` is a strong local, so ARC retains it on
    // assignment regardless, and the CFRelease below is what balances the +1 this copy
    // call itself returned. Transferring ownership through the cast and then also
    // releasing would be a double release the one time the type check fails.
    NSString *result = (CFGetTypeID(value) == CFStringGetTypeID())
        ? (__bridge NSString *)value : fallback;
    CFRelease(value);
    return result;
}

- (void)sci_writeBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value),
                             (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelPreferenceDomain);
}

- (void)sci_writeString:(NSString *)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelPreferenceDomain);
}

// MARK: - Master switch

- (id)enabledForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:SCICPEnabledKey() fallback:YES]);
}

- (void)setEnabled:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    [self sci_writeBool:value.boolValue forKey:SCICPEnabledKey()];
    [self showRestartNote];
}

// MARK: - Audio fix

- (id)audioFixOnForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:SCICPAudioFixKey fallback:YES]);
}

- (void)setAudioFixOn:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    [self sci_writeBool:value.boolValue forKey:SCICPAudioFixKey];
}

// MARK: - Preferred microphone

- (id)micOnForSpecifier:(PSSpecifier *)specifier {
    NSString *stored = [self sci_readString:SCICPPreferredMicKey fallback:@"iphone"];
    return @([stored isEqualToString:[specifier propertyForKey:@"sciMicValue"]]);
}

- (void)setMicOn:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    // Turning one off directly is not a choice among the three -- there is always
    // exactly one selected -- so only a tap that turns one *on* does anything.
    if (!value.boolValue) {
        [self reloadSpecifiers];
        return;
    }

    [self sci_writeString:[specifier propertyForKey:@"sciMicValue"] forKey:SCICPPreferredMicKey];
    [self reloadSpecifiers];
}

// MARK: - Wallpaper

- (NSString *)wallpaperStatus {
    return [NSFileManager.defaultManager fileExistsAtPath:SCICPWallpaperImagePath]
        ? SCILocalized(@"carplay_wallpaper_set") : SCILocalized(@"carplay_wallpaper_none");
}

- (void)chooseWallpaperImage {
    PHPickerConfiguration *config =
        [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker
    didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:UIImage.class]) return;

    __weak SCICPSettingsController *weakSelf = self;
    [provider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image, NSError *error) {
        if (![image isKindOfClass:UIImage.class]) return;

        // Re-encoded rather than the original file's own bytes: a HEIC or PNG straight
        // from Photos is exactly what SCICPWallpaperOverride does not need to guess
        // about decoding inside a hidden system app's process -- one predictable
        // format on the read side, chosen here where UIKit already has the decoded
        // image in hand.
        NSData *jpeg = UIImageJPEGRepresentation(image, 0.9);
        if (!jpeg) return;

        NSError *writeError = nil;
        BOOL wrote = [jpeg writeToFile:SCICPWallpaperImagePath
                                options:NSDataWritingAtomic
                                  error:&writeError];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (wrote) {
                [weakSelf reloadSpecifiers];
            } else {
                [weakSelf sayWallpaperSaveFailed:writeError];
            }
        });
    }];
}

- (void)clearWallpaperImage {
    [NSFileManager.defaultManager removeItemAtPath:SCICPWallpaperImagePath error:nil];
    [self reloadSpecifiers];
}

- (void)sayWallpaperSaveFailed:(NSError *)error {
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"carplay_wallpaper_choose")
                                            message:error.localizedDescription ?: @"?"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

// MARK: - Bridged apps

/// The stored list is comma-separated for editing; parsed and re-joined here rather
/// than trusted verbatim, so a stray blank entry from "one, ,two" never becomes a
/// bundle identifier the admission spoof tries to answer for.
- (NSArray<NSString *> *)bridgedBundleIdentifiers {
    NSString *raw = [self sci_readString:SCICPBridgedAppsKey fallback:@""];
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (NSString *entry in [raw componentsSeparatedByString:@","]) {
        NSString *trimmed = [entry stringByTrimmingCharactersInSet:
                              NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length) [identifiers addObject:trimmed];
    }
    return identifiers;
}

- (NSString *)bridgedAppsSummary {
    NSUInteger count = self.bridgedBundleIdentifiers.count;
    return count ? [NSString stringWithFormat:@"%lu", (unsigned long)count]
                 : SCILocalized(@"carplay_bridge_none");
}

- (void)editBridgedApps {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:SCILocalized(@"carplay_bridge_edit")
                          message:SCILocalized(@"carplay_bridge_edit_message")
                   preferredStyle:UIAlertControllerStyleAlert];

    NSString *current = [self.bridgedBundleIdentifiers componentsJoinedByString:@", "];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = current;
        field.placeholder = @"com.example.app, com.example.other";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    __weak SCICPSettingsController *weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSString *text = sheet.textFields.firstObject.text ?: @"";
        [weakSelf sci_writeString:text forKey:SCICPBridgedAppsKey];
        [weakSelf reloadSpecifiers];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:sheet animated:YES completion:nil];
}

// MARK: - Verbose logging

- (id)verboseOnForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:SCICPVerboseLoggingKey fallback:NO]);
}

- (void)setVerboseOn:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    [self sci_writeBool:value.boolValue forKey:SCICPVerboseLoggingKey];
}

// MARK: -

- (void)showRestartNote {
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"carplay_master")
                                            message:SCILocalized(@"switch_restart")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"carplay_title");
}

@end
