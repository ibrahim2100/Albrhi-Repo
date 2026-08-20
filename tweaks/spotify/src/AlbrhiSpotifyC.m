//
//  AlbrhiSpotifyC.m
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "Localization/SCILocalize.h"

#import <Orion/Orion.h>

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#else
#import <libroot.h>
#endif

///
/// **Orion does not start itself, and a tweak that never starts it hooks nothing at all.**
///
/// This was found before it shipped, by asking the built dylib rather than trusting the build: the
/// link succeeded, the package installed cleanly, and `nm` reported no `orion_init` and no module
/// initialiser anywhere in it. Every hook in this tweak would have been dead — the dylib loading,
/// logging its version, reading its switches and doing nothing, which is exactly the silent failure
/// this project has spent whole releases chasing in other tweaks.
///
/// The reference tweak calls it from a constructor of its own for the same reason, which is what
/// prompted the check. A build succeeding is not a hook being installed.
///
///
/// The two C helpers the ported SponsorBlock calls, kept under their original names so those files
/// stay diffable against upstream — the same decision Albrhi NextUp made about its own copy.
///
NSString *EeveeJBRootPath(NSString *path) {
#if THEOS_PACKAGE_SCHEME_ROOTHIDE
    return jbroot(path);
#else
    return JBROOT_PATH_NSSTRING(path);
#endif
}

/// A seek call whose argument is a `double`. Sent through a typed function pointer rather than a
/// bare `objc_msgSend` cast, for the reason this project crashed TikTok over twice: a message sent
/// through the wrong prototype puts the argument in the wrong register.
void EeveeSBInvokeSeekDouble(id target, SEL selector, double argument) {
    if (!target || !selector) return;
    typedef id (*SCISeekFunction)(id, SEL, double);
    SCISeekFunction send = (SCISeekFunction)objc_msgSend;
    (void)send(target, selector, argument);
}

__attribute__((constructor)) static void SCISpotifyStartOrion(void) {
    @try {
        orion_init();
        NSLog(@"[AlbrhiSpotify] Orion started");
    } @catch (NSException *exception) {
        // A tweak that cannot start its own runtime must not take Spotify down with it. It has
        // nothing to hook with at that point, and doing nothing is the correct amount of damage.
        NSLog(@"[AlbrhiSpotify] Orion refused to start: %@", exception);
    }
}
