//
//  SCIPanelHelper.h
//  Albrhi Panel
//
//  Calling the one part of this that runs as root.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Whether the helper is installed and actually setuid root.
///
/// Both halves are checked, because they fail differently and only one of them is
/// visible: a missing helper is a packaging fault, and a helper that is present without
/// the setuid bit is a postinst that did not run — which happens when a package manager
/// installs without running maintainer scripts. Either way every switch would fail, so
/// the panel asks first and says so rather than letting a switch flip back silently.
BOOL SCIPanelHelperReady(void);

/// Adds or removes one bundle identifier from one tweak's filter.
///
/// Returns NO and fills `error` with the helper's own exit code on failure. The helper
/// refuses far more than it accepts, and its refusals are the security design rather than
/// bugs — see helper/main.m.
BOOL SCIPanelSetTweak(NSString *filterFileName,
                      NSString *bundleIdentifier,
                      BOOL enabled,
                      NSError *_Nullable *_Nullable error);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
