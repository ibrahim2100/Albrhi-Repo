//
//  SCITTPlaybackProbe.x
//  Albrhi for TikTok
//
//  Reading the ladder from where the player sees it, rather than where we happen to catch it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTPlaybackProbe.h"
#import "../../SCILog.h"

///
/// TikTok's own gear picker.
///
/// **This exists because every gear this tweak has ever seen was named `lower` or `lowest`** —
/// not one `normal_720`, not one `adapt_higher_` — across every device report. Either that is
/// the whole ladder, or `bitrateModels` is a filtered subset and the player is handed something
/// larger. `AWEVideoPlayBitrateControler` is where the app chooses, so it is where the question
/// is answerable; `_HDRBitrateFilterGears` and `bitrateFilterList` on the video model say a
/// filter exists at all.
///
/// Observation only. It records what passes through and changes nothing — the download path is
/// untouched by this file, deliberately, because two releases were spent acting on inferences
/// that a single measurement would have settled first.
@interface AWEVideoPlayBitrateControler : NSObject
@end

static NSString *sciOffered = nil;
static NSString *sciChosen = nil;
static BOOL sciAttached = NO;

static NSString *SCITTDescribeGear(id entry) {
    if (!entry) return @"nil";

    NSString *gear = nil;
    SEL gearSel = NSSelectorFromString(@"gearName");
    if ([entry respondsToSelector:gearSel]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(entry, gearSel);
        if ([value isKindOfClass:[NSString class]]) gear = value;
    }

    id rate = nil;
    SEL rateSel = NSSelectorFromString(@"bitrate");
    if ([entry respondsToSelector:rateSel]) {
        rate = ((id (*)(id, SEL))objc_msgSend)(entry, rateSel);
    }

    // The audio the gear points at, which is the other half of the complaint: the app plays a
    // separate stream and the muxed file we download carries whatever audio was baked into it.
    NSString *audio = @"no selectedAudio";
    SEL audioSel = NSSelectorFromString(@"selectedAudio");
    if ([entry respondsToSelector:audioSel]) {
        id selected = ((id (*)(id, SEL))objc_msgSend)(entry, audioSel);
        if (selected) {
            SEL metaSel = NSSelectorFromString(@"audioMeta");
            id meta = [selected respondsToSelector:metaSel]
                ? ((id (*)(id, SEL))objc_msgSend)(selected, metaSel) : nil;

            id audioRate = nil;
            SEL bitrateSel = NSSelectorFromString(@"bitrate");
            if ([meta respondsToSelector:bitrateSel]) {
                audioRate = @(((long long (*)(id, SEL))objc_msgSend)(meta, bitrateSel));
            }

            SEL mapSel = NSSelectorFromString(@"urlMap");
            id map = [meta respondsToSelector:mapSel]
                ? ((id (*)(id, SEL))objc_msgSend)(meta, mapSel) : nil;

            audio = [NSString stringWithFormat:@"audio %@ bps, urlMap %@",
                     audioRate ?: @"?",
                     [map isKindOfClass:[NSDictionary class]] && [map count] ? @"present" : @"empty"];
        }
    }

    return [NSString stringWithFormat:@"%@ @ %@ (%@)", gear ?: @"?", rate ?: @"?", audio];
}

%group Probe

%hook AWEVideoPlayBitrateControler

- (id)willSelectBitrateFromModels:(NSArray *)models
                         duration:(double)duration
                     trategyType:(NSInteger)type
                 autoBitrateModel:(id)autoModel {
    id picked = %orig;

    @try {
        NSMutableArray<NSString *> *described = [NSMutableArray array];
        for (id entry in models) [described addObject:SCITTDescribeGear(entry)];

        sciOffered = [NSString stringWithFormat:@"%lu offered: %@",
                      (unsigned long)models.count,
                      [described componentsJoinedByString:@", "]];
        sciChosen = SCITTDescribeGear(picked);
    } @catch (NSException *exception) {
        SCILogV(@"playback probe: %@", exception.reason);
    }

    return picked;
}

%end

%end

void SCITTInstallPlaybackProbe(void) {
    Class controller = NSClassFromString(@"AWEVideoPlayBitrateControler");
    if (!controller) {
        SCILogV(@"playback probe: AWEVideoPlayBitrateControler is not in this build");
        return;
    }

    // The selector's real spelling includes the app's own typo, `trategyType`. Checked rather
    // than assumed: a %hook on a method a class does not have attaches nothing and reports
    // nothing, which would read here as "the player never selects".
    if (!class_getInstanceMethod(controller,
            NSSelectorFromString(@"willSelectBitrateFromModels:duration:trategyType:autoBitrateModel:"))) {
        SCILogV(@"playback probe: the selection method is not on this class");
        return;
    }

    %init(Probe);
    sciAttached = YES;
}

NSString *SCITTPlaybackReport(void) {
    if (!sciAttached) return @"not attached — the player's own picker was not found";
    if (!sciOffered) return @"attached, nothing selected yet this launch";
    return [NSString stringWithFormat:@"%@ — player took %@", sciOffered, sciChosen ?: @"?"];
}
