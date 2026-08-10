//
//  SCILKShield.h
//  Albrhi for Locket
//
//  The judgement, kept apart from the hooks that call it.
//
//  A jailbreak check is not one question. It is a small fixed set: does this file exist,
//  can this URL scheme be opened, is this folder writable, is this variable in the
//  environment. Every detector — Locket's own, AppsFlyer's, OneSignal's — asks some subset
//  of those, and the honest answer on a jailbroken phone is yes, which is the answer that
//  gets counted against the account.
//
//  **This file decides only whether a given path or scheme is one of those questions.** It
//  does not hook anything. The hooks in SCILKBypass.x ask it, and when it says "yes, this
//  is a jailbreak probe" they answer as an unmodified phone would. Keeping the list here,
//  in plain C and Objective-C, means it can be reasoned about and counted without reading
//  through Logos, and means the rule that matters most — *only* lie about these, pass
//  everything else through — is in one place rather than repeated at each hook.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Is this filesystem path one a jailbreak check looks at?
///
/// True for the Cydia/Sileo/Zebra apps, the substrate and tweak-injection libraries, the
/// apt and dpkg trees, the ssh daemon, the roothide and rootless prefixes, and the loose
/// binaries (/bin/bash and friends) that only exist once a phone is jailbroken. False for
/// everything else — which is almost everything, and all of it has to keep working.
BOOL SCILKPathIsJailbreakProbe(const char *path);

/// Is this a write to somewhere only a jailbroken phone can write?
///
/// A common check does not look for a file — it tries to *create* one outside the app's
/// sandbox (`/private/jb-test`, say) and treats success as proof. A sandboxed app cannot
/// write there anyway, so answering "no you cannot" changes nothing for a normal app and
/// removes the one signal the check was after. `mode` is the fopen mode string.
BOOL SCILKWriteIsSandboxProbe(const char *path, const char *mode);

/// Is this a URL scheme a jailbreak check probes with `-canOpenURL:`?
///
/// cydia://, sileo://, zbra://, filza://, and the rest. An app that legitimately wanted to
/// open one of these would be a package manager, and Locket is not.
BOOL SCILKSchemeIsJailbreakProbe(NSString *scheme);

/// Is this environment variable one a check reads to spot an injected library?
///
/// `DYLD_INSERT_LIBRARIES` above all: its presence is how a tweak is loaded, and reading it
/// back is the cheapest detection there is.
BOOL SCILKEnvIsJailbreakProbe(const char *name);

/// Records that a probe was answered, for the status screen. `kind` is a short label the
/// screen groups by — "file", "scheme", "env", "onesignal". Cheap and thread-safe: this is
/// called from the filesystem hooks, which run often.
void SCILKNoteIntercept(NSString *kind, NSString *detail);

/// How many probes have been answered, in total.
NSUInteger SCILKInterceptCount(void);

/// The counts per kind, and a few recent details, for the status screen.
NSDictionary<NSString *, NSNumber *> *SCILKInterceptsByKind(void);
NSArray<NSString *> *SCILKRecentIntercepts(void);

#ifdef __cplusplus
}
#endif
