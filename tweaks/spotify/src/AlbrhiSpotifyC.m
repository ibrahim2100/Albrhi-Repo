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
