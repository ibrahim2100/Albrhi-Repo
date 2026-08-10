#import <Foundation/Foundation.h>
#import "SCILKMediaHooks.h"
#import "SCILKMedia.h"
#import "SCILog.h"

///
/// The capture, on NSURLSession.
///
/// Every way the app can start a data task is hooked, because the image loaders Locket uses
/// do not all take the same one: some pass a request, some a bare URL, some a completion
/// handler and some a delegate. Capturing at the request — before the task runs, regardless
/// of how the result comes back — sees all of them, and asks SCILKMedia to keep only the
/// ones that are a moment. Nothing here waits on or reads the response; it only notes the
/// URL, so it adds nothing to the time a fetch takes.
///
/// Grouped so the constructor installs it after the panel gate. NSURLSession is always
/// present, so the group is only about that gating, not about a class that might be absent.
///

%group Media

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    [SCILKMedia captureRequest:request];
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    [SCILKMedia captureRequest:request];
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    if (url) [SCILKMedia captureRequest:[NSURLRequest requestWithURL:url]];
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (url) [SCILKMedia captureRequest:[NSURLRequest requestWithURL:url]];
    return %orig;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    [SCILKMedia captureRequest:request];
    return %orig;
}

%end

%end


void SCILKInstallMediaHooks(void) {
    %init(Media);
    SCILogV(@"moment capture attached");
}
