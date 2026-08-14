#import "SCICPScreenWatch.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <UIKit/UIKit.h>

static BOOL sciStarted = NO;

@implementation SCICPScreenWatch

+ (void)start {
    if (sciStarted) return;
    sciStarted = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sci_screenChanged:)
                                                 name:UIScreenDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sci_screenChanged:)
                                                 name:UIScreenDidDisconnectNotification
                                               object:nil];

    SCILogV(@"screen: watching, currently %@",
            [self isExternalScreenConnected] ? @"connected" : @"not connected");

    // Whatever was already true when SpringBoard finished launching -- this class starts
    // from the %ctor, and a phone can be plugged into CarPlay before the launch that
    // installs it ever happens.
    if ([self isExternalScreenConnected]) {
        [SCICPDiagnostics record:[@"external screen already present at launch — "
            stringByAppendingString:[self sci_describeExternalScreens]]];
    }
}

+ (BOOL)isExternalScreenConnected {
    // More than the main screen. UIScreen.mainScreen is always present and is not the
    // one being asked about here.
    return [UIScreen screens].count > 1;
}

+ (NSString *)sci_describeExternalScreens {
    NSMutableArray<NSString *> *descriptions = [NSMutableArray array];

    for (UIScreen *screen in [UIScreen screens]) {
        if (screen == [UIScreen mainScreen]) continue;
        [descriptions addObject:[NSString stringWithFormat:@"%@ (%.0fx%.0f @%.0fx)",
            NSStringFromClass([screen class]),
            screen.bounds.size.width, screen.bounds.size.height, screen.scale]];
    }

    return descriptions.count ? [descriptions componentsJoinedByString:@", "] : @"none";
}

+ (void)sci_screenChanged:(NSNotification *)notification {
    BOOL connected = [notification.name isEqualToString:UIScreenDidConnectNotification];

    SCILogV(@"screen: %@ — %@", connected ? @"connected" : @"disconnected",
            [self sci_describeExternalScreens]);

    [SCICPDiagnostics record:[NSString stringWithFormat:@"external screen %@ — %@",
        connected ? @"connected" : @"disconnected", [self sci_describeExternalScreens]]];
}

@end
