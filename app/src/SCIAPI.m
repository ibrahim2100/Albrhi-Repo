#import "SCIAPI.h"
#import "SCIKeychain.h"

static NSString *const kBaseKey  = @"server-base";
static NSString *const kTokenKey = @"admin-token";

@implementation SCIAPI

/// The same address every tweak is built with.
///
/// **Typed by nobody.** The tweaks have had this compiled in since the licence layer shipped, for
/// the reason written down there: telling a person a URL and asking them to type it correctly is
/// a support conversation before anything has even been tried, and a single wrong character
/// answers «no such route on the server» — a sentence about the server that is really about the
/// typing. A stored address still wins, for a staging deployment.
static NSString *const kDefaultBase = @"https://albrhi-licence.ibrahimalrahan01.workers.dev";

+ (NSString *)base {
    NSString *stored = [SCIKeychain stringForKey:kBaseKey];
    return stored.length ? stored : kDefaultBase;
}

+ (BOOL)baseIsMine { return [SCIKeychain stringForKey:kBaseKey].length > 0; }
+ (NSString *)token { return [SCIKeychain stringForKey:kTokenKey]; }

+ (void)setBase:(NSString *)base {
    // Trailing slash removed once, here, rather than at every call site: a base ending in one and
    // a path beginning with one make a URL with two, which some servers answer and some do not.
    NSString *clean = [base stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([clean hasSuffix:@"/"]) clean = [clean substringToIndex:clean.length - 1];

    [SCIKeychain setString:clean forKey:kBaseKey];
}

+ (void)setToken:(NSString *)token {
    [SCIKeychain setString:[token stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:kTokenKey];
}

+ (BOOL)isConfigured {
    NSString *base = [self base];
    return [base hasPrefix:@"https://"] && [self token].length > 0;
}

+ (void)call:(NSString *)path body:(NSDictionary *)body
        then:(void (^)(NSDictionary *_Nullable, NSString *_Nullable))then {

    void (^finish)(NSDictionary *, NSString *) = ^(NSDictionary *answer, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ then(answer, error); });
    };

    if (![self isConfigured]) {
        finish(nil, @"لا عنوان أو لا رمز — افتح الإعدادات");
        return;
    }

    NSURL *url = [NSURL URLWithString:[[self base] stringByAppendingString:path]];
    if (!url) { finish(nil, @"العنوان غير صالح"); return; }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = body ? @"POST" : @"GET";
    request.timeoutInterval = 20;
    [request setValue:[@"Bearer " stringByAppendingString:[self token]]
   forHTTPHeaderField:@"authorization"];

    if (body) {
        [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    }

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    [[[NSURLSession sessionWithConfiguration:configuration] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *failure) {

        if (failure) { finish(nil, failure.localizedDescription); return; }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode : 0;

        id parsed = data.length
            ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        NSDictionary *answer = [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;

        // **Three refusals need three sentences.** A wrong token, a route that does not exist and
        // a server saying no are different problems, and one message covering all of them sends
        // somebody to check the wrong thing.
        if (status == 401) { finish(nil, @"الرمز مرفوض — تحقّق من رمز الإدارة"); return; }
        if (status == 404) {
            // With the address named. «No such route» on its own sends somebody to check the
            // server, and the answer is almost always the address they are asking it at.
            finish(nil, [NSString stringWithFormat:@"لا وجود لهذا المسار على الخادم:\n%@",
                         url.absoluteString]);
            return;
        }
        if (status != 200) {
            NSString *why = answer[@"error"] ?: answer[@"state"];
            finish(nil, why ?: [NSString stringWithFormat:@"الخادم أجاب %ld", (long)status]);
            return;
        }

        if (!answer) { finish(nil, @"جواب غير مفهوم من الخادم"); return; }
        finish(answer, nil);
    }] resume];
}

#pragma mark - The copy on disk

static NSTimeInterval sciStaleSince = 0;

+ (NSTimeInterval)staleSince { return sciStaleSince; }

+ (NSURL *)cacheFor:(NSString *)name {
    NSURL *directory = [[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [directory URLByAppendingPathComponent:name];
}

/// Kept in Caches on purpose: iOS may reclaim it, and losing it costs one refresh. A customer
/// list has no business sitting in a backed-up directory when the server is its home.
+ (void)keep:(NSDictionary *)answer as:(NSString *)name {
    NSMutableDictionary *wrapped = [@{@"at": @([NSDate date].timeIntervalSince1970)} mutableCopy];
    wrapped[@"answer"] = answer;

    NSData *data = [NSJSONSerialization dataWithJSONObject:wrapped options:0 error:NULL];
    [data writeToURL:[self cacheFor:name] atomically:YES];
}

+ (NSDictionary *)keptAs:(NSString *)name at:(NSTimeInterval *)at {
    NSData *data = [NSData dataWithContentsOfURL:[self cacheFor:name]];
    if (!data) return nil;

    id wrapped = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![wrapped isKindOfClass:[NSDictionary class]]) return nil;

    if (at) *at = [wrapped[@"at"] doubleValue];
    id answer = wrapped[@"answer"];
    return [answer isKindOfClass:[NSDictionary class]] ? answer : nil;
}

+ (void)state:(void (^)(NSDictionary *_Nullable, NSString *_Nullable))then {
    [self call:@"/admin/state" body:nil then:^(NSDictionary *answer, NSString *error) {
        if (!error && answer) {
            sciStaleSince = 0;
            [self keep:answer as:@"state.json"];
            then(answer, nil);
            return;
        }

        // **The copy is offered, and its age is said.** Silently showing an hour-old list as
        // though it were live is worse than the error was: every screen would be plausible and
        // some of it wrong, and nothing on it would say so.
        NSTimeInterval at = 0;
        NSDictionary *kept = [self keptAs:@"state.json" at:&at];
        if (kept) {
            sciStaleSince = at;
            then(kept, nil);
            return;
        }

        then(nil, error);
    }];
}

+ (void)exportAll:(void (^)(NSData *_Nullable, NSString *_Nullable))then {
    [self call:@"/admin/export" body:nil then:^(NSDictionary *answer, NSString *error) {
        if (error) { then(nil, error); return; }

        // Written out again rather than handing over the bytes that arrived: the file that lands
        // in Files is then indented and readable by whoever opens it in a hurry, which is the
        // only circumstance in which anyone ever opens a backup.
        NSData *data = [NSJSONSerialization dataWithJSONObject:answer
                                                        options:NSJSONWritingPrettyPrinted
                                                          error:NULL];
        then(data, data ? nil : @"تعذّرت كتابة الملف");
    }];
}

+ (void)stores:(void (^)(NSArray *_Nullable, NSString *_Nullable))then {
    [self call:@"/admin/stores" body:nil then:^(NSDictionary *answer, NSString *error) {
        if (!error && answer) {
            [self keep:answer as:@"stores.json"];
            id stores = answer[@"stores"];
            then([stores isKindOfClass:[NSArray class]] ? stores : nil, nil);
            return;
        }

        NSDictionary *kept = [self keptAs:@"stores.json" at:NULL];
        id stores = kept[@"stores"];
        then([stores isKindOfClass:[NSArray class]] ? stores : nil, kept ? nil : error);
    }];
}

@end
