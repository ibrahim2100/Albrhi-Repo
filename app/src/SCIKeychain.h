//
//  SCIKeychain.h
//  Albrhi Licences
//
//  **The admin token, kept where a token belongs.**
//
//  That one string is the whole of the API's authority: whatever holds it can issue a licence, and
//  revoke every licence already sold. The web panel keeps it in the browser's storage because a
//  page has nowhere better; an app does — the Keychain, which survives a reinstall, is encrypted
//  at rest, and is not readable by anything else on the phone.
//
//  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: the token does not leave for a backup and does
//  not restore onto a different phone. Losing it costs one minute — rotating an admin token is a
//  Worker secret and a redeploy — and that is a far smaller price than it being anywhere else.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIKeychain : NSObject

+ (nullable NSString *)stringForKey:(NSString *)key;
+ (BOOL)setString:(nullable NSString *)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
