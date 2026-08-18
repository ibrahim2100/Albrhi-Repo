//
//  SCITTPlaybackProbe.x
//  Albrhi for TikTok
//
//  Reading a method's real signature before anyone hooks it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITTPlaybackProbe.h"

static NSString *sciEncoding = nil;

///
/// **No hook. This reads a type encoding and nothing else.**
///
/// 0.15.1 hooked `AWEVideoPlayBitrateControler`'s selection method with a signature invented
/// from the selector name — `(double)duration`, `(NSInteger)trategyType`, returning `id` — and
/// TikTok crashed repeatedly. Arguments of the wrong width arrive in the wrong registers; there
/// is no polite failure. `class_getInstanceMethod` returning non-NULL proves the selector
/// exists and says nothing whatever about its types.
///
/// So the missing step is taken on its own, with no hook installed and therefore no way to
/// crash: `method_getTypeEncoding` gives the real signature, and the settings screen prints it.
/// A future release can then declare exactly that and refuse to install on any mismatch.
///
/// **Why this is still worth asking.** 0.16.0 tried to reach the player's ladder without a hook
/// by reading `__playBSModel` and its siblings off the video model — and the device answered
/// that each returns a *single* gear at the same low bitrate as `bitrateModels`, not the
/// four-times-larger list the player is handed. The high-bitrate models are not on the object
/// this tweak holds, so the only place they have ever been observed is that method's argument.
void SCITTInstallPlaybackProbe(void) {
    Class controller = NSClassFromString(@"AWEVideoPlayBitrateControler");
    if (!controller) {
        sciEncoding = @"AWEVideoPlayBitrateControler is not in this build";
        return;
    }

    SEL selector = NSSelectorFromString(
        @"willSelectBitrateFromModels:duration:trategyType:autoBitrateModel:");

    Method method = class_getInstanceMethod(controller, selector);
    if (!method) {
        sciEncoding = @"the class is here; that selector is not on it";
        return;
    }

    const char *encoding = method_getTypeEncoding(method);
    sciEncoding = encoding
        ? [NSString stringWithFormat:@"%s (%u args)", encoding, method_getNumberOfArguments(method)]
        : @"the method is here and reports no type encoding";
}

NSString *SCITTPlaybackReport(void) {
    return sciEncoding ?: @"not read yet this launch";
}
