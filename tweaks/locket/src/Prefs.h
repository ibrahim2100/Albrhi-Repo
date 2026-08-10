#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that silently
/// never turns on. Here they are constants, so a mistake is a compile error.
///

/// Whether the bypass runs at all.
///
/// On, because with it off this tweak does nothing — there is no second feature. It exists
/// so a build of Locket where a hook causes trouble can be made ordinary again from the
/// settings screen rather than by uninstalling.
#define SCIPrefBypass           @"bypass"

/// Whether moments Locket fetches are remembered so they can be saved.
///
/// On by default. Independent of the bypass: saving a moment a friend sent you and hiding
/// the jailbreak from analytics are two different things, and turning one off to rule it
/// out of a problem should not take the other with it.
#define SCIPrefSaveMoments      @"save_moments"

#define SCIPrefVerboseLogging   @"verbose_logging"
