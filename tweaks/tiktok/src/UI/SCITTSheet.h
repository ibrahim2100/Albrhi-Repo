//
//  SCITTSheet.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// One choice on a sheet.
@interface SCITTSheetAction : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbol;
/// The accent-filled row. At most one per sheet -- two things that both look like the answer is
/// the same as none.
@property (nonatomic, assign) BOOL primary;
@property (nonatomic, copy) void (^handler)(void);

+ (instancetype)title:(NSString *)title
               symbol:(NSString *)symbol
              primary:(BOOL)primary
              handler:(void (^)(void))handler;

@end

///
/// The tweak's own dialog, in the tweak's own material.
///
/// **Why not `UIAlertController`.** Three of this tweak's questions are asked mid-scroll, over
/// TikTok's black feed: a like confirmation, which picture of a post to save, and how much of the
/// sound to keep. A system alert in that place is a bright grey rectangle with no relationship to
/// anything else the tweak draws — the saving banner is a dark blurred capsule and the feed button
/// is a dark blurred disc — so the one moment the tweak has to look deliberate is the one moment it
/// looked like a system error. This is the same material, the same corner curve and the same accent
/// as both of those, so all three read as one hand.
///
/// **It is a view in the key window rather than a presented view controller, and that is not a
/// shortcut.** TikTok frequently has something presented already — a comment sheet, a profile, its
/// own alerts — and presenting onto a controller that is mid-transition either fails silently or
/// throws. A view added to the window has no presentation state to conflict with, which is also why
/// the confirmations can be asked from inside a tap handler without knowing what is on screen.
///
@interface SCITTSheet : NSObject

/// Shows the sheet. `cancel` may be nil for a sheet with no way out but an answer -- though every
/// caller here passes one, since a question with no cancel is a demand.
+ (void)showTitle:(NSString *)title
          message:(NSString *)message
           symbol:(NSString *)symbol
          actions:(NSArray<SCITTSheetAction *> *)actions
           cancel:(NSString *)cancel;

/// Whether there is a window to draw in. A caller that cannot ask has to decide what to do instead,
/// and that decision belongs to the caller -- the download path answers it by saving the picture the
/// user was looking at rather than by refusing.
+ (BOOL)canPresent;

@end
