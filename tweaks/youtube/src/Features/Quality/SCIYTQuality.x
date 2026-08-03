#import <UIKit/UIKit.h>
#import <Network/Network.h>
#import <objc/message.h>
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../YouTubeHeaders.h"

///
/// Two things about quality, sharing a file because they are the same question asked twice.
///
/// **A ceiling per connection.** YouTube picks a resolution from what it thinks the network
/// can carry, and on a phone that judgement is made without knowing that the connection is
/// metered and the plan is small. The ceiling is a resolution, applied by handing the
/// player item an MLResolutionCappedFormatConstraint -- YouTube's own mechanism, the one
/// its own quality menu uses, taking a single integer. Nothing about codecs or itags is
/// decided here, which is the point: a cap says how big, and lets the app go on choosing
/// how.
///
/// **The full quality list back.** Newer builds replace the list of resolutions with a
/// two-line quick menu, and the switch that decides which appears is a config flag the app
/// asks itself for. Answering NO gives back the list.
///
/// Both hooks are on the model layer, which is where this project prefers to be. A format
/// list and a config flag are not views and do not get renamed for a redesign.
///

/// What the connection is, kept current rather than asked for.
///
/// Asked for at the moment a video starts, the answer arrives too late to use -- and asking
/// the reachability API on the main thread during playback setup is exactly the sort of
/// thing that shows. The monitor pushes changes instead, so reading it is reading a
/// variable.
static BOOL sciOnCellular = NO;
static BOOL sciKnowsNetwork = NO;

static void SCIWatchNetwork(void) {
    static nw_path_monitor_t monitor = nil;
    if (monitor) return;

    monitor = nw_path_monitor_create();
    nw_path_monitor_set_queue(monitor, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));

    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        sciOnCellular = nw_path_uses_interface_type(path, nw_interface_type_cellular);
        sciKnowsNetwork = YES;
        SCILogV(@"quality: on %@", sciOnCellular ? @"cellular" : @"wi-fi");
    });

    nw_path_monitor_start(monitor);
}

/// The ceiling that applies right now, or 0 for none.
static NSInteger SCICurrentCap(void) {
    // Before the first answer arrives, the Wi-Fi ceiling is the one used. Guessing cellular
    // would cap someone at home for the first video of every launch, and the two mistakes
    // are not equally annoying.
    NSString *key = (sciKnowsNetwork && sciOnCellular) ? SCIPrefCapCellular : SCIPrefCapWiFi;
    return SCIPrefNumber(key);
}


%hook MLHAMPlayerItem

- (void)onSelectableVideoFormats:(id)formats {
    %orig;

    NSInteger cap = SCICurrentCap();
    if (cap <= 0) return;

    Class capped = NSClassFromString(@"MLResolutionCappedFormatConstraint");
    SEL make = NSSelectorFromString(@"initWithResolutionCap:");
    if (!capped) {
        SCILogV(@"quality: no MLResolutionCappedFormatConstraint on this build");
        return;
    }

    @try {
        // -initWithResolutionCap: is the whole of it. The constraint is what the app's own
        // quality menu hands the player, so everything downstream -- the ladder, the codec
        // choice, the switch mid-playback -- stays YouTube's.
        //
        // Sent through a cast objc_msgSend rather than -performSelector:withObject:, which
        // takes an object and would hand a resolution over as a pointer. This project has
        // already crashed once on the mirror image of that mistake, reading a number as an
        // object in 0.8.3; the cast states the argument is an integer and is checked.
        id constraint = ((id (*)(id, SEL, NSInteger))objc_msgSend)([capped alloc], make, cap);
        if (constraint) self.videoFormatConstraint = constraint;
    } @catch (NSException *exception) {
        SCILogV(@"quality: cap refused — %@", exception.reason);
    }
}

%end


%hook YTIMediaQualitySettingsHotConfig

- (BOOL)enableQuickMenuVideoQualitySettings {
    BOOL original = %orig;

    if (SCIPrefEnabled(SCIPrefClassicQuality)) return NO;
    return original;
}

%end


%ctor {
    SCIWatchNetwork();
}
