//
//  SCIPanelPlans.h
//  Albrhi Panel
//
//  The screen somebody actually buys from.
//
//  **A card of ours in the window, not a `UIAlertController`.** The alert it replaces was correct
//  and looked like nothing: two bare text fields asking for a number of days, in a grey box with
//  Albrhi's name nowhere on it. That is the wrong shape twice over — an alert is for a decision,
//  and this is a choice between priced things — and it made the one screen where somebody decides
//  whether to pay look like an error dialog.
//
//  It is added to the window rather than presented, which is the same reason the TikTok sheet and
//  the YouTube Music save card are built that way here: there is no presentation state to conflict
//  with, and Settings is very often already showing something.
//
//  The free week sits at the top and is taken in place, without leaving the screen. Everything
//  below it opens a message with the device code already written in — because the alternative is
//  asking a person to copy a sixteen-character string out of one screen and into another, which
//  is where a purchase is lost.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIPanelPlans : NSObject

/// Shows the card over `host`.
///
/// **The host is passed rather than looked up**, because the first version searched
/// `UIApplication.windows` for a key window and did nothing at all when it did not find one — in
/// Settings, which is where this runs. A silent nothing is the worst outcome available to a button
/// somebody presses in order to buy something, so this takes the controller that already exists,
/// falls back to a window only if it must, and puts up an alert rather than returning quietly.
///
/// `onChange` fires whenever something happened that the page behind it should redraw for — a
/// trial taken, a request sent — and it is called on the main thread.
+ (void)presentFrom:(UIViewController *)host change:(void (^_Nullable)(void))onChange;

@end

NS_ASSUME_NONNULL_END
