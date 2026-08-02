#import "SCIYTStreamAPI.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// The client identities to ask as, in order.
///
/// These are public InnerTube clients, and the keys are not secrets: they identify a
/// client the way a web page's API key does, and authorise nothing.
///
/// Four rather than two, because they are refused differently and this is a moving
/// target. The two taken from a reference tweak were answered with HTTP 403 and HTTP
/// 400 on a real device — that tweak's build predates whatever changed, and a client
/// identity copied from a working project is a lead with a shelf life, not a fact.
/// The embedded-player clients below are the ones that historically outlive the rest,
/// because a page embedding a video has to be served one.
///
/// Each carries its numeric id as well as its name: the server wants the client in the
/// request headers *and* in the body, and a request that declares it in only one of the
/// two is a request it cannot place.
///
static NSArray<NSDictionary *> *SCIClients(void) {
    static NSArray *clients = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        clients = @[
            @{
                @"name": @"IOS",
                @"clientID": @"5",
                @"key": @"AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
                @"userAgent": @"com.google.ios.youtube/19.09.3 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)",
                @"context": @{
                    @"client": @{
                        @"hl": @"en",
                        @"gl": @"US",
                        @"clientName": @"IOS",
                        @"clientVersion": @"19.09.3",
                        @"deviceMake": @"Apple",
                        @"deviceModel": @"iPhone14,3",
                        @"osName": @"iPhone",
                        @"osVersion": @"15.6.0.19G71",
                        @"platform": @"MOBILE",
                    },
                },
            },
            @{
                @"name": @"TVHTML5_SIMPLY_EMBEDDED_PLAYER",
                @"clientID": @"85",
                @"key": @"AIzaSyDCU8hByM-4DrUqRUYnGn-3llEO78bcxq8",
                @"context": @{
                    @"client": @{
                        @"hl": @"en",
                        @"gl": @"US",
                        @"clientName": @"TVHTML5_SIMPLY_EMBEDDED_PLAYER",
                        @"clientVersion": @"2.0",
                        @"clientScreen": @"EMBED",
                        @"platform": @"TV",
                    },
                    // An embedded player is always playing on behalf of a page, and the
                    // server expects to be told which. Left as YouTube's own watch page,
                    // which is where the video is in fact being watched.
                    @"thirdParty": @{@"embedUrl": @"https://www.youtube.com/"},
                },
            },
            @{
                @"name": @"WEB_EMBEDDED_PLAYER",
                @"clientID": @"56",
                @"key": @"AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8",
                @"context": @{
                    @"client": @{
                        @"hl": @"en",
                        @"gl": @"US",
                        @"clientName": @"WEB_EMBEDDED_PLAYER",
                        @"clientVersion": @"1.20240101.00.00",
                        @"clientScreen": @"EMBED",
                        @"platform": @"DESKTOP",
                    },
                    @"thirdParty": @{@"embedUrl": @"https://www.youtube.com/"},
                },
            },
            @{
                @"name": @"MEDIA_CONNECT_FRONTEND",
                @"clientID": @"95",
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

    // The headers InnerTube expects alongside the context, which 0.7.2 left out.
    //
    // The client is declared twice on purpose -- once in the JSON body and once in
    // these headers -- and the server checks both. A request carrying only the body
    // is a request the server cannot place, which is what an HTTP 400 on a
    // well-formed body means.
    //
    // X-Goog-Api-Format-Version selects the error shape as well as the request one, so
    // it is also what makes the message read above worth reading.
    [request setValue:client[@"clientID"] forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [request setValue:client[@"context"][@"client"][@"clientVersion"]
   forHTTPHeaderField:@"X-YouTube-Client-Version"];
    [request setValue:@"2" forHTTPHeaderField:@"X-Goog-Api-Format-Version"];
    [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];

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

            // Written down, because "no downloadable formats" covers a client that was
            // refused, one that answered without links, and one that never replied --
            // and those need different fixes.
            [SCIYTDiagnostics recordStreamAttempt:
                [NSString stringWithFormat:@"%@ (%@): %@", client[@"name"], videoID, why]];

            [self ask:index + 1 forVideo:videoID completion:completion];
        };

        if (error || !data) {
            next(error.localizedDescription ?: @"no data");
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (status != 200) {
            // The body, not just the number. A 400 and a 403 both mean "no" and mean
            // completely different things: one is a request the server could not read,
            // the other a client it will not serve. InnerTube says which in a JSON
            // error message, and 0.7.2 threw that away and reported the digits -- so a
            // report could say the wall was hit without saying which wall.
            NSString *detail = nil;

            NSDictionary *envelope = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:nil];
            if ([envelope isKindOfClass:[NSDictionary class]]) {
                NSDictionary *problem = envelope[@"error"];
                if ([problem isKindOfClass:[NSDictionary class]]) {
                    NSString *message = problem[@"message"];
                    NSString *reason = nil;

                    NSArray *errors = problem[@"errors"];
                    if ([errors isKindOfClass:[NSArray class]] && errors.count) {
                        NSDictionary *first = errors.firstObject;
                        if ([first isKindOfClass:[NSDictionary class]]) reason = first[@"reason"];
                    }

                    detail = [NSString stringWithFormat:@"%@%@",
                        [message isKindOfClass:[NSString class]] ? message : @"",
                        [reason isKindOfClass:[NSString class]]
                            ? [NSString stringWithFormat:@" (%@)", reason] : @""];
                }
            }

            if (!detail.length) {
                // Not JSON, or not shaped like an error envelope. The opening of the
                // body is still worth more than nothing.
                NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                detail = text.length > 160 ? [text substringToIndex:160] : text;
            }

            next([NSString stringWithFormat:@"HTTP %ld — %@", (long)status,
                  detail.length ? detail : @"no message"]);
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

        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"%@ (%@): %ld links", client[@"name"], videoID, (long)withLinks]];

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

    // Not cleared here. The download starts each round and clears it there, having
    // already written down what the player walk found -- clearing again at this point
    // would erase the line that says why the network is being asked at all.

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
