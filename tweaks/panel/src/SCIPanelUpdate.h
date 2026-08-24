//
//  SCIPanelUpdate.h
//  Albrhi Panel
//
//  Is there a newer Albrhi than the one installed?
//
//  **Asked on a tap, never on its own.** This is the only code in the panel that touches the
//  network, and a page that phones home when it opens is a page that decided for its user. The
//  address is Albrhi's own source and nothing else -- the same line this project keeps when it
//  refuses to send what somebody is watching to a service that has no business knowing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// What the installed suite is, read from dpkg's own status file. Nil when no Albrhi package is
/// registered there -- which is the truth on a sideloaded device and is not an error.
NSString *_Nullable SCIPanelInstalledSuiteVersion(void);

/// Asks the source for its newest published suite version. The completion runs on the main
/// queue with the version and whether it is newer than what is installed; a nil version means
/// the question could not be answered, which is deliberately distinct from "you are up to date".
void SCIPanelCheckForUpdate(void (^completion)(NSString *_Nullable latest,
                                               NSString *_Nullable installed,
                                               BOOL newer));

NS_ASSUME_NONNULL_END
