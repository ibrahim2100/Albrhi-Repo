#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

///
/// What SCICPAdmissionSpoof.m and SCICPSceneManifestSpoof.m both need to hook
/// `LSBundleProxy` safely. Header rather than duplicated in both files, and
/// header-only rather than its own `.m` because there is nothing here worth a
/// translation unit of its own.
///

static inline NSString *SCICPLSProxyBundleIdentifier(id proxy) {
    SEL sel = @selector(bundleIdentifier);
    if (![proxy respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

/// Guarded the same way every other hook in this project is: never installed unless
/// the class and the exact selector are both already there, and never adds a method
/// that was not already declared -- a selector this iOS build renamed is a spoof that
/// silently does nothing, not a crash.
static inline BOOL SCICPSwizzleInstanceMethod(Class cls, SEL sel, IMP replacement,
                                               IMP *outOriginal) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return NO;

    if (outOriginal) *outOriginal = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}
