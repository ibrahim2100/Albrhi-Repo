//
//  SCITWRepostConfirm.h
//  Albrhi for Twitter
//
//  A confirmation before Retweet goes out -- the same reasoning behind every other
//  confirmation this project has shipped: a mis-tap on Like is between you and a
//  notification; a mis-tap on Retweet is between you and everyone who follows you, and
//  there is no undo that reaches whoever already saw it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks the retweet button, if this build has it. Safe when it does not.
void SCITWInstallRepostConfirm(void);

/// Whether the class was found and the hook attached.
NSString *SCITWRepostConfirmReport(void);
