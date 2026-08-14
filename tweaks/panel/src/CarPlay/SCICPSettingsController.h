#import <Preferences/PSListController.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Albrhi CarPlay's own settings page, pushed to from the single "Albrhi CarPlay" row
/// in the root list -- see SCIPanelScan's SCIPanelGroupIdentifier/SCIPanelDetailController
/// handling for why that row exists instead of the usual one-switch-per-app row.
///
/// CarPlay is one dylib loaded into two unrelated system processes, SpringBoard and
/// Camera, so its settings do not fit the shape every other row on the root page uses:
/// a master on/off, a recording-audio toggle and a three-way microphone choice are three
/// separate answers, and one switch cell only ever holds one.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCICPSettingsController : PSListController
@end

NS_ASSUME_NONNULL_END
