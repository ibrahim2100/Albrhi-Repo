#import "SCIKeychain.h"
#import <Security/Security.h>

static NSString *const kService = @"com.albrhi.licences";

@implementation SCIKeychain

+ (NSMutableDictionary *)queryFor:(NSString *)key {
    return [@{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kService,
        (__bridge id)kSecAttrAccount: key,
    } mutableCopy];
}

+ (NSString *)stringForKey:(NSString *)key {
    NSMutableDictionary *query = [self queryFor:key];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef found = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &found) != errSecSuccess) return nil;

    NSData *data = (__bridge_transfer NSData *)found;
    return data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

+ (BOOL)setString:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *query = [self queryFor:key];

    // Deleted first rather than updated. An update needs to know whether the item exists, and
    // asking is a second failure mode for no gain: the only state that matters here is what is
    // stored afterwards.
    SecItemDelete((__bridge CFDictionaryRef)query);

    if (!value.length) return YES;

    query[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
    query[(__bridge id)kSecAttrAccessible] =
        (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

@end
