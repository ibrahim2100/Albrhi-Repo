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

#define SCIPrefVerboseLogging   @"verbose_logging"
