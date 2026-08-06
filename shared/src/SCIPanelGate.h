//
//  SCIPanelGate.h
//  Shared by every Albrhi tweak.
//
//  Whether this tweak is switched on for the app it has just been loaded into.
//
//  Albrhi Panel lists the apps on the device and offers a switch per app. The switch
//  cannot change what gets *injected* — rewriting a tweak's filter file needs root, and a
//  preference bundle runs as `mobile` — so it changes what the injected code *does*. The
//  dylib still loads; with the switch off it answers every preference as NO and every
//  feature stands down.
//
//  This is the same shape DLEasy uses, and the reason is the same: its filter names twenty
//  apps and cannot name a twenty-first, so per-app control had to be a runtime question.
//
//  **The preference is read through CFPreferences, not by opening the file.** A tweak runs
//  inside a sandboxed app and cannot read another process's plist off disk; cfprefsd sits
//  outside the sandbox and is reachable from inside it, which is why every tweak with a
//  settings bundle uses this call and not NSDictionary+contentsOfFile.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// YES unless the panel has been used to switch this app off.
///
/// Defaults to YES on purpose: a device that has never opened the panel has no preference
/// written, and reading that absence as "off" would silently disable a tweak somebody
/// installed deliberately.
///
/// Read once and kept. The value is consulted on paths that run during layout and playback,
/// and a cross-process preference lookup on each of those would show. Changing the switch
/// therefore takes effect when the app is next launched, which the panel says plainly rather
/// than leaving anyone to wonder.
BOOL SCIPanelAllowsThisApp(void);

/// How that answer was arrived at, for a diagnostics page.
///
/// "The switch does nothing" has several explanations that look identical from the app —
/// the preference was never written, or it was written where this process cannot see it,
/// or it was read correctly and says on. They need different fixes, and the first version
/// of this could not tell them apart, which is why the switch appeared to do nothing and
/// nothing said why.
///
/// Returns something like "off (file: /var/mobile/…)" or "on (nothing written)".
NSString *SCIPanelGateReport(void);

#ifdef __cplusplus
}
#endif
