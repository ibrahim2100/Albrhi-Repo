//
//  SCIYTMSaveSheet.h
//  Albrhi for YouTube Music
//
//  The card that asks what to call a track and where to keep it.
//
//  **A view of ours in the key window, not a `UIAlertController`.** The system alert was correct
//  and looked like nothing: a grey box with two bare fields, the app's own identity nowhere on it,
//  and a layout that cannot show a section list, an artwork thumbnail or anything else this is
//  going to want. It is also the wrong shape for the question -- an alert is for a decision, and
//  this is a short form.
//
//  Presented by adding it to the window rather than by presenting a controller, which is the same
//  reason TikTok's own sheet is built that way here: there is no presentation state to conflict
//  with whatever the app is already showing, and a music app is very often already showing
//  something.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTMSaveSheet : NSObject

/// Asks, then calls back with the name and section chosen. `onSave` is not called if the sheet is
/// dismissed, and it is called on the main thread.
+ (void)askForName:(NSString *)suggestedName
           section:(NSString *)suggestedSection
          sections:(NSArray<NSString *> *)existingSections
            onSave:(void (^)(NSString *name, NSString *section))onSave;

@end

NS_ASSUME_NONNULL_END
