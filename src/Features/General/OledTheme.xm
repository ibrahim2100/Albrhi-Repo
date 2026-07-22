#import "../../Utils.h"
#import "../../InstagramHeaders.h"

///
/// Pure-black theming for OLED screens.
///
/// Written from scratch rather than adapted from an existing OLED tweak: the ones
/// published for Instagram carry no licence, so their code cannot be reused in a
/// GPLv3 project. The behaviour is not theirs to own, only the code.
///
/// The approach deliberately avoids naming Instagram classes, which change every
/// release. Instagram's dark theme is built from a handful of very dark greys; any
/// view given one of them is asked to use pure black instead. That covers surfaces
/// the tweak has never heard of, and leaves everything else untouched.
///

/// Read once, not per call: -setBackgroundColor: runs constantly during scrolling,
/// and hitting NSUserDefaults each time would be felt. The settings row states that
/// the toggle needs a restart, which is what makes caching correct here.
static BOOL SCIOledEnabled(void) {
    static BOOL enabled = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ enabled = [SCIUtils getBoolPref:@"oled_theme"]; });
    return enabled;
}

/// Whether a colour is one of Instagram's dark-theme backgrounds — near-black,
/// unsaturated and opaque. Bright colours, accents and translucency are left
/// alone, so avatars, buttons and images are unaffected.
static BOOL SCIIsDarkChrome(UIColor *color) {
    if (!color) return NO;

    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;

    if (a < 0.95) return NO;                            // translucent overlays keep their look
    if (r > 0.16 || g > 0.16 || b > 0.16) return NO;    // not a dark surface

    // Grey, not a dark tint of some colour: all channels close together.
    CGFloat maximum = MAX(r, MAX(g, b));
    CGFloat minimum = MIN(r, MIN(g, b));
    if (maximum - minimum > 0.04) return NO;

    // Already black — nothing to do, and skipping avoids pointless work.
    return maximum > 0.001;
}

%hook UIView

- (void)setBackgroundColor:(UIColor *)color {
    if (SCIOledEnabled() && SCIIsDarkChrome(color)) {
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}

%end

// Table and collection views set their background through their own override on
// reuse and reload, which would otherwise put Instagram's grey back.
%hook UITableView

- (void)setBackgroundColor:(UIColor *)color {
    if (SCIOledEnabled() && SCIIsDarkChrome(color)) {
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}

%end

%hook UICollectionView

- (void)setBackgroundColor:(UIColor *)color {
    if (SCIOledEnabled() && SCIIsDarkChrome(color)) {
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}

%end
