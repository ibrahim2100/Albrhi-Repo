//
//  TikTokHeaders.h
//  Albrhi for TikTok
//
//  Every TikTok class this tweak touches, declared once.
//
//  Confirmed real on TikTok 46.4.0 by scanning MusicallyCore.framework directly —
//  Mach-O sections read by hand, the same way every other private class in this
//  project is confirmed, not read out of BHTikTok's own source and trusted. Two
//  names in BHTikTok's own reference (AWEPlayVideoPlayerController,
//  TIKTOKProfileHeaderView) do not exist as exact strings on this build at all and
//  are not declared here until their replacements are found and confirmed the same
//  way.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// The feed/detail model for one video. `-isAds` is the server's own mark for a
/// promoted item, read here rather than guessed at: BHTikTok's own ad-hiding hook
/// gates on exactly this property, and the property name itself is confirmed present
/// as a string in this build's binary.
@interface AWEAwemeModel : NSObject
@property (nonatomic, readonly) BOOL isAds;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
@end
