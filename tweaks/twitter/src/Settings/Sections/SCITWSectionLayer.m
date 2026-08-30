#import "../Model/SCITWSectionRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// The switch layer, first on the screen and drawn as the heading it is.
///
/// **It was at the bottom, under Advanced, and that was the wrong way round.** Every other
/// section is a thing you choose; this one decides whether a whole section of the screen
/// exists at all — turn it off and the feature list is not disabled, it is *gone*, because
/// its rows would be switches that decide nothing. A control that governs what is below it
/// has no business being below it.
///
/// Its own section rather than a row inside another, so nothing sits beside it and the
/// footer underneath belongs to it alone.
///
@interface SCITWSectionLayer : NSObject
@end

@implementation SCITWSectionLayer

+ (void)load {
    // Order 1: ahead of the captured media at 5, which is otherwise first.
    [SCITWSectionRegistry registerBuilderWithOrder:1 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        SCITWRow *layer = [SCITWRow switchRow:SCILocalized(@"albrhi_switch_layer")
                                         note:SCILocalized(@"layer_row_note")
                                       symbol:@"switch.2"
                                         tint:[UIColor systemPurpleColor]
                                      prefKey:SCIPrefSwitchLayer];
        layer.prominent = YES;

        return @[[SCITWSection titled:nil
                               footer:SCILocalized(@"albrhi_switch_layer_note")
                                 rows:@[layer]]];
    }];
}

@end
