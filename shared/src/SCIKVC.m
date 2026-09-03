#import "SCIKVC.h"
#import <objc/runtime.h>
#import <objc/message.h>

/// The selectors KVC tries, in KVC's own documented order.
///
/// **That order is `getKey`, `key`, `isKey`, `_getKey`, `_key` — `getKey` first, not last.**
/// This function shipped with it last, on a comment asserting Foundation does the same, which
/// Foundation does not. It changes nothing unless a class declares two of them and they
/// disagree; the point is that a replacement for KVC has to match KVC, and an ordering asserted
/// from memory is not a match.
static SEL SCIGetterFor(NSString *key, id object) {
    if (!key.length) return NULL;

    NSString *capitalised = [[key substringToIndex:1].uppercaseString
                             stringByAppendingString:[key substringFromIndex:1]];

    NSString *names[] = {
        [@"get" stringByAppendingString:capitalised],
        key,
        [@"is" stringByAppendingString:capitalised],
        [@"_get" stringByAppendingString:capitalised],
        [@"_" stringByAppendingString:key],
    };

    for (NSUInteger i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        SEL selector = NSSelectorFromString(names[i]);
        if (selector && [object respondsToSelector:selector]) return selector;
    }
    return NULL;
}

/// A selector's return-type encoding — from the method if there is one, and from the object's
/// own method signature if there is not.
///
/// **`class_getInstanceMethod` returning NULL does not mean the object cannot answer.** A class
/// may resolve a selector dynamically (`+resolveInstanceMethod:`) or forward it
/// (`-forwardingTargetForSelector:`): `-respondsToSelector:` says YES and there is no `Method`
/// to read an encoding from. `LSApplicationProxy` is exactly such a class, and the first version
/// of this file treated the missing encoding as "not an object" and answered nil — which is how
/// Albrhi Panel stopped showing some apps' versions after the sweep that introduced this file.
/// The reasoning was right and one of its inputs was silently absent.
///
/// `-methodSignatureForSelector:` is the answer: it is what the forwarding machinery itself
/// consults, so it works precisely in the cases the method list does not.
static const char *SCIReturnEncoding(id object, SEL selector) {
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (method) {
        const char *encoding = method_getTypeEncoding(method);
        if (encoding && encoding[0]) return encoding;
    }

    if (![object respondsToSelector:@selector(methodSignatureForSelector:)]) return NULL;

    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    return signature.methodReturnType;
}

/// Whether a method hands back an object.
///
/// A getter that returns a scalar cannot be called through an `id`-returning cast: the
/// value comes back in a different register and of a different width, which is the same
/// mistake that crashed TikTok twice over a guessed `objc_msgSend` cast. A return type that
/// cannot be read at all is stepped over rather than guessed at.
static BOOL SCIReturnsObject(id object, SEL selector) {
    const char *encoding = SCIReturnEncoding(object, selector);
    if (!encoding || !encoding[0]) return NO;

    // The return type is the first character of a method's encoding. `@` is an object and
    // `#` is a Class, which is also safely an id.
    return encoding[0] == '@' || encoding[0] == '#';
}

/// The `_key` or `key` ivar, but only when the runtime says it holds an object.
///
/// `object_getIvar` executes nothing. This is the branch that makes the whole function
/// *safer* than the `-valueForKey:` it replaces rather than merely equivalent: KVC would
/// reach the same ivar by running its own machinery and boxing a scalar on the way, and a
/// half-built object is exactly where that has ended a process here before.
static id SCIObjectIvar(id object, NSString *key) {
    Class cls = object_getClass(object);
    if (!cls) return nil;

    NSString *underscored = [@"_" stringByAppendingString:key];
    Ivar ivar = class_getInstanceVariable(cls, underscored.UTF8String);
    if (!ivar) ivar = class_getInstanceVariable(cls, key.UTF8String);
    if (!ivar) return nil;

    const char *type = ivar_getTypeEncoding(ivar);
    if (!type || (type[0] != '@' && type[0] != '#')) return nil;

    return object_getIvar(object, ivar);
}

id SCISafeValueForKey(id object, NSString *key) {
    if (!object || !key.length) return nil;

    SEL getter = SCIGetterFor(key, object);
    if (getter && SCIReturnsObject(object, getter)) {
        id (*send)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        return send(object, getter);
    }

    // A getter that exists but does not return an object is deliberately not read through
    // the ivar behind it either -- if the class declares an accessor, the accessor is the
    // answer, and "it answers with a number" is a real answer of the wrong kind rather
    // than an absence to route around.
    if (getter) return nil;

    return SCIObjectIvar(object, key);
}

NSNumber *SCISafeNumberForKey(id object, NSString *key) {
    if (!object || !key.length) return nil;

    SEL getter = SCIGetterFor(key, object);
    if (!getter) {
        id boxed = SCIObjectIvar(object, key);
        return [boxed isKindOfClass:[NSNumber class]] ? boxed : nil;
    }

    const char *encoding = SCIReturnEncoding(object, getter);
    if (!encoding || !encoding[0]) return nil;

    switch (encoding[0]) {
        case 'B': case 'c': {
            BOOL (*send)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            return @(send(object, getter));
        }
        case 'q': case 'l': case 'i': case 's': {
            long long (*send)(id, SEL) = (long long (*)(id, SEL))objc_msgSend;
            return @(send(object, getter));
        }
        case 'Q': case 'L': case 'I': case 'S': {
            unsigned long long (*send)(id, SEL) = (unsigned long long (*)(id, SEL))objc_msgSend;
            return @(send(object, getter));
        }
        case 'd': {
            double (*send)(id, SEL) = (double (*)(id, SEL))objc_msgSend;
            return @(send(object, getter));
        }
        case 'f': {
            float (*send)(id, SEL) = (float (*)(id, SEL))objc_msgSend;
            return @(send(object, getter));
        }
        case '@': case '#': {
            id value = SCISafeValueForKey(object, key);
            return [value isKindOfClass:[NSNumber class]] ? value : nil;
        }
        default:
            // Not guessed at, for the reason the whole file exists: a wrong cast puts the
            // value in the wrong register and this project has crashed an app twice that way.
            return nil;
    }
}

BOOL SCISafeBoolForKey(id object, NSString *key) {
    // Through the object path on purpose: a BOOL property's getter returns a scalar, so
    // SCISafeValueForKey steps over it and this would answer NO for a real YES. Asked
    // directly here, with the encoding checked the same way.
    if (!object || !key.length) return NO;

    SEL getter = SCIGetterFor(key, object);
    if (!getter) {
        id boxed = SCIObjectIvar(object, key);
        return [boxed respondsToSelector:@selector(boolValue)] ? [boxed boolValue] : NO;
    }

    const char *encoding = SCIReturnEncoding(object, getter);
    if (!encoding || !encoding[0]) return NO;

    switch (encoding[0]) {
        case 'B': case 'c': {
            BOOL (*send)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            return send(object, getter);
        }
        case 'q': case 'l': case 'i': case 's': {
            long long (*send)(id, SEL) = (long long (*)(id, SEL))objc_msgSend;
            return send(object, getter) != 0;
        }
        case 'Q': case 'L': case 'I': case 'S': {
            unsigned long long (*send)(id, SEL) = (unsigned long long (*)(id, SEL))objc_msgSend;
            return send(object, getter) != 0;
        }
        case '@': case '#': {
            id value = SCISafeValueForKey(object, key);
            return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (value != nil);
        }
        default:
            // An encoding this does not know about is not guessed at. Scoring it NO costs a
            // feature; casting it wrongly costs the process.
            return NO;
    }
}
