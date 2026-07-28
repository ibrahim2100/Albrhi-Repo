#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One feature, and whether the thing it needs is actually present in this build.
@interface SCIFeatureAuditResult : NSObject

@property (nonatomic, copy) NSString *feature;      ///< shown to the user
@property (nonatomic, copy) NSString *detail;       ///< what was looked for
@property (nonatomic, assign) BOOL attached;        ///< the target exists here

@end

///
/// Checks every feature against the Instagram it is running on.
///
/// A tweak feature stops working when Instagram renames the class or method it
/// attaches to, and it does so silently: the toggle is still there, still on, and
/// nothing happens. Every diagnosis in this project so far has started with someone
/// noticing that by accident, days later.
///
/// This asks the runtime directly — is the class Albrhi needs here, does it still
/// have the method — and reports the answer per feature. It cannot say a feature
/// behaves correctly, only that what it hooks still exists, which is the difference
/// between "broken by an Instagram update" and "working but wrong", and that is the
/// question that has taken longest to answer each time.
///
@interface SCIFeatureAudit : NSObject

/// Runs the whole audit. Cheap: class and method lookups only, nothing is called.
+ (NSArray<SCIFeatureAuditResult *> *)run;

/// "12 of 14 features attached", for the row that starts the audit.
+ (NSString *)summaryForResults:(NSArray<SCIFeatureAuditResult *> *)results;

@end

NS_ASSUME_NONNULL_END
