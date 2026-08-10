//
//  SCILKBypass.h
//  Albrhi for Locket
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Installs every jailbreak-detection hook: the filesystem primitives, the Foundation and
/// UIKit checks, the environment reads, and OneSignal's own answer if that class is in the
/// build. Called once, from the constructor, after the panel switch has been consulted.
void SCILKInstallBypass(void);
