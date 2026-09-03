#import "SCIPanelButtonAction.h"
#import <objc/message.h>
#import <objc/runtime.h>

void SCISetButtonAction(PSSpecifier *specifier, SEL action) {
    SEL setter = NSSelectorFromString(@"setButtonAction:");
    if ([specifier respondsToSelector:setter]) {
        ((void (*)(id, SEL, SEL))objc_msgSend)(specifier, setter, action);
        return;
    }

    Ivar ivar = class_getInstanceVariable([specifier class], "action");
    if (!ivar) return;

    SEL *slot = (SEL *)((uint8_t *)(__bridge void *)specifier + ivar_getOffset(ivar));
    *slot = action;
}
