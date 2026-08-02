#import "SCIYTStreamAPI.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

///
/// The client identities to ask as, in order.
///
/// Both are public InnerTube clients, and both are still served plain format URLs — which
/// the app's own client is not. Two rather than one because they fail differently: a
/// video that one refuses on age or region grounds the other often serves, and trying the
/// second costs one request on a path that has already failed.
///
/// The keys are not secrets. They are the public API keys those clients ship with, the
/// same way a web page's API key is public — they identify the client, they do not
/// authorise anything.
///
static NSArray<NSDictionary *> *SCIClients(void) {
    static NSArray *clients = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        clients = @[
            @{
                @"name": @"MEDIA_CONNECT_FRONTEND",
                @"key": @"AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
                @"context": @{
                    @"client": @{
                        @"hl": @"en",
                        @"gl": @"US",
                        @"clientName": @"MEDIA_CONNECT_FRONTEND",
                        @"clientVersion": @"0.1",
                    },
                },
            },
            @{
                @"name": @"IOS",
                @"key": @"AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
                @"userAgent": @"com.google.ios.youtube/19.09.3 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)",
                @"context": @{
                    @"client": @{
                        @"hl": @"en",
                        @"gl": @"US",
                        @"clientName": @"IOS",
                        @"clientVersion": @"19.09.3",
                        @"deviceModel": @"iPhone14,3",
                    },
                },
            },
        ];
    });
    return clients;
}


@implementation SCIYTStreamAPI

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];

        // No cookies, deliberately. The request is meant to look like one of the clients
        // below asking about one video; carrying the signed-in session would make it a
        // request about this account instead, which is both unnecessary and more than the
        // question needs.
        config.HTTPCookieStorage = nil;
        config.URLCache = nil;
        config.timeoutIntervalForRequest = 12;
        config.timeoutIntervalForResource = 20;

        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

/// Does the reply actually carry links, or is it another wall?
///
/// Checked before the reply is accepted rather than after the sheet is built: a response
/// that parses but carries no url is the exact failure this whole class exists to get
/// past, and reporting it as "no formats" would be the same misleading message all over
/// again.
+ (BOOL)streamingData:(NSDictionary *)streamingData carriesLinks:(NSInteger *)counted {
    NSInteger withURL = 0;

    for (NSString *key in @[@"adaptiveFormats", @"formats"]) {
        NSArray *list = streamingData[key];
        if (![list isKindOfClass:[NSArray class]]) continue;

        for (NSDictionary *format in list) {
            if (![format isKindOfClass:[NSDictionary class]]) continue;
            NSString *url = format[@"url"];
            if ([url isKindOfClass:[NSString class]] && [url hasPrefix:@"http"]) withURL++;
        }
    }

    if (counted) *counted = withURL;
    return withURL > 0;
}

+ (void)ask:(NSUInteger)index
    forVideo:(NSString *)videoID
  completion:(void (^)(NSDictionary *, NSString *))completion {

    NSArray<NSDictionary *> *clients = SCIClients();
    if (index >= clients.count) {
        completion(nil, SCILocalized(@"dl_api_no_links"));
        return;
    }

    NSDictionary *client = clients[index];

    NSString *address = [NSString stringWithFormat:
        @"https://www.youtube.com/youtubei/v1/player?key=%@&prettyPrint=false", client[@"key"]];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    if (client[@"userAgent"]) {
        [request setValue:client[@"userAgent"] forHTTPHeaderField:@"User-Agent"];
    }

    // contentCheckOk and racyCheckOk together are what stop the server answering with an
    // "are you sure" interstitial instead of the streams for anything age-gated.
    NSDictionary *body = @{
        @"context": client[@"context"],
        @"contentCheckOk": @YES,
        @"racyCheckOk": @YES,
        @"videoId": videoID,
    };

    NSError *encodeError = nil;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encodeError];
    if (!request.HTTPBody) {
        completion(nil, encodeError.localizedDescription);
        return;
    }

    SCILogV(@"streams: asking as %@", client[@"name"]);

    NSURLSessionDataTask *task = [[self session] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        // Every failure below falls through to the next client rather than giving up,
        // because the two are refused by different videos.
        void (^next)(NSString *) = ^(NSString *why) {
            SCILogV(@"streams: %@ did not answer usefully — %@", client[@"name"], why);
            [self ask:index + 1 forVideo:videoID completion:completion];
        };

        if (error || !data) {
            next(error.localizedDescription ?: @"no data");
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (status != 200) {
            next([NSString stringWithFormat:@"HTTP %ld", (long)status]);
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) {
            next(@"unreadable JSON");
            return;
        }

        // The server says why when it will not serve a video -- private, removed, blocked
        // in this country. Passing that sentence through is far more useful than the
        // tweak inventing one.
        NSDictionary *status_ = json[@"playabilityStatus"];
        NSString *playability = [status_ isKindOfClass:[NSDictionary class]] ? status_[@"status"] : nil;

        NSDictionary *streamingData = json[@"streamingData"];
        if (![streamingData isKindOfClass:[NSDictionary class]]) {
            NSString *reason = [status_ isKindOfClass:[NSDictionary class]] ? status_[@"reason"] : nil;
            next([NSString stringWithFormat:@"%@%@",
                playability ?: @"no streamingData",
                [reason isKindOfClass:[NSString class]] ? [@": " stringByAppendingString:reason] : @""]);
            return;
        }

        NSInteger withLinks = 0;
        if (![self streamingData:streamingData carriesLinks:&withLinks]) {
            next(@"formats carry no url");
            return;
        }

        SCILogV(@"streams: %@ answered with %ld links", client[@"name"], (long)withLinks);

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(streamingData, nil);
        });
    }];

    [task resume];
}

+ (void)streamingDataForVideo:(NSString *)videoID
                   completion:(void (^)(NSDictionary *, NSString *))completion {
    if (!completion) return;

    if (!videoID.length) {
        completion(nil, SCILocalized(@"dl_why_no_data"));
        return;
    }

    // Every path out of -ask: that does not already hop to the main queue arrives here on
    // a background one, and the caller puts up UI.
    [self ask:0 forVideo:videoID completion:^(NSDictionary *streamingData, NSString *failure) {
        if ([NSThread isMainThread]) {
            completion(streamingData, failure);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(streamingData, failure);
            });
        }
    }];
}

@end
