#import "SCICPDiagnostics.h"
#import "../Localization/SCILocalize.h"

static NSMutableArray<NSString *> *sciLines = nil;
static NSUInteger const kSCIMaxLines = 200;

@implementation SCICPDiagnostics

+ (void)record:(NSString *)line {
    if (!line.length) return;

    @synchronized (self) {
        if (!sciLines) sciLines = [NSMutableArray array];

        NSString *stamped = [NSString stringWithFormat:@"%@  %@",
            [NSDateFormatter localizedStringFromDate:[NSDate date]
                                            dateStyle:NSDateFormatterNoStyle
                                            timeStyle:NSDateFormatterMediumStyle],
            line];

        [sciLines addObject:stamped];
        if (sciLines.count > kSCIMaxLines) [sciLines removeObjectAtIndex:0];
    }

    [self writeReportToFile];
}

+ (NSArray<NSString *> *)lines {
    @synchronized (self) {
        return [sciLines copy] ?: @[];
    }
}

+ (NSString *)writeReportToFile {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!documents.length) return nil;

    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%@\n", SCILocalized(@"report_title")];
    [text appendFormat:@"app %@\n", [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];
    [text appendFormat:@"written %@\n\n", [NSDate date]];

    for (NSString *line in [self lines]) {
        [text appendFormat:@"%@\n", line];
    }

    NSString *name = @"AlbrhiCP-report.txt";
    NSString *path = [documents stringByAppendingPathComponent:name];

    NSError *error = nil;
    BOOL wrote = [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    return wrote ? name : nil;
}

@end
