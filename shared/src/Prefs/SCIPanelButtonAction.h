#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

/// What a button row does when it is tapped.
///
/// `specifier->action = @selector(...)` is the usual way to write this and it needs
/// the ivar to be declared in whichever `PSSpecifier.h` the build happens to use -- a
/// header that lives outside this repository and that nothing here controls. Assuming
/// the shape of a header nobody in this project owns is how the panel lost a build to
/// a missing private framework already.
///
/// So it is asked for instead: the setter where iOS has one, the ivar by name where
/// it does not, and nothing at all if neither is there -- which is a button that does
/// nothing rather than a page that will not compile.
void SCISetButtonAction(PSSpecifier *specifier, SEL action);

NS_ASSUME_NONNULL_END
