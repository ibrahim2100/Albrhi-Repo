//
//  SCIYTNotice.h
//  Albrhi for YouTube
//
//  Telling you a download finished, when you are not looking at the app.
//
//  Now that transfers continue while YouTube is closed, the moment a save finishes is a
//  moment nobody is watching -- which is the whole point, and also means the Centre's row
//  quietly turning green is a result delivered to an empty room.
//
//  **Progress on the lock screen is not possible from here, and it is worth saying why
//  rather than half-attempting it.** A live progress bar there is a Live Activity, which
//  requires a signed app extension declared in the host's Info.plist. Nothing injected into
//  another app can provide one. What is available is an ordinary local notification, which
//  is delivered to the lock screen like any other -- so this announces the ending rather
//  than pretending to narrate the middle.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@class SCIYTJob;

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTNotice : NSObject

/// Says a save finished, or why it did not.
///
/// Silent when the app is in front: a banner over the screen that already shows the finished
/// row is noise, and the row is the better answer while you are there.
///
/// Permission is asked for once, the first time there is something to say. Asking at launch
/// would be a prompt before the tweak had done anything to justify it.
+ (void)announceFinished:(SCIYTJob *)job;
+ (void)announceFailed:(SCIYTJob *)job reason:(nullable NSString *)reason;

@end

NS_ASSUME_NONNULL_END
