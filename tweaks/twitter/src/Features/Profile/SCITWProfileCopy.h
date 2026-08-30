//
//  SCITWProfileCopy.h
//  Albrhi for X
//
//  Copying what a profile says.
//
//  A long press on the profile header offers the name, the handle and the bio as text. X
//  draws all three as labels it does not let you select, which is the whole reason this
//  exists — and it is why the text is read out of the labels themselves rather than out of
//  a model: what is on screen is what somebody asked to copy, including whatever X decided
//  to truncate or translate.
//
//  The gesture is added in `-viewDidAppear:`, once, marked on the view so a controller that
//  appears again does not collect a second recogniser.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWProfileCopyReport(void);
void SCITWInstallProfileCopy(void);
