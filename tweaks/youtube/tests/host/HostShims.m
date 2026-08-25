//
//  HostShims.m
//  Albrhi for YouTube — host tests
//
//  **The one thing the demuxer touches that a Mac has no business running.**
//
//  `SCIYTTransport` records what it did into the tweak's diagnostics screen, which drags in a
//  view controller, the settings registry and half the UI. Compiling that to test byte parsing
//  would be testing everything except the thing under test.
//
//  So the diagnostics class is stubbed: the same selectors, doing nothing. It is a shim and not a
//  fake -- nothing here asserts on it, and if a test ever needs to, it should record instead of
//  swallowing rather than the test reaching around it.
//
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface SCIYTDiagnostics : NSObject
@end

@implementation SCIYTDiagnostics

+ (BOOL)resolveInstanceMethod:(SEL)selector {
    // Every class-method call this shim receives is answered with a no-op that returns nil/zero,
    // which is what a diagnostics recorder does when nobody is reading it.
    return NO;
}

+ (BOOL)resolveClassMethod:(SEL)selector {
    class_addMethod(object_getClass(self), selector, imp_implementationWithBlock(^(id _self) { return nil; }), "@@:");
    return YES;
}

@end
