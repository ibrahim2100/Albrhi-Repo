//
//  SCIWUpdateProbe.h
//  Albrhi Watch
//

#import <Foundation/Foundation.h>

///
/// Asks the device what its own update and sync classes actually look like — and hooks nothing.
///
/// **Every class this tweak wants next lives in the dyld shared cache, which is not a file we can
/// read on iOS 16.** The Watch app's binary names them (`SUBManager`, `COSSoftwareUpdateController`)
/// and nothing more: no method list, no type encodings. This project has already paid four crashes
/// for hooks declared from a selector's *name*, the worst of them a `^q` out-parameter written as
/// an `NSInteger`, so the classes are asked at runtime instead, in the process where they exist.
///
/// The result is a report a person can copy out of Settings. One device round trip answers what a
/// 3 GB cache extraction would have.
///
void SCIWRunUpdateProbe(void);

/// The probe's findings, as text. Never nil.
NSString *SCIWUpdateProbeReport(void);
