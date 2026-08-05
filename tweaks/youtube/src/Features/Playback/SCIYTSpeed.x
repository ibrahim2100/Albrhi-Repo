#import "../../YouTubeHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// Speeds past two.
///
/// YouTube's menu stops at 2×. For a recorded lecture or a long interview that is the
/// difference between watching it and not, and the app's own machinery already supports any
/// rate — the ceiling is in the list of options, not in the player.
///
/// The list is built by handing options to
///
///     YTVarispeedSwitchControllerImpl  -addActionForOption:      v24@0:8@16
///
/// and an option is a plain pair,
///
///     YTVarispeedSwitchControllerOption  -initWithTitle:rate:    @28@0:8@16f24
///                                                          ^^^ float, not double
///
/// so the extra rates are real options of YouTube's own class. Whatever the delegate does
/// with a chosen rate, it does with ours for the same reason it does with 1.5×; nothing here
/// reimplements the switch.
///
/// **Once per menu, not once per launch.** The guard is cleared by -reset, which is what the
/// controller calls before rebuilding its list. If a future build stops calling it, the
/// worst case is that the extra rates appear once and then stop appearing — a feature that
/// goes quiet, not a menu that grows a duplicate every time it is opened.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///

/// Beyond YouTube's own 0.25 … 2. Kept short on purpose: a speed menu long enough to scroll
/// is worse than one that stops too early.
static NSArray<NSNumber *> *SCIExtraRates(void) {
    return @[@2.25f, @2.5f, @3.0f, @4.0f];
}

/// "2.5×", and "3×" rather than "3.0×".
///
/// Formatted here rather than taken from YouTube's own labels because there are none to take
/// — these rates have never had a row.
static NSString *SCIRateTitle(float rate) {
    if (fabsf(rate - roundf(rate)) < 0.001f) {
        return [NSString stringWithFormat:@"%.0f×", (double)rate];
    }
    return [NSString stringWithFormat:@"%.2f×", (double)rate];
}


%hook YTVarispeedSwitchControllerImpl

/// Whether this menu has already been given the extra rows.
%property (nonatomic, assign) BOOL sciAddedExtraRates;

- (void)reset {
    %orig;
    self.sciAddedExtraRates = NO;
}

- (void)showMenuFromView:(id)view {
    if (SCIPrefEnabled(SCIPrefExtraSpeeds) && !self.sciAddedExtraRates) {
        Class optionClass = NSClassFromString(@"YTVarispeedSwitchControllerOption");

        if (optionClass) {
            self.sciAddedExtraRates = YES;

            for (NSNumber *rate in SCIExtraRates()) {
                float value = rate.floatValue;
                YTVarispeedSwitchControllerOption *option =
                    [[optionClass alloc] initWithTitle:SCIRateTitle(value) rate:value];

                if (option) [self addActionForOption:option];
            }

            SCILogV(@"[speed] added %lu extra rates", (unsigned long)SCIExtraRates().count);
        } else {
            SCILogV(@"[speed] YTVarispeedSwitchControllerOption absent — menu left alone");
        }
    }

    %orig;
}

%end
