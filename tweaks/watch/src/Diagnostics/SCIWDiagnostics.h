//
//  SCIWDiagnostics.h
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3, except the pairing core (MIT, see
//  LICENSE-watched).
//

#import <Foundation/Foundation.h>

///
/// What actually happened inside SpringBoard, for the page in Settings.
///
/// **A pairing tweak cannot be watched while it works.** The screen that would show a mistake
/// is the pairing screen itself, on a device that has already refused, and the only feedback a
/// person gets is "it did not pair" -- which is what every possible cause looks like. So each
/// answer is counted where it is given: the classes that were present at launch, how many times
/// each gate answered, and the last watch version that was read.
///
void SCIWRecordClass(NSString *name, BOOL present);
void SCIWRecordAnswer(NSString *gate);
void SCIWRecordWatchVersion(NSInteger major, NSInteger hostMajor);

/// One line per subject, for the settings page. Never nil.
NSString *SCIWClassReport(void);
NSString *SCIWAnswerReport(void);
NSString *SCIWVersionReport(void);
