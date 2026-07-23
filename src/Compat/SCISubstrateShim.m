//
// A self-contained replacement for the one Substrate symbol Logos needs.
//
// Compiled only into the sideload build (-DSCI_SELFCONTAINED). The jailbreak
// packages are untouched: there Substrate is present and is used exactly as
// before, and this file compiles to nothing.
//
// Why this is small: hooking an Objective-C method needs nothing but the
// Objective-C runtime, which is part of iOS. Substrate's value is hooking C
// functions — which this tweak never does. Every %hook Logos generates comes down
// to a single call to MSHookMessageEx, so defining that one function is the whole
// job, and the 42 feature files stay exactly as they are.
//
// MSHookIvar needs no counterpart: substrate.h defines it inline over
// class_getInstanceVariable, so it never was an external dependency.
//

#ifdef SCI_SELFCONTAINED

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// Replaces `selector` on `cls` with `replacement`, handing back the previous
/// implementation so %orig still works.
///
/// The inherited case is the subtle one. class_replaceMethod returns NULL when
/// the class did not implement the selector itself — it has just been added — and
/// the implementation %orig must reach is the superclass's. Returning NULL there
/// would make every %orig on an inherited method crash.
void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *result) {
    if (!cls || !selector || !replacement) {
        if (result) *result = NULL;
        return;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        // Absent in this build of Instagram. Substrate is equally forgiving here,
        // and a missing class or selector should disable one feature rather than
        // take the app down.
        if (result) *result = NULL;
        return;
    }

    const char *types = method_getTypeEncoding(method);
    IMP previous = class_replaceMethod(cls, selector, replacement, types);

    if (!previous) previous = method_getImplementation(method);

    if (result) *result = previous;
}

#endif  /* SCI_SELFCONTAINED */
