//
//  SCITTWatermark.x
//  Albrhi for TikTok
//
//  Answering TikTok's own watermark question, at the object that decides it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCITTWatermark.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import "../../TikTokHeaders.h"

///
/// The class that carries a post's watermark decision.
///
/// Confirmed present in TikTok 46.4.0 by reading MusicallyCore's own class metadata: it
/// declares `watermarkType` (an unsigned integer) with a setter, and `AWEAwemeModel` declares
/// `allowDownloadWithoutWatermark` and `preventDownload` beside it. NA9 hooks the same setter,
/// which is a second confirmation of the target rather than the source of it.
@interface AWEAwemeACLItem : NSObject
// Declared as a method, not a property: the hook below overrides the getter by that name, and
// a @property here would make the two the same declaration twice over.
- (NSUInteger)watermarkType;
@end

//
// `AWEAwemeModel` comes from TikTokHeaders.h, which every file here already shares.
//
// **The permission flags' names differ from what the references use, and that matters.** NA9
// hooks `-canDownload` and `-isPreventDownload`; neither is on this class in 46.4.0. This build
// declares `preventDownload` and `disableDownload`, confirmed from its own class metadata --
// the same "a working tweak's selectors are not your build's" trap this project has now hit
// four times.

static NSUInteger sciForced = 0;
static NSUInteger sciPermitted = 0;
static BOOL sciAttached = NO;

%group Watermark

%hook AWEAwemeACLItem

- (void)setWatermarkType:(NSUInteger)type {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) {
        %orig;
        return;
    }

    // Zero is "no watermark". Forced at the setter rather than at the getter because the app
    // reads this value through more than one path, and a stored zero is true for all of them
    // while a lying getter is only true for the callers that go through it -- the same lesson
    // the YouTube tweak paid for with `-bypassOnesie`.
    sciForced++;
    %orig(0);
}

- (NSUInteger)watermarkType {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return %orig;

    // Both ends, because NA9 hooks both and the reason is sound: the setter covers every
    // reader of the stored value, but a value TikTok never sets keeps whatever it decoded from
    // the response. Answering the getter as well costs nothing and closes that case.
    return 0;
}

%end

%hook AWEAwemeModel

- (BOOL)preventDownload {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return %orig;
    sciPermitted++;
    return NO;
}

- (BOOL)disableDownload {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return %orig;
    sciPermitted++;
    return NO;
}

%end

%end

void SCITTInstallWatermarkHooks(void) {
    if (!NSClassFromString(@"AWEAwemeACLItem")) {
        SCILogV(@"watermark: AWEAwemeACLItem is not in this build");
        return;
    }

    %init(Watermark);
    sciAttached = YES;
}

NSString *SCITTWatermarkReport(void) {
    if (!sciAttached) return @"AWEAwemeACLItem is not in this build";
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return @"attached, download switched off";
    return [NSString stringWithFormat:@"attached — %lu cleared, %lu permitted",
            (unsigned long)sciForced, (unsigned long)sciPermitted];
}
