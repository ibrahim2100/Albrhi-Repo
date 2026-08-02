//
//  SCIYTChoiceSheet.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"
#import "../SCIYTHLS.h"

NS_ASSUME_NONNULL_BEGIN

///
/// What to save, and at what size.
///
/// One screen instead of two alerts. A list of qualities in a UIAlertController is what
/// this used to be, and it read as a system prompt about something going wrong rather
/// than a choice about a video — eight identically-sized rows of "1080p", "720p", with
/// nothing to look at and nothing to tell them apart at a glance.
///
/// So: a card at the top for sound or pictures, and the sizes below it as rows that say
/// how big each one is. Built out of a table and stack views — no hand-written
/// constraints between siblings, which is what took the settings panel down twice.
///
@interface SCIYTChoiceSheet : UIViewController

/// Presents it, and calls back with what was chosen. Never calls back if dismissed.
+ (void)presentFrom:(UIViewController *)presenter
           variants:(NSArray<SCIHLSVariant *> *)variants
              title:(nullable NSString *)title
             chosen:(void (^)(SCIHLSVariant *variant, SCIYTJobKind kind))chosen;

@end

NS_ASSUME_NONNULL_END
