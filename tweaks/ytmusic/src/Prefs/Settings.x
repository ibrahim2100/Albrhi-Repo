//
//  Settings.x
//  Albrhi for YouTube Music
//
//  **The screen ten features were shipped without.** 0.2.0 and 0.3.0 carried the hooks and
//  not the page that controls them, so a device had lyrics, a speed button and a theme with
//  no way to reach a single option -- reported exactly that way, and correctly.
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3. The edits: the
//  button carries this project's name, the %group gets an installer called after Albrhi's
//  gate, and the root page below drops the Premium and scrobbling rows -- one for a feature
//  deliberately not carried, one for code that is not here.
//
#import <UIKit/UIKit.h>
#import "shared/src/SCIKVC.h"
#import <objc/message.h>
#import "YTMUltimateSettingsController.h"
#import "../Headers/Localization.h"

@interface YTMAccountButton : UIButton
- (id)initWithTitle:(id)arg1 identifier:(id)arg2 icon:(id)arg3 actionBlock:(void (^)(BOOL finished))arg4;
@end

@interface YTMAvatarAccountView : UIView
@end

@interface UIView (Private)
- (id)_viewControllerForAncestor;
@end

@interface YTISupportedMessageRendererIcons : NSObject
@property (nonatomic, assign, readwrite) int iconType;
@end

@interface YTIMessageRenderer : NSObject
@property (nonatomic, strong, readwrite) YTISupportedMessageRendererIcons *icon;
@end

@interface YTMLightweightMessageCell : UIView
@end

@interface YTMMessageView : UIView
@property (nonatomic, weak, readwrite) YTMLightweightMessageCell *delegate;
@end

//
// **The same private method that crashed the downloader, guarded the same way.**
//
// `-_viewControllerForAncestor` is a private `UIView` method: it is exact where it exists and an
// unrecognised selector where it does not. The lyrics module already asks `-respondsToSelector:`
// before sending it; this file, carried over later, did not -- and it would have failed the first
// time somebody opened the account menu on a build without it.
//
static UIViewController *SCIYTMSettingsOwner(UIView *view) {
    if (!view) return nil;

    SEL ancestor = NSSelectorFromString(@"_viewControllerForAncestor");
    if ([view respondsToSelector:ancestor]) {
        id owner = ((id (*)(id, SEL))objc_msgSend)(view, ancestor);
        if ([owner isKindOfClass:[UIViewController class]]) return owner;
    }

    for (UIResponder *responder = view; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
    }

    return nil;
}

%group SettingsPage
%hook YTMAvatarAccountView

- (void)setAccountMenuUpperButtons:(id)arg1 lowerButtons:(id)arg2 {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
    UIImage *icon = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        UIImage *flameImage = [UIImage systemImageNamed:@"flame"];
        UIView *imageView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
        UIImageView *flameImageView = [[UIImageView alloc] initWithImage:flameImage];
        flameImageView.contentMode = UIViewContentModeScaleAspectFit;
        flameImageView.clipsToBounds = YES;
        flameImageView.tintColor = [UIColor redColor];
        flameImageView.frame = imageView.bounds;

        [imageView addSubview:flameImageView];
        [imageView.layer renderInContext:rendererContext.CGContext];
    }];

    //Create the YTMEnhanced button
    YTMAccountButton *button = [[%c(YTMAccountButton) alloc] initWithTitle:@"Albrhi" identifier:@"albrhi" icon:icon actionBlock:^(BOOL arg4) {
        //Push the settings view controller.
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[YTMUltimateSettingsController alloc] init]];
        [nav setModalPresentationStyle: UIModalPresentationFullScreen];
        [SCIYTMSettingsOwner(self) presentViewController:nav animated:YES completion:nil];
    }];

    button.tintColor = [UIColor redColor];

    //Add our custom button to the list.
    NSMutableArray *arrDown = [[NSMutableArray alloc] init];
    [arrDown addObjectsFromArray:arg2];
    [arrDown addObject:button];

    //Remove the subscribe to premium button on old versions
    NSMutableArray *arrUp = [[NSMutableArray alloc] init];
    for (YTMAccountButton *yt_button in arg1) {
        if (![[yt_button.titleLabel text] containsString:@"Premium"]) {
            [arrUp addObject:yt_button];
        }
    }

    //Continue the function with our own parameters.
    %orig(arrUp, arrDown);
}
%end

@interface YTMAvatarAccountViewController : UIViewController
@end

@interface YTMNavigationDrawerPromoView : UIView
@end

// Remove the subscribe to premium button on new versions
%hook YTMNavigationDrawerPromoView
- (void)loadModel:(id)model {
    if ([SCIYTMSettingsOwner(self) isKindOfClass:%c(YTMAvatarAccountViewController)]) {
        return [self removeFromSuperview];
    }

    %orig(model);
}
%end

%hook YTMMessageView
- (void)setMessageText:(id)arg1 {
    if (![self.delegate isKindOfClass:%c(YTMLightweightMessageCell)]) {
        return %orig;
    }

    YTMLightweightMessageCell *msgCell = (YTMLightweightMessageCell *)self.delegate;
    YTIMessageRenderer *renderer = SCISafeValueForKey(msgCell, @"_renderer");

    if (renderer.icon.iconType != 187) {
        return %orig;
    }

    %orig(LOC(@"REGIONAL_RESTRICTION"));
}
%end
%end


void SCIYTMInstallSettings(void) { %init(SettingsPage); }
