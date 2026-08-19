//
//  SCIWUpdateGuard.h
//  Albrhi Watch
//

#import <Foundation/Foundation.h>

/// Installs the update hold, **only if the runtime agrees with what the hooks were written for**.
void SCIWInstallUpdateGuard(void);

/// Whether the hold is installed, and if not, why. For the settings page.
NSString *SCIWUpdateGuardReport(void);
