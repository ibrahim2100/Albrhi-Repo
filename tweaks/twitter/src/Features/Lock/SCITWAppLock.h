//
//  SCITWAppLock.h
//  Albrhi for X
//
//  Face ID, or the device passcode, before X shows anything.
//
//  **A cover view first, then the prompt.** The order matters: asking for Face ID and
//  waiting leaves whatever was last on screen visible in the app switcher and for the
//  moment before the sheet appears. The cover goes up in `-applicationDidBecomeActive:`,
//  before anything else, and only comes down when LocalAuthentication says yes.
//
//  **It never locks anybody out of their own phone.** A device with no passcode and no
//  biometry cannot answer the prompt at all, so the policy asked for is
//  `DeviceOwnerAuthentication` -- biometry *or* passcode -- and a device that can evaluate
//  neither is let through rather than left staring at a cover it cannot dismiss.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWAppLockReport(void);
void SCITWInstallAppLock(void);
