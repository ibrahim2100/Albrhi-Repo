//
//  SCILKMediaHooks.h
//  Albrhi for Locket
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks NSURLSession so every moment Locket fetches is remembered. Grouped and installed
/// from the constructor after the panel gate, like the bypass, so "off" means no hook.
void SCILKInstallMediaHooks(void);
