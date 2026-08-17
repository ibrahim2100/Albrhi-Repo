//
//  TikTokHeaders.h
//  Albrhi for TikTok
//
//  Every TikTok class this tweak touches, declared once.
//
//  Confirmed real on TikTok 46.4.0 by reading MusicallyCore.framework's own Mach-O
//  sections directly (class and selector name strings), and cross-checked against the
//  exact `_ungrouped$Class$selector` Logos symbols two independent debug builds
//  actually shipped -- NA9 For TikTok and VibeTok, both compiled with debug info
//  intact. Where both agree on a class-and-selector pair, that pair is trusted more
//  than either alone. Read for architecture only; no code is taken from either.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// The feed/detail model for one video. `-isAds` is the server's own mark for a
/// promoted item, confirmed as a real property name in this build's own binary.
///
/// `-videoModel` was never more than circumstantial -- string-table proximity to
/// `playAddr`/`bitratePlayAddr`, not a hooked selector either reference tweak
/// overrides -- and a live device report has since confirmed it outright wrong on a
/// real 46.4.0 install: `-respondsToSelector:@selector(videoModel)` answers NO.
/// `SCITTMedia.m` no longer sends it as the only path; it tries several candidate
/// chains in turn (including `-video`, `-playURL`, `-url` -- real selectors read from
/// NA9's own `_objc_msgSend$…` message-send stubs, not guessed names) and records
/// which one, if any, actually resolves on the device this tweak is running on.
/// `isAd`, `isAdItem` and `isAdsOrPseudoAds` sit beside `isAds` in the same run of the
/// binary's own string table -- the same circumstantial standard `-videoModel` is held
/// to below, not a hooked selector either reference tweak overrides. `SCITTAdBlock.x`
/// checks `-respondsToSelector:` before reading any of the four, and drops a model on
/// any one of them answering YES rather than requiring all four to exist.
@interface AWEAwemeModel : NSObject
@property (nonatomic, readonly) BOOL isAds;
@property (nonatomic, readonly) BOOL isAd;
@property (nonatomic, readonly) BOOL isAdItem;
@property (nonatomic, readonly) BOOL isAdsOrPseudoAds;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
@end

/// The URL container `AWEAwemeModel.videoModel.playAddr` resolves to.
/// `-bestURLtoDownload` is confirmed twice over: present as a string in this build's
/// own binary, and the exact selector both NA9 and VibeTok call to get a downloadable
/// link (via `_ungrouped$AWEURLModel$bestURLtoDownload` in NA9's own symbol table).
@interface AWEURLModel : NSObject
- (nullable id)bestURLtoDownload;
@end
