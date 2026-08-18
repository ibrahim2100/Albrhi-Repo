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

///
/// The class that carries a post's watermark decision.
///
/// Confirmed present in TikTok 46.4.0 by reading MusicallyCore's own class metadata: it
/// declares `watermarkType` (an unsigned integer) with a setter, and `AWEAwemeModel` declares
/// `allowDownloadWithoutWatermark` and `preventDownload` beside it. NA9 hooks the same setter,
/// which is a second confirmation of the target rather than the source of it.
@interface AWEAwemeACLItem : NSObject
@property (nonatomic, assign) NSUInteger watermarkType;
@end

static NSUInteger sciForced = 0;
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
    return [NSString stringWithFormat:@"attached — %lu cleared", (unsigned long)sciForced];
}
