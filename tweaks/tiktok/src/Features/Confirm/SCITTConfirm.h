//
//  SCITTConfirm.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Installs the confirmation hooks. Every one of them passes straight through when its own switch
/// is off, so this is safe to install unconditionally and the switches decide behaviour at tap time
/// rather than at launch.
void SCITTInstallConfirm(void);

/// What the confirmations have done this launch: asked, allowed, cancelled -- and which hook points
/// attached at all, since a confirmation nobody sees has those two very different causes.
NSString *SCITTConfirmReport(void);
