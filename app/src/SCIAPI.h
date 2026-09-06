//
//  SCIAPI.h
//  Albrhi Licences
//
//  **The licence server, spoken to directly.**
//
//  The first version of this app was the published web panel in a web view, which was the right
//  first step: six tables and a dialog already existed and were used every day. What it could not
//  be is an iPhone app — no tab bar, no pull to refresh that means anything, no notification when
//  a request arrives, and a token living in a page's storage.
//
//  So the screens are native and this is what they talk to. The API is the same one the panel
//  uses: one bearer token, JSON in and out, and every route already documented in server/.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIAPI : NSObject

/// Where the server is, and the token that may command it. Both live in the Keychain; these read
/// and write there rather than keeping a copy.
+ (nullable NSString *)base;

/// Whether that address was chosen here or is the one built in. Two different facts, and only one
/// of them is worth checking when something stops working.
+ (BOOL)baseIsMine;
+ (void)setBase:(nullable NSString *)base;
+ (nullable NSString *)token;
+ (void)setToken:(nullable NSString *)token;

/// Configured means: an https address and a token. Anything less and every screen shows the same
/// sentence pointing at Settings rather than a spinner that never resolves.
+ (BOOL)isConfigured;

/// GET/POST against the admin API. `body` nil means GET.
///
/// The completion always arrives on the main queue, because every caller is a table. `error` is a
/// sentence to show a person, never a stack: the one useful thing on this side is whether it was
/// the network, the token or the server, and each of those has its own words.
+ (void)call:(NSString *)path
        body:(nullable NSDictionary *)body
        then:(void (^)(NSDictionary *_Nullable answer, NSString *_Nullable error))then;

/// The whole state in one call, as the panel fetches it: requests, licences, trials, codes.
+ (void)state:(void (^)(NSDictionary *_Nullable state, NSString *_Nullable error))then;

/// The stores, which are a second call on purpose -- most days have nothing to say about them and
/// every refresh should not pay for the listing.
+ (void)stores:(void (^)(NSArray *_Nullable stores, NSString *_Nullable error))then;

@end

NS_ASSUME_NONNULL_END
