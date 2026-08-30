//
//  SCITWLinks.h
//  Albrhi for X
//
//  What a link says, and what it carries.
//
//  Two separate things, deliberately kept apart. **Expanding** a `t.co` wrapper is about
//  what you can see before you tap; **stripping** `s` and `t` is about what leaves with the
//  link when you paste it somewhere else. Those two parameters identify the account that
//  shared the post, so a link copied out of X and sent to somebody is carrying a name that
//  was never meant to travel with it.
//
//  Neither tells X's servers anything untrue. That is the line this project keeps, and it
//  is why `app_attest_*` is not offered while these are.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWLinksReport(void);
void SCITWInstallLinks(void);
