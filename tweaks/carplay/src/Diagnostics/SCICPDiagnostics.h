#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// What this tweak actually did, from the two processes it runs in.
///
/// There is no settings screen yet -- see CHANGELOG.md -- so this is the only way to
/// know anything happened at all. Written to a file in Camera's own container on every
/// recording, because that is the process a person will actually go looking in, and
/// SpringBoard has no Documents directory a person can reach from the Files app.
///
@interface SCICPDiagnostics : NSObject

/// A short, human-readable line. Recorded, not thrown: a diagnostics call must never be
/// the reason a hook fails.
+ (void)record:(NSString *)line;

/// Every line recorded this launch, oldest first.
+ (NSArray<NSString *> *)lines;

/// Writes the report to Camera's container as AlbrhiCP-report.txt. Returns the file
/// name on success.
+ (nullable NSString *)writeReportToFile;

@end

NS_ASSUME_NONNULL_END
