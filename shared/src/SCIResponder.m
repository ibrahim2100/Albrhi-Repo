#import "SCIResponder.h"

UIViewController *SCIControllerForResponder(UIResponder *responder) {
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }

    UIViewController *controller = (UIViewController *)responder;

    // Down to whatever is on top. A controller that is presenting something cannot present
    // anything else, and UIKit's refusal is a line in the log rather than a return value --
    // which is precisely how "the button does nothing" has been reported here before.
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

UIViewController *SCIControllerForView(UIView *view) {
    return SCIControllerForResponder(view);
}
