#import "SCIPanelBackup.h"
#import "SCIPanelDomain.h"

// Stamped into every file this writes, and demanded of every file it reads back. A plist
// picked from Files is any plist at all until something says otherwise, and applying a
// stranger's dictionary to Albrhi's domain is how a restore becomes a corruption.
static NSString *const kSCIBackupMarker = @"albrhi_backup_format";
static NSString *const kSCIBackupPayload = @"values";

NSURL *SCIPanelBackupWrite(void) {
    CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)kSCIPanelPreferenceDomain,
                                               kCFPreferencesCurrentUser,
                                               kCFPreferencesAnyHost);
    if (!keys) return nil;

    CFDictionaryRef values = CFPreferencesCopyMultiple(keys,
                                                       (__bridge CFStringRef)kSCIPanelPreferenceDomain,
                                                       kCFPreferencesCurrentUser,
                                                       kCFPreferencesAnyHost);
    CFRelease(keys);
    if (!values) return nil;

    NSDictionary *payload = (__bridge_transfer NSDictionary *)values;

    NSDateFormatter *stamp = [[NSDateFormatter alloc] init];
    stamp.dateFormat = @"yyyy-MM-dd-HHmm";
    stamp.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    NSDictionary *file = @{
        kSCIBackupMarker: @1,
        @"created": [NSDate date],
        kSCIBackupPayload: payload
    };

    NSString *name = [NSString stringWithFormat:@"Albrhi-%@.plist", [stamp stringFromDate:[NSDate date]]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:file
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&error];
    if (!data || ![data writeToURL:url atomically:YES]) return nil;

    return url;
}

NSInteger SCIPanelBackupRestore(NSURL *url) {
    if (!url) return -1;

    // A file picked from another app arrives security-scoped, and reading it without asking
    // returns nothing at all rather than an error worth showing.
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (scoped) [url stopAccessingSecurityScopedResource];

    if (!data) return -1;

    id plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    if (![plist isKindOfClass:[NSDictionary class]]) return -1;

    NSDictionary *file = plist;
    if (!file[kSCIBackupMarker]) return -1;

    NSDictionary *values = file[kSCIBackupPayload];
    if (![values isKindOfClass:[NSDictionary class]]) return -1;

    NSInteger written = 0;
    for (NSString *key in values) {
        if (![key isKindOfClass:[NSString class]]) continue;

        CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                 (__bridge CFPropertyListRef)values[key],
                                 (__bridge CFStringRef)kSCIPanelPreferenceDomain);
        written++;
    }

    // Written through immediately, for the reason the switch rows already do it: the next thing
    // anyone does is relaunch an app, and cfprefsd's own schedule is slower than that.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelPreferenceDomain);

    return written;
}
