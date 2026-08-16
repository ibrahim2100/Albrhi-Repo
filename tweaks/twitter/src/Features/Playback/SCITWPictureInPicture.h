//
//  SCITWPictureInPicture.h
//  Albrhi for Twitter
//
//  What was asked for could not honestly be shipped as a toggle -- this is the record
//  that decides what can replace it.
//
//  The player configuration X builds for a video does carry a picture-in-picture setting,
//  `-[TAVPlayerViewConfiguration nativePictureInPictureBehavior]` -- but it is a `long long`
//  enum, set through one of three different fifteen-argument initialisers, and nothing in
//  the class dump names what its integer values mean. Forcing a made-up number into that
//  setter is exactly the kind of guess this project has already paid for once, rejected
//  once already this same session for the same reason: a caller that assumes a value it
//  did not ask for is a caller whose behaviour on that value is unknown, and "it might
//  disable the player instead of enabling PIP" is not a risk worth a silent toggle.
//
//  So this reads the values X sets on its own, in the situations that create them, and
//  counts them. What comes back decides which integer means what, the same way the switch
//  layer itself was learned from a real report rather than a guess -- and turns into a real
//  toggle once it does.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

void SCITWInstallPictureInPictureRecorder(void);

/// Every distinct value seen, and how many times each was set -- the report a real toggle
/// will be built from.
NSString *SCITWPictureInPictureReport(void);
