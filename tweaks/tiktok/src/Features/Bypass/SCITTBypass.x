#import <Foundation/Foundation.h>
#import "SCITTBypass.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"

///
/// Every hook here answers one question TikTok's own code asks about the device, the
/// way an unmodified phone would answer it. Nothing here touches a purchase, a receipt
/// value, or a subscription flag -- that line is deliberate, the same one Locket's own
/// bypass keeps, and reviewed the same way before writing a line of this file.
///
/// Each class is declared where it is hooked, forward-declared as `NSObject` with only
/// the one selector this file sends it -- the same minimal-declaration discipline the
/// rest of this project uses for a hooked class it does not otherwise touch.
///

@interface TTAdSplashDeviceHelper : NSObject
@end

@interface GULAppEnvironmentUtil : NSObject
@end

@interface FBSDKAppEventsUtility : NSObject
@end

@interface AWEAPMManager : NSObject
@end

@interface AWESecurity : NSObject
- (void)resetCollectMode;
@end


%group Bypass

// The direct question: is this device jailbroken. Confirmed as a real selector on
// TikTok 46.4.0's own binary before this was written, not guessed at.
%hook TTAdSplashDeviceHelper

+ (BOOL)isJailBroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isJailBroken"];
    return NO;
}

%end


// Google's own environment probe, asked here for whether the app looks like a genuine
// App Store install running as itself.
%hook GULAppEnvironmentUtil

+ (BOOL)isFromAppStore {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isFromAppStore"];
    return YES;
}

+ (BOOL)isAppStoreReceiptSandbox {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isAppStoreReceiptSandbox"];
    return NO;
}

+ (BOOL)isAppExtension {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isAppExtension"];
    return YES;
}

%end


// Meta's SDK, asked whether this is a debug build -- a jailbroken, resigned app can
// answer this differently from a genuine App Store one.
%hook FBSDKAppEventsUtility

+ (BOOL)isDebugBuild {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isDebugBuild"];
    return NO;
}

%end


// TikTok's own signing-info check, answered as a plain App Store install.
%hook AWEAPMManager

+ (id)signInfo {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"signInfo"];
    return @"AppStore";
}

%end


// Whatever this collects, it is collected about the device's own modification state --
// answered by doing nothing, the same shape as every hook above it.
%hook AWESecurity

- (void)resetCollectMode {
    if (!SCIPrefEnabled(SCIPrefBypass)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordBypassAnswer:@"resetCollectMode"];
}

%end


// A signed app has no embedded provisioning profile; a resigned one usually does, and
// this is one of the places that gets checked for. Only the one file extension is
// touched -- every other resource lookup passes straight through.
%hook NSBundle

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension {
    if ([extension isEqualToString:@"mobileprovision"] && SCIPrefEnabled(SCIPrefBypass)) {
        [SCITTDiagnostics recordBypassAnswer:@"mobileprovision lookup"];
        return nil;
    }
    return %orig;
}

%end

%end


void SCITTInstallBypass(void) {
    %init(Bypass);
    SCILogV(@"bypass hooks attached");
}
