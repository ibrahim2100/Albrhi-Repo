//
//  AlbrhiTestKit.h
//  Albrhi — host tests
//
//  Thirty lines instead of a framework. What a test needs here is a name, an assertion and a
//  tally; XCTest would need a bundle, a runner and a scheme, none of which this repository has.
//
#import <Foundation/Foundation.h>

extern NSInteger AlbrhiTestsPassed;
extern NSInteger AlbrhiTestsFailed;

// **Variadic on purpose.** A test body is a brace block, and a brace block containing a C array
// literal contains commas at the top level -- so a two-argument macro splits the body at the first
// one and reports "use of undeclared identifier" pointing at the *next* test. Caught by writing a
// test whose fixture was a byte array, which is most of them.
#define ALBRHI_TEST(name, ...) \
    do { \
        NSString *_albrhiTestName = @#name; \
        __block BOOL _albrhiOK = YES; \
        NSString *_albrhiWhy = nil; \
        @try { __VA_ARGS__ } @catch (id e) { _albrhiOK = NO; _albrhiWhy = [NSString stringWithFormat:@"exception: %@", e]; } \
        if (_albrhiOK && !_albrhiWhy) { AlbrhiTestsPassed++; printf("  ok    %s\n", _albrhiTestName.UTF8String); } \
        else { AlbrhiTestsFailed++; printf("  FAIL  %s — %s\n", _albrhiTestName.UTF8String, (_albrhiWhy ?: @"assertion failed").UTF8String); } \
    } while (0)

#define ALBRHI_ASSERT(condition, why) \
    do { if (!(condition)) { _albrhiOK = NO; if (!_albrhiWhy) _albrhiWhy = (why); } } while (0)
