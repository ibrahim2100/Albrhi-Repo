#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key the
/// settings screen writes. Here they are constants, so a mistake is a compile error.
///

/// Whether the switch layer is hooked at all.
///
/// On, because with it off this release does nothing whatsoever -- there is no second
/// feature to fall back to. It exists so that a build of X where the hook causes trouble
/// can be made ordinary again from the settings screen rather than by uninstalling.
#define SCIPrefSwitchLayer      @"switch_layer"

/// The user's own answers, key to boolean. Written by the settings screen and read once
/// at launch; the shape is a dictionary rather than one preference per key because the
/// key names come from X and there is no list of them to declare in advance.
#define SCIPrefOverrides        @"switch_overrides"

/// There is deliberately no preference for the two-finger hold.
///
/// It is the only way into this tweak's own screen, and a switch that can make the only
/// way in disappear is a switch that strands people -- the panel in Settings offers "off
/// for this app" and nothing finer, so there would be nowhere to turn it back on from.
/// Two fingers held for two thirds of a second is rare enough in a scrolling app to not
/// need one.

#define SCIPrefVerboseLogging   @"verbose_logging"
